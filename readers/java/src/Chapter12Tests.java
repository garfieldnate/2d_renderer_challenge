import java.io.IOException;
import java.nio.file.Files;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter12-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-12/*.ppm resolves.
 */
public final class Chapter12Tests {

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

    private static void assertPixelEq(String what, Pixel actual, Pixel expected) {
        if (!actual.approxEquals(expected)) {
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

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerClip();
        registerMask();
        registerGroups();
        registerPlate();
    }

    // features/chapter12-clip.feature
    private static void registerClip() {
        scenario("Clip: multiplying two coverage buffers, cell by cell", () -> {
            CoverageBuffer a = new CoverageBuffer(2, 1);
            CoverageBuffer b = new CoverageBuffer(2, 1);
            a.setCoverage(0, 0, 0.5);
            a.setCoverage(1, 0, 1.0);
            b.setCoverage(0, 0, 0.5);
            b.setCoverage(1, 0, 0.25);
            CoverageBuffer m = Clipping.multiplyCoverage(a, b);
            assertDoubleEq("coverage_at(m, 0, 0)", m.coverageAt(0, 0), 0.25);
            assertDoubleEq("coverage_at(m, 1, 0)", m.coverageAt(1, 0), 0.25);
        });

        scenario("Clip: clipping to the whole canvas changes nothing", () -> {
            CoverageBuffer cov = Fill.fillPath(Paths.circlePath(6, 6, 4, 32), "nonzero", 12, 12);
            CoverageBuffer full = Clipping.fullClip(12, 12);
            assertDoubleEq("max_coverage_difference(multiply_coverage(cov, full), cov)",
                    CoverageBuffer.maxCoverageDifference(Clipping.multiplyCoverage(cov, full), cov), 0);
        });

        scenario("Clip: nested clips commute", () -> {
            CoverageBuffer r = Clipping.clipRect(2, 2, 8, 8, 12, 12);
            CoverageBuffer c = Clipping.clipPath(Paths.circlePath(6, 6, 4, 32), "nonzero", 12, 12);
            assertDoubleEq("max_coverage_difference(multiply_coverage(r, c), multiply_coverage(c, r))",
                    CoverageBuffer.maxCoverageDifference(
                            Clipping.multiplyCoverage(r, c), Clipping.multiplyCoverage(c, r)), 0);
        });

        scenario("Clip: a clip zeroes the coverage outside it", () -> {
            Path square = Paths.polygon(
                    Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(10, 10), Tuple.point(0, 10));
            CoverageBuffer shape = Fill.fillPath(square, "nonzero", 12, 12);
            CoverageBuffer clip = Clipping.clipRect(2, 2, 6, 6, 12, 12);
            CoverageBuffer clipped = Clipping.multiplyCoverage(shape, clip);
            assertDoubleEq("coverage_at(clipped, 4, 4)", clipped.coverageAt(4, 4), 1.0);
            assertDoubleEq("coverage_at(clipped, 8, 8)", clipped.coverageAt(8, 8), 0.0);
        });
    }

    // features/chapter12-mask.feature
    private static void registerMask() {
        scenario("Mask: a soft mask fades from its center to its edge", () -> {
            CoverageBuffer m = Clipping.softMask(6, 6, 5, 12, 12);
            assertDoubleEq("coverage_at(m, 5, 5)", m.coverageAt(5, 5), 0.8586, 0.0001);
            assertDoubleEq("coverage_at(m, 1, 6)", m.coverageAt(1, 6), 0.0945, 0.0001);
            assertDoubleEq("coverage_at(m, 0, 0)", m.coverageAt(0, 0), 0);
        });

        scenario("Mask: a shape multiplied by a soft mask keeps its interior and fades its rim", () -> {
            Path square = Paths.polygon(
                    Tuple.point(0, 0), Tuple.point(12, 0), Tuple.point(12, 12), Tuple.point(0, 12));
            CoverageBuffer shape = Fill.fillPath(square, "nonzero", 12, 12);
            CoverageBuffer m = Clipping.softMask(6, 6, 5, 12, 12);
            CoverageBuffer masked = Clipping.multiplyCoverage(shape, m);
            assertDoubleEq("coverage_at(masked, 5, 5)", masked.coverageAt(5, 5), 0.8586, 0.0001);
            assertDoubleEq("coverage_at(masked, 0, 0)", masked.coverageAt(0, 0), 0);
        });
    }

    // features/chapter12-groups.feature
    private static void registerGroups() {
        scenario("Groups: scale_opacity lowers a layer's premultiplied channels together", () -> {
            Layer g = new Layer(1, 1);
            g.setPixel(0, 0, Pixel.opaque(new Color(1, 0, 0)));
            Layer h = Groups.scaleOpacity(g, 0.5);
            assertPixelEq("layer_pixel(h, 0, 0)", h.pixelAt(0, 0), new Pixel(0.5, 0, 0, 0.5));
        });

        scenario("Groups: a group at opacity 1 is drawing its children directly", () -> {
            Path a = Paths.polygon(Tuple.point(2, 2), Tuple.point(12, 2), Tuple.point(12, 12), Tuple.point(2, 12));
            Path b = Paths.polygon(Tuple.point(6, 6), Tuple.point(16, 6), Tuple.point(16, 16), Tuple.point(6, 16));
            CoverageBuffer ca = Fill.fillPath(a, "nonzero", 20, 20);
            CoverageBuffer cb = Fill.fillPath(b, "nonzero", 20, 20);
            Layer direct = Groups.paintInto(
                    Groups.paintInto(new Layer(20, 20), ca, new Color(1, 0, 0), 1.0), cb, new Color(0, 0, 1), 1.0);
            Layer group = Groups.paintInto(
                    Groups.paintInto(Groups.pushGroup(20, 20), ca, new Color(1, 0, 0), 1.0),
                    cb, new Color(0, 0, 1), 1.0);
            Layer grouped = Groups.popGroupWithOpacity(group, new Layer(20, 20), 1.0);
            assertPixelEq("layer_pixel(grouped, 8, 8)", grouped.pixelAt(8, 8), direct.pixelAt(8, 8));
            assertPixelEq("layer_pixel(grouped, 3, 3)", grouped.pixelAt(3, 3), direct.pixelAt(3, 3));
            assertPixelEq("layer_pixel(grouped, 14, 14)", grouped.pixelAt(14, 14), direct.pixelAt(14, 14));
        });

        scenario("Groups: below opacity 1 a group and per-child opacity part ways at overlaps", () -> {
            Path a = Paths.polygon(Tuple.point(2, 2), Tuple.point(12, 2), Tuple.point(12, 12), Tuple.point(2, 12));
            Path b = Paths.polygon(Tuple.point(6, 6), Tuple.point(16, 6), Tuple.point(16, 16), Tuple.point(6, 16));
            CoverageBuffer ca = Fill.fillPath(a, "nonzero", 20, 20);
            CoverageBuffer cb = Fill.fillPath(b, "nonzero", 20, 20);
            Layer perchild = Groups.paintInto(
                    Groups.paintInto(new Layer(20, 20), ca, new Color(1, 0, 0), 0.5), cb, new Color(0, 0, 1), 0.5);
            Layer group = Groups.paintInto(
                    Groups.paintInto(Groups.pushGroup(20, 20), ca, new Color(1, 0, 0), 1.0),
                    cb, new Color(0, 0, 1), 1.0);
            Layer grouped = Groups.popGroupWithOpacity(group, new Layer(20, 20), 0.5);
            assertPixelEq("layer_pixel(grouped, 3, 3)", grouped.pixelAt(3, 3), perchild.pixelAt(3, 3));
            assertTrue("layer_pixel(grouped, 8, 8) != layer_pixel(perchild, 8, 8)",
                    !grouped.pixelAt(8, 8).approxEquals(perchild.pixelAt(8, 8)));
        });
    }

    // features/chapter12-plate.feature
    private static void registerPlate() {
        scenario("Plate 12: a single circle looks the same either way, but the overlap does not", () -> {
            Canvas c = Figures.opacityPlate();
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 300);
            assertEquals("c.height", c.height, 150);
            assertTriple("ppm_pixel(p6, 40, 62)", Ppm.ppmPixel(p6, 40, 62), new int[] {185, 145, 71}, 1);
            assertTriple("ppm_pixel(p6, 190, 62)", Ppm.ppmPixel(p6, 190, 62), new int[] {185, 145, 71}, 1);
            assertTriple("ppm_pixel(p6, 75, 72)", Ppm.ppmPixel(p6, 75, 72), new int[] {203, 156, 165}, 1);
            assertTriple("ppm_pixel(p6, 225, 72)", Ppm.ppmPixel(p6, 225, 72), new int[] {176, 103, 112}, 1);
            assertTriple("ppm_pixel(p6, 5, 5)", Ppm.ppmPixel(p6, 5, 5), new int[] {39, 39, 44}, 1);
        });

        scenario("Plate 12: the opacity plate", () -> {
            Canvas c = Figures.opacityPlate();
            byte[] ref = readReference("opacity.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 12: Plate 12", () -> {
            Canvas c = Figures.plate12();
            byte[] ref = readReference("plate-12.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 600);
            assertEquals("c.height", c.height, 300);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 12: the clip demo, hard against soft", () -> {
            Canvas c = Figures.clipDemo();
            byte[] ref = readReference("clip-demo.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 300);
            assertEquals("c.height", c.height, 150);
            assertTriple("ppm_pixel(p6, 225, 45)", Ppm.ppmPixel(p6, 225, 45), new int[] {197, 155, 74}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference/chapter-12", filename));
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
        writeOne("opacity.ppm", Figures.opacityPlate());
        writeOne("plate-12.ppm", Figures.plate12());
        writeOne("clip-demo.ppm", Figures.clipDemo());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
