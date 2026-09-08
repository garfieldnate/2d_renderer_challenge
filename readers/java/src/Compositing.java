/**
 * §9.2, §9.3: over(src, dst) is src composited over dst, premultiplied,
 * every channel including alpha: src + (1 - src.a) * dst. composite(op, src,
 * dst) generalizes it to any of the twelve Porter-Duff operators, each
 * nothing but its own choice of the two coefficients Fa (how much of the
 * source survives) and Fb (how much of the destination survives):
 * Fa * src + Fb * dst, alpha included.
 */
public final class Compositing {
    private Compositing() {}

    public static Pixel over(Pixel src, Pixel dst) {
        double t = 1 - src.a;
        return new Pixel(
                src.r + t * dst.r,
                src.g + t * dst.g,
                src.b + t * dst.b,
                src.a + t * dst.a);
    }

    /** coefficients(op, a_s, a_d): the (Fa, Fb) pair for each of the twelve operators. */
    private static double[] coefficients(String op, double as, double ad) {
        switch (op) {
            case "clear": return new double[] {0, 0};
            case "src": return new double[] {1, 0};
            case "dst": return new double[] {0, 1};
            case "src-over": return new double[] {1, 1 - as};
            case "dst-over": return new double[] {1 - ad, 1};
            case "src-in": return new double[] {ad, 0};
            case "dst-in": return new double[] {0, as};
            case "src-out": return new double[] {1 - ad, 0};
            case "dst-out": return new double[] {0, 1 - as};
            case "src-atop": return new double[] {ad, 1 - as};
            case "dst-atop": return new double[] {1 - ad, as};
            case "xor": return new double[] {1 - ad, 1 - as};
            default: throw new IllegalArgumentException("unknown operator: " + op);
        }
    }

    public static Pixel composite(String op, Pixel src, Pixel dst) {
        double[] f = coefficients(op, src.a, dst.a);
        double fa = f[0];
        double fb = f[1];
        return new Pixel(
                fa * src.r + fb * dst.r,
                fa * src.g + fb * dst.g,
                fa * src.b + fb * dst.b,
                fa * src.a + fb * dst.a);
    }
}
