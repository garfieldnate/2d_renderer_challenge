import java.io.IOException;
import java.nio.file.Files;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter17-*.feature into a Java test. No JUnit, no network: run
 * from the project root so reference/chapter-16 and reference/chapter-17
 * resolve.
 */
public final class Chapter17Tests {

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

    private static void assertColorEq(String what, Color actual, Color expected) {
        assertColorEq(what, actual, expected, Numbers.DEFAULT_EPSILON);
    }

    private static void assertColorEq(String what, Color actual, Color expected, double eps) {
        if (!actual.approxEquals(expected, eps)) {
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
            font = Fonts.loadFont(Files.readString(java.nio.file.Path.of("reference/chapter-16/roboto.json")));
        }
        return font;
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerBitmap();
        registerCache();
        registerFudge();
        registerLcd();
        registerPlate();
    }

    // features/chapter17-bitmap.feature
    private static void registerBitmap() {
        scenario("Bitmap: a pen position rounds to the nearest quarter pixel", () -> {
            assertEquals("subpixel_of(10)", Bitmaps.subpixelOf(10), new Subpixel(10, 0));
            assertEquals("subpixel_of(10.1)", Bitmaps.subpixelOf(10.1), new Subpixel(10, 0));
            assertEquals("subpixel_of(10.3)", Bitmaps.subpixelOf(10.3), new Subpixel(10, 1));
            assertEquals("subpixel_of(10.5)", Bitmaps.subpixelOf(10.5), new Subpixel(10, 2));
            assertEquals("subpixel_of(10.62)", Bitmaps.subpixelOf(10.62), new Subpixel(10, 2));
            assertEquals("subpixel_of(10.9)", Bitmaps.subpixelOf(10.9), new Subpixel(11, 0));
            assertEquals("subpixel_of(-0.3)", Bitmaps.subpixelOf(-0.3), new Subpixel(-1, 3));
        });

        scenario("Bitmap: a bitmap is just big enough and knows where it sits", () -> {
            Font f = font();
            Bitmap b = Bitmaps.glyphBitmap(f, "l", 11, 0);
            assertEquals("b.width", b.width, 2);
            assertEquals("b.height", b.height, 9);
            assertEquals("b.left", b.left, 0);
            assertEquals("b.top", b.top, -9);
            assertDoubleEq("coverage_at(b.coverage, 0, 5)", b.coverage.coverageAt(0, 5), 0.1621, 0.0001);
            assertDoubleEq("coverage_at(b.coverage, 1, 5)", b.coverage.coverageAt(1, 5), 0.8315, 0.0001);
            assertEquals("glyph_bitmap(font, \"g\", 11, 0).top", Bitmaps.glyphBitmap(f, "g", 11, 0).top, -6);
            assertEquals("glyph_bitmap(font, \"g\", 11, 0).height", Bitmaps.glyphBitmap(f, "g", 11, 0).height, 9);
            assertEquals("glyph_bitmap(font, \"space\", 11, 0).width", Bitmaps.glyphBitmap(f, "space", 11, 0).width, 0);
        });

        scenario("Bitmap: a quarter to the right moves the ink, not the amount of it", () -> {
            Font f = font();
            Bitmap b1 = Bitmaps.glyphBitmap(f, "l", 11, 1);
            Bitmap b3 = Bitmaps.glyphBitmap(f, "l", 11, 3);
            assertEquals("b1.left", b1.left, 1);
            assertDoubleEq("coverage_at(b1.coverage, 0, 5)", b1.coverage.coverageAt(0, 5), 0.9121, 0.0001);
            assertDoubleEq("coverage_at(b1.coverage, 1, 5)", b1.coverage.coverageAt(1, 5), 0.0815, 0.0001);
            assertDoubleEq("coverage_at(b3.coverage, 0, 5)", b3.coverage.coverageAt(0, 5), 0.4121, 0.0001);
            assertDoubleEq("coverage_at(b3.coverage, 1, 5)", b3.coverage.coverageAt(1, 5), 0.5815, 0.0001);
            assertDoubleEq("ink(b1.coverage) = ink(glyph_bitmap(font, \"l\", 11, 0).coverage)",
                    b1.coverage.ink(), Bitmaps.glyphBitmap(f, "l", 11, 0).coverage.ink());
            assertDoubleEq("ink(b3.coverage)", b3.coverage.ink(), 8.197632, 0.0001);
            assertDoubleEq("ink(glyph_bitmap(font, \"H\", 11, 1).coverage) = ink(glyph_bitmap(font, \"H\", 11, 0).coverage)",
                    Bitmaps.glyphBitmap(f, "H", 11, 1).coverage.ink(), Bitmaps.glyphBitmap(f, "H", 11, 0).coverage.ink());
        });

        scenario("Bitmap: painting a bitmap lands it at the pen", () -> {
            Font f = font();
            Canvas c = new Canvas(10, 14);
            c.fill(new Color(1, 1, 1));
            Bitmaps.paintBitmap(c, Bitmaps.glyphBitmap(f, "l", 11, 0), 4, 11, new Color(0, 0, 0), true);
            assertColorEq("pixel_at(c, 5, 6)", c.pixelAt(5, 6), new Color(0.1685, 0.1685, 0.1685));
            assertColorEq("pixel_at(c, 4, 6)", c.pixelAt(4, 6), new Color(0.8379, 0.8379, 0.8379));
            assertColorEq("pixel_at(c, 6, 6)", c.pixelAt(6, 6), new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 5, 11)", c.pixelAt(5, 11), new Color(1, 1, 1));
        });
    }

