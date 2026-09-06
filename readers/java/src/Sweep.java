import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * §6.3: fill_path_aliased(p, rule, w, h), the classical scanline fill with
 * an edge table and an active edge list. The table is read once, front to
 * back: at each row, edges whose y_top has been reached join the active
 * list (taken off the table's front, since it's sorted), and edges whose
 * y_bottom has been passed leave it. Then the active edges' crossings are
 * sorted and the spans filled. The edge that starts exactly at a sample
 * height is active there; the one that ends there is not -- the half-open
 * rule again, and it's what makes this agree with chapter 5's winding_at at
 * every pixel center.
 */
public final class Sweep {
    private Sweep() {}

    public static CoverageBuffer fillPathAliased(Path p, String rule, int w, int h) {
        CoverageBuffer cov = new CoverageBuffer(w, h);
        List<TableEdge> table = EdgeTable.edgeTable(p);
        List<TableEdge> active = new ArrayList<>();
        int next = 0;
        for (int row = 0; row < h; row++) {
            double y = row + 0.5;
            while (next < table.size() && table.get(next).yTop() <= y) {
                active.add(table.get(next));
                next++;
            }
            active.removeIf(e -> !(e.yBottom() > y));
            List<Crossing> xs = new ArrayList<>();
            for (TableEdge e : active) {
                xs.add(new Crossing(EdgeTable.xAt(e, y), e.direction()));
            }
            xs.sort(Comparator.comparingDouble(Crossing::x));
            for (Span s : Spans.spansFromCrossings(xs, rule)) {
                Spans.fillSpan(cov, row, s.x0(), s.x1());
            }
        }
        return cov;
    }
}
