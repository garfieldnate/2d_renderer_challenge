import java.io.IOException;
import java.nio.file.Files;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter15-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-15/*.ppm resolves.
 */
public final class Chapter15Tests {

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

    private static void assertLe(String what, double actual, double bound) {
        if (!(actual <= bound)) {
            throw new AssertionError(what + ": expected <= " + bound + " but got " + actual);
        }
    }

    private static void assertTupleEq(String what, Tuple actual, Tuple expected) {
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertTupleEq(String what, Tuple actual, Tuple expected, double eps) {
        if (!(Numbers.approxEqual(actual.x, expected.x, eps) && Numbers.approxEqual(actual.y, expected.y, eps))) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual
                    + " (tolerance " + eps + ")");
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
        registerLength();
        registerPattern();
        registerDash();
        registerClosed();
        registerPlate();
    }

    // features/chapter15-length.feature
    private static void registerLength() {
        scenario("Length: the length of a path sums its segments, and a closed subpath includes the closing one", () -> {
            Path open = new Path();
            open.moveTo(Tuple.point(0, 0));
            open.lineTo(Tuple.point(3, 4));
            open.lineTo(Tuple.point(3, 0));
            assertDoubleEq("path_length(open)", Length.pathLength(open), 9);
            Path square = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(10, 10), Tuple.point(0, 10));
            assertDoubleEq("path_length(polygon(...))", Length.pathLength(square), 40);
        });

