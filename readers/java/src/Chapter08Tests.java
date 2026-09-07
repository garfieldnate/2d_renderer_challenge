import java.io.IOException;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter08-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-08/*.ppm resolves.
 */
public final class Chapter08Tests {

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

    private static void assertTupleEq(String what, Tuple actual, Tuple expected) {
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

    private static void assertBoundsEq(String what, Bounds actual, Bounds expected) {
        if (!Numbers.approxEqual(actual.minX(), expected.minX())
                || !Numbers.approxEqual(actual.minY(), expected.minY())
                || !Numbers.approxEqual(actual.maxX(), expected.maxX())
                || !Numbers.approxEqual(actual.maxY(), expected.maxY())) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerCurves();
        registerBounds();
        registerFlatten();
        registerArc();
        registerPlate();
    }

    // features/chapter08-curves.feature
    private static void registerCurves() {
        scenario("Curves: a quadratic evaluated along its length", () -> {
            Curve q = Curve.quadratic(Tuple.point(0, 0), Tuple.point(2, 4), Tuple.point(4, 0));
            assertTupleEq("point_at(q, 0)", Curves.pointAt(q, 0), Tuple.point(0, 0));
            assertTupleEq("point_at(q, 1)", Curves.pointAt(q, 1), Tuple.point(4, 0));
            assertTupleEq("point_at(q, 0.5)", Curves.pointAt(q, 0.5), Tuple.point(2, 2));
            assertTupleEq("point_at(q, 0.25)", Curves.pointAt(q, 0.25), Tuple.point(1, 1.5));
        });

        scenario("Curves: a cubic evaluated at its middle", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            assertTupleEq("point_at(c, 0.5)", Curves.pointAt(c, 0.5), Tuple.point(2, 3));
            assertTupleEq("point_at(c, 0.25)", Curves.pointAt(c, 0.25), Tuple.point(0.625, 2.25));
        });

        scenario("Curves: the derivative is the tangent, and it can point backward", () -> {
            Curve q = Curve.quadratic(Tuple.point(0, 0), Tuple.point(2, 4), Tuple.point(4, 0));
            assertTupleEq("derivative(q, 0)", Curves.derivative(q, 0), Tuple.vector(4, 8));
            assertTupleEq("derivative(q, 0.5)", Curves.derivative(q, 0.5), Tuple.vector(4, 0));
            assertTupleEq("derivative(q, 1)", Curves.derivative(q, 1), Tuple.vector(4, -8));
        });

        scenario("Curves: splitting and rejoining reproduces the curve", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            Curve[] split = Curves.splitAt(c, 0.25);
            Curve left = split[0];
            Curve right = split[1];
            assertTupleEq("point_at(left, 1) = point_at(c, 0.25)", Curves.pointAt(left, 1), Curves.pointAt(c, 0.25));
            assertTupleEq("point_at(right, 0) = point_at(c, 0.25)", Curves.pointAt(right, 0), Curves.pointAt(c, 0.25));
            assertTupleEq("point_at(left, 0.4) = point_at(c, 0.1)", Curves.pointAt(left, 0.4), Curves.pointAt(c, 0.1));
            assertTupleEq("point_at(right, 0.4) = point_at(c, 0.55)", Curves.pointAt(right, 0.4), Curves.pointAt(c, 0.55));
            assertTupleEq("point_at(right, 1)", Curves.pointAt(right, 1), Tuple.point(4, 0));
        });

