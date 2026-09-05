import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter03-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-03/*.ppm resolves.
 */
public final class Chapter03Tests {

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

    private static void assertPoints(String what, List<int[]> actual, int[][] expected) {
        boolean sameLength = actual.size() == expected.length;
        boolean same = sameLength;
        if (same) {
            for (int i = 0; i < expected.length; i++) {
                if (!Arrays.equals(actual.get(i), expected[i])) {
                    same = false;
                    break;
                }
            }
        }
        if (!same) {
            throw new AssertionError(what + ": expected " + pointsToString(expected)
                    + " but got " + pointsToString(actual));
        }
    }

    private static String pointsToString(int[][] pts) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < pts.length; i++) {
            if (i > 0) sb.append(", ");
            sb.append('(').append(pts[i][0]).append(", ").append(pts[i][1]).append(')');
        }
        return sb.append(']').toString();
    }

    private static String pointsToString(List<int[]> pts) {
        return pointsToString(pts.toArray(new int[0][]));
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerBresenham();
        registerWu();
        registerQuad();
        registerPlate();
    }

    // features/chapter03-bresenham.feature
    private static void registerBresenham() {
        scenario("Bresenham: a diagonal", () -> {
            Canvas c = new Canvas(10, 10);
            Lines.lineBresenham(c, 0, 0, 5, 5, new Color(1, 1, 1));
            assertPoints("lit_pixels(c)", Lines.litPixels(c),
                    new int[][] {{0, 0}, {1, 1}, {2, 2}, {3, 3}, {4, 4}, {5, 5}});
        });

        scenario("Bresenham: a horizontal line lights one row and nothing else", () -> {
            Canvas c = new Canvas(10, 10);
            Lines.lineBresenham(c, 0, 3, 7, 3, new Color(1, 1, 1));
            assertPoints("lit_pixels(c)", Lines.litPixels(c), new int[][] {
                    {0, 3}, {1, 3}, {2, 3}, {3, 3}, {4, 3}, {5, 3}, {6, 3}, {7, 3}});
        });

        scenario("Bresenham: a shallow line steps along x", () -> {
            Canvas c = new Canvas(10, 10);
            Lines.lineBresenham(c, 0, 0, 7, 3, new Color(1, 1, 1));
            assertPoints("lit_pixels(c)", Lines.litPixels(c), new int[][] {
                    {0, 0}, {1, 0}, {2, 1}, {3, 1}, {4, 2}, {5, 2}, {6, 3}, {7, 3}});
        });

        scenario("Bresenham: a steep line steps along y", () -> {
            Canvas c = new Canvas(10, 10);
            Lines.lineBresenham(c, 1, 1, 3, 7, new Color(1, 1, 1));
            assertPoints("lit_pixels(c)", Lines.litPixels(c), new int[][] {
                    {1, 1}, {1, 2}, {2, 3}, {2, 4}, {2, 5}, {3, 6}, {3, 7}});
        });

        scenario("Bresenham: the pixels don't depend on which end you start from", () -> {
            Canvas c1 = new Canvas(10, 10);
            Canvas c2 = new Canvas(10, 10);
            Lines.lineBresenham(c1, 1, 1, 3, 7, new Color(1, 1, 1));
            Lines.lineBresenham(c2, 3, 7, 1, 1, new Color(1, 1, 1));
            assertPoints("lit_pixels(c1) = lit_pixels(c2)", Lines.litPixels(c1),
                    Lines.litPixels(c2).toArray(new int[0][]));
            assertEquals("max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2))",
                    Ppm.maxChannelDifference(Ppm.canvasToP6(c1), Ppm.canvasToP6(c2)), 0);
        });

        scenario("Bresenham: a line going up and to the right", () -> {
            Canvas c = new Canvas(10, 10);
            Lines.lineBresenham(c, 0, 6, 7, 3, new Color(1, 1, 1));
            assertPoints("lit_pixels(c)", Lines.litPixels(c), new int[][] {
                    {6, 3}, {7, 3}, {4, 4}, {5, 4}, {2, 5}, {3, 5}, {0, 6}, {1, 6}});
        });

        scenario("Bresenham: at an exact half the line stays on its row one step longer", () -> {
            Canvas c = new Canvas(10, 10);
            Lines.lineBresenham(c, 0, 0, 4, 2, new Color(1, 1, 1));
            assertPoints("lit_pixels(c)", Lines.litPixels(c),
                    new int[][] {{0, 0}, {1, 0}, {2, 1}, {3, 1}, {4, 2}});
        });

        scenario("Bresenham: a line of one point", () -> {
            Canvas c = new Canvas(10, 10);
            Lines.lineBresenham(c, 3, 3, 3, 3, new Color(1, 1, 1));
            assertPoints("lit_pixels(c)", Lines.litPixels(c), new int[][] {{3, 3}});
        });

        scenario("Bresenham: a line may run off the canvas", () -> {
            Canvas c = new Canvas(10, 10);
            Lines.lineBresenham(c, 0, 0, 12, 6, new Color(1, 1, 1));
            assertEquals("length(lit_pixels(c))", Lines.litPixels(c).size(), 10);
        });
    }

    // features/chapter03-wu.feature
    private static void registerWu() {
        scenario("Wu: a half step lights two pixels equally", () -> {
            Canvas c = new Canvas(10, 10);
            Lines.lineWu(c, 0, 0, 4, 2, new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 0, 0)", c.pixelAt(0, 0), new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 1, 0)", c.pixelAt(1, 0), new Color(0.5, 0.5, 0.5));
            assertColorEq("pixel_at(c, 1, 1)", c.pixelAt(1, 1), new Color(0.5, 0.5, 0.5));
            assertColorEq("pixel_at(c, 2, 1)", c.pixelAt(2, 1), new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 2, 2)", c.pixelAt(2, 2), new Color(0, 0, 0));
            assertColorEq("pixel_at(c, 4, 2)", c.pixelAt(4, 2), new Color(1, 1, 1));
            assertDoubleEq("total_ink(c)", Lines.totalInk(c), 5);
        });

        scenario("Wu: a diagonal has uniform weights", () -> {
            Canvas c = new Canvas(10, 10);
            Lines.lineWu(c, 0, 0, 5, 5, new Color(1, 1, 1));
            assertPoints("lit_pixels(c)", Lines.litPixels(c),
                    new int[][] {{0, 0}, {1, 1}, {2, 2}, {3, 3}, {4, 4}, {5, 5}});
            assertColorEq("pixel_at(c, 3, 3)", c.pixelAt(3, 3), new Color(1, 1, 1));
            assertDoubleEq("total_ink(c)", Lines.totalInk(c), 6);
        });

        scenario("Wu: a horizontal line has weight 1 on its row and 0 on the neighbors", () -> {
            Canvas c = new Canvas(10, 10);
            Lines.lineWu(c, 0, 3, 7, 3, new Color(1, 1, 1));
            assertPoints("lit_pixels(c)", Lines.litPixels(c), new int[][] {
                    {0, 3}, {1, 3}, {2, 3}, {3, 3}, {4, 3}, {5, 3}, {6, 3}, {7, 3}});
            assertColorEq("pixel_at(c, 3, 3)", c.pixelAt(3, 3), new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 3, 2)", c.pixelAt(3, 2), new Color(0, 0, 0));
            assertColorEq("pixel_at(c, 3, 4)", c.pixelAt(3, 4), new Color(0, 0, 0));
            assertDoubleEq("total_ink(c)", Lines.totalInk(c), 8);
        });

        scenario("Wu: a steep line weights across columns", () -> {
            Canvas c = new Canvas(10, 10);
            Lines.lineWu(c, 1, 1, 3, 7, new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 1, 1)", c.pixelAt(1, 1), new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 1, 2)", c.pixelAt(1, 2), new Color(0.6667, 0.6667, 0.6667));
            assertColorEq("pixel_at(c, 2, 2)", c.pixelAt(2, 2), new Color(0.3333, 0.3333, 0.3333));
            assertColorEq("pixel_at(c, 2, 4)", c.pixelAt(2, 4), new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 3, 7)", c.pixelAt(3, 7), new Color(1, 1, 1));
            assertDoubleEq("total_ink(c)", Lines.totalInk(c), 7);
        });

        scenario("Wu: the weights don't depend on which end you start from", () -> {
            Canvas c1 = new Canvas(10, 10);
            Canvas c2 = new Canvas(10, 10);
            Lines.lineWu(c1, 1, 1, 3, 7, new Color(1, 1, 1));
            Lines.lineWu(c2, 3, 7, 1, 1, new Color(1, 1, 1));
            assertEquals("max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2))",
                    Ppm.maxChannelDifference(Ppm.canvasToP6(c1), Ppm.canvasToP6(c2)), 0);
        });

        scenario("Wu: sevenths", () -> {
            Canvas c = new Canvas(10, 10);
            Lines.lineWu(c, 0, 0, 7, 3, new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 1, 0)", c.pixelAt(1, 0), new Color(0.5714, 0.5714, 0.5714));
            assertColorEq("pixel_at(c, 1, 1)", c.pixelAt(1, 1), new Color(0.4286, 0.4286, 0.4286));
            assertColorEq("pixel_at(c, 2, 0)", c.pixelAt(2, 0), new Color(0.1429, 0.1429, 0.1429));
            assertColorEq("pixel_at(c, 2, 1)", c.pixelAt(2, 1), new Color(0.8571, 0.8571, 0.8571));
            assertDoubleEq("total_ink(c)", Lines.totalInk(c), 8);
        });

        int[][] wuAngleRows = {{12, 2, 11}, {10, 8, 9}, {8, 10, 9}, {2, 12, 11}};
        for (int[] row : wuAngleRows) {
            int x1 = row[0], y1 = row[1], ink = row[2];
            scenario("Wu: the ink depends on the angle (x1=" + x1 + ", y1=" + y1 + ")", () -> {
                Canvas c = new Canvas(20, 20);
                Lines.lineWu(c, 2, 2, x1, y1, new Color(1, 1, 1));
                assertDoubleEq("total_ink(c)", Lines.totalInk(c), ink);
            });
        }
    }

    // features/chapter03-quad.feature
    private static void registerQuad() {
        scenario("Quad: inside a thick line", () -> {
            Shape s = new ThickLine(0, 0, 4, 0, 1);
            assertTrue("inside(s, 2.5, 0.5)", s.inside(2.5, 0.5));
            assertTrue("inside(s, 2.5, 1.0)", s.inside(2.5, 1.0));
            assertTrue("!inside(s, 2.5, 1.01)", !s.inside(2.5, 1.01));
            assertTrue("inside(s, 0.5, 0.5)", s.inside(0.5, 0.5));
            assertTrue("!inside(s, 0.4, 0.5)", !s.inside(0.4, 0.5));
            assertTrue("inside(s, 4.5, 0.5)", s.inside(4.5, 0.5));
            assertTrue("!inside(s, 4.6, 0.5)", !s.inside(4.6, 0.5));
        });

        scenario("Quad: a horizontal thick line covers its row, with half pixels at the ends", () -> {
            Shape s = new ThickLine(0, 3, 7, 3, 1);
            CoverageBuffer cov = Rasterizer.rasterize(s, 10, 10);
            assertDoubleEq("coverage_at(cov, 0, 3)", cov.coverageAt(0, 3), 0.5);
            assertDoubleEq("coverage_at(cov, 1, 3)", cov.coverageAt(1, 3), 1);
            assertDoubleEq("coverage_at(cov, 6, 3)", cov.coverageAt(6, 3), 1);
            assertDoubleEq("coverage_at(cov, 7, 3)", cov.coverageAt(7, 3), 0.5);
            assertDoubleEq("coverage_at(cov, 8, 3)", cov.coverageAt(8, 3), 0);
            assertDoubleEq("coverage_at(cov, 3, 2)", cov.coverageAt(3, 2), 0);
            assertDoubleEq("coverage_at(cov, 3, 4)", cov.coverageAt(3, 4), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 7);
        });

        int[][] quadAngles = {{12, 2}, {10, 8}, {8, 10}, {2, 12}};
        for (int[] row : quadAngles) {
            int x1 = row[0], y1 = row[1];
            scenario("Quad: the ink is the length, whatever the angle (x1=" + x1 + ", y1=" + y1 + ")", () -> {
                Shape s = new ThickLine(2, 2, x1, y1, 1);
                CoverageBuffer cov = Rasterizer.rasterize(s, 20, 20);
                assertDoubleEq("ink(cov)", cov.ink(), 10);
            });
        }

        scenario("Quad: except that the grid is blind along the diagonal", () -> {
            Shape s = new ThickLine(2, 2, 9, 9, 1);
            CoverageBuffer cov = Rasterizer.rasterize(s, 20, 20);
            assertDoubleEq("ink(cov)", cov.ink(), 9.7188);
            assertDoubleEq("ink(cov)", cov.ink(), 9.8995, 0.25);
        });
    }

    // features/chapter03-plate.feature
    private static void registerPlate() {
        scenario("Plate 3: the ray endpoints", () -> {
            int[][] ends = Figures.rayEnds();
            int[][] expected = {
                    {152, 80}, {142, 116}, {116, 142}, {80, 152}, {44, 142}, {18, 116},
                    {8, 80}, {18, 44}, {44, 18}, {80, 8}, {116, 18}, {142, 44}
            };
            assertEquals("length(ray_ends())", ends.length, expected.length);
            for (int i = 0; i < expected.length; i++) {
                assertTrue("ray_ends()[" + i + "]", Arrays.equals(ends[i], expected[i]));
            }
        });

        scenario("Plate 3: Bresenham's fan", () -> {
            Canvas c = Figures.fanBresenham();
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 160);
            assertEquals("c.height", c.height, 160);
            assertTriple("ppm_pixel(p6, 80, 80)", Ppm.ppmPixel(p6, 80, 80), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 120, 80)", Ppm.ppmPixel(p6, 120, 80), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 10, 10)", Ppm.ppmPixel(p6, 10, 10), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 100, 91)", Ppm.ppmPixel(p6, 100, 91), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 100, 92)", Ppm.ppmPixel(p6, 100, 92), new int[] {246, 246, 241}, 1);
        });

        scenario("Plate 3: Wu's fan", () -> {
            Canvas c = Figures.fanWu();
            byte[] p6 = Ppm.canvasToP6(c);
            assertTriple("ppm_pixel(p6, 80, 80)", Ppm.ppmPixel(p6, 80, 80), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 120, 80)", Ppm.ppmPixel(p6, 120, 80), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 100, 91)", Ppm.ppmPixel(p6, 100, 91), new int[] {163, 163, 161}, 1);
            assertTriple("ppm_pixel(p6, 100, 92)", Ppm.ppmPixel(p6, 100, 92), new int[] {199, 199, 196}, 1);
        });

        scenario("Plate 3: the fan as twelve thin rectangles", () -> {
            Canvas c = Figures.fanCoverage();
            byte[] ref = readReference("fan-coverage.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 320);
            assertTriple("ppm_pixel(p6, 160, 160)", Ppm.ppmPixel(p6, 160, 160), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 10, 10)", Ppm.ppmPixel(p6, 10, 10), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 240, 160)", Ppm.ppmPixel(p6, 240, 160), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 240, 158)", Ppm.ppmPixel(p6, 240, 158), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 200, 183)", Ppm.ppmPixel(p6, 200, 183), new int[] {177, 177, 174}, 1);
            assertTriple("ppm_pixel(p6, 200, 185)", Ppm.ppmPixel(p6, 200, 185), new int[] {209, 209, 205}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 3: the plate", () -> {
            Canvas c = Figures.plate03();
            byte[] ref = readReference("plate-03.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 640);
            assertEquals("c.height", c.height, 320);
            assertTriple("ppm_pixel(p6, 160, 160)", Ppm.ppmPixel(p6, 160, 160), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 480, 160)", Ppm.ppmPixel(p6, 480, 160), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 10, 10)", Ppm.ppmPixel(p6, 10, 10), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 200, 183)", Ppm.ppmPixel(p6, 200, 183), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 200, 185)", Ppm.ppmPixel(p6, 200, 185), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 520, 183)", Ppm.ppmPixel(p6, 520, 183), new int[] {163, 163, 161}, 1);
            assertTriple("ppm_pixel(p6, 520, 185)", Ppm.ppmPixel(p6, 520, 185), new int[] {199, 199, 196}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(Path.of("reference/chapter-03", filename));
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
        writeOne("fan-coverage.ppm", Figures.fanCoverage());
        writeOne("plate-03.ppm", Figures.plate03());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
