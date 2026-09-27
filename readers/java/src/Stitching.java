import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * §22.5: stitch(kept) links the kept (from, to) pairs into closed contours.
 * Start with the first unused pair in the sweep's order (of from, then of
 * to); at each vertex take the unused pair leaving it that turns furthest
 * right -- the first met sweeping counterclockwise on screen from the way
 * you came. Then drop every vertex collinear with its two neighbours, start
 * each contour at its topmost (then leftmost) vertex, and sort the
 * contours.
 */
public final class Stitching {
    private Stitching() {}

    // Screen coordinates are y-down, so a positive cross product (b.x*a.y -
    // ... the usual math-CCW test) turns out clockwise on screen; every
    // comparison below is written for "counterclockwise on screen", which is
    // the mathematical sign flipped from the plain cross product.
    private static int halfOf(double rx, double ry, double vx, double vy) {
        double cr = rx * vy - ry * vx;
        if (cr != 0) {
            return cr > 0 ? 1 : 0;
        }
        double dt = rx * vx + ry * vy;
        return dt < 0 ? 1 : 0;
    }

    /** true when v1 turns further right (on screen) than v2, facing back along r. */
    private static boolean turnsFurtherRight(double rx, double ry, double v1x, double v1y, double v2x, double v2y) {
        int h1 = halfOf(rx, ry, v1x, v1y);
        int h2 = halfOf(rx, ry, v2x, v2y);
        if (h1 != h2) {
            return h1 < h2;
        }
        double cross12 = v1x * v2y - v1y * v2x;
        return cross12 < 0;
    }

    public static List<List<Tuple>> stitch(List<KeptEdge> kept) {
        int n = kept.size();
        Integer[] order = new Integer[n];
        for (int i = 0; i < n; i++) {
            order[i] = i;
        }
        java.util.Arrays.sort(order, (i, j) -> {
            KeptEdge a = kept.get(i), b = kept.get(j);
            int c = Splitting.compareLex(a.from(), b.from());
            if (c != 0) {
                return c;
            }
            return Splitting.compareLex(a.to(), b.to());
        });

        Map<String, List<Integer>> from = new HashMap<>();
        for (int k : order) {
            from.computeIfAbsent(Grid.key(kept.get(k).from()), key -> new ArrayList<>()).add(k);
        }

        boolean[] used = new boolean[n];
        List<List<Tuple>> out = new ArrayList<>();

        for (int k0 : order) {
            if (used[k0]) {
                continue;
            }
            Tuple start = kept.get(k0).from();
            List<Tuple> pts = new ArrayList<>();
            int k = k0;
            while (true) {
                used[k] = true;
                pts.add(kept.get(k).from());
                Tuple v = kept.get(k).to();
                if (Grid.samePoint(v, start)) {
                    break;
                }
                double dx = kept.get(k).to().x - kept.get(k).from().x;
                double dy = kept.get(k).to().y - kept.get(k).from().y;
                double rx = -dx, ry = -dy;
                List<Integer> candidates = from.get(Grid.key(v));
                Integer best = null;
                if (candidates != null) {
                    for (int j : candidates) {
                        if (used[j]) {
                            continue;
                        }
                        if (best == null) {
                            best = j;
                            continue;
                        }
                        double v1x = kept.get(j).to().x - kept.get(j).from().x;
                        double v1y = kept.get(j).to().y - kept.get(j).from().y;
                        double v2x = kept.get(best).to().x - kept.get(best).from().x;
                        double v2y = kept.get(best).to().y - kept.get(best).from().y;
                        if (turnsFurtherRight(rx, ry, v1x, v1y, v2x, v2y)) {
                            best = j;
                        }
                    }
                }
                if (best == null) {
                    // Shouldn't happen for a well-formed kept set (every vertex has
                    // as many arrows leaving as arriving); stop rather than loop.
                    break;
                }
                k = best;
            }
            removeStraightVertices(pts);
            rotateToTopLeft(pts);
            out.add(pts);
        }

        out.sort(Stitching::compareContours);
        return out;
    }

    private static void removeStraightVertices(List<Tuple> pts) {
        boolean changed = true;
        while (changed && pts.size() >= 3) {
            changed = false;
            for (int q = 0; q < pts.size(); q++) {
                Tuple u = pts.get((q - 1 + pts.size()) % pts.size());
                Tuple c = pts.get(q);
                Tuple w = pts.get((q + 1) % pts.size());
                if (Grid.orient(u, c, w) == 0) {
                    pts.remove(q);
                    changed = true;
                    break;
                }
            }
        }
    }

    private static void rotateToTopLeft(List<Tuple> pts) {
        if (pts.isEmpty()) {
            return;
        }
        int f = 0;
        for (int q = 1; q < pts.size(); q++) {
            if (Grid.lexLess(pts.get(q), pts.get(f))) {
                f = q;
            }
        }
        if (f == 0) {
            return;
        }
        List<Tuple> rotated = new ArrayList<>(pts.subList(f, pts.size()));
        rotated.addAll(pts.subList(0, f));
        pts.clear();
        pts.addAll(rotated);
    }

    private static int compareContours(List<Tuple> a, List<Tuple> b) {
        int n = Math.min(a.size(), b.size());
        for (int i = 0; i < n; i++) {
            int c = Splitting.compareLex(a.get(i), b.get(i));
            if (c != 0) {
                return c;
            }
        }
        return Integer.compare(a.size(), b.size());
    }
}
