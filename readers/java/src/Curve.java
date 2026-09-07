import java.util.List;

/**
 * §8.1: a Bezier curve, held as its control points -- three for
 * quadratic(p0, p1, p2), four for cubic(p0, p1, p2, p3). The curve starts
 * at the first point, ends at the last, and leans toward the interior
 * points without ever touching them.
 */
public final class Curve {
    private final List<Tuple> points;

    private Curve(List<Tuple> points) {
        this.points = points;
    }

    public static Curve quadratic(Tuple p0, Tuple p1, Tuple p2) {
        return new Curve(List.of(p0, p1, p2));
    }

    public static Curve cubic(Tuple p0, Tuple p1, Tuple p2, Tuple p3) {
        return new Curve(List.of(p0, p1, p2, p3));
    }

    static Curve ofPoints(List<Tuple> points) {
        return new Curve(points);
    }

    public List<Tuple> points() {
        return points;
    }

    /** The degree: 1 for a line, 2 for a quadratic, 3 for a cubic. */
    public int degree() {
        return points.size() - 1;
    }
}
