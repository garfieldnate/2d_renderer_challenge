/**
 * §1.7: mix(a, b, t) blends two colors. The global "linear blending" switch
 * decides where the arithmetic happens: on (the default) does it in light,
 * off does it in encoded file-value space, the way browsers do. The light's
 * way never clamps -- it just does the arithmetic. The browser's way clamps
 * each end to 0..1 before encoding it, the same clamp canvas_to_ppm does,
 * not the mixed result afterward.
 *
 * mix also takes the switch as an optional fourth argument, mix(a, b, t,
 * linear), for languages that would rather not touch a mutable global; it
 * overrides the switch for that call only and never changes it.
 */
public final class Mixer {
    /** Global state, on by default. */
    public static boolean linearBlending = true;

    private Mixer() {}

    public static Color mix(Color a, Color b, double t) {
        return mix(a, b, t, linearBlending);
    }

    public static Color mix(Color a, Color b, double t, boolean linear) {
        if (linear) {
            return a.add(b.subtract(a).scale(t));
        }
        double r = mixChannel(a.red, b.red, t);
        double g = mixChannel(a.green, b.green, t);
        double bch = mixChannel(a.blue, b.blue, t);
        return new Color(r, g, bch);
    }

    private static double mixChannel(double a, double b, double t) {
        double ca = Math.max(0.0, Math.min(1.0, a));
        double cb = Math.max(0.0, Math.min(1.0, b));
        double ea = Srgb.encode(ca);
        double eb = Srgb.encode(cb);
        double mixed = ea + (eb - ea) * t;
        return Srgb.decode(mixed);
    }
}
