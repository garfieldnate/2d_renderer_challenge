import java.io.IOException;
import java.nio.file.Files;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter13-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-13/*.ppm resolves.
 */
public final class Chapter13Tests {

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
        registerStroke();
        registerMiter();
        registerDegenerate();
        registerPlate();
    }

    // features/chapter13-stroke.feature
    private static void registerStroke() {
        scenario("Stroke: a stroked segment with butt caps is exactly a rectangle", () -> {
            Path seg = new Path();
            seg.moveTo(Tuple.point(0, 5));
            seg.lineTo(Tuple.point(10, 5));
            Path o = Stroke.strokeToPath(seg, 4, "butt", "miter", 4.0);
            assertEquals("length(subpaths(o))", o.subpaths().size(), 1);
            List<Tuple> pts = o.subpaths().get(0).points;
            assertTupleEq("subpaths(o)[0].points[0]", pts.get(0), Tuple.point(0, 7));
            assertTupleEq("subpaths(o)[0].points[1]", pts.get(1), Tuple.point(10, 7));
            assertTupleEq("subpaths(o)[0].points[2]", pts.get(2), Tuple.point(10, 3));
            assertTupleEq("subpaths(o)[0].points[3]", pts.get(3), Tuple.point(0, 3));
        });

        scenario("Stroke: the stroked segment fills the same pixels as the rectangle", () -> {
            Path seg = new Path();
            seg.moveTo(Tuple.point(0, 5));
            seg.lineTo(Tuple.point(10, 5));
            Path o = Stroke.strokeToPath(seg, 4, "butt", "miter", 4.0);
            Path rect = Paths.polygon(
                    Tuple.point(0, 3), Tuple.point(10, 3), Tuple.point(10, 7), Tuple.point(0, 7));
            assertDoubleEq("max_coverage_difference(fill_path(o, \"nonzero\", 12, 10), fill_path(rect, \"nonzero\", 12, 10))",
                    CoverageBuffer.maxCoverageDifference(
                            Fill.fillPath(o, "nonzero", 12, 10), Fill.fillPath(rect, "nonzero", 12, 10)), 0);
        });

        Object[][] chevronJoinTable = {
            {"miter", 4},
            {"bevel", 3},
            {"round", 13},
        };
        for (Object[] row : chevronJoinTable) {
            String join = (String) row[0];
            int points = (int) row[1];
            scenario("Stroke: a chevron's join is a different shape for each join style: join=" + join, () -> {
                Path o = Stroke.strokeToPath(Figures.chevron(), 26, "butt", join, 4.0);
                assertEquals("length(subpaths(o))", o.subpaths().size(), 3);
                assertEquals("length(subpaths(o)[2].points)", o.subpaths().get(2).points.size(), points);
            });
        }

        scenario("Stroke: the round join is an arc across the outer gap, not around the inside", () -> {
            Path o = Stroke.strokeToPath(Figures.chevron(), 26, "butt", "round", 4.0);
            List<Tuple> join = o.subpaths().get(2).points;
            assertTupleEq("subpaths(o)[2].points[0]", join.get(0), Tuple.point(80, 120));
            assertDoubleEq("subpaths(o)[2].points[6].x", join.get(6).x, 78.797, 0.01);
            assertDoubleEq("subpaths(o)[2].points[6].y", join.get(6).y, 132.944, 0.01);
            assertTrue("inside_nonzero(o, 80, 131) = true", Winding.insideNonzero(o, 80, 131));
            assertTrue("inside_nonzero(o, 80, 135) = false", !Winding.insideNonzero(o, 80, 135));
        });

        scenario("Stroke: the miter reaches its tip at the vertex plus the miter length", () -> {
            Path o = Stroke.strokeToPath(Figures.chevron(), 26, "butt", "miter", 4.0);
            List<Tuple> join = o.subpaths().get(2).points;
            assertTupleEq("subpaths(o)[2].points[0]", join.get(0), Tuple.point(80, 120));
            assertDoubleEq("subpaths(o)[2].points[2].x", join.get(2).x, 80, 0.01);
            assertDoubleEq("subpaths(o)[2].points[2].y", join.get(2).y, 144.528, 0.01);
        });

        scenario("Stroke: the join sits on the outer side of the turn", () -> {
            Path o = Stroke.strokeToPath(Figures.chevron(), 26, "butt", "bevel", 4.0);
            List<Tuple> join = o.subpaths().get(2).points;
            assertTupleEq("subpaths(o)[2].points[0]", join.get(0), Tuple.point(80, 120));
            assertDoubleEq("subpaths(o)[2].points[1].x", join.get(1).x, 68.976, 0.01);
            assertDoubleEq("subpaths(o)[2].points[1].y", join.get(1).y, 126.89, 0.01);
            assertDoubleEq("subpaths(o)[2].points[2].x", join.get(2).x, 91.024, 0.01);
            assertDoubleEq("subpaths(o)[2].points[2].y", join.get(2).y, 126.89, 0.01);
        });

        scenario("Stroke: every piece winds the same way, so overlapping pieces add instead of cancelling", () -> {
            Path hat = new Path();
            hat.moveTo(Tuple.point(30, 120));
            hat.lineTo(Tuple.point(80, 40));
            hat.lineTo(Tuple.point(130, 120));
            Path o = Stroke.strokeToPath(hat, 26, "butt", "bevel", 4.0);
            assertDoubleEq("polygon_area(o)", Fill.polygonArea(o), -4981.625, 0.01);
            assertDoubleEq("polygon_area(stroke_to_path(chevron(), 26, \"butt\", \"bevel\", 4.0))",
                    Fill.polygonArea(Stroke.strokeToPath(Figures.chevron(), 26, "butt", "bevel", 4.0)),
                    -4981.625, 0.01);
        });

        scenario("Stroke: a wide stroke around a tight bend overlaps itself and stays solid", () -> {
            Path o = Stroke.strokeToPath(Figures.uTurn(), 40, "butt", "round", 4.0);
            CoverageBuffer cov = Fill.fillPath(o, "nonzero", 100, 100);
            assertEquals("length(subpaths(o))", o.subpaths().size(), 15);
            assertDoubleEq("coverage_at(cov, 50, 37)", cov.coverageAt(50, 37), 1);
            assertDoubleEq("coverage_at(cov, 46, 22)", cov.coverageAt(46, 22), 1);
            assertDoubleEq("coverage_at(cov, 53, 22)", cov.coverageAt(53, 22), 1);
        });

        scenario("Stroke: a closed subpath strokes to segments and joins, with no caps", () -> {
            Path tri = new Path();
            tri.moveTo(Tuple.point(20, 20));
            tri.lineTo(Tuple.point(80, 20));
            tri.lineTo(Tuple.point(50, 70));
            tri.close();
            Path o = Stroke.strokeToPath(tri, 8, "butt", "miter", 4.0);
            assertEquals("length(subpaths(o))", o.subpaths().size(), 6);
        });
    }

    // features/chapter13-miter.feature
    private static void registerMiter() {
        scenario("Miter: the miter length matches the closed form", () -> {
            assertDoubleEq("miter_length(vector(1, 0), vector(0, 1), 2)",
                    Stroke.miterLength(Tuple.vector(1, 0), Tuple.vector(0, 1), 2), 2.828427, 0.0001);
            assertDoubleEq("miter_length(vector(1, 0), vector(0.5, 0.866025), 2)",
                    Stroke.miterLength(Tuple.vector(1, 0), Tuple.vector(0.5, 0.866025), 2), 2.309401, 0.0001);
        });

        scenario("Miter: the miter limit switches the join to a bevel past its threshold", () -> {
            Path sharp = Stroke.strokeToPath(Figures.chevron(), 26, "butt", "miter", 2.0);
            Path flat = Stroke.strokeToPath(Figures.chevron(), 26, "butt", "miter", 1.5);
            assertEquals("length(subpaths(sharp)[2].points)", sharp.subpaths().get(2).points.size(), 4);
            assertEquals("length(subpaths(flat)[2].points)", flat.subpaths().get(2).points.size(), 3);
        });
    }

    // features/chapter13-degenerate.feature
    private static void registerDegenerate() {
        scenario("Degenerate: duplicate consecutive points are dropped", () -> {
            Path seg = new Path();
            seg.moveTo(Tuple.point(0, 5));
            seg.lineTo(Tuple.point(0, 5));
            seg.lineTo(Tuple.point(10, 5));
            Path o = Stroke.strokeToPath(seg, 4, "butt", "miter", 4.0);
            assertEquals("length(subpaths(o))", o.subpaths().size(), 1);
            assertTupleEq("subpaths(o)[0].points[0]", o.subpaths().get(0).points.get(0), Tuple.point(0, 7));
        });

        scenario("Degenerate: a single point with a round cap is a dot", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(20, 20));
            Path o = Stroke.strokeToPath(p, 10, "round", "miter", 4.0);
            assertEquals("length(subpaths(o))", o.subpaths().size(), 1);
            Bounds b = o.bounds();
            assertDoubleEq("bounds(o).minX", b.minX(), 15);
            assertDoubleEq("bounds(o).minY", b.minY(), 15);
            assertDoubleEq("bounds(o).maxX", b.maxX(), 25);
            assertDoubleEq("bounds(o).maxY", b.maxY(), 25);
        });

        scenario("Degenerate: a single point with a butt cap draws nothing", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(20, 20));
            Path o = Stroke.strokeToPath(p, 10, "butt", "miter", 4.0);
            assertEquals("length(subpaths(o))", o.subpaths().size(), 0);
        });

        scenario("Degenerate: a square cap extends a half-width past the end", () -> {
            Path seg = new Path();
            seg.moveTo(Tuple.point(45, 40));
            seg.lineTo(Tuple.point(115, 40));
            Path o = Stroke.strokeToPath(seg, 30, "square", "miter", 4.0);
            assertEquals("length(subpaths(o))", o.subpaths().size(), 3);
            List<Tuple> capPts = o.subpaths().get(2).points;
            assertTupleEq("subpaths(o)[2].points[1]", capPts.get(1), Tuple.point(130, 55));
            assertTupleEq("subpaths(o)[2].points[2]", capPts.get(2), Tuple.point(130, 25));
        });

        scenario("Degenerate: a single point with a square cap is a square", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(20, 20));
            Path o = Stroke.strokeToPath(p, 10, "square", "miter", 4.0);
            assertEquals("length(subpaths(o))", o.subpaths().size(), 1);
            Bounds b = o.bounds();
            assertDoubleEq("bounds(o).minX", b.minX(), 15);
            assertDoubleEq("bounds(o).minY", b.minY(), 15);
            assertDoubleEq("bounds(o).maxX", b.maxX(), 25);
            assertDoubleEq("bounds(o).maxY", b.maxY(), 25);
        });
    }

    // features/chapter13-plate.feature
    private static void registerPlate() {
        scenario("Plate 13: the three joins", () -> {
            Canvas c = Figures.joinsPlate();
            byte[] ref = readReference("joins.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 480);
            assertEquals("c.height", c.height, 160);
            assertTriple("ppm_pixel(p6, 55, 80)", Ppm.ppmPixel(p6, 55, 80), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 80, 128)", Ppm.ppmPixel(p6, 80, 128), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 5, 150)", Ppm.ppmPixel(p6, 5, 150), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 13: Plate 13", () -> {
            Canvas c = Figures.plate13();
            byte[] ref = readReference("plate-13.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 960);
            assertEquals("c.height", c.height, 320);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 13: the three caps", () -> {
            Canvas c = Figures.capsDemo();
            byte[] ref = readReference("caps.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 480);
            assertEquals("c.height", c.height, 80);
            assertTriple("ppm_pixel(p6, 80, 40)", Ppm.ppmPixel(p6, 80, 40), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 240, 40)", Ppm.ppmPixel(p6, 240, 40), new int[] {206, 206, 212}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference/chapter-13", filename));
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
        writeOne("joins.ppm", Figures.joinsPlate());
        writeOne("plate-13.ppm", Figures.plate13());
        writeOne("caps.ppm", Figures.capsDemo());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