    // features/chapter17-cache.feature
    private static void registerCache() {
        scenario("Cache: a cache hit is the identical bitmap", () -> {
            Font f = font();
            GlyphCache cache = new GlyphCache();
            Bitmap a = cache.cachedBitmap(f, "H", 11, 0);
            Bitmap b = cache.cachedBitmap(f, "H", 11, 0);
            assertEquals("cache_size(cache)", cache.size(), 1);
            assertDoubleEq("max_coverage_difference(a.coverage, b.coverage)",
                    CoverageBuffer.maxCoverageDifference(a.coverage, b.coverage), 0);
            assertEquals("a.left = b.left", a.left, b.left);
            assertDoubleEq("ink(a.coverage)", a.coverage.ink(), 19.495859, 0.0001);
        });

        scenario("Cache: a different quarter or size is a different entry", () -> {
            Font f = font();
            GlyphCache cache = new GlyphCache();
            Bitmap a = cache.cachedBitmap(f, "H", 11, 0);
            Bitmap b = cache.cachedBitmap(f, "H", 11, 1);
            cache.cachedBitmap(f, "H", 12, 0);
            assertEquals("cache_size(cache)", cache.size(), 3);
            assertEquals("b.left", b.left, 1);
            assertDoubleEq("ink(b.coverage) = ink(a.coverage)", b.coverage.ink(), a.coverage.ink());
        });

        scenario("Cache: shelf packing places bitmaps left to right, then opens a new shelf", () -> {
            Atlas a = new Atlas(32, 32);
            assertEquals("atlas_add(a, bitmap(coverage_buffer(10, 8), 0, 0))",
                    a.add(new Bitmap(new CoverageBuffer(10, 8), 0, 0)), new AtlasSpot(0, 0));
            assertEquals("atlas_add(a, bitmap(coverage_buffer(20, 8), 0, 0))",
                    a.add(new Bitmap(new CoverageBuffer(20, 8), 0, 0)), new AtlasSpot(10, 0));
            assertEquals("atlas_add(a, bitmap(coverage_buffer(8, 8), 0, 0))",
                    a.add(new Bitmap(new CoverageBuffer(8, 8), 0, 0)), new AtlasSpot(0, 8));
            assertEquals("atlas_add(a, bitmap(coverage_buffer(40, 5), 0, 0))",
                    a.add(new Bitmap(new CoverageBuffer(40, 5), 0, 0)), null);
            assertEquals("atlas_add(a, bitmap(coverage_buffer(30, 20), 0, 0))",
                    a.add(new Bitmap(new CoverageBuffer(30, 20), 0, 0)), null);
            assertEquals("atlas_add(a, bitmap(coverage_buffer(2, 2), 0, 0))",
                    a.add(new Bitmap(new CoverageBuffer(2, 2), 0, 0)), new AtlasSpot(0, 16));
            assertEquals("atlas_add(a, bitmap(coverage_buffer(31, 2), 0, 0))",
                    a.add(new Bitmap(new CoverageBuffer(31, 2), 0, 0)), new AtlasSpot(0, 18));
        });

        scenario("Cache: the atlas holds the bitmap's coverage where it said", () -> {
            Font f = font();
            Atlas a = new Atlas(32, 32);
            Bitmap h = Bitmaps.glyphBitmap(f, "H", 11, 0);
            AtlasSpot at = a.add(h);
            Bitmap ag = Bitmaps.glyphBitmap(f, "a", 11, 0);
            AtlasSpot at2 = a.add(ag);
            assertEquals("at", at, new AtlasSpot(0, 0));
            assertEquals("at2", at2, new AtlasSpot(7, 0));
            assertDoubleEq("coverage_at(a.coverage, 1, 3) = coverage_at(h.coverage, 1, 3)",
                    a.coverage.coverageAt(1, 3), h.coverage.coverageAt(1, 3));
            assertDoubleEq("coverage_at(a.coverage, 8, 3) = coverage_at(glyph_bitmap(font, \"a\", 11, 0).coverage, 1, 3)",
                    a.coverage.coverageAt(8, 3), ag.coverage.coverageAt(1, 3));
        });
    }

