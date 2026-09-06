/**
 * §5.2: crossings(p, x, y) counts how many edges a ray from (x, y) toward
 * +x crosses; winding_at(p, x, y) is the same walk, signed by direction.
 * Both use the half-open rule: an edge from a to b is crossed when the
 * ray's height y satisfies a.y &lt;= y &lt; b.y or b.y &lt;= y &lt; a.y, so a vertex
 * on the ray counts once, belonging to exactly one of the two edges that
 * meet there, never twice and never zero unless the path grazes a peak or
 * a trough.
 *
 * §5.3: inside_nonzero(p, x, y) is true when the winding number isn't zero.
 * inside_evenodd(p, x, y) is true when it's odd -- both are one line on top
 * of winding_at.
 */
public final class Winding {
    private Winding() {}

    public static int crossings(Path p, double x, double y) {
        int count = 0;
        for (Edge e : p.edges()) {
            double ay = e.a().y;
            double by = e.b().y;
            boolean spans = (ay <= y && y < by) || (by <= y && y < ay);
            if (!spans) {
                continue;
            }
            double t = (y - ay) / (by - ay);
            double cx = e.a().x + t * (e.b().x - e.a().x);
            if (cx > x) {
                count++;
            }
        }
        return count;
    }

    public static int windingAt(Path p, double x, double y) {
        Tuple q = Tuple.point(x, y);
        int w = 0;
        for (Edge e : p.edges()) {
            Tuple a = e.a();
            Tuple b = e.b();
            if (a.y <= y) { // heading down, q on the left
                if (b.y > y && Tuple.cross(b.subtract(a), q.subtract(a)) > 0) {
                    w++;
                }
            } else { // heading up, q on the right
                if (b.y <= y && Tuple.cross(b.subtract(a), q.subtract(a)) < 0) {
                    w--;
                }
            }
        }
        return w;
    }

    public static boolean insideNonzero(Path p, double x, double y) {
        return windingAt(p, x, y) != 0;
    }

    public static boolean insideEvenodd(Path p, double x, double y) {
        return windingAt(p, x, y) % 2 != 0;
    }
}
