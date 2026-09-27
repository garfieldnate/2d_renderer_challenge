import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * §23.9: Plate 23, and the chapter's renders -- primitive_fields, error_map,
 * fields_vs_paths, fillets, transform_demo, atlas_corners, trap_shrink,
 * plate_23 and the title, each built exactly as chapter23-plate.feature's
 * own prose describes it (no printed pseudocode covers these, per chapters
 * 12/16/18's own precedent of pinning render geometry in the feature file
 * instead).
 */
public final class Chapter23Figures {
    private static final Color PAPER = new Color(0.02, 0.02, 0.025);
    private static final Color ORANGE = new Color(0.9, 0.55, 0.1);
    private static final Color CYAN = new Color(0.2, 0.75, 0.9);
    private static final Color MAGENTA = new Color(0.85, 0.2, 0.55);
    private static final Color DIM = new Color(0.3, 0.3, 0.34);
    private static final Color PALE = new Color(0.92, 0.9, 0.82);
    private static final Color BLACK = new Color(0, 0, 0);

    private Chapter23Figures() {}

    private static void blit(Canvas dst, Canvas src, int ox, int oy) {
        for (int y = 0; y < src.height; y++) {
            for (int x = 0; x < src.width; x++) {
                dst.writePixel(ox + x, oy + y, src.pixelAt(x, y));
            }
        }
    }

    private static double clamp01(double v) {
        return Math.max(0, Math.min(1, v));
    }

    private static Color bandColor(double d) {
        Color tint = d > 0 ? ORANGE : CYAN;
        int band = (int) Math.floor(Math.abs(d) / 6);
        double mixAmt = (band % 2 == 0) ? 0.12 : 0.3;
        Color c = Mixer.mix(PAPER, tint, mixAmt, true);
        if (Math.abs(d) < 1) {
            c = Mixer.mix(c, PALE, 1 - Math.abs(d), true);
        }
        return c;
    }

    private static Canvas bandCanvas(Field f) {
        Canvas c = new Canvas(f.width, f.height);
        for (int y = 0; y < f.height; y++) {
            for (int x = 0; x < f.width; x++) {
                c.writePixel(x, y, bandColor(Field.fieldAt(f, x, y)));
            }
        }
        return c;
    }

    private static Canvas orangePanel(CoverageBuffer cov, int w, int h) {
        Canvas c = new Canvas(w, h);
        c.fill(PAPER);
        Painter.paintThrough(c, cov, ORANGE);
        return c;
    }

    // ---- primitive_fields ------------------------------------------------------

    public static Canvas primitiveFields() {
        Canvas out = new Canvas(640, 160);
        Field circle = Field.field(160, 160, (x, y) -> Sdf.sdCircle(Tuple.point(x, y), Tuple.point(80, 80), 50));
        Field box = Field.field(160, 160, (x, y) -> Sdf.sdBox(Tuple.point(x, y), Tuple.point(80, 80), 55, 35));
        Field rounded = Field.field(160, 160,
                (x, y) -> Sdf.sdRoundedBox(Tuple.point(x, y), Tuple.point(80, 80), 55, 35, 20));
        Field star = Fields.polygonField(Figures.star(), "evenodd", 160, 160);
        Field[] fields = {circle, box, rounded, star};
        for (int i = 0; i < fields.length; i++) {
            blit(out, bandCanvas(fields[i]), i * 160, 0);
        }
        return out;
    }

    // ---- error_map ---------------------------------------------------------------