    // features/chapter17-fudge.feature
    private static void registerFudge() {
        scenario("Fudge: encoded-space blending is darker at the same coverage", () -> {
            Font f = font();
            Canvas a = new Canvas(10, 14);
            Canvas b = new Canvas(10, 14);
            a.fill(new Color(1, 1, 1));
            b.fill(new Color(1, 1, 1));
            Bitmaps.paintBitmap(a, Bitmaps.glyphBitmap(f, "l", 11, 0), 4, 11, new Color(0, 0, 0), true);
            Bitmaps.paintBitmap(b, Bitmaps.glyphBitmap(f, "l", 11, 0), 4, 11, new Color(0, 0, 0), false);
            assertColorEq("pixel_at(a, 4, 6)", a.pixelAt(4, 6), new Color(0.8379, 0.8379, 0.8379));
            assertColorEq("pixel_at(b, 4, 6)", b.pixelAt(4, 6), new Color(0.6701, 0.6701, 0.6701));
            assertColorEq("pixel_at(a, 5, 6)", a.pixelAt(5, 6), new Color(0.1685, 0.1685, 0.1685));
            assertColorEq("pixel_at(b, 5, 6)", b.pixelAt(5, 6), new Color(0.0241, 0.0241, 0.0241));
        });

        scenario("Fudge: emboldening adds ink and grows the bitmap by a pixel all round", () -> {
            Font f = font();
            Bitmap plain = Bitmaps.glyphBitmap(f, "l", 11, 0);
            Bitmap bold = Bitmaps.embolden(f, "l", 11, 0.333333);
            assertEquals("bold.width", bold.width, 4);
            assertEquals("bold.height", bold.height, 11);
            assertEquals("bold.left", bold.left, -1);
            assertEquals("bold.top", bold.top, -10);
            assertDoubleEq("ink(plain.coverage)", plain.coverage.ink(), 8.197632, 0.0001);
            assertDoubleEq("ink(bold.coverage)", bold.coverage.ink(), 12.9527, 0.001);
            assertDoubleEq("coverage_at(bold.coverage, 2, 6)", bold.coverage.coverageAt(2, 6), 1);
            assertDoubleEq("coverage_at(bold.coverage, 1, 6)", bold.coverage.coverageAt(1, 6), 0.4909, 0.001);
            assertDoubleEq("coverage_at(bold.coverage, 0, 6)", bold.coverage.coverageAt(0, 6), 0);
        });

        scenario("Fudge: more emboldening, more ink", () -> {
            Font f = font();
            assertDoubleEq("ink(embolden(font, \"o\", 11, 0.5).coverage)",
                    Bitmaps.embolden(f, "o", 11, 0.5).coverage.ink(), 25.300, 0.01);
            assertDoubleEq("ink(glyph_bitmap(font, \"o\", 11, 0).coverage)",
                    Bitmaps.glyphBitmap(f, "o", 11, 0).coverage.ink(), 14.041, 0.01);
            assertTrue("ink(embolden(font, \"o\", 11, 0.5).coverage) >= ink(embolden(font, \"o\", 11, 0.25).coverage)",
                    Bitmaps.embolden(f, "o", 11, 0.5).coverage.ink()
                            >= Bitmaps.embolden(f, "o", 11, 0.25).coverage.ink());
        });
    }

