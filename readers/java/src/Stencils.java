/**
 * §24.1: filling without sorting. triangle_winding(a, b, c, x, y) is chapter
 * 5's winding_at for the closed triangle a, b, c at (x, y): +1 inside a
 * triangle that runs clockwise on screen, -1 inside one that runs
 * counterclockwise, 0 outside, with chapter 5's half-open rule on the
 * edges. stencil_triangle(s, a, b, c, ox, oy) visits every pixel of the
 * triangle's bounding box on the canvas and adds triangle_winding at the
 * pixel's sample point (x + ox, y + oy). fan_anchor(p) is the first point
 * of the first subpath that has one, or point(0, 0). stencil_buffer(p,
 * width, height, ox, oy) adds, for every edge (a, b) of chapter 5's
 * edges(p), the triangle (anchor, a, b); ox and oy default to 0.5. cover(s,
 * rule) is a coverage buffer of 1 where the stencil fills under the rule, 0
 * elsewhere. winding_mismatches(s, p) counts the pixels where the stencil
 * and winding_at at the pixel center disagree.
 */
public final class Stencils {
    private Stencils() {}

    public static int triangleWinding(Tuple a, Tuple b, Tuple c, double x, double y) {
        int w = 0;
        Tuple[][] edges = {{a, b}, {b, c}, {c, a}};
        for (Tuple[] e : edges) {
            Tuple u = e[0];
            Tuple v = e[1];
            double cr = (v.x - u.x) * (y - u.y) - (v.y - u.y) * (x - u.x);
            if (u.y <= y) {
                if (v.y > y && cr > 0) {
                    w++;
                }
            } else if (v.y <= y && cr < 0) {
                w--;
            }
        }
        return w;
    }

    public static void stencilTriangle(Stencil s, Tuple a, Tuple b, Tuple c, double ox, double oy) {
        int x0 = (int) Math.max(0, Math.floor(Math.min(a.x, Math.min(b.x, c.x)) - ox));
        int x1 = (int) Math.min(s.width - 1, Math.ceil(Math.max(a.x, Math.max(b.x, c.x)) - ox));
        int y0 = (int) Math.max(0, Math.floor(Math.min(a.y, Math.min(b.y, c.y)) - oy));
        int y1 = (int) Math.min(s.height - 1, Math.ceil(Math.max(a.y, Math.max(b.y, c.y)) - oy));
        for (int y = y0; y <= y1; y++) {
            for (int x = x0; x <= x1; x++) {
                int w = triangleWinding(a, b, c, x + ox, y + oy);
                s.add(x, y, w);
            }
        }
    }

    public static Tuple fanAnchor(Path p) {
        for (Subpath sp : p.subpaths()) {
            if (!sp.points.isEmpty()) {
                return sp.points.get(0);
            }
        }
        return Tuple.point(0, 0);
    }

    public static Stencil stencilBuffer(Path p, int width, int height) {
        return stencilBuffer(p, width, height, 0.5, 0.5);
    }

    public static Stencil stencilBuffer(Path p, int width, int height, double ox, double oy) {
        Stencil s = new Stencil(width, height);
        Tuple anchor = fanAnchor(p);
        for (Edge e : p.edges()) {
            stencilTriangle(s, anchor, e.a(), e.b(), ox, oy);
        }
        return s;
    }

    public static int stencilAt(Stencil s, int x, int y) {
        if (x < 0 || x >= s.width || y < 0 || y >= s.height) {
            return 0;
        }
        return s.values[y * s.width + x];
    }

    public static CoverageBuffer cover(Stencil s, String rule) {
        CoverageBuffer out = new CoverageBuffer(s.width, s.height);
        for (int y = 0; y < s.height; y++) {
            for (int x = 0; x < s.width; x++) {
                out.setCoverage(x, y, Fill.applyRule(s.values[y * s.width + x], rule));
            }
        }
        return out;
    }

    public static int windingMismatches(Stencil s, Path p) {
        int count = 0;
        for (int y = 0; y < s.height; y++) {
            for (int x = 0; x < s.width; x++) {
                int st = s.values[y * s.width + x];
                int wa = Winding.windingAt(p, x + 0.5, y + 0.5);
                if (st != wa) {
                    count++;
                }
            }
        }
        return count;
    }
}