    private static void paintErrorMagenta(Canvas c, CoverageBuffer err) {
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                double k = Math.min(1, 4 * err.coverageAt(x, y));
                c.writePixel(x, y, Mixer.mix(c.pixelAt(x, y), MAGENTA, k, true));
            }
        }
    }

    public static Canvas errorMap() {
        Canvas out = new Canvas(480, 160);
        Path star = Figures.star();
        Field raw = Fields.polygonField(star, "nonzero", 160, 160);
        CoverageBuffer exact = Fill.fillPath(star, "nonzero", 160, 160);

        Canvas p1 = new Canvas(160, 160);
        p1.fill(PAPER);
        Painter.paintThrough(p1, Fields.fieldCoverage(raw), ORANGE);

        Canvas p2 = new Canvas(160, 160);
        p2.fill(PAPER);
        paintErrorMagenta(p2, Fields.coverageError(Fields.fieldCoverage(raw), exact));

        Field clean = Fields.polygonField(BoolCombine.simplify(star, "nonzero"), "nonzero", 160, 160);
        Canvas p3 = new Canvas(160, 160);
        p3.fill(PAPER);
        paintErrorMagenta(p3, Fields.coverageError(Fields.fieldCoverage(clean), exact));

        blit(out, p1, 0, 0);
        blit(out, p2, 160, 0);
        blit(out, p3, 320, 0);
        return out;
    }

    // ---- fields_vs_paths -----------------------------------------------------------

    public static Canvas fieldsVsPaths() {
        Canvas out = new Canvas(600, 400);
        Path movedStar = Paths.transformPath(Figures.star(), Transforms.translation(19.5, 19.5));

        Canvas t1 = orangePanel(
                Fill.fillPath(Stroke.strokeToPath(movedStar, 10, "round", "round", 4), "nonzero", 200, 200), 200, 200);
        Canvas t2 = orangePanel(
                Fill.fillPath(Offset.strokeCurveToPath(Fields.sCurve(), 20, "round", 0.05), "nonzero", 200, 200),
                200, 200);
        Canvas t3 = orangePanel(
                Fill.fillPath(BoolCombine.combine(Figures.plateGlyph(), "nonzero", Figures.plateStar(), "evenodd", "xor"),
                        "nonzero", 200, 200),
                200, 200);

        Canvas b1 = orangePanel(Fields.fieldCoverage(Fields.fieldStroke(
                Fields.polygonField(movedStar, "nonzero", 200, 200), 10)), 200, 200);
        Canvas b2 = orangePanel(Fields.fieldCoverage(Fields.fieldStroke(Fields.cubicField(Fields.sCurve(), 200, 200), 20)),
                200, 200);
        Canvas b3 = orangePanel(Fields.fieldCoverage(
                Fields.fieldXor(Fields.plateGlyphField(), Fields.polygonField(Figures.plateStar(), "evenodd", 200, 200))),
                200, 200);

        blit(out, t1, 0, 0);
        blit(out, t2, 200, 0);
        blit(out, t3, 400, 0);
        blit(out, b1, 0, 200);
        blit(out, b2, 200, 200);
        blit(out, b3, 400, 200);
        return out;
    }

    // ---- fillets -------------------------------------------------------------------

    public static Canvas fillets() {
        Canvas out = new Canvas(640, 160);
        int[] ks = {0, 8, 16, 32};
        for (int i = 0; i < ks.length; i++) {
            Field f = Fields.filletField(ks[i]);
            Canvas p = new Canvas(160, 160);
            p.fill(PAPER);
            Painter.paintThrough(p, Fields.fieldCoverage(f), ORANGE);
            Painter.paintThrough(p, Fields.fieldCoverage(Fields.fieldStroke(f, 1.5)), PALE);
            blit(out, p, i * 160, 0);
        }
        return out;
    }

    // ---- transform_demo --------------------------------------------------------------

    public static Canvas transformDemo() {
        Canvas out = new Canvas(576, 192);
        CoverageBuffer bmp = Figures.transformBitmap();
        Canvas p1 = new Canvas(64, 64);
        p1.fill(PAPER);
        Painter.paintThrough(p1, bmp, ORANGE);

        Field f = DistanceTransform.fieldFromCoverage(bmp);
        Canvas p2 = bandCanvas(f);

        Canvas p3 = new Canvas(64, 64);
        p3.fill(PAPER);
        double[] offsets = {6, 3, 0};
        Color[] cols = {MAGENTA, CYAN, ORANGE};
        for (int i = 0; i < offsets.length; i++) {
            Field offset = Fields.fieldOffset(f, offsets[i]);
            Painter.paintThrough(p3, Fields.fieldCoverage(Fields.fieldStroke(offset, 1.5)), cols[i]);
        }

        blit(out, Magnify.magnify(p1, 3), 0, 0);
        blit(out, Magnify.magnify(p2, 3), 192, 0);
        blit(out, Magnify.magnify(p3, 3), 384, 0);
        return out;
    }

    // ---- atlas_corners --------------------------------------------------------------

    public static Canvas atlasCorners() {
        Canvas out = new Canvas(1200, 400);
        Font font = Figures.robotoFont();
        String eName = Fonts.glyphName(font, 'E');
        String kName = Fonts.glyphName(font, 'k');
        Baked[] bakes = {
                Msdf.bakeSdf(font, eName, 16, 3),
                Msdf.bakeMsdf(font, eName, 16, 3),
                Msdf.bakeMsdf(font, kName, 16, 3),
                Msdf.bakeMsdf(font, kName, 32, 3)
        };
        double[] scales = {20, 20, 20, 10};
        for (int i = 0; i < bakes.length; i++) {
            Canvas p = new Canvas(300, 400);
            p.fill(PAPER);
            double scale = scales[i];
            double x = 10 - bakes[i].left * scale;
            double y = 10 - bakes[i].top * scale;
            Msdf.drawBaked(p, bakes[i], scale, x, y, ORANGE);
            blit(out, p, i * 300, 0);
        }
        return out;
    }

    // ---- trap_shrink ------------------------------------------------------------------

    private static Canvas trapPanel(Field f) {
        Canvas c = new Canvas(170, 160);
        c.fill(PAPER);
        Painter.paintThrough(c, Fields.fieldCoverage(Fields.fieldOffset(f, -20)), ORANGE);
        Painter.paintThrough(c, Fields.fieldCoverage(Fields.fieldStroke(f, 1.5)), DIM);
        return c;
    }

    public static Canvas trapShrink() {
        Canvas out = new Canvas(340, 160);
        Path a = Figures.peanut()[0];
        Path b = Figures.peanut()[1];
        Field fa = Fields.polygonField(a, "nonzero", 170, 160);
        Field fb = Fields.polygonField(b, "nonzero", 170, 160);
        Field minField = Fields.fieldUnion(fa, fb);
        Path u = BoolCombine.combine(a, "nonzero", b, "nonzero", "union");
        Field trueField = Fields.polygonField(u, "nonzero", 170, 160);
        blit(out, trapPanel(minField), 0, 0);
        blit(out, trapPanel(trueField), 170, 0);
        return out;
    }

    // ---- plate_23 -----------------------------------------------------------------------

    public static Field plateField() {
        Font font = Figures.robotoFont();
        String amp = Fonts.glyphName(font, '&');
        Matrix m = Glyphs.textMatrix(font, 170, 38, 164);
        List<List<Curve>> outline = Glyphs.glyphOutline(font, amp);
        Path glyphPath = Glyphs.glyphPath(font, amp, m, 0.01);
        return Field.field(200, 200, (x, y) -> {
            Tuple p = Tuple.point(x, y);
            double best = Double.POSITIVE_INFINITY;
            for (List<Curve> contour : outline) {
                for (Curve c : contour) {
                    best = Math.min(best, CurveDistance.distanceToQuadratic(p, Curves.transformCurve(c, m)));
                }
            }
            boolean inside = Winding.insideNonzero(glyphPath, x, y);
            return inside ? -best : best;
        });
    }

    public static Canvas plate23() {
        Canvas out = new Canvas(800, 200);
        Field f = plateField();

        Canvas p1 = bandCanvas(f);

        Canvas p2 = new Canvas(200, 200);
        p2.fill(PAPER);
        Painter.paintThrough(p2, Fields.fieldCoverage(f), ORANGE);

        Canvas p3 = new Canvas(200, 200);
        p3.fill(PAPER);
        Painter.paintThrough(p3, Fields.fieldCoverage(Fields.fieldStroke(f, 4)), CYAN);

        Canvas p4 = new Canvas(200, 200);
        p4.fill(PAPER);
        for (int y = 0; y < 200; y++) {
            for (int x = 0; x < 200; x++) {
                double d = Field.fieldAt(f, x, y);
                if (d > 0) {
                    double k = 0.8 * Math.exp(-d / 10);
                    p4.writePixel(x, y, Mixer.mix(p4.pixelAt(x, y), MAGENTA, k, true));
                }
            }
        }
        Painter.paintThrough(p4, Fields.fieldCoverage(f), ORANGE);

        blit(out, p1, 0, 0);
        blit(out, p2, 200, 0);
        blit(out, p3, 400, 0);
        blit(out, p4, 600, 0);
        return out;
    }

    // ---- title --------------------------------------------------------------------------

    public static Canvas title() {
        Canvas out = new Canvas(900, 220);
        out.fill(PAPER);
        Font font = Figures.robotoFont();
        List<Placement> run = Layout.layoutRun(font, "DISTANCE", 160, 78, 172, true);
        Map<String, Baked> cache = new HashMap<>();
        for (Placement pl : run) {
            cache.computeIfAbsent(pl.name(), n -> Msdf.bakeMtsdf(font, n, 32, 4));
        }
        double scale = 5;

        for (Placement pl : run) {
            Msdf.drawEffect(out, cache.get(pl.name()), scale, pl.x() + 8, pl.y() + 8, BLACK, true,
                    d -> 0.6 * clamp01((10 - d) / 20));
        }
        for (Placement pl : run) {
            Msdf.drawEffect(out, cache.get(pl.name()), scale, pl.x(), pl.y(), MAGENTA, true, d -> {
                double t = 1 - clamp01(d / 20);
                return 0.8 * t * t;
            });
        }
        for (Placement pl : run) {
            Msdf.drawEffect(out, cache.get(pl.name()), scale, pl.x(), pl.y(), ORANGE, false, d -> clamp01(0.5 - d));
        }
        for (Placement pl : run) {
            Msdf.drawEffect(out, cache.get(pl.name()), scale, pl.x(), pl.y(), PALE, false,
                    d -> clamp01(0.5 - (Math.abs(d) - 1.5)));
        }
        return out;
    }
}
