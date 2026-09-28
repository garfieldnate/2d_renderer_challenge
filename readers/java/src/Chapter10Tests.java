import java.io.IOException;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter10-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-10/*.ppm resolves.
 */
public final class Chapter10Tests {

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

    private static void assertColorEq(String what, Color actual, Color expected) {
        assertColorEq(what, actual, expected, Numbers.DEFAULT_EPSILON);
    }

    private static void assertColorEq(String what, Color actual, Color expected, double eps) {
        if (!actual.approxEquals(expected, eps)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertPixelEq(String what, Pixel actual, Pixel expected) {
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerStops();
        registerExtend();
        registerGradients();
        registerDither();
        registerPlate();
    }

    // features/chapter10-stops.feature
    private static void registerStops() {
        scenario("Stops: a stop offset returns its own colour", () -> {
            List<Stop> s = List.of(
                    new Stop(0, new Color(0, 0, 0)), new Stop(0.5, new Color(1, 0, 0)), new Stop(1, new Color(1, 1, 1)));
            assertColorEq("sample_stops(s, 0)", Stops.sampleStops(s, 0), new Color(0, 0, 0));
            assertColorEq("sample_stops(s, 0.5)", Stops.sampleStops(s, 0.5), new Color(1, 0, 0));
            assertColorEq("sample_stops(s, 1)", Stops.sampleStops(s, 1), new Color(1, 1, 1));
        });

        scenario("Stops: between two stops is a straight blend", () -> {
            List<Stop> s = List.of(
                    new Stop(0, new Color(0, 0, 0)), new Stop(0.5, new Color(1, 0, 0)), new Stop(1, new Color(1, 1, 1)));
            assertColorEq("sample_stops(s, 0.25)", Stops.sampleStops(s, 0.25), new Color(0.5, 0, 0));
            assertColorEq("sample_stops(s, 0.75)", Stops.sampleStops(s, 0.75), new Color(1, 0.5, 0.5));
        });

        scenario("Stops: outside the ends clamps to the end colours", () -> {
            List<Stop> s = List.of(
                    new Stop(0, new Color(0, 0, 0)), new Stop(0.5, new Color(1, 0, 0)), new Stop(1, new Color(1, 1, 1)));
            assertColorEq("sample_stops(s, -0.3)", Stops.sampleStops(s, -0.3), new Color(0, 0, 0));
            assertColorEq("sample_stops(s, 1.5)", Stops.sampleStops(s, 1.5), new Color(1, 1, 1));
        });

        scenario("Stops: uneven stops still blend by their own spacing", () -> {
            List<Stop> s = List.of(
                    new Stop(0, new Color(0, 0, 0)), new Stop(0.8, new Color(1, 0, 0)), new Stop(1, new Color(0, 0, 1)));
            assertColorEq("sample_stops(s, 0.4)", Stops.sampleStops(s, 0.4), new Color(0.5, 0, 0));
            assertColorEq("sample_stops(s, 0.9)", Stops.sampleStops(s, 0.9), new Color(0.5, 0, 0.5));
        });
    }

    // features/chapter10-extend.feature
    private static final Object[][] EXTEND_TABLE = {
        {0.3, 0.3, 0.3, 0.3},
        {-0.25, 0.0, 0.75, 0.25},
        {1.0, 1.0, 0.0, 1.0},
        {1.25, 1.0, 0.25, 0.75},
        {1.75, 1.0, 0.75, 0.25},
        {2.25, 1.0, 0.25, 0.25},
    };

    private static void registerExtend() {
        for (Object[] row : EXTEND_TABLE) {
            double t = (double) row[0];
            double pad = (double) row[1];
            double repeat = (double) row[2];
            double reflect = (double) row[3];
            scenario("Extend: the three modes fold a parameter back in: t=" + t, () -> {
                assertDoubleEq("extend(" + t + ", \"pad\")", Stops.extend(t, "pad"), pad);
                assertDoubleEq("extend(" + t + ", \"repeat\")", Stops.extend(t, "repeat"), repeat);
                assertDoubleEq("extend(" + t + ", \"reflect\")", Stops.extend(t, "reflect"), reflect);
            });
        }
    }

    // features/chapter10-gradients.feature
    private static void registerGradients() {
        scenario("Gradients: a linear gradient's parameter is the distance along its axis", () -> {
            LinearGradient g = new LinearGradient(Tuple.point(10, 10), Tuple.point(110, 10), List.of(), "pad");
            assertDoubleEq("linear_t(g, 10, 10)", g.linearT(10, 10), 0);
            assertDoubleEq("linear_t(g, 35, 10)", g.linearT(35, 10), 0.25);
            assertDoubleEq("linear_t(g, 60, 10)", g.linearT(60, 10), 0.5);
            assertDoubleEq("linear_t(g, 110, 10)", g.linearT(110, 10), 1);
        });

        scenario("Gradients: distance across the axis does not change the parameter", () -> {
            LinearGradient g = new LinearGradient(Tuple.point(10, 10), Tuple.point(110, 10), List.of(), "pad");
            assertDoubleEq("linear_t(g, 60, 10)", g.linearT(60, 10), 0.5);
            assertDoubleEq("linear_t(g, 60, 50)", g.linearT(60, 50), 0.5);
        });

        scenario("Gradients: a linear gradient's colour along the axis is the parameter itself", () -> {
            List<Stop> stops = List.of(new Stop(0, new Color(0, 0, 0)), new Stop(1, new Color(1, 1, 1)));
            LinearGradient g = new LinearGradient(Tuple.point(0, 0), Tuple.point(100, 0), stops, "pad");
            assertColorEq("paint_at(g, 25, 0)", g.paintAt(25, 0), new Color(0.25, 0.25, 0.25));
            assertColorEq("paint_at(g, 50, 0)", g.paintAt(50, 0), new Color(0.5, 0.5, 0.5));
        });

        scenario("Gradients: a concentric radial gradient's parameter is distance over radius", () -> {
            RadialGradient g = new RadialGradient(Tuple.point(50, 50), 0, Tuple.point(50, 50), 40, List.of(), "pad");
            assertDoubleEq("radial_t(g, 50, 50)", g.radialT(50, 50), 0);
            assertDoubleEq("radial_t(g, 70, 50)", g.radialT(70, 50), 0.5);
            assertDoubleEq("radial_t(g, 90, 50)", g.radialT(90, 50), 1);
        });

        scenario("Gradients: when both roots are valid the larger one wins", () -> {
            RadialGradient g = new RadialGradient(Tuple.point(0, 0), 10, Tuple.point(30, 0), 12, List.of(), "pad");
            assertDoubleEq("radial_t(g, 5, 0)", g.radialT(5, 0), 0.535714, 0.0001);
            assertDoubleEq("radial_t(g, 15, 0)", g.radialT(15, 0), 0.892857, 0.0001);
            assertDoubleEq("radial_t(g, 20, 0)", g.radialT(20, 0), 1.071429, 0.0001);
        });

        scenario("Gradients: a focal gradient runs from the focal point to the end circle", () -> {
            RadialGradient g = new RadialGradient(Tuple.point(35, 50), 0, Tuple.point(50, 50), 40, List.of(), "pad");
            assertDoubleEq("radial_t(g, 35, 50)", g.radialT(35, 50), 0);
            assertDoubleEq("radial_t(g, 90, 50)", g.radialT(90, 50), 1);
        });

        scenario("Gradients: a conic gradient sweeps the angle around its center", () -> {
            ConicGradient g = new ConicGradient(Tuple.point(50, 50), -Math.PI / 2, List.of(), "pad");
            assertDoubleEq("conic_t(g, 50, 10)", g.conicT(50, 10), 0);
            assertDoubleEq("conic_t(g, 90, 50)", g.conicT(90, 50), 0.25);
            assertDoubleEq("conic_t(g, 50, 90)", g.conicT(50, 90), 0.5);
            assertDoubleEq("conic_t(g, 10, 50)", g.conicT(10, 50), 0.75);
        });
    }

    // features/chapter10-dither.feature
    private static void registerDither() {
        scenario("Dither: the Bayer matrix and its thresholds", () -> {
            int[][] b = Dither.BAYER4;
            assertEquals("b[0][0]", b[0][0], 0);
            assertEquals("b[0][1]", b[0][1], 8);
            assertEquals("b[1][0]", b[1][0], 12);
            assertDoubleEq("dither_threshold(0, 0)", Dither.ditherThreshold(0, 0), 0);
            assertDoubleEq("dither_threshold(1, 0)", Dither.ditherThreshold(1, 0), 0.5);
            assertDoubleEq("dither_threshold(0, 1)", Dither.ditherThreshold(0, 1), 0.75);
        });

        scenario("Dither: one light value dithers to the two bytes around it", () -> {
            assertEquals("to_byte_dithered(0.5, 0, 0)", Dither.toByteDithered(0.5, 0, 0), 187);
            assertEquals("to_byte_dithered(0.5, 1, 0)", Dither.toByteDithered(0.5, 1, 0), 188);
            assertEquals("to_byte(0.5)", Ppm.toByte(0.5), 188);
        });

        scenario("Dither: a flat patch is one byte plain but two dithered", () -> {
            Canvas c = new Canvas(16, 16);
            c.fill(new Color(0.5, 0.5, 0.5));
            assertEquals("distinct_values(canvas_to_p6(c))", Ppm.distinctValues(Ppm.canvasToP6(c)), 1);
            assertEquals("distinct_values(canvas_to_p6_dithered(c))",
                    Ppm.distinctValues(Ppm.canvasToP6Dithered(c)), 2);
        });
    }

    // features/chapter10-plate.feature
    private static void registerPlate() {
        scenario("Plate 10: a solid paint fills exactly like paint_through", () -> {
            Path box = Paths.polygon(
                    Tuple.point(1, 1), Tuple.point(6, 1), Tuple.point(6, 6), Tuple.point(1, 6));
            CoverageBuffer cov = Fill.fillPath(box, "nonzero", 8, 8);
            Canvas a = new Canvas(8, 8);
            Canvas b = new Canvas(8, 8);
            a.fill(new Color(0.02, 0.02, 0.025));
            b.fill(new Color(0.02, 0.02, 0.025));
            Painter.paintFill(a, cov, Paint.solid(new Color(0.9, 0.5, 0.2)));
            Painter.paintThrough(b, cov, new Color(0.9, 0.5, 0.2));
            assertColorEq("pixel_at(a, 3, 3)", a.pixelAt(3, 3), b.pixelAt(3, 3));
            assertColorEq("pixel_at(a, 1, 1)", a.pixelAt(1, 1), b.pixelAt(1, 1));
        });

        scenario("Plate 10: an unreachable focal pixel takes the last stop, not black", () -> {
            List<Stop> stops = List.of(new Stop(0, new Color(0, 0, 0)), new Stop(1, new Color(1, 1, 1)));
            RadialGradient g = new RadialGradient(Tuple.point(100, 50), 0, Tuple.point(50, 50), 20, stops, "pad");
            assertTrue("radial_t(g, 110, 50) = none", g.radialT(110, 50) == null);
            assertColorEq("paint_at(g, 110, 50)", g.paintAt(110, 50), new Color(1, 1, 1));
        });

        scenario("Plate 10: the three gradients", () -> {
            Canvas c = Figures.threeGradients();
            byte[] ref = readReference("three-gradients.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 458);
            assertEquals("c.height", c.height, 150);
            assertTriple("ppm_pixel(p6, 10, 10)", Ppm.ppmPixel(p6, 10, 10), new int[] {68, 40, 108}, 1);
            assertTriple("ppm_pixel(p6, 140, 140)", Ppm.ppmPixel(p6, 140, 140), new int[] {255, 249, 225}, 1);
            assertTriple("ppm_pixel(p6, 209, 55)", Ppm.ppmPixel(p6, 209, 55), new int[] {71, 41, 109}, 1);
            assertTriple("ppm_pixel(p6, 383, 20)", Ppm.ppmPixel(p6, 383, 20), new int[] {65, 39, 108}, 1);
            assertTriple("ppm_pixel(p6, 438, 75)", Ppm.ppmPixel(p6, 438, 75), new int[] {196, 95, 130}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 10: the extend strip", () -> {
            Canvas c = Figures.extendStrip();
            byte[] ref = readReference("extend-modes.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 360);
            assertEquals("c.height", c.height, 180);
            assertTriple("ppm_pixel(p6, 20, 30)", Ppm.ppmPixel(p6, 20, 30), new int[] {89, 108, 188}, 1);
            assertTriple("ppm_pixel(p6, 340, 30)", Ppm.ppmPixel(p6, 340, 30), new int[] {255, 218, 89}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 10: Plate 10", () -> {
            Canvas c = Figures.plate10();
            byte[] ref = readReference("plate-10.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 458);
            assertEquals("c.height", c.height, 150);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference/chapter-10", filename));
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
        writeOne("three-gradients.ppm", Figures.threeGradients());
        writeOne("plate-10.ppm", Figures.plate10());
        writeOne("extend-modes.ppm", Figures.extendStrip());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