        scenario("Length: the arc-length table is the running length of chords", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            double[] table = Length.arcLengthTable(c, 4);
            assertEquals("length(table)", table.length, 5);
            assertDoubleEq("table[0]", table[0], 0);
            assertDoubleEq("table[1]", table[1], 2.335193);
            assertDoubleEq("table[2]", table[2], 3.901438);
            assertDoubleEq("table[4]", table[4], 7.802876);
        });

        scenario("Length: more chords creep up on the true length", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            Curve line = Curve.cubic(Tuple.point(0, 0), Tuple.point(1, 1), Tuple.point(2, 2), Tuple.point(3, 3));
            assertDoubleEq("arc_length(c, 4)", Length.arcLength(c, 4), 7.802876);
            assertDoubleEq("arc_length(c, 16)", Length.arcLength(c, 16), 7.987725);
            assertDoubleEq("arc_length(c, 256)", Length.arcLength(c, 256), 7.999952);
            assertDoubleEq("arc_length(line, 256)", Length.arcLength(line, 256), 4.242641);
        });

        scenario("Length: the parameter at a length, by interpolation", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            double[] table = Length.arcLengthTable(c, 256);
            double total = Length.arcLength(c, 256);
            assertDoubleEq("t_at_length(table, 0)", Length.tAtLength(table, 0), 0);
            assertDoubleEq("t_at_length(table, total / 2)", Length.tAtLength(table, total / 2), 0.5);
            assertDoubleEq("t_at_length(table, total / 4)", Length.tAtLength(table, total / 4), 0.201966);
            assertDoubleEq("t_at_length(table, total + 1)", Length.tAtLength(table, total + 1), 1);
            assertDoubleEq("t_at_length(table, -1)", Length.tAtLength(table, -1), 0);
        });

        scenario("Length: a point and a split at a given length", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            double total = Length.arcLength(c, 256);
            Curve[] split = Length.splitAtLength(c, 2, 256);
            Curve left = split[0];
            Curve right = split[1];
            assertTupleEq("point_at_length(c, total / 2, 256)", Length.pointAtLength(c, total / 2, 256), Tuple.point(2, 3));
            assertTupleEq("point_at_length(c, total / 4, 256)",
                    Length.pointAtLength(c, total / 4, 256), Tuple.point(0.423579, 1.93411), 0.0001);
            assertDoubleEq("arc_length(left, 256)", Length.arcLength(left, 256), 2, 0.001);
            assertDoubleEq("arc_length(right, 256)", Length.arcLength(right, 256), 6, 0.001);
            assertTupleEq("point_at(left, 1)", Curves.pointAt(left, 1), Curves.pointAt(right, 0));
        });

        scenario("Length: the parameter is not the length", () -> {
            Curve c = Figures.lopsided();
            double total = Length.arcLength(c, 256);
            assertDoubleEq("total", total, 198.0971, 0.001);
            assertTupleEq("point_at(c, 0.5)", Curves.pointAt(c, 0.5), Tuple.point(71.875, 58.125));
            assertTupleEq("point_at_length(c, total / 2, 256)",
                    Length.pointAtLength(c, total / 2, 256), Tuple.point(98.7142, 52.9628), 0.001);
            assertDoubleEq("t_at_length(arc_length_table(c, 256), total / 2)",
                    Length.tAtLength(Length.arcLengthTable(c, 256), total / 2), 0.635558, 0.0001);
        });
    }

    // features/chapter15-pattern.feature
    private static void registerPattern() {
        scenario("Pattern: an odd pattern is repeated so on and off alternate the same way each cycle", () -> {
            assertTrue("normalize_pattern([5]) = [5, 5]",
                    Arrays.equals(Dash.normalizePattern(new double[] {5}), new double[] {5, 5}));
            assertTrue("normalize_pattern([5, 2, 1]) = [5, 2, 1, 5, 2, 1]",
                    Arrays.equals(Dash.normalizePattern(new double[] {5, 2, 1}), new double[] {5, 2, 1, 5, 2, 1}));
            assertTrue("normalize_pattern([4, 2]) = [4, 2]",
                    Arrays.equals(Dash.normalizePattern(new double[] {4, 2}), new double[] {4, 2}));
        });

        scenario("Pattern: a pattern that adds up to nothing, or has a negative entry, is no pattern", () -> {
            Path seg = new Path();
            seg.moveTo(Tuple.point(0, 0));
            seg.lineTo(Tuple.point(100, 0));
            assertTrue("normalize_pattern([0, 0]) = []", Dash.normalizePattern(new double[] {0, 0}).length == 0);
            assertTrue("normalize_pattern([]) = []", Dash.normalizePattern(new double[0]).length == 0);
            assertTrue("normalize_pattern([5, -5]) = []", Dash.normalizePattern(new double[] {5, -5}).length == 0);
            assertTrue("normalize_pattern([6, -2]) = []", Dash.normalizePattern(new double[] {6, -2}).length == 0);
            Path d1 = Dash.dash(seg, new double[] {0, 0}, 0);
            assertEquals("length(subpaths(dash(seg, [0, 0], 0)))", d1.subpaths().size(), 1);
            assertTupleEq("subpaths(dash(seg, [0, 0], 0))[0].points[1]", d1.subpaths().get(0).points.get(1), Tuple.point(100, 0));
            assertEquals("length(subpaths(dash(seg, [], 0)))", Dash.dash(seg, new double[0], 0).subpaths().size(), 1);
            assertEquals("length(subpaths(dash(seg, [6, -2], 0)))",
                    Dash.dash(seg, new double[] {6, -2}, 0).subpaths().size(), 1);
        });

        scenario("Pattern: a repeated odd pattern walks as its doubled self", () -> {
            Path seg = new Path();
            seg.moveTo(Tuple.point(0, 0));
            seg.lineTo(Tuple.point(30, 0));
            Path d = Dash.dash(seg, new double[] {5, 2, 1}, 0);
            assertEquals("length(subpaths(d))", d.subpaths().size(), 6);
            assertTupleEq("subpaths(d)[0].points[1]", d.subpaths().get(0).points.get(1), Tuple.point(5, 0));
            assertTupleEq("subpaths(d)[1].points[0]", d.subpaths().get(1).points.get(0), Tuple.point(7, 0));
            assertTupleEq("subpaths(d)[1].points[1]", d.subpaths().get(1).points.get(1), Tuple.point(8, 0));
            assertTupleEq("subpaths(d)[2].points[0]", d.subpaths().get(2).points.get(0), Tuple.point(13, 0));
            assertTupleEq("subpaths(d)[3].points[0]", d.subpaths().get(3).points.get(0), Tuple.point(16, 0));
            assertTupleEq("subpaths(d)[3].points[1]", d.subpaths().get(3).points.get(1), Tuple.point(21, 0));
        });

        scenario("Pattern: a zero-length dash is a point, and with a round cap a dot", () -> {
            Path seg = new Path();
            seg.moveTo(Tuple.point(0, 0));
            seg.lineTo(Tuple.point(12, 0));
            Path d = Dash.dash(seg, new double[] {0, 6}, 0);
            assertEquals("length(subpaths(d))", d.subpaths().size(), 2);
            assertEquals("length(subpaths(d)[0].points)", d.subpaths().get(0).points.size(), 1);
            assertTupleEq("subpaths(d)[0].points[0]", d.subpaths().get(0).points.get(0), Tuple.point(0, 0));
            assertTupleEq("subpaths(d)[1].points[0]", d.subpaths().get(1).points.get(0), Tuple.point(6, 0));
            Path roundStroke = Stroke.strokeToPath(d, 4, "round", "round", 4.0);
            assertEquals("length(subpaths(stroke_to_path(d, 4, \"round\", \"round\", 4.0)))", roundStroke.subpaths().size(), 2);
            Bounds b = roundStroke.bounds();
            assertDoubleEq("bounds.minX", b.minX(), -2);
            assertDoubleEq("bounds.minY", b.minY(), -2);
            assertDoubleEq("bounds.maxX", b.maxX(), 8);
            assertDoubleEq("bounds.maxY", b.maxY(), 2);
            Path buttStroke = Stroke.strokeToPath(d, 4, "butt", "round", 4.0);
            assertEquals("length(subpaths(stroke_to_path(d, 4, \"butt\", \"round\", 4.0)))", buttStroke.subpaths().size(), 0);
        });
    }

    // features/chapter15-dash.feature
    private static void registerDash() {
        scenario("Dash: dashes on a straight line land at exact multiples", () -> {
            Path seg = new Path();
            seg.moveTo(Tuple.point(0, 0));
            seg.lineTo(Tuple.point(100, 0));
            Path d = Dash.dash(seg, new double[] {10, 5}, 0);
            assertEquals("length(subpaths(d))", d.subpaths().size(), 7);
            assertTupleEq("subpaths(d)[0].points[0]", d.subpaths().get(0).points.get(0), Tuple.point(0, 0));
            assertTupleEq("subpaths(d)[0].points[1]", d.subpaths().get(0).points.get(1), Tuple.point(10, 0));
            assertTupleEq("subpaths(d)[1].points[0]", d.subpaths().get(1).points.get(0), Tuple.point(15, 0));
            assertTupleEq("subpaths(d)[1].points[1]", d.subpaths().get(1).points.get(1), Tuple.point(25, 0));
            assertTupleEq("subpaths(d)[6].points[0]", d.subpaths().get(6).points.get(0), Tuple.point(90, 0));
            assertTupleEq("subpaths(d)[6].points[1]", d.subpaths().get(6).points.get(1), Tuple.point(100, 0));
            assertTrue("subpaths(d)[6].closed = false", !d.subpaths().get(6).closed);
        });

        scenario("Dash: the dashes and the gaps add up to the path", () -> {
            Path seg = new Path();
            seg.moveTo(Tuple.point(0, 0));
            seg.lineTo(Tuple.point(100, 0));
            Path d = Dash.dash(seg, new double[] {10, 5}, 0);
            assertDoubleEq("path_length(d)", Length.pathLength(d), 70);
            assertDoubleEq("path_length(seg) - path_length(d)", Length.pathLength(seg) - Length.pathLength(d), 30);
        });

        scenario("Dash: the phase starts the walk partway into the pattern", () -> {
            Path seg = new Path();
            seg.moveTo(Tuple.point(0, 0));
            seg.lineTo(Tuple.point(100, 0));
            Path d = Dash.dash(seg, new double[] {10, 5}, 3);
            assertEquals("length(subpaths(d))", d.subpaths().size(), 7);
            assertTupleEq("subpaths(d)[0].points[0]", d.subpaths().get(0).points.get(0), Tuple.point(0, 0));
            assertTupleEq("subpaths(d)[0].points[1]", d.subpaths().get(0).points.get(1), Tuple.point(7, 0));
            assertTupleEq("subpaths(d)[1].points[0]", d.subpaths().get(1).points.get(0), Tuple.point(12, 0));
            assertTupleEq("subpaths(d)[6].points[1]", d.subpaths().get(6).points.get(1), Tuple.point(97, 0));
        });

        scenario("Dash: a phase into a gap starts with a gap", () -> {
            Path seg = new Path();
            seg.moveTo(Tuple.point(0, 0));
            seg.lineTo(Tuple.point(100, 0));
            Path d = Dash.dash(seg, new double[] {10, 5}, 12);
            assertEquals("length(subpaths(d))", d.subpaths().size(), 7);
            assertTupleEq("subpaths(d)[0].points[0]", d.subpaths().get(0).points.get(0), Tuple.point(3, 0));
            assertTupleEq("subpaths(d)[0].points[1]", d.subpaths().get(0).points.get(1), Tuple.point(13, 0));
            assertTupleEq("subpaths(d)[6].points[0]", d.subpaths().get(6).points.get(0), Tuple.point(93, 0));
            assertTupleEq("subpaths(d)[6].points[1]", d.subpaths().get(6).points.get(1), Tuple.point(100, 0));
        });

        scenario("Dash: a phase of the pattern's sum is no phase, and a negative phase wraps", () -> {
            Path seg = new Path();
            seg.moveTo(Tuple.point(0, 0));
            seg.lineTo(Tuple.point(100, 0));
            Path d15 = Dash.dash(seg, new double[] {10, 5}, 15);
            assertTupleEq("subpaths(dash(seg, [10, 5], 15))[0].points[1]", d15.subpaths().get(0).points.get(1), Tuple.point(10, 0));
            assertTupleEq("subpaths(dash(seg, [10, 5], 15))[1].points[0]", d15.subpaths().get(1).points.get(0), Tuple.point(15, 0));
            Path dNeg = Dash.dash(seg, new double[] {10, 5}, -3);
            assertTupleEq("subpaths(dash(seg, [10, 5], -3))[0].points[0]", dNeg.subpaths().get(0).points.get(0), Tuple.point(3, 0));
            assertTupleEq("subpaths(dash(seg, [10, 5], -3))[0].points[1]", dNeg.subpaths().get(0).points.get(1), Tuple.point(13, 0));
        });

        scenario("Dash: a dash that reaches a corner turns it", () -> {
            Path bend = new Path();
            bend.moveTo(Tuple.point(0, 0));
            bend.lineTo(Tuple.point(10, 0));
            bend.lineTo(Tuple.point(10, 10));
            Path d = Dash.dash(bend, new double[] {12, 4}, 0);
            assertEquals("length(subpaths(d))", d.subpaths().size(), 2);
            assertEquals("length(subpaths(d)[0].points)", d.subpaths().get(0).points.size(), 3);
            assertTupleEq("subpaths(d)[0].points[1]", d.subpaths().get(0).points.get(1), Tuple.point(10, 0));
            assertTupleEq("subpaths(d)[0].points[2]", d.subpaths().get(0).points.get(2), Tuple.point(10, 2));
            assertTupleEq("subpaths(d)[1].points[0]", d.subpaths().get(1).points.get(0), Tuple.point(10, 6));
            assertTupleEq("subpaths(d)[1].points[1]", d.subpaths().get(1).points.get(1), Tuple.point(10, 10));
        });

        scenario("Dash: a gap that reaches a corner turns it too", () -> {
            Path bend = new Path();
            bend.moveTo(Tuple.point(0, 0));
            bend.lineTo(Tuple.point(10, 0));
            bend.lineTo(Tuple.point(10, 10));
            Path d = Dash.dash(bend, new double[] {8, 4}, 0);
            assertEquals("length(subpaths(d))", d.subpaths().size(), 2);
            assertTupleEq("subpaths(d)[0].points[1]", d.subpaths().get(0).points.get(1), Tuple.point(8, 0));
            assertTupleEq("subpaths(d)[1].points[0]", d.subpaths().get(1).points.get(0), Tuple.point(10, 2));
        });

        scenario("Dash: duplicate points do not stall the walk", () -> {
            Path seg = new Path();
            seg.moveTo(Tuple.point(0, 0));
            seg.lineTo(Tuple.point(0, 0));
            seg.lineTo(Tuple.point(10, 0));
            Path d = Dash.dash(seg, new double[] {4, 2}, 0);
            assertEquals("length(subpaths(d))", d.subpaths().size(), 2);
            assertTupleEq("subpaths(d)[0].points[1]", d.subpaths().get(0).points.get(1), Tuple.point(4, 0));
            assertTupleEq("subpaths(d)[1].points[0]", d.subpaths().get(1).points.get(0), Tuple.point(6, 0));
        });
    }

    // features/chapter15-closed.feature
    private static void registerClosed() {
        scenario("Closed: each subpath starts the pattern over", () -> {
            Path two = new Path();
            two.moveTo(Tuple.point(0, 0));
            two.lineTo(Tuple.point(7, 0));
            two.moveTo(Tuple.point(0, 10));
            two.lineTo(Tuple.point(20, 10));
            Path d = Dash.dash(two, new double[] {6, 4}, 0);
            assertEquals("length(subpaths(d))", d.subpaths().size(), 3);
            assertTupleEq("subpaths(d)[0].points[1]", d.subpaths().get(0).points.get(1), Tuple.point(6, 0));
            assertTupleEq("subpaths(d)[1].points[0]", d.subpaths().get(1).points.get(0), Tuple.point(0, 10));
            assertTupleEq("subpaths(d)[1].points[1]", d.subpaths().get(1).points.get(1), Tuple.point(6, 10));
            assertTupleEq("subpaths(d)[2].points[0]", d.subpaths().get(2).points.get(0), Tuple.point(10, 10));
            assertTupleEq("subpaths(d)[2].points[1]", d.subpaths().get(2).points.get(1), Tuple.point(16, 10));
        });

        scenario("Closed: a closed subpath is walked around its closing segment", () -> {
            Path square = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(10, 10), Tuple.point(0, 10));
            Path d = Dash.dash(square, new double[] {6, 4}, 0);
            assertEquals("length(subpaths(d))", d.subpaths().size(), 4);
            assertTupleEq("subpaths(d)[3].points[0]", d.subpaths().get(3).points.get(0), Tuple.point(0, 10));
            assertTupleEq("subpaths(d)[3].points[1]", d.subpaths().get(3).points.get(1), Tuple.point(0, 4));
            assertTrue("subpaths(d)[3].closed = false", !d.subpaths().get(3).closed);
        });

        scenario("Closed: a last dash that runs into the first is joined to it", () -> {
            Path square = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(10, 10), Tuple.point(0, 10));
            Path d = Dash.dash(square, new double[] {4, 2}, 0);
            assertEquals("length(subpaths(d))", d.subpaths().size(), 6);
            assertTupleEq("subpaths(d)[0].points[0]", d.subpaths().get(0).points.get(0), Tuple.point(6, 0));
            assertTupleEq("subpaths(d)[0].points[1]", d.subpaths().get(0).points.get(1), Tuple.point(10, 0));
            assertEquals("length(subpaths(d)[5].points)", d.subpaths().get(5).points.size(), 3);
            assertTupleEq("subpaths(d)[5].points[0]", d.subpaths().get(5).points.get(0), Tuple.point(0, 4));
            assertTupleEq("subpaths(d)[5].points[1]", d.subpaths().get(5).points.get(1), Tuple.point(0, 0));
            assertTupleEq("subpaths(d)[5].points[2]", d.subpaths().get(5).points.get(2), Tuple.point(4, 0));
            assertDoubleEq("path_length(d)", Length.pathLength(d), 28);
        });

        scenario("Closed: a dash that covers the whole loop is the loop, closed", () -> {
            Path square = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(10, 10), Tuple.point(0, 10));
            Path d = Dash.dash(square, new double[] {100, 1}, 0);
            assertEquals("length(subpaths(d))", d.subpaths().size(), 1);
            assertTrue("subpaths(d)[0].closed = true", d.subpaths().get(0).closed);
            assertEquals("length(subpaths(d)[0].points)", d.subpaths().get(0).points.size(), 4);
            assertDoubleEq("path_length(d)", Length.pathLength(d), 40);
        });

        scenario("Closed: a pattern that ends on a gap at the start leaves the corner alone", () -> {
            Path square = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(10, 10), Tuple.point(0, 10));
            Path d = Dash.dash(square, new double[] {10, 10}, 0);
            assertEquals("length(subpaths(d))", d.subpaths().size(), 2);
            assertTupleEq("subpaths(d)[0].points[0]", d.subpaths().get(0).points.get(0), Tuple.point(0, 0));
            assertTupleEq("subpaths(d)[1].points[1]", d.subpaths().get(1).points.get(1), Tuple.point(0, 10));
        });
    }

    // features/chapter15-plate.feature
    private static void registerPlate() {
        scenario("Plate 15: marks by parameter and by length", () -> {
            Canvas c = Figures.evenMarks();
            byte[] ref = readReference("even-marks.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 400);
            assertEquals("c.height", c.height, 120);
            assertTriple("ppm_pixel(p6, 71, 58)", Ppm.ppmPixel(p6, 71, 58), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 298, 52)", Ppm.ppmPixel(p6, 298, 52), new int[] {124, 196, 237}, 1);
            assertTriple("ppm_pixel(p6, 100, 100)", Ppm.ppmPixel(p6, 100, 100), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 15: the strip", () -> {
            Canvas c = Figures.dashStrip();
            byte[] ref = readReference("dash-strip.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 160);
            assertTriple("ppm_pixel(p6, 160, 20)", Ppm.ppmPixel(p6, 160, 20), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 20, 140)", Ppm.ppmPixel(p6, 20, 140), new int[] {237, 137, 149}, 1);
            assertTriple("ppm_pixel(p6, 24, 140)", Ppm.ppmPixel(p6, 24, 140), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 15: the spiral is one subpath, and it dashes into seventeen", () -> {
            Path sp = Figures.goldenSpiral();
            assertEquals("length(subpaths(sp))", sp.subpaths().size(), 1);
            assertDoubleEq("path_length(sp)", Length.pathLength(sp), 427.493, 0.01);
            assertEquals("dash_count(sp, [16, 10], 0)", Dash.dashCount(sp, new double[] {16, 10}, 0), 17);
            Path d = Dash.dash(sp, new double[] {16, 10}, 0);
            assertTupleEq("subpaths(dash(sp, [16, 10], 0))[0].points[0]", d.subpaths().get(0).points.get(0), Tuple.point(142, 130));
            assertDoubleEq("path_length(dash(sp, [16, 10], 0))", Length.pathLength(d), 267.493, 0.01);
        });

        scenario("Plate 15: the spiral, dashed", () -> {
            Canvas c = Figures.spiralDashes();
            byte[] ref = readReference("spiral-dashes.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 340);
            assertEquals("c.height", c.height, 340);
            assertTriple("ppm_pixel(p6, 142, 130)", Ppm.ppmPixel(p6, 142, 130), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 157, 138)", Ppm.ppmPixel(p6, 157, 138), new int[] {124, 196, 237}, 1);
            assertTriple("ppm_pixel(p6, 20, 20)", Ppm.ppmPixel(p6, 20, 20), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 15: Plate 15", () -> {
            Canvas c = Figures.plate15();
            byte[] ref = readReference("plate-15.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 680);
            assertEquals("c.height", c.height, 680);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    // ---- helpers -------------------------------------------------------

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference", "chapter-15", filename));
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
        writeOne("even-marks.ppm", Figures.evenMarks());
        writeOne("dash-strip.ppm", Figures.dashStrip());
        writeOne("spiral-dashes.ppm", Figures.spiralDashes());
        writeOne("plate-15.ppm", Figures.plate15());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
