/**
 * §9.1: a translucent pixel, stored premultiplied. pixel(r, g, b, a) holds
 * r, g, b each already scaled by a, so a half-covered red is
 * pixel(0.5, 0, 0, 0.5) and a transparent pixel is genuinely
 * pixel(0, 0, 0, 0) -- no phantom color left behind to bleed into an
 * average. from_color(c, a) premultiplies a straight color; opaque(c) is
 * that at alpha 1; pixel_color un-premultiplies (a transparent pixel has no
 * color to recover, so it reads black); pixel_alpha reads the alpha back.
 */
public final class Pixel {
    public final double r;
    public final double g;
    public final double b;
    public final double a;

    public static final Pixel CLEAR = new Pixel(0, 0, 0, 0);

    public Pixel(double r, double g, double b, double a) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }

    public static Pixel fromColor(Color c, double alpha) {
        return new Pixel(c.red * alpha, c.green * alpha, c.blue * alpha, alpha);
    }

    public static Pixel opaque(Color c) {
        return fromColor(c, 1.0);
    }

    /** A transparent pixel has no color to recover, so it reads black. */
    public Color pixelColor() {
        if (a == 0) {
            return new Color(0, 0, 0);
        }
        return new Color(r / a, g / a, b / a);
    }

    public double pixelAlpha() {
        return a;
    }

    /** lerp_pixel(x, y, t): straight down the premultiplied channels, alpha included. */
    public static Pixel lerpPixel(Pixel x, Pixel y, double t) {
        return new Pixel(
                x.r + (y.r - x.r) * t,
                x.g + (y.g - x.g) * t,
                x.b + (y.b - x.b) * t,
                x.a + (y.a - x.a) * t);
    }

    public boolean approxEquals(Pixel o) {
        return approxEquals(o, Numbers.DEFAULT_EPSILON);
    }

    public boolean approxEquals(Pixel o, double epsilon) {
        return Numbers.approxEqual(r, o.r, epsilon)
                && Numbers.approxEqual(g, o.g, epsilon)
                && Numbers.approxEqual(b, o.b, epsilon)
                && Numbers.approxEqual(a, o.a, epsilon);
    }

    @Override
    public String toString() {
        return "pixel(" + r + ", " + g + ", " + b + ", " + a + ")";
    }
}
