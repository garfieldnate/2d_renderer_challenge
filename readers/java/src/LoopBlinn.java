import java.util.ArrayList;
import java.util.List;

/**
 * §24.2: curves without flattening. Give a quadratic's control points p0,
 * p1 and p2 the coordinates (0, 0), (1/2, 0) and (1, 1) and interpolate
 * across the triangle: with det = cross(p1 - p0, p2 - p0), s = cross(q -
 * p0, p2 - p0) / det and t = cross(p1 - p0, q - p0) / det, loop_blinn_uv(c,
 * q) is (u, v, s) with u = s / 2 + t and v = t, or none when det = 0.
 * inside_curve(c, q) is s &gt; 0 and u^2 - v &lt; 0, which holds exactly between
 * the curve and its chord p0 to p2. curve_sign(c) is 1 when det &gt; 0 and -1
 * otherwise. loop_blinn_stencil(curves, anchor, width, height) takes closed
 * contours of quadratics: first the fan of chords, stencil_triangle(s,
 * anchor, p0, p2) for every curve in order, then, for every curve with det
 * != 0, every pixel of the control triangle's bounding box whose center is
 * inside_curve gets curve_sign added and counts as a fragment.
 * glyph_stencil(font, name, m, width, height) is loop_blinn_stencil of the
 * glyph's quadratics through m, anchored at the first curve's first point.
 * Nothing is ever flattened.
 */
public final class LoopBlinn {
    private LoopBlinn() {}

    public record UV(double u, double v, double s) {}

    public static UV loopBlinnUv(Curve c, Tuple q) {
        List<Tuple> pts = c.points();
        Tuple p0 = pts.get(0);
        Tuple p1 = pts.get(1);
        Tuple p2 = pts.get(2);
        double det = Tuple.cross(p1.subtract(p0), p2.subtract(p0));
        if (det == 0) {
            return null;
        }
        double s = Tuple.cross(q.subtract(p0), p2.subtract(p0)) / det;
        double t = Tuple.cross(p1.subtract(p0), q.subtract(p0)) / det;
        double u = s / 2 + t;
        return new UV(u, t, s);
    }

    public static boolean insideCurve(Curve c, Tuple q) {
        UV uv = loopBlinnUv(c, q);
        if (uv == null) {
            return false;
        }
        return uv.s() > 0 && uv.u() * uv.u() - uv.v() < 0;
    }

    private static double detOf(Curve c) {
        List<Tuple> pts = c.points();
        Tuple p0 = pts.get(0);
        Tuple p1 = pts.get(1);
        Tuple p2 = pts.get(2);
        return Tuple.cross(p1.subtract(p0), p2.subtract(p0));
    }

    public static int curveSign(Curve c) {
        return detOf(c) > 0 ? 1 : -1;
    }

    private static int[] curveBox(Curve c, int width, int height) {
        List<Tuple> pts = c.points();
        double minX = Math.min(pts.get(0).x, Math.min(pts.get(1).x, pts.get(2).x));
        double maxX = Math.max(pts.get(0).x, Math.max(pts.get(1).x, pts.get(2).x));
        double minY = Math.min(pts.get(0).y, Math.min(pts.get(1).y, pts.get(2).y));
        double maxY = Math.max(pts.get(0).y, Math.max(pts.get(1).y, pts.get(2).y));
        int x0 = (int) Math.max(0, Math.floor(minX - 0.5));
        int x1 = (int) Math.min(width - 1, Math.ceil(maxX - 0.5));
        int y0 = (int) Math.max(0, Math.floor(minY - 0.5));
        int y1 = (int) Math.min(height - 1, Math.ceil(maxY - 0.5));
        return new int[] {x0, x1, y0, y1};
    }

    private static void addCurve(Stencil s, Curve c, int width, int height) {
        if (detOf(c) == 0) {
            return;
        }
        int sign = curveSign(c);
        int[] box = curveBox(c, width, height);
        for (int y = box[2]; y <= box[3]; y++) {
            for (int x = box[0]; x <= box[1]; x++) {
                if (insideCurve(c, Tuple.point(x + 0.5, y + 0.5))) {
                    s.add(x, y, sign);
                }
            }
        }
    }

    public static Stencil loopBlinnStencil(List<Curve> curves, Tuple anchor, int width, int height) {
        Stencil s = new Stencil(width, height);
        for (Curve c : curves) {
            List<Tuple> pts = c.points();
            Stencils.stencilTriangle(s, anchor, pts.get(0), pts.get(2), 0.5, 0.5);
        }
        for (Curve c : curves) {
            addCurve(s, c, width, height);
        }
        return s;
    }

    /** curve_terms(curves, width, height): loop_blinn_stencil's second half alone. */
    public static Stencil curveTerms(List<Curve> curves, int width, int height) {
        Stencil s = new Stencil(width, height);
        for (Curve c : curves) {
            addCurve(s, c, width, height);
        }
        return s;
    }

    /** glyph_curves(font, name, m): every quadratic of glyph_outline, transformed by m, one flat list. */
    public static List<Curve> glyphCurves(Font font, String name, Matrix m) {
        List<Curve> out = new ArrayList<>();
        for (List<Curve> contour : Glyphs.glyphOutline(font, name)) {
            for (Curve c : contour) {
                out.add(Curves.transformCurve(c, m));
            }
        }
        return out;
    }

    public static Stencil glyphStencil(Font font, String name, Matrix m, int width, int height) {
        List<Curve> curves = glyphCurves(font, name, m);
        Tuple anchor = curves.isEmpty() ? Tuple.point(0, 0) : curves.get(0).points().get(0);
        return loopBlinnStencil(curves, anchor, width, height);
    }
}