    // features/chapter17-lcd.feature
    private static void registerLcd() {
        scenario("LCD: the filter's taps sum to one and spread a spike over three stripes", () -> {
            assertTrue("LCD_TAPS = (0.333333, 0.333333, 0.333333)",
                    Numbers.approxEqual(Lcd.LCD_TAPS[0], 0.333333, 0.0001)
                            && Numbers.approxEqual(Lcd.LCD_TAPS[1], 0.333333, 0.0001)
                            && Numbers.approxEqual(Lcd.LCD_TAPS[2], 0.333333, 0.0001));
            assertTrue("lcd_filter([0, 0, 3, 0, 0]) = [0, 1, 1, 1, 0]",
                    Arrays.equals(Lcd.lcdFilter(new double[] {0, 0, 3, 0, 0}), new double[] {0, 1, 1, 1, 0}));
            double[] r = Lcd.lcdFilter(new double[] {1, 1, 1});
            assertDoubleEq("lcd_filter([1, 1, 1])[0]", r[0], 0.666667, 0.0001);
            assertDoubleEq("lcd_filter([1, 1, 1])[1]", r[1], 1, 0.0001);
            assertDoubleEq("lcd_filter([1, 1, 1])[2]", r[2], 0.666667, 0.0001);
            assertTrue("lcd_filter([6]) = [2]", Arrays.equals(Lcd.lcdFilter(new double[] {6}), new double[] {2}));
            assertEquals("length(lcd_filter([]))", Lcd.lcdFilter(new double[] {}).length, 0);
        });

        scenario("LCD: three coverages per pixel carry three times the ink", () -> {
            Font f = font();
            CoverageBuffer cov3 = Lcd.lcdCoverage(f, "l", 11, 4, 11, 10, 14);
            CoverageBuffer gray = Fill.fillPath(
                    Glyphs.glyphPath(f, "l", Glyphs.textMatrix(f, 11, 4, 11), 0.1), "nonzero", 10, 14);
            assertEquals("cov3.width", cov3.width, 30);
            assertEquals("cov3.height", cov3.height, 14);
            assertDoubleEq("ink(cov3)", cov3.ink(), 24.592896, 0.0001);
            assertDoubleEq("ink(gray)", gray.ink(), 8.197632, 0.0001);
            assertDoubleEq("coverage_at(gray, 4, 5)", gray.coverageAt(4, 5), 0.1621, 0.0001);
            assertDoubleEq("coverage_at(gray, 5, 5)", gray.coverageAt(5, 5), 0.8315, 0.0001);
            assertDoubleEq("coverage_at(cov3, 13, 5)", cov3.coverageAt(13, 5), 0.1621, 0.0001);
            assertDoubleEq("coverage_at(cov3, 14, 5)", cov3.coverageAt(14, 5), 0.4954, 0.0001);
            assertDoubleEq("coverage_at(cov3, 15, 5)", cov3.coverageAt(15, 5), 0.8288, 0.0001);
            assertDoubleEq("coverage_at(cov3, 16, 5)", cov3.coverageAt(16, 5), 0.8315, 0.0001);
            assertDoubleEq("coverage_at(cov3, 17, 5)", cov3.coverageAt(17, 5), 0.4982, 0.0001);
            assertDoubleEq("coverage_at(cov3, 18, 5)", cov3.coverageAt(18, 5), 0.1649, 0.0001);
            assertDoubleEq("coverage_at(cov3, 12, 5)", cov3.coverageAt(12, 5), 0);
        });

        scenario("LCD: each channel takes its own stripe", () -> {
            Font f = font();
            Canvas c = new Canvas(10, 14);
            c.fill(new Color(1, 1, 1));
            Lcd.paintLcd(c, Lcd.lcdCoverage(f, "l", 11, 4, 11, 10, 14), new Color(0, 0, 0));
            assertColorEq("pixel_at(c, 4, 5)", c.pixelAt(4, 5), new Color(1, 0.8379, 0.5046), 0.0001);
            assertColorEq("pixel_at(c, 5, 5)", c.pixelAt(5, 5), new Color(0.1712, 0.1685, 0.5018), 0.0001);
            assertColorEq("pixel_at(c, 6, 5)", c.pixelAt(6, 5), new Color(0.8351, 1, 1), 0.0001);
            assertColorEq("pixel_at(c, 8, 5)", c.pixelAt(8, 5), new Color(1, 1, 1));
        });
    }

