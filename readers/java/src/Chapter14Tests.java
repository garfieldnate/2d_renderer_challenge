import java.io.IOException;
import java.nio.file.Files;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter14-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-14/*.ppm resolves.
 */
public final class Chapter14Tests {

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

    private static void assertGe(String what, double actual, double bound) {
        if (!(actual >= bound)) {
            throw new AssertionError(what + ": expected >= " + bound + " but got " + actual);
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
        registerOffset();
        registerCurvature();
        registerFit();
        registerCurve();
        registerStroke();
        registerPlate();
    }

    // features/chapter14-offset.feature
    private static void registerOffset() {
        scenario("Offset: the normal is the tangent turned toward +y", () -> {
            Curve q = Curve.quadratic(Tuple.point(0, 0), Tuple.point(2, 4), Tuple.point(4, 0));
            assertTupleEq("tangent_at(q, 0)", Offset.tangentAt(q, 0), Tuple.vector(0.447214, 0.894427));
            assertTupleEq("normal_at(q, 0)", Offset.normalAt(q, 0), Tuple.vector(-0.894427, 0.447214));
            assertTupleEq("tangent_at(q, 0.5)", Offset.tangentAt(q, 0.5), Tuple.vector(1, 0));
            assertTupleEq("normal_at(q, 0.5)", Offset.normalAt(q, 0.5), Tuple.vector(0, 1));
        });

        scenario("Offset: offsetting a straight curve gives the parallel line", () -> {
            Curve line = Curve.cubic(Tuple.point(0, 0), Tuple.point(1, 1), Tuple.point(2, 2), Tuple.point(3, 3));
            assertTupleEq("offset_point(line, 0, 1)", Offset.offsetPoint(line, 0, 1), Tuple.point(-0.707107, 0.707107));
            assertTupleEq("offset_point(line, 0.5, sqrt(2))",
                    Offset.offsetPoint(line, 0.5, Math.sqrt(2)), Tuple.point(0.5, 2.5));
            assertTupleEq("offset_point(line, 1, -1)", Offset.offsetPoint(line, 1, -1), Tuple.point(3.707107, 2.292893));
        });

        scenario("Offset: positive d is below a rightward tangent, negative is above", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            assertTupleEq("point_at(c, 0.5)", Curves.pointAt(c, 0.5), Tuple.point(2, 3));
            assertTupleEq("offset_point(c, 0.5, 1)", Offset.offsetPoint(c, 0.5, 1), Tuple.point(2, 4));
            assertTupleEq("offset_point(c, 0.5, -1)", Offset.offsetPoint(c, 0.5, -1), Tuple.point(2, 2));
        });

        scenario("Offset: offsetting a circle moves it to another circle about the same center", () -> {
            Curve arc = Curve.cubic(Tuple.point(100, 0), Tuple.point(100, 55.2285),
                    Tuple.point(55.2285, 100), Tuple.point(0, 100));
            assertDoubleEq("magnitude(offset_point(arc, 0.5, 10) - point(0, 0))",
                    Offset.offsetPoint(arc, 0.5, 10).subtract(Tuple.point(0, 0)).magnitude(), 90, 0.05);
            assertDoubleEq("magnitude(offset_point(arc, 0.25, -10) - point(0, 0))",
                    Offset.offsetPoint(arc, 0.25, -10).subtract(Tuple.point(0, 0)).magnitude(), 110, 0.05);
            assertDoubleEq("magnitude(offset_point(arc, 0, 10) - point(0, 0))",
                    Offset.offsetPoint(arc, 0, 10).subtract(Tuple.point(0, 0)).magnitude(), 90, 0.0001);
        });

        scenario("Offset: a handle sitting on its anchor still has a direction", () -> {
            Curve stalled = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 0), Tuple.point(4, 4), Tuple.point(4, 0));
            assertTupleEq("offset_point(stalled, 0, 1)", Offset.offsetPoint(stalled, 0, 1),
                    Tuple.point(-0.707107, 0.707107), 0.001);
        });
    }

    // features/chapter14-curvature.feature
    private static void registerCurvature() {
        scenario("Curvature: the second derivative of a quadratic is constant, a cubic's is linear", () -> {
            Curve q = Curve.quadratic(Tuple.point(0, 0), Tuple.point(2, 4), Tuple.point(4, 0));
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            assertTupleEq("second_derivative(q, 0)", Offset.secondDerivative(q, 0), Tuple.vector(0, -16));
            assertTupleEq("second_derivative(q, 0.5)", Offset.secondDerivative(q, 0.5), Tuple.vector(0, -16));
            assertTupleEq("second_derivative(c, 0)", Offset.secondDerivative(c, 0), Tuple.vector(24, -24));
            assertTupleEq("second_derivative(c, 0.5)", Offset.secondDerivative(c, 0.5), Tuple.vector(0, -24));
            assertTupleEq("second_derivative(c, 1)", Offset.secondDerivative(c, 1), Tuple.vector(-24, -24));
        });

        scenario("Curvature: curvature is signed like the cross product and its reciprocal is a radius", () -> {
            Curve q = Curve.quadratic(Tuple.point(0, 0), Tuple.point(2, 4), Tuple.point(4, 0));
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            Curve line = Curve.cubic(Tuple.point(0, 0), Tuple.point(1, 1), Tuple.point(2, 2), Tuple.point(3, 3));
            Curve arc = Curve.cubic(Tuple.point(100, 0), Tuple.point(100, 55.2285),
                    Tuple.point(55.2285, 100), Tuple.point(0, 100));
            assertDoubleEq("curvature(q, 0.5)", Offset.curvature(q, 0.5), -1);
            assertDoubleEq("curvature(q, 0)", Offset.curvature(q, 0), -0.089443);
            assertDoubleEq("curvature(c, 0.5)", Offset.curvature(c, 0.5), -0.666667);
            assertDoubleEq("curvature(line, 0.5)", Offset.curvature(line, 0.5), 0);
            assertDoubleEq("curvature(arc, 0.5)", Offset.curvature(arc, 0.5), 0.009938, 0.0001);
            assertDoubleEq("curvature(arc, 0)", Offset.curvature(arc, 0), 0.009786, 0.0001);
        });

        scenario("Curvature: the offset stalls where d reaches the radius, on the inside of the turn", () -> {
            Curve q = Curve.quadratic(Tuple.point(0, 0), Tuple.point(2, 4), Tuple.point(4, 0));
            assertEquals("length(cusps(q, -0.5))", Offset.cusps(q, -0.5).size(), 0);
            assertEquals("length(cusps(q, 2))", Offset.cusps(q, 2).size(), 0);
            List<Double> c2 = Offset.cusps(q, -2);
            assertEquals("length(cusps(q, -2))", c2.size(), 2);
            assertDoubleEq("cusps(q, -2)[0]", c2.get(0), 0.308395, 0.0001);
            assertDoubleEq("cusps(q, -2)[1]", c2.get(1), 0.691605, 0.0001);
            assertDoubleEq("curvature(q, cusps(q, -2)[0])", Offset.curvature(q, c2.get(0)), -0.5, 0.0001);
        });

        scenario("Curvature: a wider offset stalls sooner", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            assertEquals("length(cusps(c, -1))", Offset.cusps(c, -1).size(), 0);
            assertEquals("length(cusps(c, -1.5))", Offset.cusps(c, -1.5).size(), 0);
            List<Double> c2 = Offset.cusps(c, -2);
            assertEquals("length(cusps(c, -2))", c2.size(), 2);
            assertDoubleEq("cusps(c, -2)[0]", c2.get(0), 0.30334, 0.0001);
            assertDoubleEq("cusps(c, -2)[1]", c2.get(1), 0.69666, 0.0001);
        });
    }

    // features/chapter14-fit.feature
    private static void registerFit() {
        scenario("Fit: the fit of a straight curve is exact", () -> {
            Curve line = Curve.cubic(Tuple.point(0, 0), Tuple.point(1, 1), Tuple.point(2, 2), Tuple.point(3, 3));
            Curve f = Offset.fitOffset(line, 1);
            assertTupleEq("f.points[0]", f.points().get(0), Tuple.point(-0.707107, 0.707107));
            assertTupleEq("f.points[1]", f.points().get(1), Tuple.point(0.292893, 1.707107));
            assertTupleEq("f.points[3]", f.points().get(3), Tuple.point(2.292893, 3.707107));
            assertDoubleEq("offset_error(line, 1, f)", Offset.offsetError(line, 1, f), 0);
        });

        scenario("Fit: the fit of a quarter circle lands its handles on the offset circle", () -> {
            Curve arc = Curve.cubic(Tuple.point(100, 0), Tuple.point(100, 55.2285),
                    Tuple.point(55.2285, 100), Tuple.point(0, 100));
            Curve f = Offset.fitOffset(arc, 10);
            assertTupleEq("f.points[0]", f.points().get(0), Tuple.point(90, 0));
            assertTupleEq("f.points[1]", f.points().get(1), Tuple.point(90, 49.7056), 0.001);
            assertTupleEq("f.points[2]", f.points().get(2), Tuple.point(49.7056, 90), 0.001);
            assertTupleEq("f.points[3]", f.points().get(3), Tuple.point(0, 90));
            assertDoubleEq("offset_error(arc, 10, f)", Offset.offsetError(arc, 10, f), 0.012092, 0.0001);
        });

        scenario("Fit: a U-turn cannot be fitted in one piece, and the miss says so", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            Curve f = Offset.fitOffset(c, 1);
            assertTupleEq("f.points[0]", f.points().get(0), Tuple.point(-1, 0));
            assertTupleEq("f.points[1]", f.points().get(1), Tuple.point(-1, 2));
            assertTupleEq("f.points[2]", f.points().get(2), Tuple.point(5, 2));
            assertTupleEq("f.points[3]", f.points().get(3), Tuple.point(5, 0));
            assertDoubleEq("offset_error(c, 1, f)", Offset.offsetError(c, 1, f), 2.5);
        });

        scenario("Fit: the distance from a point to a curve", () -> {
            Curve line = Curve.cubic(Tuple.point(0, 0), Tuple.point(1, 1), Tuple.point(2, 2), Tuple.point(3, 3));
            Curve q = Curve.quadratic(Tuple.point(0, 0), Tuple.point(2, 4), Tuple.point(4, 0));
            Curve arc = Curve.cubic(Tuple.point(100, 0), Tuple.point(100, 55.2285),
                    Tuple.point(55.2285, 100), Tuple.point(0, 100));
            assertDoubleEq("distance_to_curve(line, point(3, 0))",
                    Offset.distanceToCurve(line, Tuple.point(3, 0)), 2.121320);
            assertDoubleEq("distance_to_curve(line, point(5, 5))",
                    Offset.distanceToCurve(line, Tuple.point(5, 5)), 2.828427);
            assertDoubleEq("distance_to_curve(q, point(2, 5))",
                    Offset.distanceToCurve(q, Tuple.point(2, 5)), 3);
            assertDoubleEq("distance_to_curve(q, point(2, 0))",
                    Offset.distanceToCurve(q, Tuple.point(2, 0)), 1.732051);
            assertDoubleEq("distance_to_curve(arc, point(0, 0))",
                    Offset.distanceToCurve(arc, Tuple.point(0, 0)), 100, 0.03);
        });
    }

    // features/chapter14-curve.feature
    private static void registerCurve() {
        scenario("Curve: a piece of a curve between two parameters", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            Curve piece = Offset.subCurve(c, 0.25, 0.75);
            assertTupleEq("point_at(piece, 0)", Curves.pointAt(piece, 0), Tuple.point(0.625, 2.25));
            assertTupleEq("point_at(piece, 0.5)", Curves.pointAt(piece, 0.5), Tuple.point(2, 3));
            assertTupleEq("point_at(piece, 1)", Curves.pointAt(piece, 1), Tuple.point(3.375, 2.25));
        });

        scenario("Curve: a gentle offset needs one piece at a loose tolerance and four at a tight one", () -> {
            Curve arc = Curve.cubic(Tuple.point(100, 0), Tuple.point(100, 55.2285),
                    Tuple.point(55.2285, 100), Tuple.point(0, 100));
            assertEquals("length(offset_curve(arc, 10, 0.1))", Offset.offsetCurve(arc, 10, 0.1).size(), 1);
            assertEquals("length(offset_curve(arc, 10, 0.01))", Offset.offsetCurve(arc, 10, 0.01).size(), 4);
            assertEquals("length(offset_curve(arc, -10, 0.01))", Offset.offsetCurve(arc, -10, 0.01).size(), 4);
        });

        scenario("Curve: the pieces chain end to end from the first offset point to the last", () -> {
            Curve c = Curve.cubic(Tuple.point(0, 0), Tuple.point(0, 4), Tuple.point(4, 4), Tuple.point(4, 0));
            List<Curve> pieces = Offset.offsetCurve(c, 1, 0.01);
            assertEquals("length(pieces)", pieces.size(), 4);
            assertTupleEq("pieces[0].points[0]", pieces.get(0).points().get(0), Tuple.point(-1, 0));
            assertTupleEq("pieces[1].points[0]", pieces.get(1).points().get(0), pieces.get(0).points().get(3));
            assertTupleEq("pieces[1].points[3]", pieces.get(1).points().get(3), Tuple.point(2, 4));
            assertTupleEq("pieces[2].points[0]", pieces.get(2).points().get(0), Tuple.point(2, 4));
            assertTupleEq("pieces[3].points[3]", pieces.get(3).points().get(3), Tuple.point(5, 0));
        });

        scenario("Curve: on the outside every point of the offset is a distance d from the curve", () -> {
            Curve arc = Curve.cubic(Tuple.point(100, 0), Tuple.point(100, 55.2285),
                    Tuple.point(55.2285, 100), Tuple.point(0, 100));
            Curve q = Curve.quadratic(Tuple.point(0, 0), Tuple.point(2, 4), Tuple.point(4, 0));
            assertLe("offset_distance_error(arc, 10, 0.01)", Offset.offsetDistanceError(arc, 10, 0.01), 0.01);
            assertLe("offset_distance_error(arc, -10, 0.01)", Offset.offsetDistanceError(arc, -10, 0.01), 0.01);
            assertLe("offset_distance_error(q, 2, 0.01)", Offset.offsetDistanceError(q, 2, 0.01), 0.01);
            assertLe("offset_distance_error(q, 2, 0.1)", Offset.offsetDistanceError(q, 2, 0.1), 0.1);
        });

        scenario("Curve: on the inside of a tight bend the offset folds and comes closer than d", () -> {
            Curve q = Curve.quadratic(Tuple.point(0, 0), Tuple.point(2, 4), Tuple.point(4, 0));
            List<Curve> pieces = Offset.offsetCurve(q, -2, 0.01);
            assertEquals("length(pieces)", pieces.size(), 6);
            assertTupleEq("pieces[1].points[3]", pieces.get(1).points().get(3), Tuple.point(2.4502, 0.118898), 0.0001);
            assertTupleEq("pieces[2].points[3]", pieces.get(2).points().get(3), Tuple.point(2, 0));
            assertTupleEq("pieces[3].points[3]", pieces.get(3).points().get(3), Tuple.point(1.5498, 0.118898), 0.0001);
            assertDoubleEq("distance_to_curve(q, point(2, 0))", Offset.distanceToCurve(q, Tuple.point(2, 0)), 1.732051);
            assertGe("offset_distance_error(q, -2, 0.01)", Offset.offsetDistanceError(q, -2, 0.01), 0.7);
        });
    }

    // features/chapter14-stroke.feature
    private static void registerStroke() {
        scenario("Stroke: the stroke of a curve is one closed subpath, right offset out and left offset back", () -> {
            Path o = Offset.strokeCurveToPath(Figures.hairpin(), 60, "butt", 0.25);
            assertEquals("length(subpaths(o))", o.subpaths().size(), 1);
            assertTrue("subpaths(o)[0].closed = true", o.subpaths().get(0).closed);
            List<Tuple> pts = o.subpaths().get(0).points;
            assertEquals("length(subpaths(o)[0].points)", pts.size(), 58);
            assertTupleEq("subpaths(o)[0].points[0]", pts.get(0), Offset.offsetPoint(Figures.hairpin(), 0, 30));
            assertTupleEq("subpaths(o)[0].points[57]", pts.get(57), Offset.offsetPoint(Figures.hairpin(), 0, -30));
            assertTupleEq("subpaths(o)[0].points[0]", pts.get(0), Tuple.point(64.5435, 145.214), 0.001);
        });

        scenario("Stroke: caps add their points to the same outline", () -> {
            assertEquals("point_count(stroke_curve_to_path(hairpin(), 60, \"round\", 0.25))",
                    Offset.pointCount(Offset.strokeCurveToPath(Figures.hairpin(), 60, "round", 0.25)), 88);
            assertEquals("point_count(stroke_curve_to_path(hairpin(), 60, \"square\", 0.25))",
                    Offset.pointCount(Offset.strokeCurveToPath(Figures.hairpin(), 60, "square", 0.25)), 62);
        });

        scenario("Stroke: flattening first gives the same picture from many more pieces", () -> {
            Path o = Offset.strokeCurveToPath(Figures.hairpin(), 60, "butt", 0.25);
            Path f = Offset.flattenThenStroke(Figures.hairpin(), 60, "butt", 0.25);
            assertEquals("length(subpaths(f))", f.subpaths().size(), 43);
            assertEquals("point_count(f)", Offset.pointCount(f), 172);
            assertEquals("point_count(o)", Offset.pointCount(o), 58);
            assertLe("max_coverage_difference(fill_path(o, \"nonzero\", 160, 160), fill_path(f, \"nonzero\", 160, 160))",
                    CoverageBuffer.maxCoverageDifference(
                            Fill.fillPath(o, "nonzero", 160, 160), Fill.fillPath(f, "nonzero", 160, 160)), 0.6);
        });

        scenario("Stroke: the inner offset folds into a loop, and nonzero fills it", () -> {
            Path o = Offset.strokeCurveToPath(Figures.hairpin(), 60, "butt", 0.25);
            assertEquals("length(cusps(hairpin(), 30))", Offset.cusps(Figures.hairpin(), 30).size(), 2);
            assertEquals("length(cusps(hairpin(), -30))", Offset.cusps(Figures.hairpin(), -30).size(), 0);
            assertDoubleEq("distance_to_curve(hairpin(), point(80.5, 60.5))",
                    Offset.distanceToCurve(Figures.hairpin(), Tuple.point(80.5, 60.5)), 25.967, 0.01);
            assertTrue("inside_nonzero(o, 80.5, 60.5) = true", Winding.insideNonzero(o, 80.5, 60.5));
            assertTrue("inside_evenodd(o, 80.5, 60.5) = false", !Winding.insideEvenodd(o, 80.5, 60.5));
            assertDoubleEq("distance_to_curve(hairpin(), point(80.5, 30.5))",
                    Offset.distanceToCurve(Figures.hairpin(), Tuple.point(80.5, 30.5)), 14.503, 0.01);
            assertTrue("inside_nonzero(o, 80.5, 30.5) = true", Winding.insideNonzero(o, 80.5, 30.5));
            assertTrue("inside_evenodd(o, 80.5, 30.5) = true", Winding.insideEvenodd(o, 80.5, 30.5));
            assertDoubleEq("distance_to_curve(hairpin(), point(80.5, 85.5))",
                    Offset.distanceToCurve(Figures.hairpin(), Tuple.point(80.5, 85.5)), 32.626, 0.01);
            assertTrue("inside_nonzero(o, 80.5, 85.5) = false", !Winding.insideNonzero(o, 80.5, 85.5));
        });
    }

    // features/chapter14-plate.feature
    private static void registerPlate() {
        scenario("Plate 14: two strokes", () -> {
            Canvas c = Figures.twoStrokes();
            byte[] ref = readReference("two-strokes.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 160);
            assertTriple("ppm_pixel(p6, 80, 40)", Ppm.ppmPixel(p6, 80, 40), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 240, 40)", Ppm.ppmPixel(p6, 240, 40), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 80, 100)", Ppm.ppmPixel(p6, 80, 100), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 14: the fold under two rules", () -> {
            Canvas c = Figures.foldDemo();
            byte[] ref = readReference("fold.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 160);
            assertTriple("ppm_pixel(p6, 80, 40)", Ppm.ppmPixel(p6, 80, 40), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 240, 40)", Ppm.ppmPixel(p6, 240, 40), new int[] {206, 206, 212}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 14: the offsets", () -> {
            Canvas c = Figures.offsetsPlate();
            byte[] ref = readReference("offsets.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 270);
            assertTriple("ppm_pixel(p6, 160, 66)", Ppm.ppmPixel(p6, 160, 66), new int[] {243, 243, 246}, 1);
            assertTriple("ppm_pixel(p6, 160, 36)", Ppm.ppmPixel(p6, 160, 36), new int[] {137, 203, 243}, 1);
            assertTriple("ppm_pixel(p6, 10, 10)", Ppm.ppmPixel(p6, 10, 10), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 14: Plate 14", () -> {
            Canvas c = Figures.plate14();
            byte[] ref = readReference("plate-14.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 640);
            assertEquals("c.height", c.height, 540);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    // ---- helpers -------------------------------------------------------

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference", "chapter-14", filename));
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
        writeOne("two-strokes.ppm", Figures.twoStrokes());
        writeOne("fold.ppm", Figures.foldDemo());
        writeOne("offsets.ppm", Figures.offsetsPlate());
        writeOne("plate-14.ppm", Figures.plate14());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
