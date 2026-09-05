/**
 * §1.7: mix(a, b, t) blends two colors. The global "linear blending" switch
 * decides where the arithmetic happens: on (the default) does it in light,
 * off does it in encoded file-value space, the way browsers do.
 */
public final class Mixer {
    /** Global state, on by default. */
    public static boolean linearBlending = true;

    private Mixer() {}

    public static Color mix(Color a, Color b, double t) {
        if (linearBlending) {
            return a.add(b.subtract(a).scale(t));
        }
        double r = mixChannel(a.red, b.red, t);
        double g = mixChannel(a.green, b.green, t);
        double bch = mixChannel(a.blue, b.blue, t);
        return new Color(r, g, bch);
    }

    private static double mixChannel(double a, double b, double t) {
        double ea = Srgb.encode(a);
        double eb = Srgb.encode(b);
        double mixed = ea + (eb - ea) * t;
        return Srgb.decode(mixed);
    }
}
