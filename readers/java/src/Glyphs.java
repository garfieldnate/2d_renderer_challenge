import java.util.ArrayList;
import java.util.List;

/**
 * §16.3: a component's transform is six numbers [a, b, c, d, dx, dy] that
 * TrueType applies as x' = a*x + c*y + dx, y' = b*x + d*y + dy;
 * component_matrix builds the matrix3 with the letters in that order.
 * glyph_outline(font, name) is every contour of a glyph as quadratics, in
 * font units, y up -- its own contours through contour_curves, followed by
 * each component's own outline, recursively, taken through its matrix.
 * glyph_bounds(font, name) is the tight box of the outline from chapter 8's
 * curve_bounds on every quadratic, (0, 0, 0, 0) for an empty glyph.
 *
 * §16.4: text_matrix(font, size, x, y) is the one place the font's y-up,
 * baseline-origin coordinates turn into the canvas's y-down, corner-origin
 * ones: scale by size / units_per_em with y negated, then translate the
 * glyph's origin to (x, y). glyph_path/contour_path take every quadratic of
 * the outline through a matrix, flatten in device space (after the
 * transform, per chapter 8's own rule), and close each contour into a
 * subpath.
 */
public final class Glyphs {
    private Glyphs() {}

    public static Matrix componentMatrix(double[] t) {
        return Matrix.matrix3(
                t[0], t[2], t[4],
                t[1], t[3], t[5],
                0, 0, 1);
    }

    public static List<List<Curve>> glyphOutline(Font font, String name) {
        Glyph g = font.glyphs.get(name);
        List<List<Curve>> out = new ArrayList<>();
        for (List<ContourPoint> contour : g.contours()) {
            out.add(Contours.contourCurves(contour));
        }
        for (Component comp : g.components()) {
            Matrix m = componentMatrix(comp.transform());
            for (List<Curve> contour : glyphOutline(font, comp.glyph())) {
                List<Curve> moved = new ArrayList<>();
                for (Curve c : contour) {
                    moved.add(Curves.transformCurve(c, m));
                }
                out.add(moved);
            }
        }
        return out;
    }

    public static Bounds glyphBounds(Font font, String name) {
        boolean any = false;
        double minX = 0, minY = 0, maxX = 0, maxY = 0;
        for (List<Curve> contour : glyphOutline(font, name)) {
            for (Curve c : contour) {
                Bounds b = Curves.curveBounds(c);
                if (!any) {
                    minX = b.minX();
                    minY = b.minY();
                    maxX = b.maxX();
                    maxY = b.maxY();
                    any = true;
                } else {
                    minX = Math.min(minX, b.minX());
                    minY = Math.min(minY, b.minY());
                    maxX = Math.max(maxX, b.maxX());
                    maxY = Math.max(maxY, b.maxY());
                }
            }
        }
        return new Bounds(minX, minY, maxX, maxY);
    }

    public static Matrix textMatrix(Font font, double size, double x, double y) {
        double s = size / font.unitsPerEm;
        return Transforms.translation(x, y).multiply(Transforms.scaling(s, -s));
    }

    private static void appendContour(Path out, List<Curve> contour, Matrix m, double tolerance) {
        boolean first = true;
        for (Curve c : contour) {
            Curve tc = Curves.transformCurve(c, m);
            for (Tuple p : Curves.flatten(tc, tolerance)) {
                if (first) {
                    out.moveTo(p);
                    first = false;
                } else {
                    out.lineTo(p);
                }
            }
        }
        out.close();
    }

    /** glyph_path(font, name, m, tolerance): one closed subpath per contour. */
    public static Path glyphPath(Font font, String name, Matrix m, double tolerance) {
        Path out = new Path();
        for (List<Curve> contour : glyphOutline(font, name)) {
            appendContour(out, contour, m, tolerance);
        }
        return out;
    }

    /** contour_path(font, name, i, m, tolerance): just contour i, as its own path. */
    public static Path contourPath(Font font, String name, int index, Matrix m, double tolerance) {
        Path out = new Path();
        appendContour(out, glyphOutline(font, name).get(index), m, tolerance);
        return out;
    }

    /** §17.5: a glyph's advance, in pixels, at a given size. */
    public static double penAdvance(Font font, String name, double size) {
        return Fonts.glyphAdvance(font, name) * size / font.unitsPerEm;
    }
}
