import java.io.IOException;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter05-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-05/*.ppm resolves.
 */
public final class Chapter05Tests {

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
        registerPaths();
        registerWinding();
        registerRules();
        registerPlate();
    }

    // features/chapter05-paths.feature
    private static void registerPaths() {
        scenario("Paths: an empty path", () -> {
            Path p = new Path();
            assertEquals("length(subpaths(p))", p.subpaths().size(), 0);
            assertEquals("length(edges(p))", p.edges().size(), 0);
            assertBoundsEq("bounds(p)", p.bounds(), new Bounds(0, 0, 0, 0));
        });

        scenario("Paths: a triangle, closed", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(1, 1));
            p.lineTo(Tuple.point(9, 1));
            p.lineTo(Tuple.point(5, 8));
            p.close();
            assertEquals("length(subpaths(p))", p.subpaths().size(), 1);
            assertEquals("subpaths(p)[0].closed", p.subpaths().get(0).closed, true);
            assertEquals("length(subpaths(p)[0].points)", p.subpaths().get(0).points.size(), 3);
            assertTupleEq("subpaths(p)[0].points[2]", p.subpaths().get(0).points.get(2), Tuple.point(5, 8));
            assertEquals("length(edges(p))", p.edges().size(), 3);
            Edge e2 = p.edges().get(2);
            assertTupleEq("edges(p)[2].a", e2.a(), Tuple.point(5, 8));
            assertTupleEq("edges(p)[2].b", e2.b(), Tuple.point(1, 1));
            assertBoundsEq("bounds(p)", p.bounds(), new Bounds(1, 1, 9, 8));
        });

        scenario("Paths: a triangle left open still has three edges", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(1, 1));
            p.lineTo(Tuple.point(9, 1));
            p.lineTo(Tuple.point(5, 8));
            assertEquals("subpaths(p)[0].closed", p.subpaths().get(0).closed, false);
            assertEquals("length(edges(p))", p.edges().size(), 3);
            Edge e2 = p.edges().get(2);
            assertTupleEq("edges(p)[2].a", e2.a(), Tuple.point(5, 8));
            assertTupleEq("edges(p)[2].b", e2.b(), Tuple.point(1, 1));
        });

        scenario("Paths: move_to starts a second subpath", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(0, 0));
            p.lineTo(Tuple.point(10, 0));
            p.lineTo(Tuple.point(10, 10));
            p.lineTo(Tuple.point(0, 10));
            p.close();
            p.moveTo(Tuple.point(3, 3));
            p.lineTo(Tuple.point(3, 7));
            p.lineTo(Tuple.point(7, 7));
            p.lineTo(Tuple.point(7, 3));
            p.close();
            assertEquals("length(subpaths(p))", p.subpaths().size(), 2);
            assertTupleEq("subpaths(p)[1].points[0]", p.subpaths().get(1).points.get(0), Tuple.point(3, 3));
            assertEquals("length(edges(p))", p.edges().size(), 8);
            assertBoundsEq("bounds(p)", p.bounds(), new Bounds(0, 0, 10, 10));
        });

        scenario("Paths: line_to after a close starts a new subpath where the closed one began", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(1, 1));
            p.lineTo(Tuple.point(4, 1));
            p.lineTo(Tuple.point(4, 4));
            p.close();
            p.lineTo(Tuple.point(9, 9));
            assertEquals("length(subpaths(p))", p.subpaths().size(), 2);
            assertEquals("subpaths(p)[1].closed", p.subpaths().get(1).closed, false);
            assertEquals("length(subpaths(p)[1].points)", p.subpaths().get(1).points.size(), 2);
            assertTupleEq("subpaths(p)[1].points[0]", p.subpaths().get(1).points.get(0), Tuple.point(1, 1));
            assertTupleEq("subpaths(p)[1].points[1]", p.subpaths().get(1).points.get(1), Tuple.point(9, 9));
        });

        scenario("Paths: line_to with nothing to extend behaves as move_to", () -> {
            Path p = new Path();
            p.lineTo(Tuple.point(2, 3));
            assertEquals("length(subpaths(p))", p.subpaths().size(), 1);
            assertEquals("length(subpaths(p)[0].points)", p.subpaths().get(0).points.size(), 1);
            assertTupleEq("subpaths(p)[0].points[0]", p.subpaths().get(0).points.get(0), Tuple.point(2, 3));
        });

        scenario("Paths: a subpath of one point has no edges, and closing nothing does nothing", () -> {
            Path p = new Path();
            p.close();
            p.moveTo(Tuple.point(1, 1));
            p.moveTo(Tuple.point(2, 2));
            assertEquals("length(subpaths(p))", p.subpaths().size(), 2);
            assertEquals("length(edges(p))", p.edges().size(), 0);
            assertBoundsEq("bounds(p)", p.bounds(), new Bounds(1, 1, 2, 2));
        });

        scenario("Paths: a subpath of two points has two edges and encloses nothing", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(1, 1));
            p.lineTo(Tuple.point(9, 9));
            assertEquals("length(edges(p))", p.edges().size(), 2);
            assertEquals("winding_at(p, 3, 5)", Winding.windingAt(p, 3, 5), 0);
        });

        scenario("Paths: polygon is a closed subpath through its points", () -> {
            Path p = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(10, 10), Tuple.point(0, 10));
            assertEquals("length(subpaths(p))", p.subpaths().size(), 1);
            assertEquals("subpaths(p)[0].closed", p.subpaths().get(0).closed, true);
            assertEquals("length(edges(p))", p.edges().size(), 4);
        });

        scenario("Paths: circle_path is a polygon standing in for a circle", () -> {
            Path p = Paths.circlePath(10, 10, 5, 8);
            assertEquals("length(subpaths(p)[0].points)", p.subpaths().get(0).points.size(), 8);
            assertTupleEq("subpaths(p)[0].points[0]", p.subpaths().get(0).points.get(0), Tuple.point(15, 10));
            assertTupleEq("subpaths(p)[0].points[1]", p.subpaths().get(0).points.get(1),
                    Tuple.point(13.5355, 13.5355));
            assertTupleEq("subpaths(p)[0].points[2]", p.subpaths().get(0).points.get(2), Tuple.point(10, 15));
            assertBoundsEq("bounds(p)", p.bounds(), new Bounds(5, 5, 15, 15));
        });
    }

    // features/chapter05-winding.feature
    private static void registerWinding() {
        scenario("Winding: crossings from inside and outside a square", () -> {
            Path p = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(10, 10), Tuple.point(0, 10));
            assertEquals("crossings(p, 5, 5)", Winding.crossings(p, 5, 5), 1);
            assertEquals("crossings(p, 15, 5)", Winding.crossings(p, 15, 5), 0);
            assertEquals("crossings(p, -1, 5)", Winding.crossings(p, -1, 5), 2);
        });

        scenario("Winding: a clockwise square winds once", () -> {
            Path p = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(10, 10), Tuple.point(0, 10));
            assertEquals("winding_at(p, 5, 5)", Winding.windingAt(p, 5, 5), 1);
            assertEquals("winding_at(p, 15, 5)", Winding.windingAt(p, 15, 5), 0);
            assertEquals("winding_at(p, -1, 5)", Winding.windingAt(p, -1, 5), 0);
            assertEquals("winding_at(p, 5, -1)", Winding.windingAt(p, 5, -1), 0);
            assertEquals("winding_at(p, 5, 11)", Winding.windingAt(p, 5, 11), 0);
        });

        scenario("Winding: the same square the other way round winds minus once", () -> {
            Path p = Paths.polygon(Tuple.point(0, 0), Tuple.point(0, 10), Tuple.point(10, 10), Tuple.point(10, 0));
            assertEquals("winding_at(p, 5, 5)", Winding.windingAt(p, 5, 5), -1);
            assertEquals("crossings(p, 5, 5)", Winding.crossings(p, 5, 5), 1);
        });

        scenario("Winding: a ray through a vertex counts it once", () -> {
            Path p = Paths.polygon(Tuple.point(5, 0), Tuple.point(10, 5), Tuple.point(5, 10), Tuple.point(0, 5));
            assertEquals("crossings(p, 2, 5)", Winding.crossings(p, 2, 5), 1);
            assertEquals("winding_at(p, 2, 5)", Winding.windingAt(p, 2, 5), 1);
            assertEquals("crossings(p, -1, 5)", Winding.crossings(p, -1, 5), 2);
            assertEquals("winding_at(p, -1, 5)", Winding.windingAt(p, -1, 5), 0);
            assertEquals("winding_at(p, 12, 5)", Winding.windingAt(p, 12, 5), 0);
            assertEquals("winding_at(p, 5, 5)", Winding.windingAt(p, 5, 5), 1);
        });

        scenario("Winding: the boundary belongs to the top and the left", () -> {
            Path p = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(10, 10), Tuple.point(0, 10));
            assertEquals("winding_at(p, 5, 0)", Winding.windingAt(p, 5, 0), 1);
            assertEquals("winding_at(p, 0, 5)", Winding.windingAt(p, 0, 5), 1);
            assertEquals("winding_at(p, 0, 0)", Winding.windingAt(p, 0, 0), 1);
            assertEquals("winding_at(p, 5, 10)", Winding.windingAt(p, 5, 10), 0);
            assertEquals("winding_at(p, 10, 5)", Winding.windingAt(p, 10, 5), 0);
            assertEquals("winding_at(p, 10, 10)", Winding.windingAt(p, 10, 10), 0);
        });

        scenario("Winding: two rectangles that share an edge cover it once", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(0, 0));
            p.lineTo(Tuple.point(5, 0));
            p.lineTo(Tuple.point(5, 10));
            p.lineTo(Tuple.point(0, 10));
            p.close();
            p.moveTo(Tuple.point(5, 0));
            p.lineTo(Tuple.point(10, 0));
            p.lineTo(Tuple.point(10, 10));
            p.lineTo(Tuple.point(5, 10));
            p.close();
            assertEquals("winding_at(p, 2, 5)", Winding.windingAt(p, 2, 5), 1);
            assertEquals("winding_at(p, 5, 5)", Winding.windingAt(p, 5, 5), 1);
            assertEquals("winding_at(p, 8, 5)", Winding.windingAt(p, 8, 5), 1);
        });

        scenario("Winding: a diamond wound twice has winding number 2", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(5, 0));
            p.lineTo(Tuple.point(10, 5));
            p.lineTo(Tuple.point(5, 10));
            p.lineTo(Tuple.point(0, 5));
            p.lineTo(Tuple.point(5, 0));
            p.lineTo(Tuple.point(10, 5));
            p.lineTo(Tuple.point(5, 10));
            p.lineTo(Tuple.point(0, 5));
            p.close();
            assertEquals("length(edges(p))", p.edges().size(), 8);
            assertEquals("winding_at(p, 5, 5)", Winding.windingAt(p, 5, 5), 2);
            assertEquals("crossings(p, 5, 5)", Winding.crossings(p, 5, 5), 2);
            assertEquals("winding_at(p, 12, 5)", Winding.windingAt(p, 12, 5), 0);
        });

        scenario("Winding: the polygon circle", () -> {
            Path p = Paths.circlePath(10, 10, 5, 8);
            assertEquals("winding_at(p, 10, 10)", Winding.windingAt(p, 10, 10), 1);
            assertEquals("winding_at(p, 14.9, 10)", Winding.windingAt(p, 14.9, 10), 1);
            assertEquals("winding_at(p, 15, 10)", Winding.windingAt(p, 15, 10), 0);
            assertEquals("winding_at(p, 10, 5.1)", Winding.windingAt(p, 10, 5.1), 1);
            assertEquals("winding_at(p, 10, 4.9)", Winding.windingAt(p, 10, 4.9), 0);
        });

        scenario("Winding: the pentagram's center winds twice", () -> {
            Path p = Figures.star();
            assertEquals("winding_at(p, 80.5, 80.5)", Winding.windingAt(p, 80.5, 80.5), 2);
            assertEquals("crossings(p, 80.5, 80.5)", Winding.crossings(p, 80.5, 80.5), 2);
            assertEquals("winding_at(p, 80.5, 20)", Winding.windingAt(p, 80.5, 20), 1);
            assertEquals("winding_at(p, 30, 60)", Winding.windingAt(p, 30, 60), 1);
            assertEquals("crossings(p, 30, 60)", Winding.crossings(p, 30, 60), 3);
            assertEquals("winding_at(p, 80.5, 120)", Winding.windingAt(p, 80.5, 120), 0);
            assertEquals("crossings(p, 80.5, 120)", Winding.crossings(p, 80.5, 120), 2);
            assertEquals("winding_at(p, 10, 10)", Winding.windingAt(p, 10, 10), 0);
        });
    }

    // features/chapter05-rules.feature
    private static void registerRules() {
        scenario("Rules: a single loop is inside under both rules", () -> {
            Path p = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(10, 10), Tuple.point(0, 10));
            assertTrue("inside_nonzero(p, 5, 5)", Winding.insideNonzero(p, 5, 5));
            assertTrue("inside_evenodd(p, 5, 5)", Winding.insideEvenodd(p, 5, 5));
            assertTrue("!inside_nonzero(p, 15, 5)", !Winding.insideNonzero(p, 15, 5));
            assertTrue("!inside_evenodd(p, 15, 5)", !Winding.insideEvenodd(p, 15, 5));
        });

        scenario("Rules: an inner loop the other way round is a hole under both rules", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(0, 0));
            p.lineTo(Tuple.point(10, 0));
            p.lineTo(Tuple.point(10, 10));
            p.lineTo(Tuple.point(0, 10));
            p.close();
            p.moveTo(Tuple.point(3, 3));
            p.lineTo(Tuple.point(3, 7));
            p.lineTo(Tuple.point(7, 7));
            p.lineTo(Tuple.point(7, 3));
            p.close();
            assertEquals("winding_at(p, 5, 5)", Winding.windingAt(p, 5, 5), 0);
            assertEquals("winding_at(p, 1, 1)", Winding.windingAt(p, 1, 1), 1);
            assertTrue("!inside_nonzero(p, 5, 5)", !Winding.insideNonzero(p, 5, 5));
            assertTrue("!inside_evenodd(p, 5, 5)", !Winding.insideEvenodd(p, 5, 5));
            assertTrue("inside_nonzero(p, 1, 1)", Winding.insideNonzero(p, 1, 1));
        });

        scenario("Rules: an inner loop the same way round is a hole only under even-odd", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(0, 0));
            p.lineTo(Tuple.point(10, 0));
            p.lineTo(Tuple.point(10, 10));
            p.lineTo(Tuple.point(0, 10));
            p.close();
            p.moveTo(Tuple.point(3, 3));
            p.lineTo(Tuple.point(7, 3));
            p.lineTo(Tuple.point(7, 7));
            p.lineTo(Tuple.point(3, 7));
            p.close();
            assertEquals("winding_at(p, 5, 5)", Winding.windingAt(p, 5, 5), 2);
            assertTrue("inside_nonzero(p, 5, 5)", Winding.insideNonzero(p, 5, 5));
            assertTrue("!inside_evenodd(p, 5, 5)", !Winding.insideEvenodd(p, 5, 5));
        });

        scenario("Rules: a loop wound twice vanishes under even-odd", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(5, 0));
            p.lineTo(Tuple.point(10, 5));
            p.lineTo(Tuple.point(5, 10));
            p.lineTo(Tuple.point(0, 5));
            p.lineTo(Tuple.point(5, 0));
            p.lineTo(Tuple.point(10, 5));
            p.lineTo(Tuple.point(5, 10));
            p.lineTo(Tuple.point(0, 5));
            p.close();
            assertTrue("inside_nonzero(p, 5, 5)", Winding.insideNonzero(p, 5, 5));
            assertTrue("!inside_evenodd(p, 5, 5)", !Winding.insideEvenodd(p, 5, 5));
        });

        scenario("Rules: the pentagram's center is inside under nonzero and outside under even-odd", () -> {
            Path p = Figures.star();
            assertTrue("inside_nonzero(p, 80.5, 80.5)", Winding.insideNonzero(p, 80.5, 80.5));
            assertTrue("!inside_evenodd(p, 80.5, 80.5)", !Winding.insideEvenodd(p, 80.5, 80.5));
            assertTrue("inside_nonzero(p, 80.5, 20)", Winding.insideNonzero(p, 80.5, 20));
            assertTrue("inside_evenodd(p, 80.5, 20)", Winding.insideEvenodd(p, 80.5, 20));
            assertTrue("!inside_nonzero(p, 80.5, 120)", !Winding.insideNonzero(p, 80.5, 120));
            assertTrue("!inside_evenodd(p, 80.5, 120)", !Winding.insideEvenodd(p, 80.5, 120));
        });

        scenario("Rules: a filled path is a shape", () -> {
            Shape s = Paths.filled(Paths.polygon(
                    Tuple.point(2, 2), Tuple.point(6, 2), Tuple.point(6, 6), Tuple.point(2, 6)), "nonzero");
            CoverageBuffer cov = Rasterizer.rasterize(s, 8, 8);
            assertTrue("inside(s, 3, 3)", s.inside(3, 3));
            assertTrue("!inside(s, 7, 3)", !s.inside(7, 3));
            assertDoubleEq("coverage_at(cov, 3, 3)", cov.coverageAt(3, 3), 1);
            assertDoubleEq("coverage_at(cov, 1, 3)", cov.coverageAt(1, 3), 0);
            assertDoubleEq("coverage_at(cov, 6, 3)", cov.coverageAt(6, 3), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 16);
        });

        scenario("Rules: a filled path takes the rule seriously", () -> {
            Path p = Figures.star();
            Shape a = Paths.filled(p, "nonzero");
            Shape b = Paths.filled(p, "evenodd");
            CoverageBuffer ca = Rasterizer.rasterize(a, 160, 160);
            CoverageBuffer cb = Rasterizer.rasterize(b, 160, 160);
            assertDoubleEq("coverage_at(ca, 80, 80)", ca.coverageAt(80, 80), 1);
            assertDoubleEq("coverage_at(cb, 80, 80)", cb.coverageAt(80, 80), 0);
            assertDoubleEq("coverage_at(ca, 80, 20)", ca.coverageAt(80, 20), 1);
            assertDoubleEq("coverage_at(cb, 80, 20)", cb.coverageAt(80, 20), 1);
            assertDoubleEq("coverage_at(ca, 80, 10)", ca.coverageAt(80, 10), 0.0625);
            assertDoubleEq("coverage_at(cb, 80, 10)", cb.coverageAt(80, 10), 0.0625);
            assertDoubleEq("ink(ca)", ca.ink(), 5499.9375);
            assertDoubleEq("ink(cb)", cb.ink(), 3800.375);
        });

        scenario("Rules: rasterizing within the bounds gives the same coverage", () -> {
            Path p = Figures.star();
            Shape s = Paths.filled(p, "evenodd");
            CoverageBuffer full = Rasterizer.rasterize(s, 160, 160);
            CoverageBuffer within = Paths.rasterizeWithin(s, p.bounds(), 160, 160);
            assertDoubleEq("ink(within)", within.ink(), full.ink());
            assertDoubleEq("coverage_at(within, 80, 20)", within.coverageAt(80, 20), full.coverageAt(80, 20));
            assertDoubleEq("coverage_at(within, 13, 58)", within.coverageAt(13, 58), full.coverageAt(13, 58));
            assertDoubleEq("coverage_at(within, 10, 10)", within.coverageAt(10, 10), 0);
        });

        scenario("Rules: the box is inclusive of the pixels it touches, and clipped to the buffer", () -> {
            Shape s = Paths.filled(Paths.polygon(
                    Tuple.point(1.5, 1.5), Tuple.point(6.5, 1.5), Tuple.point(6.5, 6.5), Tuple.point(1.5, 6.5)),
                    "nonzero");
            CoverageBuffer cov = Paths.rasterizeWithin(s, new Bounds(1.5, 1.5, 6.5, 6.5), 8, 8);
            CoverageBuffer big = Paths.rasterizeWithin(s, new Bounds(-5, -5, 20, 20), 8, 8);
            assertDoubleEq("coverage_at(cov, 1, 1)", cov.coverageAt(1, 1), 0.25);
            assertDoubleEq("coverage_at(cov, 6, 6)", cov.coverageAt(6, 6), 0.25);
            assertDoubleEq("coverage_at(cov, 3, 3)", cov.coverageAt(3, 3), 1);
            assertDoubleEq("ink(cov)", cov.ink(), 25);
            assertDoubleEq("ink(big)", big.ink(), 25);
        });
    }

    // features/chapter05-plate.feature
    private static void registerPlate() {
        scenario("Plate 5: the pentagram", () -> {
            Path p = Figures.star();
            assertEquals("length(subpaths(p))", p.subpaths().size(), 1);
            assertEquals("length(edges(p))", p.edges().size(), 5);
            List<Tuple> pts = p.subpaths().get(0).points;
            assertTupleEq("subpaths(p)[0].points[0]", pts.get(0), Tuple.point(80.5, 10.5));
            assertTupleEq("subpaths(p)[0].points[1]", pts.get(1), Tuple.point(121.645, 137.1312));
            assertTupleEq("subpaths(p)[0].points[2]", pts.get(2), Tuple.point(13.926, 58.8688));
            assertTupleEq("subpaths(p)[0].points[3]", pts.get(3), Tuple.point(147.074, 58.8688));
            assertTupleEq("subpaths(p)[0].points[4]", pts.get(4), Tuple.point(39.355, 137.1312));
            assertBoundsEq("bounds(p)", p.bounds(), new Bounds(13.926, 10.5, 147.074, 137.1312));
        });

        scenario("Plate 5: the star by the center question", () -> {
            Canvas c = Figures.starCenters();
            byte[] ref = readReference("star-centers.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 160);
            assertTriple("ppm_pixel(p6, 80, 80)", Ppm.ppmPixel(p6, 80, 80), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 240, 80)", Ppm.ppmPixel(p6, 240, 80), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 80, 20)", Ppm.ppmPixel(p6, 80, 20), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 240, 20)", Ppm.ppmPixel(p6, 240, 20), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 30, 60)", Ppm.ppmPixel(p6, 30, 60), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 190, 60)", Ppm.ppmPixel(p6, 190, 60), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 80, 120)", Ppm.ppmPixel(p6, 80, 120), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 80, 10)", Ppm.ppmPixel(p6, 80, 10), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 10, 10)", Ppm.ppmPixel(p6, 10, 10), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 5: the star by coverage", () -> {
            Canvas c = Figures.starCoverage();
            byte[] ref = readReference("star-coverage.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 160);
            assertTriple("ppm_pixel(p6, 80, 80)", Ppm.ppmPixel(p6, 80, 80), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 240, 80)", Ppm.ppmPixel(p6, 240, 80), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 80, 20)", Ppm.ppmPixel(p6, 80, 20), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 240, 20)", Ppm.ppmPixel(p6, 240, 20), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 80, 120)", Ppm.ppmPixel(p6, 80, 120), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 80, 10)", Ppm.ppmPixel(p6, 80, 10), new int[] {77, 65, 48}, 1);
            assertTriple("ppm_pixel(p6, 240, 10)", Ppm.ppmPixel(p6, 240, 10), new int[] {77, 65, 48}, 1);
            assertTriple("ppm_pixel(p6, 80, 11)", Ppm.ppmPixel(p6, 80, 11), new int[] {199, 160, 76}, 1);
            assertTriple("ppm_pixel(p6, 14, 58)", Ppm.ppmPixel(p6, 14, 58), new int[] {101, 83, 52}, 1);
            assertTriple("ppm_pixel(p6, 174, 58)", Ppm.ppmPixel(p6, 174, 58), new int[] {101, 83, 52}, 1);
            assertTriple("ppm_pixel(p6, 10, 10)", Ppm.ppmPixel(p6, 10, 10), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 5: plate 5", () -> {
            Canvas c = Figures.plate05();
            byte[] ref = readReference("plate-05.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 640);
            assertEquals("c.height", c.height, 640);
            assertTriple("ppm_pixel(p6, 160, 160)", Ppm.ppmPixel(p6, 160, 160), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 480, 160)", Ppm.ppmPixel(p6, 480, 160), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 160, 480)", Ppm.ppmPixel(p6, 160, 480), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 480, 480)", Ppm.ppmPixel(p6, 480, 480), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 160, 40)", Ppm.ppmPixel(p6, 160, 40), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 480, 360)", Ppm.ppmPixel(p6, 480, 360), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 160, 20)", Ppm.ppmPixel(p6, 160, 20), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 160, 341)", Ppm.ppmPixel(p6, 160, 341), new int[] {77, 65, 48}, 1);
            assertTriple("ppm_pixel(p6, 480, 341)", Ppm.ppmPixel(p6, 480, 341), new int[] {77, 65, 48}, 1);
            assertTriple("ppm_pixel(p6, 348, 437)", Ppm.ppmPixel(p6, 348, 437), new int[] {101, 83, 52}, 1);
            assertTriple("ppm_pixel(p6, 20, 20)", Ppm.ppmPixel(p6, 20, 20), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference/chapter-05", filename));
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
        writeOne("star-centers.ppm", Figures.starCenters());
        writeOne("star-coverage.ppm", Figures.starCoverage());
        writeOne("plate-05.ppm", Figures.plate05());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
