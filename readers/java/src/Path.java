import java.util.ArrayList;
import java.util.List;

/**
 * §5.1: a path is a list of subpaths, one for each time the pen went down.
 * path() is empty (new Path()). move_to(p, point) lifts the pen and starts a
 * new subpath there. line_to(p, point) extends the current subpath -- unless
 * there is no current subpath (nothing has been drawn, or the last one was
 * closed), in which case it starts a new one, and if the last subpath was
 * closed the new one starts at that subpath's own first point, because
 * that's where close left the pen. close(p) marks the last subpath closed;
 * closing nothing, or closing twice, does nothing.
 *
 * edges(p) lists every edge of every subpath as (a, b) pairs, treating every
 * subpath as closed for the purpose of filling whether or not close(p) was
 * called: it always includes the edge from the last point back to the
 * first. A subpath of one point contributes no edges; one of two points
 * contributes two, there and back.
 *
 * bounds(p) is the smallest box around every point of every subpath, (0, 0,
 * 0, 0) when the path is empty.
 */
public final class Path {
    private final List<Subpath> subpaths = new ArrayList<>();

    public void moveTo(Tuple p) {
        Subpath sp = new Subpath();
        sp.points.add(p);
        subpaths.add(sp);
    }

    public void lineTo(Tuple p) {
        if (subpaths.isEmpty()) {
            moveTo(p);
            return;
        }
        Subpath last = subpaths.get(subpaths.size() - 1);
        if (last.closed) {
            // §5.1: a line_to after a close starts a new subpath where the
            // closed one began -- that's where close left the pen.
            moveTo(last.points.get(0));
            subpaths.get(subpaths.size() - 1).points.add(p);
            return;
        }
        last.points.add(p);
    }

    public void close() {
        if (subpaths.isEmpty()) {
            return;
        }
        subpaths.get(subpaths.size() - 1).closed = true;
    }

    public List<Subpath> subpaths() {
        return subpaths;
    }

    /**
     * §20.4: chapter 20's build_path drops a subpath that is nothing but its
     * own move_to -- one point, not closed -- right before starting the next
     * one, and once more at the end.
     */
    public void dropLoneSubpath() {
        if (!subpaths.isEmpty()) {
            Subpath last = subpaths.get(subpaths.size() - 1);
            if (last.points.size() == 1 && !last.closed) {
                subpaths.remove(subpaths.size() - 1);
            }
        }
    }

    public List<Edge> edges() {
        List<Edge> result = new ArrayList<>();
        for (Subpath sp : subpaths) {
            int n = sp.points.size();
            if (n < 2) {
                continue;
            }
            for (int i = 0; i < n; i++) {
                Tuple a = sp.points.get(i);
                Tuple b = sp.points.get((i + 1) % n);
                result.add(new Edge(a, b));
            }
        }
        return result;
    }

    public Bounds bounds() {
        boolean any = false;
        double minX = 0;
        double minY = 0;
        double maxX = 0;
        double maxY = 0;
        for (Subpath sp : subpaths) {
            for (Tuple p : sp.points) {
                if (!any) {
                    minX = maxX = p.x;
                    minY = maxY = p.y;
                    any = true;
                } else {
                    minX = Math.min(minX, p.x);
                    minY = Math.min(minY, p.y);
                    maxX = Math.max(maxX, p.x);
                    maxY = Math.max(maxY, p.y);
                }
            }
        }
        return new Bounds(minX, minY, maxX, maxY);
    }
}
