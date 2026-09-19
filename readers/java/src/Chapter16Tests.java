import java.io.IOException;
import java.nio.file.Files;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter16-*.feature into a Java test. No JUnit, no network: run
 * from the project root so reference/chapter-16/*.ppm and roboto.json
 * resolve.
 */
public final class Chapter16Tests {

    private interface Scenario {
        void run() throws Exception;
    }

    private static final List<String> names = new java.util.ArrayList<>();
    private static final List<Scenario> bodies = new java.util.ArrayList<>();

    private static void scenario(String name, Scenario body) {
        names.add(name);
        bodies.add(body);
    }

    // ---- assertion helpers -------------------------------------------------

    private static void assertTrue(String what, boolean condition) {
        if (!condition) {
            throw new AssertionError(what);
        }
    }

    private static void assertEquals(String what, Object actual, Object expected) {
        if (!actual.equals(expected)) {
            throw new AssertionError(what + ": expected [" + expected + "] but got [" + actual + "]");
        }
    }

    private static void assertDoubleEq(String what, double actual, double expected) {
        assertDoubleEq(what, actual, expected, Numbers.DEFAULT_EPSILON);
    }

    private static void assertDoubleEq(String what, double actual, double expected, double eps) {
        if (!Numbers.approxEqual(actual, expected, eps)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual
                    + " (tolerance " + eps + ")");
        }
    }

    private static void assertTupleEq(String what, Tuple actual, Tuple expected) {
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertContourPointEq(String what, ContourPoint actual, ContourPoint expected) {
        if (!Numbers.approxEqual(actual.x(), expected.x()) || !Numbers.approxEqual(actual.y(), expected.y())
                || actual.on() != expected.on()) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertTriple(String what, int[] actual, int[] expected, int tolerance) {
        for (int i = 0; i < 3; i++) {
            if (Math.abs(actual[i] - expected[i]) > tolerance) {
                throw new AssertionError(what + ": expected " + Arrays.toString(expected)
                        + " but got " + Arrays.toString(actual) + " (tolerance " + tolerance + ")");
            }
        }
    }

    private static Font font;

    private static Font font() throws IOException {
        if (font == null) {
            font = Fonts.loadFont(readReferenceText("roboto.json"));
        }
        return font;
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerFont();
        registerContours();
        registerComposites();
        registerPath();
        registerPlate();
    }

    // features/chapter16-font.feature
    private static void registerFont() {
        scenario("Font: the font's vertical metrics", () -> {
            Font f = font();
            assertDoubleEq("font.units_per_em", f.unitsPerEm, 2048);
            assertDoubleEq("font.ascender", f.ascender, 1900);
            assertDoubleEq("font.descender", f.descender, -500);
            assertDoubleEq("font.line_gap", f.lineGap, 0);
            assertEquals("glyph_count(font)", Fonts.glyphCount(f), 177);
        });

        scenario("Font: characters map to glyph names, and a missing one maps to .notdef", () -> {
            Font f = font();
            assertEquals("glyph_name(font, 65)", Fonts.glyphName(f, 65), "A");
            assertEquals("glyph_name(font, 233)", Fonts.glyphName(f, 233), "eacute");
            assertEquals("glyph_name(font, 64257)", Fonts.glyphName(f, 64257), "f_i");
            assertEquals("glyph_name(font, 9731)", Fonts.glyphName(f, 9731), ".notdef");
        });

        scenario("Font: advances are in font units", () -> {
            Font f = font();
            assertDoubleEq("glyph_advance(font, \"A\")", Fonts.glyphAdvance(f, "A"), 1336);
            assertDoubleEq("glyph_advance(font, \"space\")", Fonts.glyphAdvance(f, "space"), 507);
            assertDoubleEq("glyph_advance(font, \".notdef\")", Fonts.glyphAdvance(f, ".notdef"), 908);
            assertDoubleEq("glyph_advance(font, \"i\")", Fonts.glyphAdvance(f, "i"), 497);
        });

        scenario("Font: a glyph is contours of flagged points", () -> {
            Font f = font();
            Glyph g = f.glyphs.get("i");
            assertEquals("length(g.contours)", g.contours().size(), 2);
            assertEquals("length(g.contours[0])", g.contours().get(0).size(), 4);
            assertContourPointEq("g.contours[0][0]", g.contours().get(0).get(0), new ContourPoint(341, 0, true));
            assertEquals("length(g.contours[1])", g.contours().get(1).size(), 9);
            assertContourPointEq("g.contours[1][1]", g.contours().get(1).get(1), new ContourPoint(141, 1414, false));
            assertEquals("length(g.components)", g.components().size(), 0);
        });
    }

    // features/chapter16-contours.feature
    private static void registerContours() {
        scenario("Contours: a loop of off-curve points implies a midpoint between each pair", () -> {
            List<ContourPoint> c = List.of(
                    new ContourPoint(0, 0, false), new ContourPoint(10, 0, false),
                    new ContourPoint(10, 10, false), new ContourPoint(0, 10, false));
            List<ContourPoint> pts = Contours.impliedPoints(c);
            assertEquals("length(pts)", pts.size(), 8);
            assertContourPointEq("pts[0]", pts.get(0), new ContourPoint(5, 0, true));
            assertContourPointEq("pts[1]", pts.get(1), new ContourPoint(10, 0, false));
            assertContourPointEq("pts[2]", pts.get(2), new ContourPoint(10, 5, true));
            assertContourPointEq("pts[7]", pts.get(7), new ContourPoint(0, 0, false));
            List<Curve> curves = Contours.contourCurves(c);
            assertEquals("length(contour_curves(c))", curves.size(), 4);
            assertTupleEq("contour_curves(c)[0].points[0]", curves.get(0).points().get(0), Tuple.point(5, 0));
            assertTupleEq("contour_curves(c)[0].points[1]", curves.get(0).points().get(1), Tuple.point(10, 0));
            assertTupleEq("contour_curves(c)[0].points[2]", curves.get(0).points().get(2), Tuple.point(10, 5));
        });

        scenario("Contours: a loop that starts off-curve is rotated to start on-curve", () -> {
            List<ContourPoint> c = List.of(
                    new ContourPoint(10, 0, false), new ContourPoint(10, 10, true),
                    new ContourPoint(0, 10, true), new ContourPoint(0, 0, true));
            List<ContourPoint> pts = Contours.impliedPoints(c);
            assertEquals("length(pts)", pts.size(), 4);
            assertContourPointEq("pts[0]", pts.get(0), new ContourPoint(10, 10, true));
            assertContourPointEq("pts[3]", pts.get(3), new ContourPoint(10, 0, false));
        });

        scenario("Contours: straight edges become quadratics through their midpoints", () -> {
            List<ContourPoint> c = List.of(
                    new ContourPoint(0, 0, true), new ContourPoint(10, 0, true), new ContourPoint(5, 8, true));
            List<Curve> curves = Contours.contourCurves(c);
            assertEquals("length(curves)", curves.size(), 3);
            assertTupleEq("curves[0].points[1]", curves.get(0).points().get(1), Tuple.point(5, 0));
            assertTupleEq("curves[1].points[1]", curves.get(1).points().get(1), Tuple.point(7.5, 4));
            assertTupleEq("curves[2].points[0]", curves.get(2).points().get(0), Tuple.point(5, 8));
            assertTupleEq("curves[2].points[2]", curves.get(2).points().get(2), Tuple.point(0, 0));
        });

        scenario("Contours: mixed points: on, off, off, on", () -> {
            List<ContourPoint> c = List.of(
                    new ContourPoint(0, 0, true), new ContourPoint(10, 0, false),
                    new ContourPoint(10, 10, false), new ContourPoint(0, 10, true));
            List<Curve> curves = Contours.contourCurves(c);
            assertEquals("length(implied_points(c))", Contours.impliedPoints(c).size(), 5);
            assertContourPointEq("implied_points(c)[2]", Contours.impliedPoints(c).get(2), new ContourPoint(10, 5, true));
            assertEquals("length(curves)", curves.size(), 3);
            assertTupleEq("curves[0].points[2]", curves.get(0).points().get(2), Tuple.point(10, 5));
            assertTupleEq("curves[1].points[0]", curves.get(1).points().get(0), Tuple.point(10, 5));
            assertTupleEq("curves[2].points[1]", curves.get(2).points().get(1), Tuple.point(0, 5));
        });

        scenario("Contours: the dot of the i is mostly implied", () -> {
            Font f = font();
            List<ContourPoint> dot = f.glyphs.get("i").contours().get(1);
            assertEquals("length(dot)", dot.size(), 9);
            assertEquals("length(implied_points(dot))", Contours.impliedPoints(dot).size(), 16);
            assertContourPointEq("implied_points(dot)[2]", Contours.impliedPoints(dot).get(2),
                    new ContourPoint(168.5, 1445, true));
            List<Curve> dotCurves = Contours.contourCurves(dot);
            assertEquals("length(contour_curves(dot))", dotCurves.size(), 8);
            assertTupleEq("contour_curves(dot)[1].points[0]", dotCurves.get(1).points().get(0), Tuple.point(168.5, 1445));
            assertTupleEq("contour_curves(dot)[1].points[1]", dotCurves.get(1).points().get(1), Tuple.point(196, 1476));
            assertTupleEq("contour_curves(dot)[1].points[2]", dotCurves.get(1).points().get(2), Tuple.point(250, 1476));
            assertEquals("length(contour_curves(font.glyphs[\"i\"].contours[0]))",
                    Contours.contourCurves(f.glyphs.get("i").contours().get(0)).size(), 4);
            assertEquals("length(contour_curves(font.glyphs[\"o\"].contours[0]))",
                    Contours.contourCurves(f.glyphs.get("o").contours().get(0)).size(), 12);
        });
    }

    // features/chapter16-composites.feature
    private static void registerComposites() {
        scenario("Composites: a component transform is a matrix", () -> {
            assertTupleEq("component_matrix([1, 0, 0, 1, 340, 0]) * point(5, 5)",
                    Glyphs.componentMatrix(new double[] {1, 0, 0, 1, 340, 0}).multiply(Tuple.point(5, 5)),
                    Tuple.point(345, 5));
            assertTupleEq("component_matrix([2, 0, 0, 1, 10, 0]) * point(3, 4)",
                    Glyphs.componentMatrix(new double[] {2, 0, 0, 1, 10, 0}).multiply(Tuple.point(3, 4)),
                    Tuple.point(16, 4));
            assertTupleEq("component_matrix([1, 0.5, 0, 1, 0, 0]) * point(2, 4)",
                    Glyphs.componentMatrix(new double[] {1, 0.5, 0, 1, 0, 0}).multiply(Tuple.point(2, 4)),
                    Tuple.point(2, 5));
            assertTupleEq("component_matrix([1, 0, 0.5, 1, 0, 0]) * point(2, 4)",
                    Glyphs.componentMatrix(new double[] {1, 0, 0.5, 1, 0, 0}).multiply(Tuple.point(2, 4)),
                    Tuple.point(4, 4));
            assertTrue("component_matrix([1, 0, 0, 1, 0, 0]) = identity()",
                    Glyphs.componentMatrix(new double[] {1, 0, 0, 1, 0, 0}).approxEquals(Matrix.identity()));
        });

        scenario("Composites: eacute is an e and an acute moved right", () -> {
            Font f = font();
            Glyph g = f.glyphs.get("eacute");
            assertEquals("length(g.contours)", g.contours().size(), 0);
            assertEquals("length(g.components)", g.components().size(), 2);
            assertEquals("g.components[0][0]", g.components().get(0).glyph(), "e");
            assertEquals("g.components[1][0]", g.components().get(1).glyph(), "acute");
            assertTrue("g.components[1][1] = [1, 0, 0, 1, 340, 0]",
                    Arrays.equals(g.components().get(1).transform(), new double[] {1, 0, 0, 1, 340, 0}));
            assertEquals("length(glyph_outline(font, \"eacute\"))", Glyphs.glyphOutline(f, "eacute").size(), 3);
            assertEquals("length(glyph_outline(font, \"e\"))", Glyphs.glyphOutline(f, "e").size(), 2);
            assertEquals("length(glyph_outline(font, \"acute\"))", Glyphs.glyphOutline(f, "acute").size(), 1);
        });

        scenario("Composites: a composite's bounds are the union of its transformed components", () -> {
            Font f = font();
            assertBounds("glyph_bounds(font, \"e\")", Glyphs.glyphBounds(f, "e"), 93, -20, 1011, 1102);
            assertBounds("glyph_bounds(font, \"acute\")", Glyphs.glyphBounds(f, "acute"), 123, 1240, 540, 1534);
            assertBounds("glyph_bounds(font, \"eacute\")", Glyphs.glyphBounds(f, "eacute"), 93, -20, 1011, 1534);
            assertBounds("glyph_bounds(font, \"aring\")", Glyphs.glyphBounds(f, "aring"), 109, -20, 1002, 1627);
            assertBounds("glyph_bounds(font, \"space\")", Glyphs.glyphBounds(f, "space"), 0, 0, 0, 0);
        });

        scenario("Composites: two more real glyphs' bounds", () -> {
            Font f = font();
            assertBounds("glyph_bounds(font, \"o\")", Glyphs.glyphBounds(f, "o"), 91, -20, 1076, 1102);
            assertBounds("glyph_bounds(font, \"H\")", Glyphs.glyphBounds(f, "H"), 169, 0, 1288, 1456);
        });

        scenario("Composites: bounds are tight, not the control box: a hand-written bump stops where its curve does", () -> {
            String json = "{\"units_per_em\": 1000, \"ascender\": 800, \"descender\": -200, \"line_gap\": 0, "
                    + "\"cmap\": {\"98\": \"bump\"}, \"glyphs\": {\"bump\": {\"advance\": 300, "
                    + "\"contours\": [[[0, 0, true], [100, 200, false], [200, 0, true]]], \"components\": []}, "
                    + "\"twice\": {\"advance\": 600, \"contours\": [], \"components\": ["
                    + "{\"glyph\": \"bump\", \"transform\": [1, 0, 0, 1, 0, 0]}, "
                    + "{\"glyph\": \"bump\", \"transform\": [1, 0, 0.5, 2, 300, 0]}]}}}";
            Font tiny = Fonts.loadFont(json);
            assertEquals("glyph_count(tiny)", Fonts.glyphCount(tiny), 2);
            assertEquals("glyph_name(tiny, 98)", Fonts.glyphName(tiny, 98), "bump");
            assertEquals("length(glyph_outline(tiny, \"bump\"))", Glyphs.glyphOutline(tiny, "bump").size(), 1);
            assertEquals("length(glyph_outline(tiny, \"bump\")[0])", Glyphs.glyphOutline(tiny, "bump").get(0).size(), 2);
            assertBounds("glyph_bounds(tiny, \"bump\")", Glyphs.glyphBounds(tiny, "bump"), 0, 0, 200, 100);
            assertBounds("glyph_bounds(tiny, \"twice\")", Glyphs.glyphBounds(tiny, "twice"), 0, 0, 500, 200);
        });
    }

    private static void assertBounds(String what, Bounds b, double minX, double minY, double maxX, double maxY) {
        assertDoubleEq(what + ".minX", b.minX(), minX);
        assertDoubleEq(what + ".minY", b.minY(), minY);
        assertDoubleEq(what + ".maxX", b.maxX(), maxX);
        assertDoubleEq(what + ".maxY", b.maxY(), maxY);
    }

    // features/chapter16-path.feature
    private static void registerPath() {
        scenario("Path: the text matrix scales and turns y over", () -> {
            Font f = font();
            Matrix m = Glyphs.textMatrix(f, 2048, 100, 500);
            assertTupleEq("m * point(0, 0)", m.multiply(Tuple.point(0, 0)), Tuple.point(100, 500));
            assertTupleEq("m * point(2048, 2048)", m.multiply(Tuple.point(2048, 2048)), Tuple.point(2148, -1548));
            assertTupleEq("m * point(0, 1900)", m.multiply(Tuple.point(0, 1900)), Tuple.point(100, -1400));
            assertTupleEq("text_matrix(font, 16, 10, 20) * point(1024, 1024)",
                    Glyphs.textMatrix(f, 16, 10, 20).multiply(Tuple.point(1024, 1024)), Tuple.point(18, 12));
        });

        scenario("Path: a glyph path has one closed subpath per contour", () -> {
            Font f = font();
            Matrix m = Glyphs.textMatrix(f, 200, 20, 160);
            Path o = Glyphs.glyphPath(f, "o", m, 0.05);
            assertEquals("length(subpaths(glyph_path(font, \"o\", m, 0.05)))", o.subpaths().size(), 2);
            assertTrue("subpaths(...)[0].closed", o.subpaths().get(0).closed);
            assertTrue("subpaths(...)[1].closed", o.subpaths().get(1).closed);
            assertEquals("length(subpaths(glyph_path(font, \"eacute\", m, 0.05)))",
                    Glyphs.glyphPath(f, "eacute", m, 0.05).subpaths().size(), 3);
            assertEquals("length(subpaths(glyph_path(font, \"i\", m, 0.05)))",
                    Glyphs.glyphPath(f, "i", m, 0.05).subpaths().size(), 2);
        });

        scenario("Path: the two contours of an o wind opposite ways, and the flip turns both over", () -> {
            Font f = font();
            Matrix m = Glyphs.textMatrix(f, 200, 20, 160);
            assertDoubleEq("polygon_area(contour_path(font, \"o\", 0, m, 0.05))",
                    Fill.polygonArea(Glyphs.contourPath(f, "o", 0, m, 0.05)), 8509.81, 0.01);
            assertDoubleEq("polygon_area(contour_path(font, \"o\", 1, m, 0.05))",
                    Fill.polygonArea(Glyphs.contourPath(f, "o", 1, m, 0.05)), -3894.40, 0.01);
            assertTrue("polygon_area(contour_path(font, \"o\", 0, identity(), 1)) <= 0",
                    Fill.polygonArea(Glyphs.contourPath(f, "o", 0, Matrix.identity(), 1)) <= 0);
            assertTrue("polygon_area(contour_path(font, \"o\", 1, identity(), 1)) >= 0",
                    Fill.polygonArea(Glyphs.contourPath(f, "o", 1, Matrix.identity(), 1)) >= 0);
        });

        scenario("Path: the counter is a hole: the ink is the outer area minus the inner", () -> {
            Font f = font();
            Matrix m = Glyphs.textMatrix(f, 200, 20, 160);
            CoverageBuffer cov = Fill.fillPath(Glyphs.glyphPath(f, "o", m, 0.05), "nonzero", 200, 200);
            assertDoubleEq("ink(cov)", cov.ink(), 4615.41, 0.01);
            assertDoubleEq("coverage_at(cov, 35, 110)", cov.coverageAt(35, 110), 1);
            assertDoubleEq("coverage_at(cov, 72, 100)", cov.coverageAt(72, 100), 0);
            assertDoubleEq("coverage_at(cov, 5, 5)", cov.coverageAt(5, 5), 0);
        });
    }

    // features/chapter16-plate.feature
    private static void registerPlate() {
        scenario("Plate 16: the glyph and its control points", () -> {
            Canvas c = Figures.glyphPlate();
            byte[] ref = readReference("glyph.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 320);
            assertTriple("ppm_pixel(p6, 160, 160)", Ppm.ppmPixel(p6, 160, 160), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 10, 10)", Ppm.ppmPixel(p6, 10, 10), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 16: Plate 16", () -> {
            Canvas c = Figures.plate16();
            byte[] ref = readReference("plate-16.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 640);
            assertEquals("c.height", c.height, 640);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 16: a composite in two inks", () -> {
            Canvas c = Figures.compositeDemo();
            byte[] ref = readReference("composite.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 240);
            assertEquals("c.height", c.height, 240);
            assertTriple("ppm_pixel(p6, 120, 120)", Ppm.ppmPixel(p6, 120, 120), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 120, 30)", Ppm.ppmPixel(p6, 120, 30), new int[] {124, 196, 237}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 16: one glyph at four sizes", () -> {
            Canvas c = Figures.sizes();
            byte[] ref = readReference("sizes.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 240);
            assertEquals("c.height", c.height, 120);
            assertTriple("ppm_pixel(p6, 95, 40)", Ppm.ppmPixel(p6, 95, 40), new int[] {199, 199, 204}, 1);
            assertTriple("ppm_pixel(p6, 230, 110)", Ppm.ppmPixel(p6, 230, 110), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 16: the flip, forgotten", () -> {
            Canvas c = Figures.flipTrap();
            byte[] ref = readReference("flip.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 240);
            assertEquals("c.height", c.height, 120);
            assertTriple("ppm_pixel(p6, 50, 40)", Ppm.ppmPixel(p6, 50, 40), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 170, 80)", Ppm.ppmPixel(p6, 170, 80), new int[] {237, 124, 196}, 1);
            assertTriple("ppm_pixel(p6, 60, 100)", Ppm.ppmPixel(p6, 60, 100), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference/chapter-16", filename));
    }

    private static String readReferenceText(String filename) throws IOException {
        return Files.readString(java.nio.file.Path.of("reference/chapter-16", filename));
    }

    // ---- runner ---------------------------------------------------------

    public static void main(String[] args) throws IOException {
        registerAll();

        int passed = 0;
        int failed = 0;
        long start = System.nanoTime();
        for (int i = 0; i < names.size(); i++) {
            Mixer.linearBlending = true; // reset before each scenario, per §1.7
            String name = names.get(i);
            try {
                bodies.get(i).run();
                passed++;
                System.out.println("PASS  " + name);
            } catch (Throwable t) {
                failed++;
                System.out.println("FAIL  " + name + " -- " + t.getMessage());
            }
        }
        long elapsedMs = (System.nanoTime() - start) / 1_000_000;

        System.out.println();
        System.out.println("Total: " + names.size() + "  Passed: " + passed + "  Failed: " + failed
                + "  (" + elapsedMs + " ms)");

        writeRenders();
    }

    private static void writeRenders() throws IOException {
        Files.createDirectories(java.nio.file.Path.of("out"));
        writeOne("glyph.ppm", Figures.glyphPlate());
        writeOne("plate-16.ppm", Figures.plate16());
        writeOne("composite.ppm", Figures.compositeDemo());
        writeOne("sizes.ppm", Figures.sizes());
        writeOne("flip.ppm", Figures.flipTrap());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