    // features/chapter17-plate.feature
    private static void registerPlate() {
        scenario("Plate 17: the pen advance in pixels", () -> {
            Font f = font();
            assertDoubleEq("pen_advance(font, \"H\", 11)", Glyphs.penAdvance(f, "H", 11), 7.8418, 0.0001);
            assertDoubleEq("pen_advance(font, \"space\", 11)", Glyphs.penAdvance(f, "space", 11), 2.7231, 0.0001);
        });

        scenario("Plate 17: draw_text steps the pen by each advance and answers where it stopped", () -> {
            Font f = font();
            Canvas c = new Canvas(30, 14);
            c.fill(new Color(1, 1, 1));
            double pen = Figures.drawText(c, f, "Ha", 11, 2, 11, new Color(0, 0, 0), true);
            assertDoubleEq("pen", pen, 15.8252, 0.0001);
            assertDoubleEq("pen = 2 + pen_advance(font, \"H\", 11) + pen_advance(font, \"a\", 11)", pen,
                    2 + Glyphs.penAdvance(f, "H", 11) + Glyphs.penAdvance(f, "a", 11), 0.0001);
            assertColorEq("pixel_at(c, 3, 6)", c.pixelAt(3, 6), new Color(0.0331, 0.0331, 0.0331));
            assertColorEq("pixel_at(c, 29, 6)", c.pixelAt(29, 6), new Color(1, 1, 1));
        });

        scenario("Plate 17: the same stem at four quarters", () -> {
            Canvas c = Figures.subpixelStrip();
            byte[] ref = readReference("subpixels.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 112);
            assertTriple("ppm_pixel(p6, 40, 60)", Ppm.ppmPixel(p6, 40, 60), new int[] {114, 114, 114}, 1);
            assertTriple("ppm_pixel(p6, 120, 60)", Ppm.ppmPixel(p6, 120, 60), new int[] {84, 84, 84}, 1);
            assertTriple("ppm_pixel(p6, 280, 60)", Ppm.ppmPixel(p6, 280, 60), new int[] {202, 202, 202}, 1);
            assertTriple("ppm_pixel(p6, 10, 10)", Ppm.ppmPixel(p6, 10, 10), new int[] {255, 255, 255}, 0);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 17: three ways to smooth", () -> {
            Canvas c = Figures.smoothingDemo();
            byte[] ref = readReference("smoothing.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 288);
            assertEquals("c.height", c.height, 168);
            assertTriple("ppm_pixel(p6, 150, 20)", Ppm.ppmPixel(p6, 150, 20), new int[] {250, 250, 250}, 1);
            assertTriple("ppm_pixel(p6, 150, 76)", Ppm.ppmPixel(p6, 150, 76), new int[] {243, 243, 243}, 1);
            assertTriple("ppm_pixel(p6, 150, 132)", Ppm.ppmPixel(p6, 150, 132), new int[] {174, 174, 174}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 17: grayscale above, stripes below", () -> {
            Canvas c = Figures.lcdPlate();
            byte[] ref = readReference("lcd.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 144);
            assertEquals("c.height", c.height, 192);
            assertTriple("ppm_pixel(p6, 60, 40)", Ppm.ppmPixel(p6, 60, 40), new int[] {46, 46, 46}, 1);
            assertTriple("ppm_pixel(p6, 60, 136)", Ppm.ppmPixel(p6, 60, 136), new int[] {123, 51, 126}, 1);
            assertTriple("ppm_pixel(p6, 5, 5)", Ppm.ppmPixel(p6, 5, 5), new int[] {255, 255, 255}, 0);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 17: Plate 17", () -> {
            Canvas c = Figures.plate17();
            byte[] ref = readReference("plate-17.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 288);
            assertEquals("c.height", c.height, 384);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference/chapter-17", filename));
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
        writeOne("subpixels.ppm", Figures.subpixelStrip());
        writeOne("smoothing.ppm", Figures.smoothingDemo());
        writeOne("lcd.ppm", Figures.lcdPlate());
        writeOne("plate-17.ppm", Figures.plate17());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
