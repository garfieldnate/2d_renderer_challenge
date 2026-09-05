import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * §1.5: the P3 PPM writer and the two little reader helpers the tests use.
 * Converting a channel to a file value: clamp to 0..1, encode, multiply by
 * 255, round. Lines are greedily word-wrapped at 70 characters; each pixel
 * row always starts a fresh line.
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

    private static int[] header(String ppm) {
        // P3 / width height / maxval -- three header lines, four tokens.
        String[] tokens = ppm.trim().split("\\s+");
        int width = Integer.parseInt(tokens[1]);
        int height = Integer.parseInt(tokens[2]);
        return new int[] {width, height};
    }

    private static int[] pixelValues(String ppm) {
        String[] tokens = ppm.trim().split("\\s+");
        int[] values = new int[tokens.length - 4];
        for (int i = 4; i < tokens.length; i++) {
            values[i - 4] = Integer.parseInt(tokens[i]);
        }
        return values;
    }

    public static int[] ppmPixel(String ppm, int x, int y) {
        int[] wh = header(ppm);
        int width = wh[0];
        int[] values = pixelValues(ppm);
        int idx = (y * width + x) * 3;
        return new int[] {values[idx], values[idx + 1], values[idx + 2]};
    }

    public static int maxChannelDifference(String a, String b) {
        int[] va = pixelValues(a);
        int[] vb = pixelValues(b);
        int max = 0;
        int n = Math.min(va.length, vb.length);
        for (int i = 0; i < n; i++) {
            max = Math.max(max, Math.abs(va[i] - vb[i]));
        }
        return max;
    }

    public static int distinctValues(String ppm) {
        int[] values = pixelValues(ppm);
        Set<Integer> distinct = new LinkedHashSet<>();
        for (int v : values) {
            distinct.add(v);
        }
        return distinct.size();
    }
}
