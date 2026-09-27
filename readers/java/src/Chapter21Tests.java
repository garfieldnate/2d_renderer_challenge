import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter21-*.feature into a Java test. No JUnit, no network: run
 * from the project root so reference/chapter-20, reference/chapter-21
 * resolve.
 */
public final class Chapter21Tests {

    private interface Scenario {
        void run() throws Exception;
    }

    private static final List<String> names = new ArrayList<>();
    private static final List<Scenario> bodies = new ArrayList<>();

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
        if (!java.util.Objects.equals(actual, expected)) {
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

    private static void assertPixelEq(String what, Pixel actual, Pixel expected) {
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertIntBoundsEq(String what, BoundedFill.IntBounds actual, BoundedFill.IntBounds expected) {
        if (!actual.equals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertRowEq(String what, String[] actual, String[] expected) {
        if (!Arrays.equals(actual, expected)) {
            throw new AssertionError(what + ": expected " + Arrays.toString(expected)
                    + " but got " + Arrays.toString(actual));
        }
    }

    private static void assertPairEq(String what, int[] actual, int partial, int solid) {
        if (actual[0] != partial || actual[1] != solid) {
            throw new AssertionError(what + ": expected (" + partial + ", " + solid + ") but got ("
                    + actual[0] + ", " + actual[1] + ")");
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

    private static String readText(String path) throws IOException {
        return java.nio.file.Files.readString(java.nio.file.Path.of(path));
    }

    private static byte[] readBytes(String path) throws IOException {
        return java.nio.file.Files.readAllBytes(java.nio.file.Path.of(path));
    }

    private static Color color(double r, double g, double b) {
        return new Color(r, g, b);
    }

    private static Tuple pt(double x, double y) {
        return Tuple.point(x, y);
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerBounds();
        registerCounting();
        registerTiles();
        registerSpans();
        registerSimd();
        registerPlate();
    }

    // ---- §21.3: bounds -----------------------------------------------------

    private static void registerBounds() {
        scenario("Bounds: the window under a path, in whole pixels", () -> {
            assertIntBoundsEq("axis-aligned, fractional",
                    BoundedFill.fillBounds(
                            Paths.polygon(pt(2.5, 3.25), pt(20, 3.25), pt(20, 17.75), pt(2.5, 17.75)), 64, 64),
                    new BoundedFill.IntBounds(2, 3, 21, 18));
            assertIntBoundsEq("edges on integers are included",
                    BoundedFill.fillBounds(Paths.polygon(pt(2, 3), pt(20, 3), pt(20, 18), pt(2, 18)), 64, 64),
                    new BoundedFill.IntBounds(2, 3, 21, 19));
            assertIntBoundsEq("clipped to the canvas",
                    BoundedFill.fillBounds(
                            Paths.polygon(pt(-5, -5), pt(10.5, -5), pt(10.5, 70), pt(-5, 70)), 64, 64),
                    new BoundedFill.IntBounds(0, 0, 11, 64));
            assertIntBoundsEq("entirely off canvas",
                    BoundedFill.fillBounds(Paths.polygon(pt(70, 5), pt(80, 5), pt(80, 10), pt(70, 10)), 64, 64),
                    BoundedFill.IntBounds.EMPTY);
            assertIntBoundsEq("an empty path", BoundedFill.fillBounds(new Path(), 64, 64),
                    BoundedFill.IntBounds.EMPTY);
        });

        scenario("Bounds: a bounded fill resolves only its window, and agrees with chapter 7", () -> {
            Stats st = new Stats();
            Path tri = Paths.polygon(pt(3.3, 2.7), pt(40.1, 9.9), pt(12.6, 33.3));
            BoundedFill.FillWindow win = BoundedFill.fillPathBounded(tri, "nonzero", 64, 64, st);
            assertEquals("win.x0", win.x0(), 3);
            assertEquals("win.y0", win.y0(), 2);
            assertEquals("win.cov.width", win.cov().width, 38);
            assertEquals("win.cov.height", win.cov().height, 32);
            assertEquals("st.cells", st.cells, 1216L);
            assertDoubleEq("coverage_in(win, 1, 1)", Coverage.coverageIn(win, 1, 1), 0);
            assertDoubleEq("coverage_in(win, 60, 60)", Coverage.coverageIn(win, 60, 60), 0);
            assertTrue("max_coverage_difference <= 0.000001",
                    CoverageBuffer.maxCoverageDifference(
                            Coverage.fullCoverage(win, 64, 64), Fill.fillPath(tri, "nonzero", 64, 64))
                            <= 0.000001);
        });

        scenario("Bounds: the tiger, bounded", () -> {
            Stats st = new Stats();
            Canvas c = SvgWalker.renderSvgWith(readText("reference/chapter-20/tiger.svg"), 450, 450, "bounded", st);
            assertEquals("st.cells", st.cells, 1395287L);
            assertEquals("st.copies", st.copies, 0L);
            assertTrue("max_channel_difference <= 1",
                    Ppm.maxChannelDifference(Ppm.canvasToP6(c), readBytes("reference/chapter-20/tiger.ppm")) <= 1);
        });
    }

    // ---- §21.2: counting the work --------------------------------------------

    private static void registerCounting() {
        scenario("Counting: chapter 7 resolves the whole canvas for a small square", () -> {
            Stats st = new Stats();
            Path square = Paths.polygon(pt(4, 4), pt(20, 4), pt(20, 20), pt(4, 20));
            CoverageBuffer cov = FillCounting.fillPathCounted(square, "nonzero", 64, 64, st);
            assertEquals("st.cells", st.cells, 4096L);
            assertEquals("st.blends", st.blends, 0L);
            assertEquals("st.copies", st.copies, 0L);
            assertTrue("agrees with chapter 7",
                    CoverageBuffer.maxCoverageDifference(cov, Fill.fillPath(square, "nonzero", 64, 64)) == 0);
        });

        scenario("Counting: only the pixels with coverage are blended", () -> {
            Stats st = new Stats();
            Layer l = new Layer(64, 64);
            Path square = Paths.polygon(pt(4, 4), pt(20, 4), pt(20, 20), pt(4, 20));
            CoverageBuffer cov = Fill.fillPath(square, "nonzero", 64, 64);
            FillCounting.drawCoverageCounted(l, cov, Paint.solid(color(1, 0, 0)), 1, st);
            assertEquals("st.blends", st.blends, 256L);
            assertPixelEq("layer_pixel(l, 10, 10)", l.pixelAt(10, 10), new Pixel(1, 0, 0, 1));
            assertPixelEq("layer_pixel(l, 30, 30)", l.pixelAt(30, 30), new Pixel(0, 0, 0, 0));
        });

        scenario("Counting: the tiger, as chapter 20 draws it", () -> {
            Stats st = new Stats();
            Canvas c = SvgWalker.renderSvgWith(readText("reference/chapter-20/tiger.svg"), 450, 450, "whole", st);
            assertEquals("st.cells", st.cells, 61762500L);
            assertEquals("st.copies", st.copies, 0L);
            assertTrue("max_channel_difference <= 1",
                    Ppm.maxChannelDifference(Ppm.canvasToP6(c), readBytes("reference/chapter-20/tiger.ppm")) <= 1);
        });
    }

    // ---- §21.4: tiles --------------------------------------------------------

    private static void registerTiles() {
        scenario("Tiles: a square leaves its middle tiles solid", () -> {
            String[][] t = Tiles.classifyTiles(
                    Paths.polygon(pt(4, 4), pt(60, 4), pt(60, 60), pt(4, 60)), "nonzero", 64, 64);
            assertRowEq("t[0]", t[0], new String[] {"partial", "partial", "partial", "partial"});
            assertRowEq("t[1]", t[1], new String[] {"partial", "solid", "solid", "partial"});
            assertRowEq("t[3]", t[3], new String[] {"partial", "partial", "partial", "partial"});
            assertEquals("tile_count(t, \"solid\")", Tiles.tileCount(t, "solid"), 4L);
        });

        scenario("Tiles: an edge on a tile boundary deposits into the tile on its right", () -> {
            String[][] t = Tiles.classifyTiles(
                    Paths.polygon(pt(16, 16), pt(48, 16), pt(48, 48), pt(16, 48)), "nonzero", 64, 64);
            assertRowEq("t[0]", t[0], new String[] {"empty", "empty", "empty", "empty"});
            assertRowEq("t[1]", t[1], new String[] {"empty", "partial", "solid", "partial"});
            assertRowEq("t[2]", t[2], new String[] {"empty", "partial", "solid", "partial"});
            assertRowEq("t[3]", t[3], new String[] {"empty", "empty", "empty", "empty"});
        });

        scenario("Tiles: a horizontal edge makes a tile partial, and an edge off canvas deposits nothing", () -> {
            String[][] t = Tiles.classifyTiles(
                    Paths.polygon(pt(0, 0), pt(64, 0), pt(64, 40), pt(0, 40)), "nonzero", 64, 64);
            assertRowEq("t[0]", t[0], new String[] {"partial", "solid", "solid", "solid"});
            assertRowEq("t[2]", t[2], new String[] {"partial", "partial", "partial", "partial"});
            assertRowEq("t[3]", t[3], new String[] {"empty", "empty", "empty", "empty"});
        });

        scenario("Tiles: the fill rule decides what a hole is", () -> {
            Path ring = new Path();
            ring.moveTo(pt(2, 2));
            ring.lineTo(pt(62, 2));
            ring.lineTo(pt(62, 62));
            ring.lineTo(pt(2, 62));
            ring.close();
            ring.moveTo(pt(14, 14));
            ring.lineTo(pt(50, 14));
            ring.lineTo(pt(50, 50));
            ring.lineTo(pt(14, 50));
            ring.close();
            assertRowEq("nonzero", Tiles.classifyTiles(ring, "nonzero", 64, 64)[1],
                    new String[] {"partial", "solid", "solid", "partial"});
            assertRowEq("evenodd", Tiles.classifyTiles(ring, "evenodd", 64, 64)[1],
                    new String[] {"partial", "empty", "empty", "partial"});
        });

        scenario("Tiles: only partial tiles are resolved, and the coverage agrees with chapter 7", () -> {
            Stats st = new Stats();
            Path sq = Paths.polygon(pt(4, 4), pt(60, 4), pt(60, 60), pt(4, 60));
            TiledCoverage t = Tiles.fillPathTiled(sq, "nonzero", 64, 64, st);
            assertEquals("st.cells", st.cells, 3072L);
            assertDoubleEq("coverage_in(t, 30, 30)", Coverage.coverageIn(t, 30, 30), 1);
            assertDoubleEq("coverage_in(t, 2, 2)", Coverage.coverageIn(t, 2, 2), 0);
            assertDoubleEq("coverage_in(t, 4, 30)", Coverage.coverageIn(t, 4, 30), 1);
            assertTrue("agrees with chapter 7",
                    CoverageBuffer.maxCoverageDifference(
                            Coverage.fullCoverage(t, 64, 64), Fill.fillPath(sq, "nonzero", 64, 64))
                            <= 0.000001);
        });

        scenario("Tiles: a tiny shape in a corner of a canvas cut short", () -> {
            String[][] t = Tiles.classifyTiles(
                    Paths.polygon(pt(3, 3), pt(5, 3), pt(5, 5), pt(3, 5)), "nonzero", 40, 40);
            assertEquals("length(t)", t.length, 3);
            assertEquals("length(t[0])", t[0].length, 3);
            assertRowEq("t[0]", t[0], new String[] {"partial", "empty", "empty"});
            assertEquals("tile_count(t, \"empty\")", Tiles.tileCount(t, "empty"), 8L);
        });
    }

    // ---- §21.5: spans ----------------------------------------------------------

    private static void registerSpans() {
        scenario("Spans: a solid opaque colour copies its solid tiles and blends its edges", () -> {
            Path sq = Paths.polygon(pt(4, 4), pt(60, 4), pt(60, 60), pt(4, 60));
            TiledCoverage t = Tiles.fillPathTiled(sq, "nonzero", 64, 64, new Stats());
            Stats st = new Stats();
            Layer l = new Layer(64, 64);
            Tiles.drawTiled(l, t, Paint.solid(color(1, 0, 0)), 1, st);
            assertEquals("st.copies", st.copies, 1024L);
            assertEquals("st.blends", st.blends, 2112L);
            assertPixelEq("layer_pixel(l, 30, 30)", l.pixelAt(30, 30), new Pixel(1, 0, 0, 1));
            assertPixelEq("layer_pixel(l, 2, 2)", l.pixelAt(2, 2), new Pixel(0, 0, 0, 0));
        });

        scenario("Spans: the copies draw exactly what blending would have", () -> {
            Path sq = Paths.polygon(pt(4.5, 4.5), pt(59.5, 4.5), pt(59.5, 59.5), pt(4.5, 59.5));
            Layer a = new Layer(64, 64);
            Layer b = new Layer(64, 64);
            Tiles.drawTiled(a, Tiles.fillPathTiled(sq, "nonzero", 64, 64, new Stats()),
                    Paint.solid(color(0.2, 0.6, 0.9)), 1, new Stats());
            Groups.drawCoverage(b, Fill.fillPath(sq, "nonzero", 64, 64), Paint.solid(color(0.2, 0.6, 0.9)), 1);
            assertTrue("layers_equal(a, b)", Simd.layersEqual(a, b));
        });

        scenario("Spans: at half alpha nothing is copied", () -> {
            Path sq = Paths.polygon(pt(4, 4), pt(60, 4), pt(60, 60), pt(4, 60));
            TiledCoverage t = Tiles.fillPathTiled(sq, "nonzero", 64, 64, new Stats());
            Stats st = new Stats();
            Layer l = new Layer(64, 64);
            Tiles.drawTiled(l, t, Paint.solid(color(1, 0, 0)), 0.5, st);
            assertEquals("st.copies", st.copies, 0L);
            assertEquals("st.blends", st.blends, 3136L);
            assertPixelEq("layer_pixel(l, 30, 30)", l.pixelAt(30, 30), new Pixel(0.5, 0, 0, 0.5));
        });
    }

    // ---- §21.6: four pixels at a time -------------------------------------------

    private static void registerSimd() {
        scenario("Simd: a coverage of 0 is an exact no-op, and 1 is an exact copy", () -> {
            Layer l = new Layer(4, 1);
            l.setPixel(0, 0, new Pixel(0.1, 0.2, 0.3, 0.5));
            l.setPixel(1, 0, new Pixel(0.1, 0.2, 0.3, 0.5));
            l.setPixel(2, 0, new Pixel(0.1, 0.2, 0.3, 0.5));
            Simd.compositeSpan(l, 0, 0, new double[] {0, 1, 0.5}, color(0.8, 0.4, 0.2));
            assertPixelEq("layer_pixel(l, 0, 0)", l.pixelAt(0, 0), new Pixel(0.1, 0.2, 0.3, 0.5));
            assertPixelEq("layer_pixel(l, 1, 0)", l.pixelAt(1, 0), new Pixel(0.8, 0.4, 0.2, 1));
            assertPixelEq("layer_pixel(l, 2, 0)", l.pixelAt(2, 0), new Pixel(0.45, 0.3, 0.25, 0.75));
            assertPixelEq("layer_pixel(l, 3, 0)", l.pixelAt(3, 0), new Pixel(0, 0, 0, 0));
        });

        scenario("Simd: four at a time gives the same numbers, the leftover pixels included", () -> {
            Layer a = new Layer(12, 1);
            Layer b = new Layer(12, 1);
            a.setPixel(4, 0, new Pixel(0.1, 0.2, 0.3, 0.5));
            b.setPixel(4, 0, new Pixel(0.1, 0.2, 0.3, 0.5));
            a.setPixel(10, 0, new Pixel(0.05, 0.1, 0.02, 0.2));
            b.setPixel(10, 0, new Pixel(0.05, 0.1, 0.02, 0.2));
            double[] ks = {0, 1, 0.5, 0.25, 0.1, 0.9, 0, 1, 0.3, 0.7, 0.05};
            Simd.compositeSpan(a, 0, 1, ks, color(0.8, 0.4, 0.2));
            Simd.compositeSpan4(b, 0, 1, ks, color(0.8, 0.4, 0.2));
            assertTrue("layers_equal(a, b)", Simd.layersEqual(a, b));
            assertPixelEq("layer_pixel(b, 4, 0)", l4(b), new Pixel(0.275, 0.25, 0.275, 0.625));
            assertPixelEq("layer_pixel(b, 11, 0)", b.pixelAt(11, 0), new Pixel(0.04, 0.02, 0.01, 0.05));
            assertPixelEq("layer_pixel(b, 0, 0)", b.pixelAt(0, 0), new Pixel(0, 0, 0, 0));
        });
    }

    private static Pixel l4(Layer l) {
        return l.pixelAt(4, 0);
    }

    // ---- Plate 21 ----------------------------------------------------------------

    private static void registerPlate() {
        scenario("Plate: the tiger, tiled, drawn byte for byte as chapter 20 drew it", () -> {
            Stats st = new Stats();
            String text = readText("reference/chapter-20/tiger.svg");
            Canvas c = SvgWalker.renderSvgWith(text, 450, 450, "tiled", st);
            assertEquals("st.cells", st.cells, 816480L);
            assertEquals("st.copies", st.copies, 207872L);
            assertTrue("byte for byte with chapter 20",
                    Ppm.maxChannelDifference(Ppm.canvasToP6(c), Ppm.canvasToP6(SvgWalker.renderSvg(text, 450, 450)))
                            == 0);
            assertTrue("max_channel_difference <= 1",
                    Ppm.maxChannelDifference(Ppm.canvasToP6(c), readBytes("reference/chapter-20/tiger.ppm")) <= 1);
        });

        scenario("Plate: the harbor and the rose, every way, byte for byte", () -> {
            String harbor = readText("reference/chapter-20/harbor.svg");
            String rose = readText("reference/chapter-20/rose.svg");
            byte[] h = Ppm.canvasToP6(SvgWalker.renderSvg(harbor, 480, 320));
            byte[] r = Ppm.canvasToP6(SvgWalker.renderSvg(rose, 400, 400));
            assertTrue("harbor bounded",
                    Ppm.maxChannelDifference(
                            Ppm.canvasToP6(SvgWalker.renderSvgWith(harbor, 480, 320, "bounded", new Stats())), h)
                            == 0);
            assertTrue("harbor tiled",
                    Ppm.maxChannelDifference(
                            Ppm.canvasToP6(SvgWalker.renderSvgWith(harbor, 480, 320, "tiled", new Stats())), h)
                            == 0);
            assertTrue("rose bounded",
                    Ppm.maxChannelDifference(
                            Ppm.canvasToP6(SvgWalker.renderSvgWith(rose, 400, 400, "bounded", new Stats())), r)
                            == 0);
            assertTrue("rose tiled",
                    Ppm.maxChannelDifference(
                            Ppm.canvasToP6(SvgWalker.renderSvgWith(rose, 400, 400, "tiled", new Stats())), r)
                            == 0);
        });

        scenario("Plate: where the tiger's work is", () -> {
            int[][][] w = SvgWalker.tileWork(readText("reference/chapter-20/tiger.svg"), 450, 450);
            assertEquals("length(w)", w.length, 29);
            assertEquals("length(w[0])", w[0].length, 29);
            assertPairEq("w[0][0]", w[0][0], 0, 0);
            assertPairEq("w[14][3]", w[14][3], 31, 0);
            assertPairEq("w[12][12]", w[12][12], 23, 1);
            assertPairEq("w[2][21]", w[2][21], 0, 2);
        });

        scenario("Plate 21", () -> {
            Canvas c = Figures.plate21();
            byte[] ref = readBytes("reference/chapter-21/work_map.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 910);
            assertEquals("c.height", c.height, 450);
            assertTriple("ppm_pixel(p6, 250, 200)", Ppm.ppmPixel(p6, 250, 200), new int[] {0, 0, 0}, 1);
            assertTriple("ppm_pixel(p6, 455, 5)", Ppm.ppmPixel(p6, 455, 5), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 516, 232)", Ppm.ppmPixel(p6, 516, 232), new int[] {237, 124, 196}, 1);
            assertTriple("ppm_pixel(p6, 660, 200)", Ppm.ppmPixel(p6, 660, 200), new int[] {213, 112, 176}, 1);
            assertTriple("ppm_pixel(p6, 804, 40)", Ppm.ppmPixel(p6, 804, 40), new int[] {100, 180, 196}, 1);
            assertTriple("ppm_pixel(p6, 460, 0)", Ppm.ppmPixel(p6, 460, 0), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    public static void main(String[] args) throws IOException {
        registerAll();

        int passed = 0;
        int failed = 0;
        long start = System.nanoTime();
        for (int i = 0; i < names.size(); i++) {
            Mixer.linearBlending = true;
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
        java.nio.file.Files.createDirectories(java.nio.file.Path.of("out"));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "work_map.ppm"), Ppm.canvasToP6(Figures.workMap()));
    }
}
