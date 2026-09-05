/**
 * §1.4: the sRGB transfer functions. Both operate on numbers between 0 and 1.
 * decode: file value -> light. encode: light -> file value.
 */
public final class Srgb {
    private Srgb() {}

    public static double decode(double v) {
        if (v <= 0.04045) {
            return v / 12.92;
        }
        return Math.pow((v + 0.055) / 1.055, 2.4);
    }

    public static double encode(double l) {
        if (l <= 0.0031308) {
            return l * 12.92;
        }
        return 1.055 * Math.pow(l, 1.0 / 2.4) - 0.055;
    }
}
