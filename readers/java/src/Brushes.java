import java.util.ArrayList;
import java.util.List;

/**
 * §25.1: dab_coverage(b, d), at distance d from a dab's center, is 1 when
 * d &lt;= hardness * radius, 0 when d &gt;= radius, and a straight ramp between.
 * stamp_positions(events, b) spaces dabs by distance, not by event: the
 * first event is a dab, and then one every step = spacing * 2 * radius of
 * arc length along the polyline through the events, the distance still
 * needed carried from segment to segment. stroke_mask(width, height,
 * centers, b) is one stroke's coverage: for every center in order, at
 * every pixel of its box with k = dab_coverage above 0, m &lt;- 1 - (1 - m)(1
 * - flow * k). paint_stroke(c, events, b, col, by_distance) makes the mask
 * from stamp_positions when by_distance is true and from the events
 * themselves when it's false, multiplies it by opacity, and paints it
 * through with chapter 2's paint_through; it answers the mask it painted.
 * wobbly_events() is 25 pointer events bunched at the start where the hand
 * was slow. min_along(m, events, n) is the least mask value at the pixels
 * under n evenly spaced points of every segment of the events.
 */
public final class Brushes {
    private Brushes() {}

    public static double dabCoverage(Brush b, double d) {
        double inner = b.hardness() * b.radius();
        if (d <= inner) {
            return 1;
        }
        if (d >= b.radius()) {
            return 0;
        }
        return (b.radius() - d) / (b.radius() - inner);
    }

    public static List<Tuple> stampPositions(List<Tuple> events, Brush b) {
        List<Tuple> out = new ArrayList<>();
        if (events.isEmpty()) {
            return out;
        }
        double step = b.spacing() * 2 * b.radius();
        out.add(events.get(0));
        double need = step;
        for (int i = 0; i + 1 < events.size(); i++) {
            Tuple a = events.get(i);
            Tuple c = events.get(i + 1);
            double segLen = c.subtract(a).magnitude();
            double pos = 0;
            while (segLen - pos >= need) {
                pos += need;
                double t = pos / segLen;
                out.add(Tuple.point(a.x + (c.x - a.x) * t, a.y + (c.y - a.y) * t));
                need = step;
            }
            need -= segLen - pos;
        }
        return out;
    }

    public static CoverageBuffer strokeMask(int width, int height, List<Tuple> centers, Brush b) {
        double[] m = new double[width * height];
        for (Tuple q : centers) {
            int x0 = Math.max(0, (int) Math.floor(q.x - b.radius()));
            int x1 = Math.min(width - 1, (int) Math.ceil(q.x + b.radius()));
            int y0 = Math.max(0, (int) Math.floor(q.y - b.radius()));
            int y1 = Math.min(height - 1, (int) Math.ceil(q.y + b.radius()));
            for (int y = y0; y <= y1; y++) {
                for (int x = x0; x <= x1; x++) {
                    double dx = x + 0.5 - q.x;
                    double dy = y + 0.5 - q.y;
                    double k = dabCoverage(b, Math.sqrt(dx * dx + dy * dy));
                    if (k > 0) {
                        int i = y * width + x;
                        m[i] = 1 - (1 - m[i]) * (1 - b.flow() * k);
                    }
                }
            }
        }
        CoverageBuffer out = new CoverageBuffer(width, height);
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                out.setCoverage(x, y, m[y * width + x]);
            }
        }
        return out;
    }

    public static CoverageBuffer paintStroke(Canvas c, List<Tuple> events, Brush b, Color col, boolean byDistance) {
        CoverageBuffer m = strokeMask(c.width, c.height, byDistance ? stampPositions(events, b) : events, b);
        CoverageBuffer scaled = new CoverageBuffer(c.width, c.height);
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                scaled.setCoverage(x, y, m.coverageAt(x, y) * b.opacity());
            }
        }
        Painter.paintThrough(c, scaled, col);
        return scaled;
    }

    public static List<Tuple> wobblyEvents() {
        List<Tuple> out = new ArrayList<>();
        for (int i = 0; i < 25; i++) {
            double u = i / 24.0;
            out.add(Tuple.point(20 + 360 * u * u, 60 + 30 * Math.sin(2 * Math.PI * u)));
        }
        return out;
    }

    public static double minAlong(CoverageBuffer m, List<Tuple> events, int n) {
        double best = Double.MAX_VALUE;
        for (int i = 0; i + 1 < events.size(); i++) {
            Tuple a = events.get(i);
            Tuple c = events.get(i + 1);
            for (int k = 0; k < n; k++) {
                double t = (double) k / n;
                double px = a.x + (c.x - a.x) * t;
                double py = a.y + (c.y - a.y) * t;
                double v = m.coverageAt((int) Math.floor(px), (int) Math.floor(py));
                best = Math.min(best, v);
            }
        }
        return best;
    }
}
