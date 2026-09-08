/**
 * §9.4, §9.5: blend(mode, src, dst) is source-over with the overlap passed
 * through a blend function first: out.rgb = a_s*(1-a_d)*Cs + a_s*a_d*B +
 * (1-a_s)*dst.rgb, out.a = a_s + a_d*(1-a_s). blend_color(mode, backdrop,
 * source) is that function -- the twelve separable modes act on each
 * channel of the two straight colors on its own; the four non-separable
 * ones (hue, saturation, color, luminosity) mix whole colors through three
 * helpers from the compositing spec: Lum(C) = 0.3R + 0.59G + 0.11B, Sat(C) =
 * max - min, set_lum shifts a color to a target brightness and clips it back
 * into range without changing its hue, set_sat stretches it to a target
 * saturation.
 */
public final class Blend {
    private Blend() {}

    private interface Channel {
        double apply(double backdrop, double source);
    }

    private static double screen(double b, double s) {
        return b + s - b * s;
    }

    private static double hardLight(double b, double s) {
        return s <= 0.5 ? b * 2 * s : screen(b, 2 * s - 1);
    }

    private static double softLight(double b, double s) {
        if (s <= 0.5) {
            return b - (1 - 2 * s) * b * (1 - b);
        }
        double d = b <= 0.25 ? ((16 * b - 12) * b + 4) * b : Math.sqrt(b);
        return b + (2 * s - 1) * (d - b);
    }

    private static double dodge(double b, double s) {
        if (b == 0) return 0;
        if (s == 1) return 1;
        return Math.min(1, b / (1 - s));
    }

    private static double burn(double b, double s) {
        if (b == 1) return 1;
        if (s == 0) return 0;
        return 1 - Math.min(1, (1 - b) / s);
    }

    private static Channel separable(String mode) {
        switch (mode) {
            case "normal": return (b, s) -> s;
            case "multiply": return (b, s) -> b * s;
            case "screen": return Blend::screen;
            case "overlay": return (b, s) -> hardLight(s, b);
            case "darken": return Math::min;
            case "lighten": return Math::max;
            case "color-dodge": return Blend::dodge;
            case "color-burn": return Blend::burn;
            case "hard-light": return Blend::hardLight;
            case "soft-light": return Blend::softLight;
            case "difference": return (b, s) -> Math.abs(b - s);
            case "exclusion": return (b, s) -> b + s - 2 * b * s;
            default: return null;
        }
    }

    private static boolean isSeparable(String mode) {
        return separable(mode) != null;
    }

    private static double lum(Color c) {
        return 0.3 * c.red + 0.59 * c.green + 0.11 * c.blue;
    }

    private static double sat(Color c) {
        return Math.max(c.red, Math.max(c.green, c.blue)) - Math.min(c.red, Math.min(c.green, c.blue));
    }

    private static Color clipColor(Color c) {
        double l = lum(c);
        double n = Math.min(c.red, Math.min(c.green, c.blue));
        double x = Math.max(c.red, Math.max(c.green, c.blue));
        double r = c.red;
        double g = c.green;
        double b = c.blue;
        if (n < 0) {
            r = l + (r - l) * l / (l - n);
            g = l + (g - l) * l / (l - n);
            b = l + (b - l) * l / (l - n);
        }
        if (x > 1) {
            r = l + (r - l) * (1 - l) / (x - l);
            g = l + (g - l) * (1 - l) / (x - l);
            b = l + (b - l) * (1 - l) / (x - l);
        }
        return new Color(r, g, b);
    }

    private static Color setLum(Color c, double l) {
        double d = l - lum(c);
        return clipColor(new Color(c.red + d, c.green + d, c.blue + d));
    }

    private static Color setSat(Color c, double s) {
        double[] ch = {c.red, c.green, c.blue};
        // sort indices by value, ascending
        Integer[] idx = {0, 1, 2};
        java.util.Arrays.sort(idx, (i, j) -> Double.compare(ch[i], ch[j]));
        int lo = idx[0];
        int mid = idx[1];
        int hi = idx[2];
        double[] out = {0, 0, 0};
        if (ch[hi] > ch[lo]) {
            out[mid] = (ch[mid] - ch[lo]) * s / (ch[hi] - ch[lo]);
            out[hi] = s;
        }
        out[lo] = 0;
        return new Color(out[0], out[1], out[2]);
    }

    private static Color nonSeparable(String mode, Color backdrop, Color source) {
        switch (mode) {
            case "hue": return setLum(setSat(source, sat(backdrop)), lum(backdrop));
            case "saturation": return setLum(setSat(backdrop, sat(source)), lum(backdrop));
            case "color": return setLum(source, lum(backdrop));
            case "luminosity": return setLum(backdrop, lum(source));
            default: throw new IllegalArgumentException("unknown blend mode: " + mode);
        }
    }

    public static Color blendColor(String mode, Color backdrop, Color source) {
        Channel f = separable(mode);
        if (f != null) {
            return new Color(
                    f.apply(backdrop.red, source.red),
                    f.apply(backdrop.green, source.green),
                    f.apply(backdrop.blue, source.blue));
        }
        return nonSeparable(mode, backdrop, source);
    }

    public static Pixel blend(String mode, Pixel src, Pixel dst) {
        double as = src.a;
        double ad = dst.a;
        Color cs = src.pixelColor();
        Color cb = dst.pixelColor();
        Color bcol = blendColor(mode, cb, cs);
        double r = as * (1 - ad) * cs.red + as * ad * bcol.red + (1 - as) * dst.r;
        double g = as * (1 - ad) * cs.green + as * ad * bcol.green + (1 - as) * dst.g;
        double b = as * (1 - ad) * cs.blue + as * ad * bcol.blue + (1 - as) * dst.b;
        double a = as + ad * (1 - as);
        return new Pixel(r, g, b, a);
    }
}
