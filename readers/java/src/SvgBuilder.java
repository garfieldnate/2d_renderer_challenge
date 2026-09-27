import java.util.List;

/**
 * §20.4: build_path(cmds, m, tolerance) walks the commands keeping a
 * current point in user space: M is a move_to and L a line_to, each point
 * taken through m; C and Q are cubics and quadratics from the current
 * point, taken through m and then flattened (chapter 8's order: transform,
 * then flatten); A is its arc_cubics, each done the same way; Z is a
 * close. A subpath that is nothing but its moveto is dropped.
 *
 * commands_bounds(cmds) is the tight box of the geometry in user space:
 * every M and L point and chapter 8's curve_bounds of every curve, (0, 0,
 * 0, 0) when there's none.
 */
public final class SvgBuilder {
    private SvgBuilder() {}

    public static Path buildPath(List<SvgCommand> cmds, Matrix m, double tolerance) {
        Path path = new Path();
        double cx = 0;
        double cy = 0;
        double sx = 0;
        double sy = 0;
        for (SvgCommand c : cmds) {
            double[] a = c.args();
            switch (c.op()) {
                case "M" -> {
                    cx = a[0];
                    cy = a[1];
                    sx = cx;
                    sy = cy;
                    path.dropLoneSubpath();
                    path.moveTo(m.multiply(Tuple.point(cx, cy)));
                }
                case "L" -> {
                    cx = a[0];
                    cy = a[1];
                    path.lineTo(m.multiply(Tuple.point(cx, cy)));
                }
                case "C" -> {
                    Curve raw = Curve.cubic(
                            Tuple.point(cx, cy), Tuple.point(a[0], a[1]), Tuple.point(a[2], a[3]),
                            Tuple.point(a[4], a[5]));
                    flattenIntoPathNoDup(path, Curves.transformCurve(raw, m), tolerance);
                    cx = a[4];
                    cy = a[5];
                }
                case "Q" -> {
                    Curve raw = Curve.quadratic(Tuple.point(cx, cy), Tuple.point(a[0], a[1]), Tuple.point(a[2], a[3]));
                    flattenIntoPathNoDup(path, Curves.transformCurve(raw, m), tolerance);
                    cx = a[2];
                    cy = a[3];
                }
                case "A" -> {
                    List<Curve> cubics = ArcCubics.arcCubics(
                            cx, cy, a[0], a[1], a[2], a[3] != 0, a[4] != 0, a[5], a[6]);
                    for (Curve raw : cubics) {
                        flattenIntoPathNoDup(path, Curves.transformCurve(raw, m), tolerance);
                    }
                    cx = a[5];
                    cy = a[6];
                }
                default -> { // Z
                    path.close();
                    cx = sx;
                    cy = sy;
                }
            }
        }
        path.dropLoneSubpath();
        return path;
    }

    /**
     * Chapter 20's own flatten_into_path, which -- unlike chapter 8's (reused
     * verbatim by chapter 16, where the repeated point is harmless) -- drops
     * the flattened curve's own first point when it lands exactly on the
     * path's current point, so a run of curves sharing endpoints (an arc's
     * cubics, or C/Q one after another) doesn't grow a zero-length edge at
     * every join.
     */
    private static void flattenIntoPathNoDup(Path path, Curve c, double tolerance) {
        List<Tuple> pts = Curves.flatten(c, tolerance);
        List<Subpath> subpaths = path.subpaths();
        if (subpaths.isEmpty() || subpaths.get(subpaths.size() - 1).closed) {
            path.moveTo(pts.get(0));
            pts = pts.subList(1, pts.size());
        } else {
            List<Tuple> currentPoints = subpaths.get(subpaths.size() - 1).points;
            Tuple cur = currentPoints.get(currentPoints.size() - 1);
            Tuple first = pts.get(0);
            if (cur.x == first.x && cur.y == first.y) {
                pts = pts.subList(1, pts.size());
            }
        }
        for (Tuple q : pts) {
            path.lineTo(q);
        }
    }

    public static Bounds commandsBounds(List<SvgCommand> cmds) {
        double cx = 0;
        double cy = 0;
        double sx = 0;
        double sy = 0;
        boolean any = false;
        double minX = 0;
        double minY = 0;
        double maxX = 0;
        double maxY = 0;
        for (SvgCommand c : cmds) {
            double[] a = c.args();
            switch (c.op()) {
                case "M" -> {
                    cx = a[0];
                    cy = a[1];
                    sx = cx;
                    sy = cy;
                    minX = any ? Math.min(minX, cx) : cx;
                    maxX = any ? Math.max(maxX, cx) : cx;
                    minY = any ? Math.min(minY, cy) : cy;
                    maxY = any ? Math.max(maxY, cy) : cy;
                    any = true;
                }
                case "L" -> {
                    cx = a[0];
                    cy = a[1];
                    minX = any ? Math.min(minX, cx) : cx;
                    maxX = any ? Math.max(maxX, cx) : cx;
                    minY = any ? Math.min(minY, cy) : cy;
                    maxY = any ? Math.max(maxY, cy) : cy;
                    any = true;
                }
                case "C" -> {
                    Curve raw = Curve.cubic(
                            Tuple.point(cx, cy), Tuple.point(a[0], a[1]), Tuple.point(a[2], a[3]),
                            Tuple.point(a[4], a[5]));
                    Bounds b = Curves.curveBounds(raw);
                    minX = any ? Math.min(minX, b.minX()) : b.minX();
                    maxX = any ? Math.max(maxX, b.maxX()) : b.maxX();
                    minY = any ? Math.min(minY, b.minY()) : b.minY();
                    maxY = any ? Math.max(maxY, b.maxY()) : b.maxY();
                    any = true;
                    cx = a[4];
                    cy = a[5];
                }
                case "Q" -> {
                    Curve raw = Curve.quadratic(Tuple.point(cx, cy), Tuple.point(a[0], a[1]), Tuple.point(a[2], a[3]));
                    Bounds b = Curves.curveBounds(raw);
                    minX = any ? Math.min(minX, b.minX()) : b.minX();
                    maxX = any ? Math.max(maxX, b.maxX()) : b.maxX();
                    minY = any ? Math.min(minY, b.minY()) : b.minY();
                    maxY = any ? Math.max(maxY, b.maxY()) : b.maxY();
                    any = true;
                    cx = a[2];
                    cy = a[3];
                }
                case "A" -> {
                    List<Curve> cubics = ArcCubics.arcCubics(
                            cx, cy, a[0], a[1], a[2], a[3] != 0, a[4] != 0, a[5], a[6]);
                    for (Curve raw : cubics) {
                        Bounds b = Curves.curveBounds(raw);
                        minX = any ? Math.min(minX, b.minX()) : b.minX();
                        maxX = any ? Math.max(maxX, b.maxX()) : b.maxX();
                        minY = any ? Math.min(minY, b.minY()) : b.minY();
                        maxY = any ? Math.max(maxY, b.maxY()) : b.maxY();
                        any = true;
                    }
                    cx = a[5];
                    cy = a[6];
                }
                default -> { // Z
                    cx = sx;
                    cy = sy;
                }
            }
        }
        if (!any) {
            return new Bounds(0, 0, 0, 0);
        }
        return new Bounds(minX, minY, maxX, maxY);
    }
}
