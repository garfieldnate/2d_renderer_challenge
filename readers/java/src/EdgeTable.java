import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * §6.1: edge_table(p) prepares every non-horizontal edge of a path for the
 * sweep, sorted by y_top then by x_top. "Horizontal" means a.y = b.y
 * exactly -- dropped, not clamped, not special-cased, because chapter 5's
 * half-open rule already says they never cross a sample height and their
 * slope would be a division by zero besides. x_at(edge, y) is the one thing
 * an edge knows how to do: x_top + (y - y_top) * slope.
 */
public final class EdgeTable {
    private EdgeTable() {}

    public static List<TableEdge> edgeTable(Path p) {
        List<TableEdge> result = new ArrayList<>();
        for (Edge e : p.edges()) {
            double ay = e.a().y;
            double by = e.b().y;
            if (ay == by) {
                continue; // horizontal: dropped
            }
            double yTop;
            double yBottom;
            double xTop;
            double xBottom;
            int direction;
            if (ay < by) {
                yTop = ay;
                xTop = e.a().x;
                yBottom = by;
                xBottom = e.b().x;
                direction = 1;
            } else {
                yTop = by;
                xTop = e.b().x;
                yBottom = ay;
                xBottom = e.a().x;
                direction = -1;
            }
            double slope = (xBottom - xTop) / (yBottom - yTop);
            result.add(new TableEdge(yTop, yBottom, xTop, slope, direction));
        }
        result.sort(Comparator.comparingDouble(TableEdge::yTop).thenComparingDouble(TableEdge::xTop));
        return result;
    }

    public static double xAt(TableEdge e, double y) {
        return e.xTop() + (y - e.yTop()) * e.slope();
    }
}
