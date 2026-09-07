import java.util.ArrayList;
import java.util.List;

/**
 * §8.1: point_at(c, t) is de Casteljau's construction -- interpolate between
 * each neighbouring pair of control points by t, then do it again on those,
 * until one point is left. split_at(c, t) keeps the two edges of that
 * pyramid as two new curves of the same degree. derivative(c, t) is the
 * tangent: n times the de Casteljau construction on the control points'
 * successive differences, one degree lower. transform_curve(c, m) takes
 * every control point through m.
 *
 * §8.2: curve_bounds(c) evaluates the curve at both ends and at every
 * parameter where a component of the derivative is zero -- the derivative
 * is itself a lower-degree Bezier, so its zero is found directly rather
 * than by search: linear for a quadratic's derivative, the quadratic
 * formula for a cubic's.
 *
 * §8.3: flatness(c) is the farthest an interior control point strays from
 * the chord between the curve's ends. flatten(c, tolerance) recursively
 * splits at 0.5 until every piece is flat enough, and returns the
 * endpoints, first to last. polyline_length and flatten_length measure the
 * result. flatten_into_path appends a flattened curve to a path with
 * line_to -- the path's own rule for what happens with no current point,
 * or after a close, does the rest.
 */
public final class Curves {
    private Curves() {}

    private static Tuple lerp(Tuple a, Tuple b, double t) {
        return a.add(b.subtract(a).scale(t));
    }

    private static List<Tuple> reduce(List<Tuple> pts, double t) {
        List<Tuple> next = new ArrayList<>();
        for (int i = 0; i < pts.size() - 1; i++) {
            next.add(lerp(pts.get(i), pts.get(i + 1), t));
        }
        return next;
    }

    private static Tuple evaluate(List<Tuple> pts, double t) {
        List<Tuple> level = pts;
        while (level.size() > 1) {
            level = reduce(level, t);
        }
        return level.get(0);
    }

    public static Tuple pointAt(Curve c, double t) {
        return evaluate(c.points(), t);
    }

    public static Curve[] splitAt(Curve c, double t) {
        List<List<Tuple>> levels = new ArrayList<>();
        List<Tuple> level = c.points();
        levels.add(level);
        while (level.size() > 1) {
            level = reduce(level, t);
            levels.add(level);
        }
        int n = levels.size() - 1; // the degree
        List<Tuple> left = new ArrayList<>();
        List<Tuple> right = new ArrayList<>();
        for (int i = 0; i <= n; i++) {
            List<Tuple> row = levels.get(i);
            left.add(row.get(0));
            List<Tuple> rowFromEnd = levels.get(n - i);
            right.add(rowFromEnd.get(rowFromEnd.size() - 1));
        }
        return new Curve[] {Curve.ofPoints(left), Curve.ofPoints(right)};
    }