        scenario("Curves: a curve taken through a matrix", () -> {
            Curve q = Curve.quadratic(Tuple.point(0, 0), Tuple.point(2, 4), Tuple.point(4, 0));
            Curve t = Curves.transformCurve(q, Transforms.translation(10, 20));
            assertTupleEq("point_at(t, 0)", Curves.pointAt(t, 0), Tuple.point(10, 20));
            assertTupleEq("point_at(t, 0.5)", Curves.pointAt(t, 0.5), Tuple.point(12, 22));
        });
    }

    // features/chapter08-bounds.feature
    private static void registerBounds() {
        scenario("Bounds: the curve stays well inside its control points", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(1, 3), Tuple.point(3, -2), Tuple.point(4, 1));
            assertBoundsEq("curve_bounds(c)", Curves.curveBounds(c), new Bounds(0, 0, 4, 1));
        });

        scenario("Bounds: an arch peaks below its control points", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            assertBoundsEq("curve_bounds(c)", Curves.curveBounds(c), new Bounds(0, 0, 4, 3));
        });

        scenario("Bounds: a quadratic's bounds come from its one turning point", () -> {
            Curve q = Curve.quadratic(Tuple.point(0, 0), Tuple.point(2, 4), Tuple.point(4, 0));
            assertBoundsEq("curve_bounds(q)", Curves.curveBounds(q), new Bounds(0, 0, 4, 2));
        });
    }

    // features/chapter08-flatten.feature
    private static void registerFlatten() {
        scenario("Flatten: flatness is the reach of the control points from the chord", () -> {
            Curve q = Curve.quadratic(Tuple.point(0, 0), Tuple.point(2, 4), Tuple.point(4, 0));
            assertDoubleEq("flatness(q)", Curves.flatness(q), 4);
            assertDoubleEq("flatness(cubic(...))",
                    Curves.flatness(Curve.cubic(Tuple.point(0, 0), Tuple.point(1, 1), Tuple.point(2, 2), Tuple.point(3, 3))),
                    0);
        });

        scenario("Flatten: a straight curve flattens to its two endpoints", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(1, 1), Tuple.point(2, 2), Tuple.point(3, 3));
            List<Tuple> pts = Curves.flatten(c, 0.01);
            assertEquals("length(pts)", pts.size(), 2);
            assertTupleEq("pts[0]", pts.get(0), Tuple.point(0, 0));
            assertTupleEq("pts[1]", pts.get(1), Tuple.point(3, 3));
        });

        scenario("Flatten: flattening always keeps both ends", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            List<Tuple> pts = Curves.flatten(c, 2.0);
            assertTupleEq("pts[0]", pts.get(0), Tuple.point(0, 0));
            assertTupleEq("pts[length(pts) - 1]", pts.get(pts.size() - 1), Tuple.point(4, 0));
        });

        scenario("Flatten: a tighter tolerance uses more points", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            assertEquals("length(flatten(c, 2.0))", Curves.flatten(c, 2.0).size(), 3);
            assertEquals("length(flatten(c, 0.1))", Curves.flatten(c, 0.1).size(), 9);
        });

        scenario("Flatten: the flattened length converges to the arc length", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            assertDoubleEq("flatten_length(c, 2.0)", Curves.flattenLength(c, 2.0), 7.2111, 0.001);
            assertDoubleEq("flatten_length(c, 0.1)", Curves.flattenLength(c, 0.1), 7.9509, 0.001);
            assertDoubleEq("flatten_length(c, 0.001)", Curves.flattenLength(c, 0.001), 7.9992, 0.001);
        });
    }

    // features/chapter08-arc.feature
    private static void registerArc() {
        scenario("Arc: the two flags choose among four arcs between the same endpoints", () -> {
            Arc a = Arc.arc(0, 0, 5, 5, 0, false, false, 6, 0);
            assertTupleEq("arc_point(a, 0.5)", Arc.arcPoint(a, 0.5), Tuple.point(3, 1));
            Arc b = Arc.arc(0, 0, 5, 5, 0, false, true, 6, 0);
            assertTupleEq("arc_point(arc(...false,true...), 0.5)", Arc.arcPoint(b, 0.5), Tuple.point(3, -1));
            Arc c = Arc.arc(0, 0, 5, 5, 0, true, false, 6, 0);
            assertTupleEq("arc_point(arc(...true,false...), 0.5)", Arc.arcPoint(c, 0.5), Tuple.point(3, 9));
            Arc d = Arc.arc(0, 0, 5, 5, 0, true, true, 6, 0);
            assertTupleEq("arc_point(arc(...true,true...), 0.5)", Arc.arcPoint(d, 0.5), Tuple.point(3, -9));
        });

        scenario("Arc: every one of the four still meets both endpoints", () -> {
            Arc a = Arc.arc(0, 0, 5, 5, 0, true, false, 6, 0);
            assertTupleEq("arc_point(a, 0)", Arc.arcPoint(a, 0), Tuple.point(0, 0));
            assertTupleEq("arc_point(a, 1)", Arc.arcPoint(a, 1), Tuple.point(6, 0));
        });

        scenario("Arc: radii too small to reach are grown until they do", () -> {
            Arc a = Arc.arc(0, 0, 0.5, 0.5, 0, false, true, 2, 0);
            assertEquals("a.corrected", a.corrected, true);
            assertDoubleEq("a.rx", a.rx, 1.0);
            assertDoubleEq("a.ry", a.ry, 1.0);
            assertTupleEq("arc_point(a, 0)", Arc.arcPoint(a, 0), Tuple.point(0, 0));
            assertTupleEq("arc_point(a, 1)", Arc.arcPoint(a, 1), Tuple.point(2, 0));
            assertTupleEq("arc_point(a, 0.5)", Arc.arcPoint(a, 0.5), Tuple.point(1, -1));
        });

        scenario("Arc: a rotated ellipse still lands on its endpoints", () -> {
            Arc a = Arc.arc(1, 1, 4, 2, Math.PI / 6, false, true, 7, 4);
            assertEquals("a.corrected", a.corrected, false);
            assertTupleEq("arc_point(a, 0)", Arc.arcPoint(a, 0), Tuple.point(1, 1));
            assertTupleEq("arc_point(a, 1)", Arc.arcPoint(a, 1), Tuple.point(7, 4));
            assertTupleEq("arc_point(a, 0.5)", Arc.arcPoint(a, 0.5), Tuple.point(4.268029, 1.595108));
        });

        scenario("Arc: a degenerate arc is no arc", () -> {
            assertTrue("arc(0, 0, 1, 1, 0, 0, 1, 0, 0) = none",
                    Arc.arc(0, 0, 1, 1, 0, false, true, 0, 0) == null);
            assertTrue("arc(0, 0, 0, 1, 0, 0, 1, 2, 0) = none",
                    Arc.arc(0, 0, 0, 1, 0, false, true, 2, 0) == null);
        });
    }

    // features/chapter08-plate.feature
    private static void registerPlate() {
        scenario("Plate 8: the teardrop, coarse against fine", () -> {
            Canvas c = Figures.drops();
            byte[] ref = readReference("drops.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 480);
            assertEquals("c.height", c.height, 240);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 8: the flowers", () -> {
            Canvas c = Figures.flower();
            byte[] ref = readReference("flower.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 360);
            assertEquals("c.height", c.height, 360);
            assertTriple("ppm_pixel(p6, 200, 105)", Ppm.ppmPixel(p6, 200, 105), new int[] {124, 196, 237}, 1);
            assertTriple("ppm_pixel(p6, 200, 145)", Ppm.ppmPixel(p6, 200, 145), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 108, 212)", Ppm.ppmPixel(p6, 108, 212), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 108, 250)", Ppm.ppmPixel(p6, 108, 250), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 286, 214)", Ppm.ppmPixel(p6, 286, 214), new int[] {237, 137, 149}, 1);
            assertTriple("ppm_pixel(p6, 10, 10)", Ppm.ppmPixel(p6, 10, 10), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 8: plate 8", () -> {
            Canvas c = Figures.plate08();
            byte[] ref = readReference("plate-08.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 720);
            assertEquals("c.height", c.height, 720);
            assertTriple("ppm_pixel(p6, 400, 210)", Ppm.ppmPixel(p6, 400, 210), new int[] {124, 196, 237}, 1);
            assertTriple("ppm_pixel(p6, 216, 424)", Ppm.ppmPixel(p6, 216, 424), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 572, 428)", Ppm.ppmPixel(p6, 572, 428), new int[] {237, 137, 149}, 1);
            assertTriple("ppm_pixel(p6, 20, 20)", Ppm.ppmPixel(p6, 20, 20), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference/chapter-08", filename));
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
        writeOne("drops.ppm", Figures.drops());
        writeOne("flower.ppm", Figures.flower());
        writeOne("plate-08.ppm", Figures.plate08());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
