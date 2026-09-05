import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * §1.5: the P3 PPM writer and the two little reader helpers the tests use.
 * Converting a channel to a file value: clamp to 0..1, encode, multiply by
 * 255, round. Lines are greedily word-wrapped at 70 characters; each pixel
 * row always starts a fresh line.
 *
 * §2.2: P6 is the binary sibling -- same three header lines with a 6 in
 * place of the 3, one newline, then raw pixel bytes, nothing in between.
 * ppm_pixel, distinct_values and max_channel_difference read either format:
 * pass a String for a P3 file, a byte[] for a P6 one.
 */
public final class Ppm {
    private static final int MAX_LINE_LENGTH = 70;

    private Ppm() {}

    public static String canvasToPpm(Canvas c) {
        StringBuilder sb = new StringBuilder();
        sb.append("P3\n");
        sb.append(c.width).append(' ').append(c.height).append('\n');
        sb.append("255\n");

        for (int y = 0; y < c.height; y++) {
            StringBuilder line = new StringBuilder();
            for (int x = 0; x < c.width; x++) {
                Color col = c.pixelAt(x, y);
                appendToken(sb, line, channelToFileValue(col.red));
                appendToken(sb, line, channelToFileValue(col.green));
                appendToken(sb, line, channelToFileValue(col.blue));
            }
            sb.append(line).append('\n');
        }
        return sb.toString();
    }

    /** §2.2: the same channel-to-file-value conversion, written as raw bytes instead of digits. */
    public static byte[] canvasToP6(Canvas c) {
        byte[] header = ("P6\n" + c.width + " " + c.height + "\n255\n")
                .getBytes(StandardCharsets.US_ASCII);
        byte[] out = new byte[header.length + c.width * c.height * 3];
        System.arraycopy(header, 0, out, 0, header.length);
        int pos = header.length;
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                Color col = c.pixelAt(x, y);
                out[pos++] = (byte) channelToFileValue(col.red);
                out[pos++] = (byte) channelToFileValue(col.green);
                out[pos++] = (byte) channelToFileValue(col.blue);
            }
        }
        return out;
    }

    private static int channelToFileValue(double channel) {
        double clamped = Math.max(0.0, Math.min(1.0, channel));
        double encoded = Srgb.encode(clamped);
        return (int) Numbers.round(encoded * 255.0);
    }

    private static void appendToken(StringBuilder ppm, StringBuilder line, int value) {
        String token = Integer.toString(value);
        if (line.length() == 0) {
            line.append(token);
        } else if (line.length() + 1 + token.length() > MAX_LINE_LENGTH) {
            ppm.append(line).append('\n');
            line.setLength(0);
            line.append(token);
        } else {
            line.append(' ').append(token);
        }
    }

    /** Lines, 1-indexed in the scenarios; index 0 unused. */
    public static String[] lines(String ppm) {
        // Split off the trailing newline's empty tail; a file that "ends
        // with a newline" should not manifest as a phantom last line.
        String[] raw = ppm.split("\n", -1);
        int count = raw.length;
        if (count > 0 && raw[count - 1].isEmpty()) {
            count--;
        }
        String[] result = new String[count];
        System.arraycopy(raw, 0, result, 0, count);
        return result;
    }

    /** A parsed header (width, height) plus every channel value, in row-major RGB order. */
    private record Parsed(int width, int height, int[] values) {}

    private static byte[] toBytes(Object ppm) {
        if (ppm instanceof byte[] bytes) {
            return bytes;
        }
        if (ppm instanceof String text) {
            // A P3 file is text that happens to be stored in bytes: ASCII round-trips exactly.
            return text.getBytes(StandardCharsets.ISO_8859_1);
        }
        throw new IllegalArgumentException("expected a String (P3) or byte[] (P6), got " + ppm);
    }

    private static boolean isWhitespace(byte b) {
        return b == ' ' || b == '\n' || b == '\t' || b == '\r';
    }

    private static Parsed parse(byte[] data) {
        boolean p6 = data.length >= 2 && data[0] == 'P' && data[1] == '6';
        if (p6) {
            // P6 / width height / maxval, then exactly one whitespace byte, then raw pixel bytes.
            int pos = 0;
            String[] tokens = new String[4];
            for (int t = 0; t < 4; t++) {
                while (isWhitespace(data[pos])) {
                    pos++;
                }
                int start = pos;
                while (!isWhitespace(data[pos])) {
                    pos++;
                }
                tokens[t] = new String(data, start, pos - start, StandardCharsets.US_ASCII);
            }
            pos++; // the single whitespace byte after maxval
            int width = Integer.parseInt(tokens[1]);
            int height = Integer.parseInt(tokens[2]);
            int[] values = new int[width * height * 3];
            for (int i = 0; i < values.length; i++) {
                values[i] = data[pos + i] & 0xFF;
            }
            return new Parsed(width, height, values);
        }
        // P3 / width height / maxval -- three header lines, four tokens, then decimal values.
        String text = new String(data, StandardCharsets.ISO_8859_1);
        String[] tokens = text.trim().split("\\s+");
        int width = Integer.parseInt(tokens[1]);
        int height = Integer.parseInt(tokens[2]);
        int[] values = new int[tokens.length - 4];
        for (int i = 4; i < tokens.length; i++) {
            values[i - 4] = Integer.parseInt(tokens[i]);
        }
        return new Parsed(width, height, values);
    }

    public static int[] ppmPixel(Object ppm, int x, int y) {
        Parsed p = parse(toBytes(ppm));
        int idx = (y * p.width() + x) * 3;
        return new int[] {p.values()[idx], p.values()[idx + 1], p.values()[idx + 2]};
    }

    /**
     * §2.2: sizes still have to match. A comparison between differently-shaped
     * images isn't a pixel comparison at all, so it's reported as maximally
     * different (255) rather than compared value by value.
     */
    public static int maxChannelDifference(Object a, Object b) {
        Parsed pa = parse(toBytes(a));
        Parsed pb = parse(toBytes(b));
        if (pa.width() != pb.width() || pa.height() != pb.height()) {
            return 255;
        }
        int max = 0;
        int n = Math.min(pa.values().length, pb.values().length);
        for (int i = 0; i < n; i++) {
            max = Math.max(max, Math.abs(pa.values()[i] - pb.values()[i]));
        }
        return max;
    }

    public static int distinctValues(Object ppm) {
        int[] values = parse(toBytes(ppm)).values();
        Set<Integer> distinct = new LinkedHashSet<>();
        for (int v : values) {
            distinct.add(v);
        }
        return distinct.size();
    }
}
