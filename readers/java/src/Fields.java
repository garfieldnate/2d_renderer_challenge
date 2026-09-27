import java.util.List;

/**
 * §23.3: field_coverage(f) is chapter 2's coverage buffer with clamp(0.5 -
 * d, 0, 1); polygon_field(p, rule, w, h) is the field of sd_polygon;
 * coverage_error is |cov - exact|.
 *
 * §23.4: chapters 13, 14 and 22 for free -- offset, stroke, and the four
 * boolean operations, each one line applied at every pixel.
 *
 * §23.5: smooth_min(a, b, k) fillets the crease where min(a, b) meets.
 */
public final class Fields {
    private Fields() {}

    public static CoverageBuffer fieldCoverage(Field f) {
        CoverageBuffer cov = new CoverageBuffer(f.width, f.height);
        for (int y = 0; y < f.height; y++) {
            for (int x = 0; x < f.width; x++) {
                double d = Field.fieldAt(f, x, y);
                cov.setCoverage(x, y, Math.max(0, Math.min(1, 0.5 - d)));
            }
        }
        return cov;
    }

    public static Field polygonField(Path p, String rule, int w, int h) {
        return Field.field(w, h, (x, y) -> Sdf.sdPolygon(Tuple.point(x, y), p, rule));
    }

    public static CoverageBuffer coverageError(CoverageBuffer cov, CoverageBuffer exact) {
        CoverageBuffer out = new CoverageBuffer(cov.width, cov.height);
        for (int y = 0; y < cov.height; y++) {
            for (int x = 0; x < cov.width; x++) {
                out.setCoverage(x, y, Math.abs(cov.coverageAt(x, y) - exact.coverageAt(x, y)));
            }
        }
        return out;
    }

    // ---- §23.4: chapters 13, 14 and 22 for free ------------------------------

    private interface Unary {
        double apply(double v);
    }

    private interface Binary {
        double apply(double a, double b);
    }

    private static Field mapField(Field f, Unary fn) {
        double[] out = new double[f.values.length];
        for (int i = 0; i < out.length; i++) {
            out[i] = fn.apply(f.values[i]);
        }
        return new Field(f.width, f.height, out);
    }

    private static Field zipFields(Field a, Field b, Binary fn) {
        double[] out = new double[a.values.length];
        for (int i = 0; i < out.length; i++) {
            out[i] = fn.apply(a.values[i], b.values[i]);
        }
        return new Field(a.width, a.height, out);
    }

    public static Field fieldOffset(Field f, double r) {
        return mapField(f, d -> d - r);
    }

    public static Field fieldStroke(Field f, double width) {
        return mapField(f, d -> Math.abs(d) - width / 2);
    }

    public static Field fieldUnion(Field a, Field b) {
        return zipFields(a, b, Math::min);
    }

    public static Field fieldIntersection(Field a, Field b) {
        return zipFields(a, b, Math::max);
    }

    public static Field fieldDifference(Field a, Field b) {
        return zipFields(a, b, (x, y) -> Math.max(x, -y));
    }

    public static Field fieldXor(Field a, Field b) {
        return zipFields(a, b, (x, y) -> Math.max(Math.min(x, y), -Math.max(x, y)));
    }

    public static Field cubicField(Curve c, int w, int h) {
        return Field.field(w, h, (x, y) -> CurveDistance.distanceToCubic(Tuple.point(x, y), c));
    }

    public static Curve sCurve() {
        return Curve.cubic(Tuple.point(30, 150), Tuple.point(40, 20), Tuple.point(160, 180), Tuple.point(170, 50));
    }

    /** §23.4: plate_glyph_field() -- the field of chapter 22's plate_glyph() on a 200 by 200 canvas. */
    public static Field plateGlyphField() {
        Font font = Figures.robotoFont();
        Matrix m = Glyphs.textMatrix(font, 200, 40, 140);
        List<List<Curve>> outline = Glyphs.glyphOutline(font, "g");
        Path glyphPath = Glyphs.glyphPath(font, "g", m, 0.01);
        return Field.field(200, 200, (x, y) -> {
            Tuple p = Tuple.point(x, y);
            double best = Double.POSITIVE_INFINITY;
            for (List<Curve> contour : outline) {
                for (Curve quad : contour) {
                    Curve device = Curves.transformCurve(quad, m);
                    best = Math.min(best, CurveDistance.distanceToQuadratic(p, device));
                }
            }
            boolean inside = Winding.insideNonzero(glyphPath, x, y);
            return inside ? -best : best;
        });
    }

    // ---- §23.5: something paths can't do -------------------------------------

    public static double smoothMin(double a, double b, double k) {
        if (k <= 0) {
            return Math.min(a, b);
        }
        double h = Math.max(k - Math.abs(a - b), 0) / k;
        return Math.min(a, b) - h * h * k / 4;
    }

    public static Field fieldSmoothUnion(Field a, Field b, double k) {
        return zipFields(a, b, (x, y) -> smoothMin(x, y, k));
    }

    public static Field filletField(double k) {
        return Field.field(160, 160, (x, y) -> {
            Tuple p = Tuple.point(x, y);
            double a = Sdf.sdCircle(p, Tuple.point(60, 70), 36);
            double b = Sdf.sdRoundedBox(p, Tuple.point(105, 95), 40, 25, 4);
            return smoothMin(a, b, k);
        });
    }
}
