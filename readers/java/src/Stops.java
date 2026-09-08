import java.util.List;

/**
 * §10.1: sample_stops(stops, t) is the color at parameter t: below the
 * first stop you get the first color, above the last you get the last, and
 * between two stops a straight blend in linear light weighted by where t
 * falls between their offsets, found by binary search once there are more
 * than a couple of stops.
 *
 * §10.2: extend(t, mode) folds a parameter that fell outside [0, 1] back
 * in. "pad" clamps to the ends, "repeat" wraps, "reflect" bounces so the
 * gradient mirrors every unit.
 */
public final class Stops {
    private Stops() {}

    public static Color sampleStops(List<Stop> stops, double t) {
        Stop first = stops.get(0);
        Stop last = stops.get(stops.size() - 1);
        if (t <= first.offset()) {
            return first.color();
        }
        if (t >= last.offset()) {
            return last.color();
        }
        int lo = 0;
        int hi = stops.size() - 1;
        while (hi - lo > 1) {
            int mid = (lo + hi) >>> 1;
            if (stops.get(mid).offset() <= t) {
                lo = mid;
            } else {
                hi = mid;
            }
        }
        Stop a = stops.get(lo);
        Stop b = stops.get(hi);
        double frac = (t - a.offset()) / (b.offset() - a.offset());
        return Mixer.mix(a.color(), b.color(), frac, true);
    }

    public static double extend(double t, String mode) {
        switch (mode) {
            case "pad":
                return t < 0 ? 0 : t > 1 ? 1 : t;
            case "repeat":
                return t - Math.floor(t);
            case "reflect": {
                double u = Math.abs(t) % 2.0;
                return u <= 1 ? u : 2 - u;
            }
            default:
                throw new IllegalArgumentException("unknown extend mode: " + mode);
        }
    }
}
