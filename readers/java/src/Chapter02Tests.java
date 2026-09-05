import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter02-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-02/*.ppm resolves.
 */
public final class Chapter02Tests {

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
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertEquals(String what, Object actual, Object expected) {
        if (!actual.equals(expected)) {
            throw new AssertionError(what + ": expected [" + expected + "] but got [" + actual + "]");
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

    private static int unsignedByte(byte[] data, int oneIndexed) {
        return data[oneIndexed - 1] & 0xFF;
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerShapes();
        registerP6();
        registerMagnify();
        registerCenters();
        registerPaint();
        registerCoverage();
        registerTwice();
        registerPlate();
    }

    // features/chapter02-shapes.feature
    private static void registerShapes() {
        scenario("Shapes: a point inside a circle", () -> {
            Shape s = new Circle(8, 8, 5);
            assertTrue("inside(s, 8, 8)", s.inside(8, 8));
            assertTrue("inside(s, 12, 8)", s.inside(12, 8));
            assertTrue("inside(s, 13, 8)", s.inside(13, 8));
            assertTrue("!inside(s, 13.01, 8)", !s.inside(13.01, 8));
            assertTrue("!inside(s, 11.6, 11.6)", !s.inside(11.6, 11.6));
        });

        scenario("Shapes: a point inside a rectangle", () -> {
            Shape s = new Rectangle(1.25, 2.0, 4.75, 5.0);
            assertTrue("inside(s, 3, 3)", s.inside(3, 3));
            assertTrue("inside(s, 1.25, 2.0)", s.inside(1.25, 2.0));
            assertTrue("inside(s, 4.75, 5.0)", s.inside(4.75, 5.0));
            assertTrue("!inside(s, 1.2, 3)", !s.inside(1.2, 3));
            assertTrue("!inside(s, 3, 5.1)", !s.inside(3, 5.1));
        });

        scenario("Shapes: a point inside a half-plane", () -> {
            Shape s = new HalfPlane(2.5, 0, 1, 0);
            assertTrue("inside(s, 2.5, 7)", s.inside(2.5, 7));
            assertTrue("inside(s, 3, -4)", s.inside(3, -4));
            assertTrue("!inside(s, 2.4, 0)", !s.inside(2.4, 0));
        });

        scenario("Shapes: the normal picks the side", () -> {
            Shape s = new HalfPlane(2.5, 0, -1, 0);
            assertTrue("inside(s, 2.4, 0)", s.inside(2.4, 0));
            assertTrue("!inside(s, 3, 0)", !s.inside(3, 0));
        });
    }

    // features/chapter02-p6.feature
    private static void registerP6() {
        scenario("P6: the header, then the bytes", () -> {
            Canvas c = new Canvas(2, 1);
            c.writePixel(0, 0, new Color(1, 0, 0));
            c.writePixel(1, 0, new Color(0, 0.5, 0));
            byte[] p6 = Ppm.canvasToP6(c);
            String head = new String(p6, 0, 11, java.nio.charset.StandardCharsets.US_ASCII);
            assertEquals("p6 begins with the header", head, "P6\n2 1\n255\n");
            assertEquals("length(p6)", p6.length, 17);
            assertEquals("byte 12 of p6", unsignedByte(p6, 12), 255);
            assertEquals("byte 13 of p6", unsignedByte(p6, 13), 0);
            assertEquals("byte 16 of p6", unsignedByte(p6, 16), 188);
        });

        scenario("P6: the same pixel comes back out of either format", () -> {
            Canvas c = new Canvas(2, 1);
            c.writePixel(1, 0, new Color(0, 0.5, 0));
            String p3 = Ppm.canvasToPpm(c);
            byte[] p6 = Ppm.canvasToP6(c);
            assertTrue("ppm_pixel(p6, 1, 0) = (0, 188, 0)",
                    Arrays.equals(Ppm.ppmPixel(p6, 1, 0), new int[] {0, 188, 0}));
            assertTrue("ppm_pixel(p3, 1, 0) = (0, 188, 0)",
                    Arrays.equals(Ppm.ppmPixel(p3, 1, 0), new int[] {0, 188, 0}));
            assertEquals("max_channel_difference(p3, p6)", Ppm.maxChannelDifference(p3, p6), 0);
            assertEquals("distinct_values(p6)", Ppm.distinctValues(p6), 2);
        });

        scenario("P6: rows go top to bottom", () -> {
            Canvas c = new Canvas(1, 2);
            c.writePixel(0, 0, new Color(1, 0, 0));
            c.writePixel(0, 1, new Color(0, 0, 1));
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("byte 12 of p6", unsignedByte(p6, 12), 255);
            assertEquals("byte 17 of p6", unsignedByte(p6, 17), 255);
            assertTrue("ppm_pixel(p6, 0, 0) = (255, 0, 0)",
                    Arrays.equals(Ppm.ppmPixel(p6, 0, 0), new int[] {255, 0, 0}));
            assertTrue("ppm_pixel(p6, 0, 1) = (0, 0, 255)",
                    Arrays.equals(Ppm.ppmPixel(p6, 0, 1), new int[] {0, 0, 255}));
        });

        scenario("P6: the binary writer clamps too", () -> {
            Canvas c = new Canvas(2, 1);
            c.writePixel(0, 0, new Color(1.5, 0, -0.5));
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("byte 12 of p6", unsignedByte(p6, 12), 255);
            assertEquals("byte 13 of p6", unsignedByte(p6, 13), 0);
            assertEquals("byte 14 of p6", unsignedByte(p6, 14), 0);
            assertTrue("ppm_pixel(p6, 0, 0) = (255, 0, 0)",
                    Arrays.equals(Ppm.ppmPixel(p6, 0, 0), new int[] {255, 0, 0}));
        });

        scenario("P6: pixel bytes that look like whitespace are still pixel bytes", () -> {
            Canvas c = new Canvas(2, 1);
            c.writePixel(0, 0, new Color(0.00304, 0.01444, 0.00304));
            c.writePixel(1, 0, new Color(1, 1, 1));
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("length(p6)", p6.length, 17);
            assertEquals("byte 12 of p6", unsignedByte(p6, 12), 10);
            assertEquals("byte 13 of p6", unsignedByte(p6, 13), 32);
            assertTrue("ppm_pixel(p6, 0, 0) = (10, 32, 10)",
                    Arrays.equals(Ppm.ppmPixel(p6, 0, 0), new int[] {10, 32, 10}));
            assertTrue("ppm_pixel(p6, 1, 0) = (255, 255, 255)",
                    Arrays.equals(Ppm.ppmPixel(p6, 1, 0), new int[] {255, 255, 255}));
            assertEquals("max_channel_difference(canvas_to_ppm(c), p6)",
                    Ppm.maxChannelDifference(Ppm.canvasToPpm(c), p6), 0);
        });

        scenario("P6: sizes still have to match", () -> {
            Canvas c1 = new Canvas(2, 1);
            Canvas c2 = new Canvas(1, 2);
            byte[] p6a = Ppm.canvasToP6(c1);
            byte[] p6b = Ppm.canvasToP6(c2);
            assertEquals("max_channel_difference(p6a, p6b)", Ppm.maxChannelDifference(p6a, p6b), 255);
        });
    }

    // features/chapter02-magnify.feature
    private static void registerMagnify() {
        scenario("Magnify: every pixel becomes a block", () -> {
            Canvas c = new Canvas(2, 1);
            c.writePixel(0, 0, new Color(1, 0, 0));
            c.writePixel(1, 0, new Color(0, 0.5, 0));
            Canvas m = Magnify.magnify(c, 3);
            assertEquals("m.width", m.width, 6);
            assertEquals("m.height", m.height, 3);
            assertColorEq("pixel_at(m, 0, 0)", m.pixelAt(0, 0), new Color(1, 0, 0));
            assertColorEq("pixel_at(m, 2, 2)", m.pixelAt(2, 2), new Color(1, 0, 0));
            assertColorEq("pixel_at(m, 3, 0)", m.pixelAt(3, 0), new Color(0, 0.5, 0));
            assertColorEq("pixel_at(m, 5, 2)", m.pixelAt(5, 2), new Color(0, 0.5, 0));
            int redCount = 0;
            for (int y = 0; y < m.height; y++) {
                for (int x = 0; x < m.width; x++) {
                    if (m.pixelAt(x, y).approxEquals(new Color(1, 0, 0))) {
                        redCount++;
                    }
                }
            }
            assertEquals("count of red pixels", redCount, 9);
        });

        scenario("Magnify: magnifying by one changes nothing", () -> {
            Canvas c = new Canvas(2, 1);
            c.writePixel(1, 0, new Color(0, 0.5, 0));
            Canvas m = Magnify.magnify(c, 1);
            assertEquals("max_channel_difference(canvas_to_p6(c), canvas_to_p6(m))",
                    Ppm.maxChannelDifference(Ppm.canvasToP6(c), Ppm.canvasToP6(m)), 0);
        });
    }

    // features/chapter02-centers.feature
    private static void registerCenters() {
        scenario("Centers: a new coverage buffer is empty", () -> {
            CoverageBuffer cov = new CoverageBuffer(4, 3);
            assertEquals("cov.width", cov.width, 4);
            assertEquals("cov.height", cov.height, 3);
            assertDoubleEq("coverage_at(cov, 2, 1)", cov.coverageAt(2, 1), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 0);
        });

        scenario("Centers: setting coverage", () -> {
            CoverageBuffer cov = new CoverageBuffer(4, 3);
            cov.setCoverage(2, 1, 0.75);
            assertDoubleEq("coverage_at(cov, 2, 1)", cov.coverageAt(2, 1), 0.75);
            assertDoubleEq("coverage_at(cov, 1, 2)", cov.coverageAt(1, 2), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 0.75);
        });

        scenario("Centers: setting coverage outside the buffer is ignored, and reading it gives 0", () -> {
            CoverageBuffer cov = new CoverageBuffer(4, 3);
            cov.setCoverage(-1, 1, 1);
            cov.setCoverage(4, 1, 1);
            cov.setCoverage(1, 3, 1);
            assertDoubleEq("ink(cov)", cov.ink(), 0);
            assertDoubleEq("coverage_at(cov, -1, 1)", cov.coverageAt(-1, 1), 0);
            assertDoubleEq("coverage_at(cov, 4, 1)", cov.coverageAt(4, 1), 0);
            assertDoubleEq("coverage_at(cov, 1, 3)", cov.coverageAt(1, 3), 0);
        });

        scenario("Centers: the center of pixel (x, y) is (x + 0.5, y + 0.5)", () -> {
            Shape s = new HalfPlane(2.5, 0, 1, 0);
            assertDoubleEq("center_inside(s, 2, 4)", Rasterizer.centerInside(s, 2, 4), 1);
            assertDoubleEq("center_inside(s, 1, 4)", Rasterizer.centerInside(s, 1, 4), 0);
            Shape t = new HalfPlane(2.6, 0, 1, 0);
            assertDoubleEq("center_inside(t, 2, 4)", Rasterizer.centerInside(t, 2, 4), 0);
        });

        scenario("Centers: the center question is not \"at least half\"", () -> {
            Shape s = new HalfPlane(2.55, 0, 1, 0);
            assertDoubleEq("center_inside(s, 2, 4)", Rasterizer.centerInside(s, 2, 4), 0);
            assertDoubleEq("coverage(s, 2, 4)", Rasterizer.coverage(s, 2, 4), 0.5);
        });

        scenario("Centers: a buffer need not be square", () -> {
            Shape s = new Rectangle(0, 0, 2, 1);
            CoverageBuffer cov = Rasterizer.rasterizeCenters(s, 4, 2);
            assertEquals("cov.width", cov.width, 4);
            assertEquals("cov.height", cov.height, 2);
            assertDoubleEq("coverage_at(cov, 1, 0)", cov.coverageAt(1, 0), 1);
            assertDoubleEq("coverage_at(cov, 0, 1)", cov.coverageAt(0, 1), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 2);
        });

        scenario("Centers: a rectangle, by asking each center", () -> {
            Shape s = new Rectangle(1.25, 2.0, 4.75, 5.0);
            CoverageBuffer cov = Rasterizer.rasterizeCenters(s, 8, 8);
            assertDoubleEq("coverage_at(cov, 1, 4)", cov.coverageAt(1, 4), 1);
            assertDoubleEq("coverage_at(cov, 4, 1)", cov.coverageAt(4, 1), 0);
            assertDoubleEq("coverage_at(cov, 4, 4)", cov.coverageAt(4, 4), 1);
            assertDoubleEq("coverage_at(cov, 0, 3)", cov.coverageAt(0, 3), 0);
            assertDoubleEq("coverage_at(cov, 5, 3)", cov.coverageAt(5, 3), 0);
            assertDoubleEq("coverage_at(cov, 2, 1)", cov.coverageAt(2, 1), 0);
            assertDoubleEq("coverage_at(cov, 2, 5)", cov.coverageAt(2, 5), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 12);
        });

        scenario("Centers: a disc, by asking each center", () -> {
            Shape s = new Circle(8, 8, 5);
            CoverageBuffer cov = Rasterizer.rasterizeCenters(s, 16, 16);
            assertEquals("cov.width", cov.width, 16);
            assertEquals("cov.height", cov.height, 16);
            assertDoubleEq("coverage_at(cov, 8, 8)", cov.coverageAt(8, 8), 1);
            assertDoubleEq("coverage_at(cov, 3, 8)", cov.coverageAt(3, 8), 1);
            assertDoubleEq("coverage_at(cov, 12, 8)", cov.coverageAt(12, 8), 1);
            assertDoubleEq("coverage_at(cov, 2, 8)", cov.coverageAt(2, 8), 0);
            assertDoubleEq("coverage_at(cov, 13, 8)", cov.coverageAt(13, 8), 0);
            assertDoubleEq("coverage_at(cov, 4, 4)", cov.coverageAt(4, 4), 1);
            assertDoubleEq("coverage_at(cov, 3, 4)", cov.coverageAt(3, 4), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 80);
        });
    }

    // features/chapter02-paint.feature
    private static void registerPaint() {
        scenario("Paint: half coverage is half the paint", () -> {
            Canvas c = new Canvas(1, 1);
            CoverageBuffer cov = new CoverageBuffer(1, 1);
            cov.setCoverage(0, 0, 0.5);
            Painter.paintThrough(c, cov, new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 0, 0)", c.pixelAt(0, 0), new Color(0.5, 0.5, 0.5));
        });

        scenario("Paint: paint over something that isn't black", () -> {
            Canvas c = new Canvas(1, 1);
            CoverageBuffer cov = new CoverageBuffer(1, 1);
            c.fill(new Color(0.2, 0.2, 0.2));
            cov.setCoverage(0, 0, 0.25);
            Painter.paintThrough(c, cov, new Color(1, 0, 0));
            assertColorEq("pixel_at(c, 0, 0)", c.pixelAt(0, 0), new Color(0.4, 0.15, 0.15));
        });

        scenario("Paint: zero leaves it alone and one replaces it", () -> {
            Canvas c = new Canvas(2, 1);
            CoverageBuffer cov = new CoverageBuffer(2, 1);
            c.fill(new Color(0.2, 0.2, 0.2));
            cov.setCoverage(1, 0, 1);
            Painter.paintThrough(c, cov, new Color(1, 0, 0));
            assertColorEq("pixel_at(c, 0, 0)", c.pixelAt(0, 0), new Color(0.2, 0.2, 0.2));
            assertColorEq("pixel_at(c, 1, 0)", c.pixelAt(1, 0), new Color(1, 0, 0));
        });

        scenario("Paint: the arithmetic is on light", () -> {
            Canvas c = new Canvas(1, 1);
            CoverageBuffer cov = new CoverageBuffer(1, 1);
            cov.setCoverage(0, 0, 0.5);
            Painter.paintThrough(c, cov, new Color(1, 1, 1));
            String ppm = Ppm.canvasToPpm(c);
            assertTrue("ppm_pixel(ppm, 0, 0) = (188, 188, 188)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 0, 0), new int[] {188, 188, 188}));
        });

        scenario("Paint: the disc by centers", () -> {
            Canvas c = Figures.discCenters();
            byte[] ref = readReference("disc-centers.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 320);
            assertTriple("ppm_pixel(p6, 160, 160)", Ppm.ppmPixel(p6, 160, 160),
                    new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 124, 36)", Ppm.ppmPixel(p6, 124, 36),
                    new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 132, 36)", Ppm.ppmPixel(p6, 132, 36),
                    new int[] {243, 196, 89}, 1);
            assertEquals("distinct_values(p6)", Ppm.distinctValues(p6), 5);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    // features/chapter02-coverage.feature
    private static void registerCoverage() {
        scenario("Coverage: the sixty-four sample points", () -> {
            Shape s = new HalfPlane(2.5, 0, 1, 0);
            assertDoubleEq("coverage(s, 2, 4)", Rasterizer.coverage(s, 2, 4), 0.5);
            assertDoubleEq("coverage(s, 1, 4)", Rasterizer.coverage(s, 1, 4), 0);
            assertDoubleEq("coverage(s, 3, 4)", Rasterizer.coverage(s, 3, 4), 1);
        });

        scenario("Coverage: a rectangle is covered exactly, when its edges land on sample boundaries", () -> {
            Shape s = new Rectangle(1.25, 2.0, 4.75, 5.0);
            CoverageBuffer cov = Rasterizer.rasterize(s, 8, 8);
            assertDoubleEq("coverage_at(cov, 0, 2)", cov.coverageAt(0, 2), 0);
            assertDoubleEq("coverage_at(cov, 1, 2)", cov.coverageAt(1, 2), 0.75);
            assertDoubleEq("coverage_at(cov, 2, 2)", cov.coverageAt(2, 2), 1);
            assertDoubleEq("coverage_at(cov, 3, 2)", cov.coverageAt(3, 2), 1);
            assertDoubleEq("coverage_at(cov, 4, 2)", cov.coverageAt(4, 2), 0.75);
            assertDoubleEq("coverage_at(cov, 5, 2)", cov.coverageAt(5, 2), 0);
            assertDoubleEq("coverage_at(cov, 2, 1)", cov.coverageAt(2, 1), 0);
            assertDoubleEq("coverage_at(cov, 2, 5)", cov.coverageAt(2, 5), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 10.5);
        });

        scenario("Coverage: neither need the buffer be square here", () -> {
            Shape s = new Rectangle(0, 0, 2, 1);
            CoverageBuffer cov = Rasterizer.rasterize(s, 4, 2);
            assertEquals("cov.width", cov.width, 4);
            assertEquals("cov.height", cov.height, 2);
            assertDoubleEq("coverage_at(cov, 1, 0)", cov.coverageAt(1, 0), 1);
            assertDoubleEq("coverage_at(cov, 2, 0)", cov.coverageAt(2, 0), 0);
            assertDoubleEq("coverage_at(cov, 0, 1)", cov.coverageAt(0, 1), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 2);
        });

        scenario("Coverage: a half-plane through a pixel center covers half of it", () -> {
            Shape s = new HalfPlane(2.5, 4.5, 0.6, 0.8);
            assertDoubleEq("coverage(s, 2, 4)", Rasterizer.coverage(s, 2, 4), 0.5);
        });

        scenario("Coverage: except when the grid conspires", () -> {
            Shape s = new HalfPlane(2.5, 4.5, 1, 1);
            assertDoubleEq("coverage(s, 2, 4)", Rasterizer.coverage(s, 2, 4), 0.5625);
        });

        scenario("Coverage: a disc is only ever approximately covered", () -> {
            Shape s = new Circle(8, 8, 5);
            CoverageBuffer cov = Rasterizer.rasterize(s, 16, 16);
            assertDoubleEq("coverage_at(cov, 8, 8)", cov.coverageAt(8, 8), 1);
            assertDoubleEq("coverage_at(cov, 3, 8)", cov.coverageAt(3, 8), 0.96875);
            assertDoubleEq("coverage_at(cov, 12, 8)", cov.coverageAt(12, 8), 0.96875);
            assertDoubleEq("coverage_at(cov, 4, 4)", cov.coverageAt(4, 4), 0.5625);
            assertDoubleEq("coverage_at(cov, 3, 4)", cov.coverageAt(3, 4), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 78.5);
            assertDoubleEq("ink(cov) ~ true area", cov.ink(), 78.5398, 0.1);
        });

        scenario("Coverage: the disc by coverage", () -> {
            Canvas c = Figures.discCoverage();
            byte[] ref = readReference("disc-coverage.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 320);
            assertTriple("ppm_pixel(p6, 160, 160)", Ppm.ppmPixel(p6, 160, 160),
                    new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 124, 36)", Ppm.ppmPixel(p6, 124, 36),
                    new int[] {157, 127, 64}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    // features/chapter02-twice.feature
    private static void registerTwice() {
        scenario("Twice: half coverage, painted twice, is three quarters", () -> {
            Canvas c = new Canvas(1, 1);
            CoverageBuffer cov = new CoverageBuffer(1, 1);
            cov.setCoverage(0, 0, 0.5);
            Painter.paintThrough(c, cov, new Color(1, 1, 1));
            Painter.paintThrough(c, cov, new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 0, 0)", c.pixelAt(0, 0), new Color(0.75, 0.75, 0.75));
        });

        scenario("Twice: the disc, once and twice", () -> {
            Canvas c = Figures.paintedTwice();
            byte[] ref = readReference("painted-twice.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 480);
            assertEquals("c.height", c.height, 240);
            assertTriple("ppm_pixel(p6, 120, 120)", Ppm.ppmPixel(p6, 120, 120),
                    new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 360, 120)", Ppm.ppmPixel(p6, 360, 120),
                    new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 93, 27)", Ppm.ppmPixel(p6, 93, 27),
                    new int[] {157, 127, 64}, 1);
            assertTriple("ppm_pixel(p6, 333, 27)", Ppm.ppmPixel(p6, 333, 27),
                    new int[] {194, 156, 74}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    // features/chapter02-plate.feature
    private static void registerPlate() {
        scenario("Plate 2: the plate", () -> {
            Canvas c = Figures.plate02();
            byte[] ref = readReference("plate-02.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 480);
            assertEquals("c.height", c.height, 240);
            assertTriple("ppm_pixel(p6, 120, 120)", Ppm.ppmPixel(p6, 120, 120),
                    new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 360, 120)", Ppm.ppmPixel(p6, 360, 120),
                    new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 93, 27)", Ppm.ppmPixel(p6, 93, 27),
                    new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 333, 27)", Ppm.ppmPixel(p6, 333, 27),
                    new int[] {157, 127, 64}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(Path.of("reference/chapter-02", filename));
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
        Files.createDirectories(Path.of("out"));
        writeOne("disc-centers.ppm", Figures.discCenters());
        writeOne("disc-coverage.ppm", Figures.discCoverage());
        writeOne("painted-twice.ppm", Figures.paintedTwice());
        writeOne("plate-02.ppm", Figures.plate02());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
