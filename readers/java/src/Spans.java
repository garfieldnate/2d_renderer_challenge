import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * §6.2: crossings_on_row(table, y) collects (x, direction) for every edge of
 * the table that spans height y, half-open (y_top &lt;= y &lt; y_bottom), sorted
 * by x. spans_from_crossings(xs, rule) walks them left to right,
 * accumulating the winding number, and returns the maximal intervals where
 * the rule says inside, merging two inside stretches that touch. spans(p,
 * rule, row) does both for one pixel row, sampled at height row + 0.5.
 * fill_span(cov, row, x0, x1) sets every pixel of the row whose center lies
 * in [x0, x1) to 1, half-open at the right end.
 */
public final class Spans {
    private Spans() {}

    public static List<Crossing> crossingsOnRow(List<TableEdge> table, double y) {
        List<Crossing> result = new ArrayList<>();
        for (TableEdge e : table) {
            if (e.yTop() <= y && y < e.yBottom()) {
                result.add(new Crossing(EdgeTable.xAt(e, y), e.direction()));
            }
        }
        result.sort(Comparator.comparingDouble(Crossing::x));
        return result;
    }

    public static List<Span> spansFromCrossings(List<Crossing> xs, String rule) {
        List<Span> out = new ArrayList<>();
        int w = 0;
        Double start = null;
        for (Crossing c : xs) {
            w += c.direction();
            boolean inside = rule.equals("nonzero") ? w != 0 : (w % 2 != 0);
            if (inside && start == null) {
                start = c.x();
            }
            if (!inside && start != null) {
                out.add(new Span(start, c.x()));
                start = null;
            }
        }
        return out;
    }

    public static List<Span> spans(Path p, String rule, int row) {
        double y = row + 0.5;
        List<Crossing> xs = crossingsOnRow(EdgeTable.edgeTable(p), y);
        return spansFromCrossings(xs, rule);
    }

    public static void fillSpan(CoverageBuffer cov, int row, double x0, double x1) {
        int first = (int) Math.ceil(x0 - 0.5);
        int last = (int) Math.ceil(x1 - 0.5) - 1;
        int lo = Math.max(first, 0);
        int hi = Math.min(last, cov.width - 1);
        for (int x = lo; x <= hi; x++) {
            cov.setCoverage(x, row, 1);
        }
    }
}
