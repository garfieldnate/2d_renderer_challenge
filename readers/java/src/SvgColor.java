import java.util.Map;

/**
 * §20.6: parse_color(s) reads a colour and answers it in linear light,
 * because the file's numbers are sRGB and the canvas stores light: each
 * byte b becomes decode(b / 255). It reads #rgb, #rrggbb, rgb(r, g, b)
 * (numbers 0-255 or percentages of 255, each clamped), and the seventeen
 * named colours, with hex digits and names in either case and whitespace
 * around the value ignored. Anything else is null ("none").
 */
public final class SvgColor {
    private SvgColor() {}

    private static final Map<String, int[]> NAMED = Map.ofEntries(
            Map.entry("black", new int[] {0, 0, 0}),
            Map.entry("silver", new int[] {192, 192, 192}),
            Map.entry("gray", new int[] {128, 128, 128}),
            Map.entry("white", new int[] {255, 255, 255}),
            Map.entry("maroon", new int[] {128, 0, 0}),
            Map.entry("red", new int[] {255, 0, 0}),
            Map.entry("purple", new int[] {128, 0, 128}),
            Map.entry("fuchsia", new int[] {255, 0, 255}),
            Map.entry("green", new int[] {0, 128, 0}),
            Map.entry("lime", new int[] {0, 255, 0}),
            Map.entry("olive", new int[] {128, 128, 0}),
            Map.entry("yellow", new int[] {255, 255, 0}),
            Map.entry("navy", new int[] {0, 0, 128}),
            Map.entry("blue", new int[] {0, 0, 255}),
            Map.entry("teal", new int[] {0, 128, 128}),
            Map.entry("aqua", new int[] {0, 255, 255}),
            Map.entry("orange", new int[] {255, 165, 0}));

    private static Color byteColor(double r, double g, double b) {
        return new Color(Srgb.decode(r / 255), Srgb.decode(g / 255), Srgb.decode(b / 255));
    }

    private static Integer hexNibble(char c) {
        if (c >= '0' && c <= '9') {
            return c - '0';
        }
        if (c >= 'a' && c <= 'f') {
            return c - 'a' + 10;
        }
        return null;
    }

    private static Integer hexByte(String h, int i) {
        Integer hi = hexNibble(h.charAt(i));
        Integer lo = hexNibble(h.charAt(i + 1));
        if (hi == null || lo == null) {
            return null;
        }
        return hi * 16 + lo;
    }

    public static Color parseColor(String raw) {
        String s = raw.trim();
        String low = s.toLowerCase();
        if (NAMED.containsKey(low)) {
            int[] rgb = NAMED.get(low);
            return byteColor(rgb[0], rgb[1], rgb[2]);
        }
        if (low.startsWith("#")) {
            String h = low.substring(1);
            for (int i = 0; i < h.length(); i++) {
                if (hexNibble(h.charAt(i)) == null) {
                    return null;
                }
            }
            if (h.length() == 3) {
                Integer r = hexNibble(h.charAt(0));
                Integer g = hexNibble(h.charAt(1));
                Integer b = hexNibble(h.charAt(2));
                return byteColor(r * 16 + r, g * 16 + g, b * 16 + b);
            }
            if (h.length() == 6) {
                Integer r = hexByte(h, 0);
                Integer g = hexByte(h, 2);
                Integer b = hexByte(h, 4);
                if (r == null || g == null || b == null) {
                    return null;
                }
                return byteColor(r, g, b);
            }
            return null;
        }
        if (low.startsWith("rgb(") && low.endsWith(")")) {
            String[] parts = low.substring(4, low.length() - 1).split(",", -1);
            if (parts.length != 3) {
                return null;
            }
            double[] vals = new double[3];
            for (int q = 0; q < 3; q++) {
                String p = parts[q].trim();
                if (p.isEmpty()) {
                    return null;
                }
                boolean pct = p.endsWith("%");
                String body = pct ? p.substring(0, p.length() - 1) : p;
                SvgNumbers.NumberResult r = SvgNumbers.readNumber(body, 0);
                if (r.value() == null || r.index() != body.length()) {
                    return null;
                }
                double v = pct ? r.value() * 255 / 100 : r.value();
                vals[q] = Math.min(255, Math.max(0, v));
            }
            return byteColor(vals[0], vals[1], vals[2]);
        }
        return null;
    }
}
