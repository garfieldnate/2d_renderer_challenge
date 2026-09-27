/**
 * §23.1: exact signed distance fields for the primitives -- a circle, a
 * segment (unsigned, since a segment has no inside), a box, a rounded box,
 * and a polygon (the least distance to any edge, signed by chapter 5's
 * winding number).
 */
public final class Sdf {
    private Sdf() {}

    public static double sdCircle(Tuple p, Tuple c, double r) {
        return p.subtract(c).magnitude() - r;
    }

    public static double distanceToSegment(Tuple p, Tuple a, Tuple b) {
        Tuple ab = b.subtract(a);
        double denom = Tuple.dot(ab, ab);
        double t = denom == 0 ? 0 : Tuple.dot(p.subtract(a), ab) / denom;
        t = Math.max(0, Math.min(1, t));
        Tuple q = a.add(ab.scale(t));
        return p.subtract(q).magnitude();
    }

    public static double sdBox(Tuple p, Tuple c, double hw, double hh) {
        double qx = Math.abs(p.x - c.x) - hw;
        double qy = Math.abs(p.y - c.y) - hh;
        double lx = Math.max(qx, 0);
        double ly = Math.max(qy, 0);
        return Math.hypot(lx, ly) + Math.min(Math.max(qx, qy), 0);
    }

    public static double sdRoundedBox(Tuple p, Tuple c, double hw, double hh, double r) {
        return sdBox(p, c, hw - r, hh - r) - r;
    }

    public static double sdPolygon(Tuple p, Path path, String rule) {
        double best = Double.POSITIVE_INFINITY;
        for (Edge e : path.edges()) {
            best = Math.min(best, distanceToSegment(p, e.a(), e.b()));
        }
        boolean inside = rule.equals("nonzero")
                ? Winding.insideNonzero(path, p.x, p.y)
                : Winding.insideEvenodd(path, p.x, p.y);
        return inside ? -best : best;
    }
}
