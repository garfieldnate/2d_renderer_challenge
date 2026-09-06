/**
 * §5.1: polygon(p1, p2, ...) is a closed subpath through the points.
 * circle_path(cx, cy, r, n) is a regular n-gon standing in for a circle, its
 * first point at angle 0 (on the right), going clockwise on the screen.
 *
 * §5.3: filled(p, rule) and rasterize_within(shape, box, w, h), chapter 2's
 * rasterize restricted to the pixels the box touches: columns from
 * floor(min x) up to but not including ceil(max x), rows likewise, clipped
 * to the buffer, leaving the rest at zero.
 *
 * §6.4: transform_path(p, m), a new path with every point of every subpath
 * taken through m, closed flags and all. The original is untouched.
 */
public final class Paths {
    private Paths() {}

    public static Path polygon(Tuple... points) {
        Path p = new Path();
        for (int i = 0; i < points.length; i++) {
            if (i == 0) {
                p.moveTo(points[i]);
            } else {
                p.lineTo(points[i]);
            }
        }
        p.close();
        return p;
    }

    public static Path circlePath(double cx, double cy, double r, int n) {
        Path p = new Path();
        for (int k = 0; k < n; k++) {
            double a = Math.toRadians(360.0 * k / n);
            Tuple pt = Tuple.point(cx + r * Math.cos(a), cy + r * Math.sin(a));
            if (k == 0) {
                p.moveTo(pt);
            } else {
                p.lineTo(pt);
            }
        }
        p.close();
        return p;
    }

    public static Shape filled(Path p, String rule) {
        return new FilledPath(p, rule);
    }

    public static CoverageBuffer rasterizeWithin(Shape s, Bounds box, int w, int h) {
        CoverageBuffer cov = new CoverageBuffer(w, h);
        int x0 = Math.max(0, (int) Math.floor(box.minX()));
        int x1 = Math.min(w, (int) Math.ceil(box.maxX()));
        int y0 = Math.max(0, (int) Math.floor(box.minY()));
        int y1 = Math.min(h, (int) Math.ceil(box.maxY()));
        for (int y = y0; y < y1; y++) {
            for (int x = x0; x < x1; x++) {
                cov.setCoverage(x, y, Rasterizer.coverage(s, x, y));
            }
        }
        return cov;
    }

    public static Path transformPath(Path p, Matrix m) {
        Path result = new Path();
        for (Subpath sp : p.subpaths()) {
            boolean first = true;
            for (Tuple point : sp.points) {
                Tuple moved = m.multiply(point);
                if (first) {
                    result.moveTo(moved);
                    first = false;
                } else {
                    result.lineTo(moved);
                }
            }
            if (sp.closed) {
                result.close();
            }
        }
        return result;
    }
}
