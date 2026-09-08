import java.util.List;

/**
 * §10.3: a radial gradient is two circles, a start circle at t = 0 and an
 * end circle at t = 1. The parameter of a point is the t of the
 * interpolated circle that passes through it: interpolate the centers and
 * radii, write "the point is on that circle", and solve the resulting
 * quadratic in t, taking the largest root whose radius isn't negative.
 * radial_t returns null (the book's none) when no such root exists -- the
 * focal trap of §10.3's aside: a region the family of circles never reaches.
 */
public final class RadialGradient implements Paint {
    public final Tuple c0;
    public final double r0;
    public final Tuple c1;
    public final double r1;
    public final List<Stop> stops;
    public final String extend;

    public RadialGradient(Tuple c0, double r0, Tuple c1, double r1, List<Stop> stops, String extend) {
        this.c0 = c0;
        this.r0 = r0;
        this.c1 = c1;
        this.r1 = r1;
        this.stops = stops;
        this.extend = extend;
    }

    /** radial_t(point): the largest root t with r0 + t*dr >= 0, or null if there is none. */
    public Double radialT(double x, double y) {
        double cdx = c1.x - c0.x;
        double cdy = c1.y - c0.y;
        double dr = r1 - r0;
        double pdx = x - c0.x;
        double pdy = y - c0.y;

        double a = cdx * cdx + cdy * cdy - dr * dr;
        double b = -2 * (pdx * cdx + pdy * cdy + r0 * dr);
        double c = pdx * pdx + pdy * pdy - r0 * r0;

        if (Math.abs(a) < 1e-9) {
            if (Math.abs(b) < 1e-12) {
                return null;
            }
            double t0 = -c / b;
            return (r0 + t0 * dr >= 0) ? t0 : null;
        }

        double disc = b * b - 4 * a * c;
        if (disc < 0) {
            return null;
        }
        double s = Math.sqrt(disc);
        double[] roots = {(-b + s) / (2 * a), (-b - s) / (2 * a)};
        for (double root : roots) {
            if (r0 + root * dr >= 0) {
                return root;
            }
        }
        return null;
    }

    @Override
    public Color paintAt(double x, double y) {
        Double t = radialT(x, y);
        if (t == null) {
            // Unreachable: take the last stop's color, not black.
            return Stops.sampleStops(stops, 1);
        }
        return Stops.sampleStops(stops, Stops.extend(t, extend));
    }
}