    /** The control points of the derivative -- a Bezier one degree lower, of vectors. */
    private static List<Tuple> derivativeControlPoints(Curve c) {
        int n = c.degree();
        List<Tuple> pts = c.points();
        List<Tuple> diffs = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            diffs.add(pts.get(i + 1).subtract(pts.get(i)).scale(n));
        }
        return diffs;
    }

    public static Tuple derivative(Curve c, double t) {
        return evaluate(derivativeControlPoints(c), t);
    }

    public static Curve transformCurve(Curve c, Matrix m) {
        List<Tuple> moved = new ArrayList<>();
        for (Tuple p : c.points()) {
            moved.add(m.multiply(p));
        }
        return Curve.ofPoints(moved);
    }

    /** The roots in [0, 1] of one component (x if isX, else y) of the derivative. */
    private static List<Double> rootsOfAxis(List<Tuple> diffs, boolean isX) {
        List<Double> roots = new ArrayList<>();
        int degree = diffs.size() - 1;
        if (degree == 1) {
            double p0 = isX ? diffs.get(0).x : diffs.get(0).y;
            double p1 = isX ? diffs.get(1).x : diffs.get(1).y;
            double denom = p1 - p0;
            if (denom != 0) {
                double t = -p0 / denom;
                if (t >= 0 && t <= 1) {
                    roots.add(t);
                }
            }
        } else if (degree == 2) {
            double d0 = isX ? diffs.get(0).x : diffs.get(0).y;
            double d1 = isX ? diffs.get(1).x : diffs.get(1).y;
            double d2 = isX ? diffs.get(2).x : diffs.get(2).y;
            double a = d0 - 2 * d1 + d2;
            double b = 2 * (d1 - d0);
            double cc = d0;
            if (a == 0) {
                if (b != 0) {
                    double t = -cc / b;
                    if (t >= 0 && t <= 1) {
                        roots.add(t);
                    }
                }
            } else {
                double disc = b * b - 4 * a * cc;
                if (disc >= 0) {
                    double sq = Math.sqrt(disc);
                    double t1 = (-b + sq) / (2 * a);
                    double t2 = (-b - sq) / (2 * a);
                    if (t1 >= 0 && t1 <= 1) {
                        roots.add(t1);
                    }
                    if (t2 >= 0 && t2 <= 1) {
                        roots.add(t2);
                    }
                }
            }
        }
        return roots;
    }

    public static Bounds curveBounds(Curve c) {
        List<Tuple> diffs = derivativeControlPoints(c);
        List<Double> ts = new ArrayList<>();
        ts.add(0.0);
        ts.add(1.0);
        ts.addAll(rootsOfAxis(diffs, true));
        ts.addAll(rootsOfAxis(diffs, false));

        double minX = Double.POSITIVE_INFINITY;
        double minY = Double.POSITIVE_INFINITY;
        double maxX = Double.NEGATIVE_INFINITY;
        double maxY = Double.NEGATIVE_INFINITY;
        for (double t : ts) {
            Tuple p = evaluate(c.points(), t);
            minX = Math.min(minX, p.x);
            minY = Math.min(minY, p.y);
            maxX = Math.max(maxX, p.x);
            maxY = Math.max(maxY, p.y);
        }
        return new Bounds(minX, minY, maxX, maxY);
    }

    private static double distanceFromChord(Tuple a, Tuple b, Tuple p) {
        Tuple ab = b.subtract(a);
        double len = ab.magnitude();
        if (len == 0) {
            return p.subtract(a).magnitude();
        }
        double cross = Tuple.cross(ab, p.subtract(a));
        return Math.abs(cross) / len;
    }

    public static double flatness(Curve c) {
        List<Tuple> pts = c.points();
        Tuple start = pts.get(0);
        Tuple end = pts.get(pts.size() - 1);
        double max = 0;
        for (int i = 1; i < pts.size() - 1; i++) {
            max = Math.max(max, distanceFromChord(start, end, pts.get(i)));
        }
        return max;
    }

    public static List<Tuple> flatten(Curve c, double tolerance) {
        if (flatness(c) <= tolerance) {
            List<Tuple> pts = c.points();
            return List.of(pts.get(0), pts.get(pts.size() - 1));
        }
        Curve[] halves = splitAt(c, 0.5);
        List<Tuple> left = flatten(halves[0], tolerance);
        List<Tuple> right = flatten(halves[1], tolerance);
        List<Tuple> result = new ArrayList<>(left);
        result.addAll(right.subList(1, right.size()));
        return result;
    }

    public static double polylineLength(List<Tuple> points) {
        double sum = 0;
        for (int i = 0; i < points.size() - 1; i++) {
            sum += points.get(i + 1).subtract(points.get(i)).magnitude();
        }
        return sum;
    }

    public static double flattenLength(Curve c, double tolerance) {
        return polylineLength(flatten(c, tolerance));
    }

    public static void flattenIntoPath(Path p, Curve c, double tolerance) {
        for (Tuple pt : flatten(c, tolerance)) {
            p.lineTo(pt);
        }
    }
}
