import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter25-*.feature into a Java test. No JUnit, no network: run
 * from the project root so reference/chapter-25 resolves.
 */
public final class Chapter25Tests {

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

    private static void assertTupleEq(String what, Tuple actual, Tuple expected) {
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertTupleListEq(String what, List<Tuple> actual, List<Tuple> expected) {
        assertEquals(what + ".size", actual.size(), expected.size());
        for (int i = 0; i < actual.size(); i++) {
            assertTupleEq(what + "[" + i + "]", actual.get(i), expected.get(i));
        }
    }

    private static void assertColorEq(String what, Color actual, Color expected) {
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertIntArrayEq(String what, int[] actual, int[] expected) {
        if (!Arrays.equals(actual, expected)) {
            throw new AssertionError(what + ": expected " + Arrays.toString(expected)
                    + " but got " + Arrays.toString(actual));
        }
    }

    private static void assertByteTupleEq(String what, int[] actual, int[] expected) {
        if (!Arrays.equals(actual, expected)) {
            throw new AssertionError(what + ": expected " + Arrays.toString(expected)
                    + " but got " + Arrays.toString(actual));
        }
    }

    private static void assertPaletteEq(String what, List<int[]> actual, List<int[]> expected) {
        assertEquals(what + ".size", actual.size(), expected.size());
        for (int i = 0; i < actual.size(); i++) {
            assertByteTupleEq(what + "[" + i + "]", actual.get(i), expected.get(i));
        }
    }

    private static void assertTriple(String what, int[] actual, int[] expected) {
        for (int i = 0; i < 3; i++) {
            if (Math.abs(actual[i] - expected[i]) > 1) {
                throw new AssertionError(what + ": expected " + Arrays.toString(expected)
                        + " but got " + Arrays.toString(actual));
            }
        }
    }

    private static byte[] readBytes(String path) throws IOException {
        return java.nio.file.Files.readAllBytes(java.nio.file.Path.of(path));
    }

    private static Tuple pt(double x, double y) {
        return Tuple.point(x, y);
    }

    private static int[] rgb(int r, int g, int b) {
        return new int[] {r, g, b};
    }

    private static void checkRender(Canvas c, String refPath, int w, int h) throws IOException {
        byte[] ref = readBytes(refPath);
        byte[] p6 = Ppm.canvasToP6(c);
        assertEquals("width", c.width, w);
        assertEquals("height", c.height, h);
        assertTrue("max_channel_difference <= 1 (" + refPath + ")", Ppm.maxChannelDifference(p6, ref) <= 1);
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerBrush();
        registerFlood();
        registerQuantize();
        registerSelect();
        registerPlate();
    }

    // ---- §25.1: brushes ---------------------------------------------------------

    private static void registerBrush() {
        scenario("Brush: a dab's profile", () -> {
            Brush b = new Brush(10, 0.5, 0.25, 0.6, 1);
            assertDoubleEq("dab_coverage(b, 0)", Brushes.dabCoverage(b, 0), 1);
            assertDoubleEq("dab_coverage(b, 5)", Brushes.dabCoverage(b, 5), 1);
            assertDoubleEq("dab_coverage(b, 7.5)", Brushes.dabCoverage(b, 7.5), 0.5);
            assertDoubleEq("dab_coverage(b, 10)", Brushes.dabCoverage(b, 10), 0);
            assertDoubleEq("dab_coverage(b, 12)", Brushes.dabCoverage(b, 12), 0);
        });

        scenario("Brush: dabs are spaced by distance along the path, carried across events", () -> {
            assertTupleListEq("stamp_positions #1",
                    Brushes.stampPositions(List.of(pt(0, 0), pt(3, 0), pt(10, 0)),
                            new Brush(10, 0.5, 0.25, 0.6, 1)),
                    List.of(pt(0, 0), pt(5, 0), pt(10, 0)));
            assertTupleListEq("stamp_positions #2",
                    Brushes.stampPositions(List.of(pt(0, 0), pt(12, 0)), new Brush(2, 1, 0.5, 1, 1)),
                    List.of(pt(0, 0), pt(2, 0), pt(4, 0), pt(6, 0), pt(8, 0), pt(10, 0), pt(12, 0)));
            assertEquals("length(stamp_positions(wobbly_events(), ...))",
                    Brushes.stampPositions(Brushes.wobblyEvents(), new Brush(8, 0.5, 0.25, 0.6, 1)).size(), 99);
        });

        scenario("Brush: flow builds up where dabs overlap", () -> {
            CoverageBuffer one = Brushes.strokeMask(20, 20, List.of(pt(10, 10)), new Brush(4, 0.5, 1, 0.6, 1));
            CoverageBuffer two = Brushes.strokeMask(
                    20, 20, List.of(pt(10, 10), pt(10, 10)), new Brush(4, 0.5, 1, 0.6, 1));
            assertDoubleEq("coverage_at(one, 10, 10)", one.coverageAt(10, 10), 0.6);
            assertDoubleEq("coverage_at(one, 12, 10)", one.coverageAt(12, 10), 0.435147, 0.000001);
            assertDoubleEq("coverage_at(two, 10, 10)", two.coverageAt(10, 10), 0.84);
        });

        scenario("Brush: one dab per event leaves beads; spacing by distance doesn't", () -> {
            List<Tuple> ev = Brushes.wobblyEvents();
            Brush b = new Brush(8, 0.5, 0.25, 0.6, 1);
            CoverageBuffer byDistance = Brushes.strokeMask(400, 120, Brushes.stampPositions(ev, b), b);
            CoverageBuffer byEvent = Brushes.strokeMask(400, 120, ev, b);
            assertDoubleEq("min_along(by_event, ev, 50)", Brushes.minAlong(byEvent, ev, 50), 0);
            assertDoubleEq("min_along(by_distance, ev, 50)", Brushes.minAlong(byDistance, ev, 50), 0.704456,
                    0.000001);
        });
    }

    // ---- §25.2: flood fill --------------------------------------------------------

    private static void registerFlood() {
        scenario("Flood: the ring's pixels", () -> {
            Canvas c = Chapter25Figures.ringCanvas();
            assertIntArrayEq("bytes_at(c, 80, 80)", FloodFill.bytesAt(c, 80, 80), rgb(246, 243, 234));
            assertIntArrayEq("bytes_at(c, 80, 20)", FloodFill.bytesAt(c, 80, 20), rgb(63, 63, 80));
            assertIntArrayEq("bytes_at(c, 142, 80)", FloodFill.bytesAt(c, 142, 80), rgb(246, 243, 234));
        });

        scenario("Flood: tolerance decides how much of the antialiased edge the bucket takes", () -> {
            Canvas c = Chapter25Figures.ringCanvas();
            assertDoubleEq("ink(flood_mask(c,80,80,0,4))",
                    FloodFill.floodMask(c, 80, 80, 0, 4, new FillStats()).ink(), 10324);
            assertDoubleEq("ink(flood_mask(c,80,80,32,4))",
                    FloodFill.floodMask(c, 80, 80, 32, 4, new FillStats()).ink(), 10484);
            assertDoubleEq("ink(flood_mask(c,80,80,160,4))",
                    FloodFill.floodMask(c, 80, 80, 160, 4, new FillStats()).ink(), 10700);
            assertDoubleEq("ink(flood_mask(c,80,80,254,4))",
                    FloodFill.floodMask(c, 80, 80, 254, 4, new FillStats()).ink(), 25600);
            assertDoubleEq("ink(anti_alias_mask(flood_mask(c,80,80,32,4)))",
                    FloodFill.antiAliasMask(FloodFill.floodMask(c, 80, 80, 32, 4, new FillStats())).ink(), 10648);
            assertDoubleEq("ink(select_color(c,80,80,0))", FloodFill.selectColor(c, 80, 80, 0).ink(), 23636);
        });

        scenario("Flood: eight-way connectivity leaks through a diagonal", () -> {
            Canvas c = new Canvas(3, 3);
            c.fill(new Color(1, 1, 1));
            c.writePixel(1, 0, new Color(0, 0, 0));
            c.writePixel(0, 1, new Color(0, 0, 0));
            assertDoubleEq("ink(flood_mask(c,0,0,0,4))", FloodFill.floodMask(c, 0, 0, 0, 4, new FillStats()).ink(), 1);
            assertDoubleEq("ink(flood_mask(c,0,0,0,8))", FloodFill.floodMask(c, 0, 0, 0, 8, new FillStats()).ink(), 7);
        });

        scenario("Flood: recursion goes as deep as the region is big; the scanline stack doesn't", () -> {
            FillStats fs = new FillStats();
            CoverageBuffer m = FloodFill.floodMask(new Canvas(200, 200), 0, 0, 0, 4, fs);
            assertDoubleEq("ink(m)", m.ink(), 40000);
            assertEquals("fs.pushes", fs.pushes, 200);
            assertEquals("fs.deepest", fs.deepest, 1);
            assertEquals("naive_depth(4, 3)", FloodFill.naiveDepth(4, 3), 12);
            assertEquals("naive_depth(200, 200)", FloodFill.naiveDepth(200, 200), 40000);
        });
    }

    // ---- §25.3: quantization --------------------------------------------------------

    private static void registerQuantize() {
        scenario("Quantize: median cut", () -> {
            List<int[]> cols = List.of(
                    rgb(10, 10, 10), rgb(10, 10, 10), rgb(10, 10, 10), rgb(200, 0, 0), rgb(250, 0, 0),
                    rgb(0, 0, 90), rgb(0, 0, 100), rgb(0, 0, 110));
            assertPaletteEq("median_cut(cols, 1)", Quantize.medianCut(cols, 1), List.of(rgb(60, 4, 41)));
            assertPaletteEq("median_cut(cols, 2)", Quantize.medianCut(cols, 2),
                    List.of(rgb(5, 5, 55), rgb(225, 0, 0)));
            assertPaletteEq("median_cut(cols, 4)", Quantize.medianCut(cols, 4),
                    List.of(rgb(10, 10, 10), rgb(0, 0, 100), rgb(200, 0, 0), rgb(250, 0, 0)));
            assertPaletteEq("median_cut(cols, 20)", Quantize.medianCut(cols, 20),
                    List.of(rgb(10, 10, 10), rgb(0, 0, 90), rgb(0, 0, 100), rgb(0, 0, 110), rgb(200, 0, 0),
                            rgb(250, 0, 0)));
            assertPaletteEq("median_cut(canvas_bytes(ring_canvas()), 4)",
                    Quantize.medianCut(Quantize.canvasBytes(Chapter25Figures.ringCanvas()), 4),
                    List.of(rgb(63, 63, 80), rgb(128, 127, 130), rgb(226, 223, 215), rgb(246, 243, 234)));
        });

        scenario("Quantize: the nearest entry", () -> {
            List<int[]> pal = List.of(rgb(0, 0, 0), rgb(255, 255, 255), rgb(255, 0, 0));
            assertEquals("nearest_index(pal, (120,120,120))", Quantize.nearestIndex(pal, rgb(120, 120, 120)), 0);
            assertEquals("nearest_index(pal, (128,128,128))", Quantize.nearestIndex(pal, rgb(128, 128, 128)), 1);
            assertEquals("nearest_index(pal, (200,40,30))", Quantize.nearestIndex(pal, rgb(200, 40, 30)), 2);
            assertEquals("nearest_index([(0,0,0),(0,0,0)], (1,1,1))",
                    Quantize.nearestIndex(List.of(rgb(0, 0, 0), rgb(0, 0, 0)), rgb(1, 1, 1)), 0);
        });

        scenario("Quantize: two inks three ways, error diffusion keeps the light", () -> {
            Canvas r = Quantize.rampCanvas(256, 32);
            List<int[]> bw = List.of(rgb(0, 0, 0), rgb(255, 255, 255));
            assertIntArrayEq("error_diffuse(ramp_canvas(4,1), bw)",
                    Quantize.errorDiffuse(Quantize.rampCanvas(4, 1), bw), new int[] {0, 0, 1, 1});
            assertDoubleEq("mean_light(r)", Quantize.meanLight(r), 0.5);
            assertDoubleEq("mean_light(indexed_canvas(threshold(r, bw), bw, 256, 32))",
                    Quantize.meanLight(Quantize.indexedCanvas(Quantize.threshold(r, bw), bw, 256, 32)), 0.5);
            assertDoubleEq("mean_light(indexed_canvas(ordered_dither(r, bw), bw, 256, 32))",
                    Quantize.meanLight(Quantize.indexedCanvas(Quantize.orderedDither(r, bw), bw, 256, 32)),
                    0.530273, 0.000001);
            assertDoubleEq("mean_light(indexed_canvas(error_diffuse(r, bw), bw, 256, 32))",
                    Quantize.meanLight(Quantize.indexedCanvas(Quantize.errorDiffuse(r, bw), bw, 256, 32)),
                    0.500732, 0.000001);
        });

        scenario("Quantize: an 8-bit BMP, byte by byte", () -> {
            int[] idx = {0, 1, 2, 1, 0, 2, 1, 1, 1, 0};
            List<int[]> pal = List.of(rgb(10, 20, 30), rgb(200, 100, 50), rgb(0, 0, 255));
            byte[] bm = Quantize.canvasToBmp8(idx, pal, 5, 2);
            assertEquals("length(bm)", bm.length, 1094);
            assertIntArrayEq("bytes_of(bm, 0, 14)", slice(bm, 0, 14),
                    new int[] {66, 77, 70, 4, 0, 0, 0, 0, 0, 0, 54, 4, 0, 0});
            assertIntArrayEq("bytes_of(bm, 14, 54)", slice(bm, 14, 54),
                    new int[] {40, 0, 0, 0, 5, 0, 0, 0, 2, 0, 0, 0, 1, 0, 8, 0, 0, 0, 0, 0, 16, 0, 0, 0, 19, 11,
                        0, 0, 19, 11, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0});
            assertIntArrayEq("bytes_of(bm, 54, 66)", slice(bm, 54, 66),
                    new int[] {30, 20, 10, 0, 50, 100, 200, 0, 255, 0, 0, 0});
            assertIntArrayEq("bytes_of(bm, 1078, 1094)", slice(bm, 1078, 1094),
                    new int[] {2, 1, 1, 1, 0, 0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0});
            Quantize.BmpImage read = Quantize.readBmp8(bm);
            assertEquals("read_bmp8(bm).width", read.width(), 5);
            assertEquals("read_bmp8(bm).height", read.height(), 2);
            assertPaletteEq("read_bmp8(bm).palette", read.palette(), pal);
            assertIntArrayEq("read_bmp8(bm).indices", read.indices(), idx);
        });
    }

    private static int[] slice(byte[] b, int from, int to) {
        int[] out = new int[to - from];
        for (int i = from; i < to; i++) {
            out[i - from] = b[i] & 0xFF;
        }
        return out;
    }

    // ---- §25.4: selection and undo -----------------------------------------------

    private static void registerSelect() {
        scenario("Select: selections combine like coverage", () -> {
            CoverageBuffer a = Selection.marquee(2, 2, 6, 6, 8, 8);
            CoverageBuffer b = Selection.marquee(4, 4, 8, 8, 8, 8);
            assertDoubleEq("ink(add_selection(a, b))", Selection.addSelection(a, b).ink(), 28);
            assertDoubleEq("ink(subtract_selection(a, b))", Selection.subtractSelection(a, b).ink(), 12);
            assertDoubleEq("ink(intersect_selection(a, b))", Selection.intersectSelection(a, b).ink(), 4);
        });

        scenario("Select: feathering keeps the selection's size and softens its edge", () -> {
            CoverageBuffer f = Selection.feather(Selection.marquee(2, 2, 6, 6, 8, 8), 1);
            assertDoubleEq("coverage_at(f, 3, 3)", f.coverageAt(3, 3), 1);
            assertDoubleEq("coverage_at(f, 2, 2)", f.coverageAt(2, 2), 0.444444, 0.000001);
            assertDoubleEq("coverage_at(f, 1, 1)", f.coverageAt(1, 1), 0.111111, 0.000001);
            assertDoubleEq("ink(f)", f.ink(), 16);
        });

        scenario("Select: off the buffer counts as unselected", () -> {
            CoverageBuffer f = Selection.feather(Selection.marquee(0, 0, 4, 4, 8, 8), 1);
            assertDoubleEq("coverage_at(f, 0, 0)", f.coverageAt(0, 0), 0.444444, 0.000001);
            assertDoubleEq("coverage_at(f, 1, 1)", f.coverageAt(1, 1), 1);
        });

        scenario("Select: a floating selection moves and drops", () -> {
            Canvas c = new Canvas(8, 8);
            c.fill(new Color(0, 0, 1));
            c.writePixel(2, 2, new Color(1, 0, 0));
            c.writePixel(3, 2, new Color(1, 0, 0));
            c.writePixel(2, 3, new Color(1, 0, 0));
            c.writePixel(3, 3, new Color(1, 0, 0));
            Floating f = Selection.floatSelection(c, Selection.marquee(2, 2, 4, 4, 8, 8), new Color(0, 0, 1));
            Selection.moveFloating(f, 3, 1);
            Selection.dropFloating(c, f);
            assertColorEq("pixel_at(c, 2, 2)", c.pixelAt(2, 2), new Color(0, 0, 1));
            assertColorEq("pixel_at(c, 5, 3)", c.pixelAt(5, 3), new Color(1, 0, 0));
            assertColorEq("pixel_at(c, 6, 4)", c.pixelAt(6, 4), new Color(1, 0, 0));
            assertColorEq("pixel_at(c, 4, 2)", c.pixelAt(4, 2), new Color(0, 0, 1));
        });

        scenario("Select: undo, redo, and a new edit ends redo", () -> {
            Canvas c = new Canvas(8, 8);
            History h = new History(c);
            h.historyFill(0, 0, 4, 4, new Color(1, 1, 1));
            h.historyFill(2, 2, 6, 6, new Color(1, 0, 0));
            assertColorEq("pixel_at(c, 3, 3)", c.pixelAt(3, 3), new Color(1, 0, 0));
            assertEquals("stored_pixels(h)", h.storedPixels(), 32);
            assertEquals("undo(h)", h.undo(), true);
            assertColorEq("pixel_at(c, 3, 3)", c.pixelAt(3, 3), new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 5, 5)", c.pixelAt(5, 5), new Color(0, 0, 0));
            assertEquals("redo(h)", h.redo(), true);
            assertColorEq("pixel_at(c, 3, 3)", c.pixelAt(3, 3), new Color(1, 0, 0));
            assertEquals("undo(h)", h.undo(), true);
            assertEquals("undo(h)", h.undo(), true);
            assertEquals("undo(h)", h.undo(), false);
            assertColorEq("pixel_at(c, 1, 1)", c.pixelAt(1, 1), new Color(0, 0, 0));
            assertEquals("redo(h)", h.redo(), true);
            assertColorEq("pixel_at(c, 1, 1)", c.pixelAt(1, 1), new Color(1, 1, 1));
        });

        scenario("Select: an edit after an undo throws redo away", () -> {
            Canvas c = new Canvas(8, 8);
            History h = new History(c);
            h.historyFill(0, 0, 4, 4, new Color(1, 1, 1));
            h.historyFill(2, 2, 6, 6, new Color(1, 0, 0));
            h.undo();
            h.historyFill(0, 0, 1, 1, new Color(0, 1, 0));
            assertEquals("redo(h)", h.redo(), false);
            assertEquals("stored_pixels(h)", h.storedPixels(), 17);
            assertColorEq("pixel_at(c, 0, 0)", c.pixelAt(0, 0), new Color(0, 1, 0));
        });
    }

    // ---- §25.5: Plate 25, and the chapter's renders --------------------------------

    private static void registerPlate() {
        scenario("Plate: dither_strip", () ->
                checkRender(Chapter25Figures.ditherStrip(), "reference/chapter-25/dither-strip.ppm", 256, 96));
        scenario("Plate: halo_demo", () ->
                checkRender(Chapter25Figures.haloDemo(), "reference/chapter-25/halo-demo.ppm", 640, 160));
        scenario("Plate: brush_demo", () ->
                checkRender(Chapter25Figures.brushDemo(), "reference/chapter-25/brush-demo.ppm", 400, 240));
        scenario("Plate: paint_by_script", () ->
                checkRender(Chapter25Figures.paintByScript(), "reference/chapter-25/paint-by-script.ppm", 480, 320));

        scenario("Plate: the halo, and the two controls that fight over it", () -> {
            byte[] p6 = Ppm.canvasToP6(Chapter25Figures.haloDemo());
            assertTriple("(72,22)", Ppm.ppmPixel(p6, 72, 22), new int[] {177, 175, 172});
            assertTriple("(232,22)", Ppm.ppmPixel(p6, 232, 22), new int[] {177, 175, 172});
            assertTriple("(392,22)", Ppm.ppmPixel(p6, 392, 22), new int[] {153, 202, 212});
            assertTriple("(552,22)", Ppm.ppmPixel(p6, 552, 22), new int[] {124, 225, 243});
            assertTriple("(80,80)", Ppm.ppmPixel(p6, 80, 80), new int[] {124, 225, 243});
        });

        scenario("Plate: the painting", () -> {
            byte[] p6 = Ppm.canvasToP6(Chapter25Figures.paintByScript());
            assertTriple("(10,300)", Ppm.ppmPixel(p6, 10, 300), new int[] {39, 89, 124});
            assertTriple("(370,110)", Ppm.ppmPixel(p6, 370, 110), new int[] {247, 217, 145});
        });

        scenario("Plate: Plate 25", () -> {
            Canvas c = Chapter25Figures.plate25();
            byte[] ref = readBytes("reference/chapter-25/plate-25.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 480);
            assertEquals("c.height", c.height, 240);
            assertTriple("(150,120)", Ppm.ppmPixel(p6, 150, 120), new int[] {124, 225, 243});
            assertTriple("(236,120)", Ppm.ppmPixel(p6, 236, 120), new int[] {246, 243, 234});
            assertTrue("max_channel_difference <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
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
            long t0 = System.nanoTime();
            try {
                bodies.get(i).run();
                passed++;
                System.out.println("PASS  " + name + "  (" + (System.nanoTime() - t0) / 1_000_000 + " ms)");
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
        java.nio.file.Files.write(java.nio.file.Path.of("out", "plate-25.ppm"),
                Ppm.canvasToP6(Chapter25Figures.plate25()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "dither-strip.ppm"),
                Ppm.canvasToP6(Chapter25Figures.ditherStrip()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "halo-demo.ppm"),
                Ppm.canvasToP6(Chapter25Figures.haloDemo()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "brush-demo.ppm"),
                Ppm.canvasToP6(Chapter25Figures.brushDemo()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "paint-by-script.ppm"),
                Ppm.canvasToP6(Chapter25Figures.paintByScript()));
    }
}
