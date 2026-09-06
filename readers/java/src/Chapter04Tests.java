import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter04-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-04/*.ppm resolves.
 */
public final class Chapter04Tests {

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

    private static void assertMatrixEq(String what, Matrix actual, Matrix expected) {
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected\n" + expected + "but got\n" + actual);
        }
    }

    private static void assertMatrixNotEq(String what, Matrix actual, Matrix other) {
        if (actual.approxEquals(other)) {
            throw new AssertionError(what + ": expected matrices to differ, both were\n" + actual);
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

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerTuples();
        registerMatrices();
        registerTransforms();
        registerScale();
        registerShapes();
        registerPlate();
    }

    // features/chapter04-tuples.feature
    private static void registerTuples() {
        scenario("Tuples: a point has w = 1", () -> {
            Tuple p = Tuple.point(4, -4);
            assertDoubleEq("p.x", p.x, 4);
            assertDoubleEq("p.y", p.y, -4);
            assertDoubleEq("p.w", p.w, 1);
        });

        scenario("Tuples: a vector has w = 0", () -> {
            Tuple v = Tuple.vector(4, -4);
            assertDoubleEq("v.x", v.x, 4);
            assertDoubleEq("v.y", v.y, -4);
            assertDoubleEq("v.w", v.w, 0);
        });

        scenario("Tuples: the difference of two points is the vector between them", () -> {
            Tuple a = Tuple.point(3, 2);
            Tuple b = Tuple.point(5, 6);
            assertTupleEq("b - a", b.subtract(a), Tuple.vector(2, 4));
            assertTupleEq("a - b", a.subtract(b), Tuple.vector(-2, -4));
        });

        scenario("Tuples: a point plus a vector is a point", () -> {
            Tuple p = Tuple.point(3, -2);
            Tuple v = Tuple.vector(-2, 3);
            assertTupleEq("p + v", p.add(v), Tuple.point(1, 1));
            assertTupleEq("p - v", p.subtract(v), Tuple.point(5, -5));
        });

        scenario("Tuples: a vector plus a vector is a vector", () -> {
            Tuple a = Tuple.vector(3, -2);
            Tuple b = Tuple.vector(-2, 3);
            assertTupleEq("a + b", a.add(b), Tuple.vector(1, 1));
            assertTupleEq("a - b", a.subtract(b), Tuple.vector(5, -5));
        });

        scenario("Tuples: negating, scaling and dividing a vector", () -> {
            Tuple v = Tuple.vector(1, -2);
            assertTupleEq("-v", v.negate(), Tuple.vector(-1, 2));
            assertTupleEq("v * 3.5", v.scale(3.5), Tuple.vector(3.5, -7));
            assertTupleEq("v * 0.5", v.scale(0.5), Tuple.vector(0.5, -1));
            assertTupleEq("v / 2", v.divide(2), Tuple.vector(0.5, -1));
        });

        scenario("Tuples: the magnitude of a vector", () -> {
            assertDoubleEq("magnitude(vector(1, 0))", Tuple.vector(1, 0).magnitude(), 1);
            assertDoubleEq("magnitude(vector(0, 1))", Tuple.vector(0, 1).magnitude(), 1);
            assertDoubleEq("magnitude(vector(3, 4))", Tuple.vector(3, 4).magnitude(), 5);
            assertDoubleEq("magnitude(vector(-3, -4))", Tuple.vector(-3, -4).magnitude(), 5);
            assertDoubleEq("magnitude(vector(-1, -2))", Tuple.vector(-1, -2).magnitude(), 2.2361);
        });

        scenario("Tuples: normalizing a vector", () -> {
            assertTupleEq("normalize(vector(4, 0))", Tuple.vector(4, 0).normalize(), Tuple.vector(1, 0));
            assertTupleEq("normalize(vector(1, 2))", Tuple.vector(1, 2).normalize(), Tuple.vector(0.4472, 0.8944));
            assertDoubleEq("magnitude(normalize(vector(1, 2)))", Tuple.vector(1, 2).normalize().magnitude(), 1);
        });

        scenario("Tuples: the dot product of two vectors", () -> {
            Tuple a = Tuple.vector(1, 2);
            Tuple b = Tuple.vector(2, 3);
            assertDoubleEq("dot(a, b)", Tuple.dot(a, b), 8);
            assertDoubleEq("dot(a, vector(-2, 1))", Tuple.dot(a, Tuple.vector(-2, 1)), 0);
        });

        scenario("Tuples: magnitude and dot look at x and y only", () -> {
            assertDoubleEq("magnitude(point(3, 4))", Tuple.point(3, 4).magnitude(), 5);
            assertDoubleEq("dot(point(1, 2), point(2, 3))", Tuple.dot(Tuple.point(1, 2), Tuple.point(2, 3)), 8);
        });

        scenario("Tuples: the cross product of two vectors is a number", () -> {
            Tuple a = Tuple.vector(1, 0);
            Tuple b = Tuple.vector(0, 1);
            assertDoubleEq("cross(a, b)", Tuple.cross(a, b), 1);
            assertDoubleEq("cross(b, a)", Tuple.cross(b, a), -1);
            assertDoubleEq("cross(a, a)", Tuple.cross(a, a), 0);
            assertDoubleEq("cross(vector(2, 3), vector(4, 5))",
                    Tuple.cross(Tuple.vector(2, 3), Tuple.vector(4, 5)), -2);
        });

        scenario("Tuples: the sign of the cross product says which side of a line a point is on", () -> {
            Tuple a = Tuple.point(0, 0);
            Tuple b = Tuple.point(10, 0);
            assertDoubleEq("cross(b - a, point(5, 3) - a)",
                    Tuple.cross(b.subtract(a), Tuple.point(5, 3).subtract(a)), 30);
            assertDoubleEq("cross(b - a, point(5, -3) - a)",
                    Tuple.cross(b.subtract(a), Tuple.point(5, -3).subtract(a)), -30);
            assertDoubleEq("cross(b - a, point(20, 0) - a)",
                    Tuple.cross(b.subtract(a), Tuple.point(20, 0).subtract(a)), 0);
        });
    }

    // features/chapter04-matrices.feature
    private static void registerMatrices() {
        scenario("Matrices: constructing and inspecting a matrix", () -> {
            Matrix m = Matrix.matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
            assertDoubleEq("M[0, 0]", m.get(0, 0), 1);
            assertDoubleEq("M[0, 2]", m.get(0, 2), 3);
            assertDoubleEq("M[1, 0]", m.get(1, 0), 4);
            assertDoubleEq("M[1, 1]", m.get(1, 1), 5);
            assertDoubleEq("M[2, 0]", m.get(2, 0), 7);
            assertDoubleEq("M[2, 2]", m.get(2, 2), 9);
            assertMatrixEq("M = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)", m,
                    Matrix.matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9));
        });

        scenario("Matrices: matrix equality with identical matrices", () -> {
            Matrix a = Matrix.matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
            Matrix b = Matrix.matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
            assertMatrixEq("A = B", a, b);
        });

        scenario("Matrices: matrix equality with different matrices", () -> {
            Matrix a = Matrix.matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
            Matrix b = Matrix.matrix3(1, 2, 3, 4, 5, 6, 7, 8, 8);
            assertMatrixNotEq("A != B", a, b);
        });

        scenario("Matrices: multiplying two matrices", () -> {
            Matrix a = Matrix.matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
            Matrix b = Matrix.matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
            assertMatrixEq("A * B", a.multiply(b), Matrix.matrix3(4, 8, 8, 13, 17, 17, 22, 26, 26));
        });

        scenario("Matrices: matrix multiplication is not commutative", () -> {
            Matrix a = Matrix.matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
            Matrix b = Matrix.matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
            assertMatrixNotEq("A * B != B * A", a.multiply(b), b.multiply(a));
        });

        scenario("Matrices: a matrix multiplied by a point", () -> {
            Matrix a = Matrix.matrix3(1, 2, 3, 4, 5, 6, 0, 0, 1);
            Tuple p = Tuple.point(1, 2);
            assertTupleEq("A * p", a.multiply(p), Tuple.point(8, 20));
        });

        scenario("Matrices: a matrix multiplied by a vector ignores the last column", () -> {
            Matrix a = Matrix.matrix3(1, 2, 3, 4, 5, 6, 0, 0, 1);
            Tuple v = Tuple.vector(1, 2);
            assertTupleEq("A * v", a.multiply(v), Tuple.vector(5, 14));
        });

        scenario("Matrices: multiplying by the identity matrix changes nothing", () -> {
            Matrix a = Matrix.matrix3(0, 1, 2, 1, 2, 4, 2, 4, 8);
            Tuple p = Tuple.point(1, 2);
            assertMatrixEq("A * identity()", a.multiply(Matrix.identity()), a);
            assertMatrixEq("identity() * A", Matrix.identity().multiply(a), a);
            assertTupleEq("identity() * p", Matrix.identity().multiply(p), p);
        });

        scenario("Matrices: transposing a matrix", () -> {
            Matrix a = Matrix.matrix3(0, 9, 3, 9, 8, 0, 1, 8, 5);
            assertMatrixEq("transpose(A)", a.transpose(), Matrix.matrix3(0, 9, 1, 9, 8, 8, 3, 0, 5));
        });

        scenario("Matrices: transposing the identity matrix", () -> {
            assertMatrixEq("transpose(identity())", Matrix.identity().transpose(), Matrix.identity());
        });

        scenario("Matrices: the determinant of a 3 by 3 matrix", () -> {
            Matrix a = Matrix.matrix3(1, 2, 6, -5, 8, -4, 2, 6, 4);
            assertDoubleEq("determinant(A)", a.determinant(), -196);
        });

        scenario("Matrices: the determinant of a transform is the area factor", () -> {
            assertDoubleEq("determinant(identity())", Matrix.identity().determinant(), 1);
            assertDoubleEq("determinant(scaling(2, 3))", Transforms.scaling(2, 3).determinant(), 6);
            assertDoubleEq("determinant(rotation(0.7))", Transforms.rotation(0.7).determinant(), 1);
            assertDoubleEq("determinant(translation(4, 9))", Transforms.translation(4, 9).determinant(), 1);
            assertDoubleEq("determinant(scaling(-1, 1))", Transforms.scaling(-1, 1).determinant(), -1);
        });

        scenario("Matrices: testing an invertible matrix for invertibility", () -> {
            Matrix a = Matrix.matrix3(3, 0, 2, 2, 0, -2, 0, 1, 1);
            assertDoubleEq("determinant(A)", a.determinant(), 10);
            assertTrue("is_invertible(A)", a.isInvertible());
        });

        scenario("Matrices: testing a non-invertible matrix for invertibility", () -> {
            Matrix a = Matrix.matrix3(1, 2, 3, 2, 4, 6, 0, 0, 1);
            assertDoubleEq("determinant(A)", a.determinant(), 0);
            assertTrue("!is_invertible(A)", !a.isInvertible());
        });

        scenario("Matrices: invertibility is an exact test against zero", () -> {
            Matrix s = Transforms.scaling(0.0001, 1);
            assertTrue("is_invertible(scaling(0.0001, 1))", s.isInvertible());
            assertDoubleEq("determinant(scaling(0.0001, 1))", s.determinant(), 0.0001);
            assertTupleEq("inverse(scaling(0.0001, 1)) * point(0.0001, 3)",
                    s.inverse().multiply(Tuple.point(0.0001, 3)), Tuple.point(1, 3));
        });

        scenario("Matrices: calculating the inverse of a matrix", () -> {
            Matrix a = Matrix.matrix3(3, 0, 2, 2, 0, -2, 0, 1, 1);
            Matrix b = a.inverse();
            assertDoubleEq("B[0, 0]", b.get(0, 0), 0.2);
            assertDoubleEq("B[1, 2]", b.get(1, 2), 1);
            assertDoubleEq("B[2, 1]", b.get(2, 1), -0.3);
            assertMatrixEq("B", b, Matrix.matrix3(0.2, 0.2, 0, -0.2, 0.3, 1, 0.2, -0.3, 0));
            assertMatrixEq("A * B", a.multiply(b), Matrix.identity());
        });

        scenario("Matrices: multiplying a product by its inverse", () -> {
            Matrix a = Matrix.matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
            Matrix b = Matrix.matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
            Matrix c = a.multiply(b);
            assertMatrixEq("C * inverse(B)", c.multiply(b.inverse()), a);
        });

        scenario("Matrices: the inverse of a transform is a transform", () -> {
            Matrix a = Transforms.translation(5, -3).multiply(Transforms.rotation(Math.PI / 6))
                    .multiply(Transforms.scaling(2, 3));
            Matrix b = a.inverse();
            assertDoubleEq("B[2, 0]", b.get(2, 0), 0);
            assertDoubleEq("B[2, 1]", b.get(2, 1), 0);
            assertDoubleEq("B[2, 2]", b.get(2, 2), 1);
            assertDoubleEq("B[0, 0]", b.get(0, 0), 0.4330);
            assertDoubleEq("B[0, 2]", b.get(0, 2), -1.4151);
            assertDoubleEq("B[1, 2]", b.get(1, 2), 1.6994);
            assertMatrixEq("B * A", b.multiply(a), Matrix.identity());
        });
    }

    // features/chapter04-transforms.feature
    private static void registerTransforms() {
        scenario("Transforms: multiplying by a translation matrix", () -> {
            Matrix t = Transforms.translation(5, -3);
            Tuple p = Tuple.point(-3, 4);
            assertTupleEq("t * p", t.multiply(p), Tuple.point(2, 1));
        });

        scenario("Transforms: the inverse of a translation moves the other way", () -> {
            Matrix t = Transforms.translation(5, -3);
            Tuple p = Tuple.point(-3, 4);
            assertTupleEq("inverse(t) * p", t.inverse().multiply(p), Tuple.point(-8, 7));
        });

        scenario("Transforms: translation does not affect vectors", () -> {
            Matrix t = Transforms.translation(5, -3);
            Tuple v = Tuple.vector(-3, 4);
            assertTupleEq("t * v", t.multiply(v), v);
        });

        scenario("Transforms: a scaling matrix applied to a point", () -> {
            Matrix s = Transforms.scaling(2, 3);
            Tuple p = Tuple.point(-4, 6);
            assertTupleEq("s * p", s.multiply(p), Tuple.point(-8, 18));
        });

        scenario("Transforms: a scaling matrix applied to a vector", () -> {
            Matrix s = Transforms.scaling(2, 3);
            Tuple v = Tuple.vector(-4, 6);
            assertTupleEq("s * v", s.multiply(v), Tuple.vector(-8, 18));
        });

        scenario("Transforms: the inverse of a scaling shrinks", () -> {
            Matrix s = Transforms.scaling(2, 3);
            Tuple v = Tuple.vector(-4, 6);
            assertTupleEq("inverse(s) * v", s.inverse().multiply(v), Tuple.vector(-2, 2));
        });

        scenario("Transforms: reflection is scaling by a negative value", () -> {
            Matrix s = Transforms.scaling(-1, 1);
            Tuple p = Tuple.point(2, 3);
            assertTupleEq("s * p", s.multiply(p), Tuple.point(-2, 3));
        });

        scenario("Transforms: a positive rotation turns x toward y", () -> {
            Tuple p = Tuple.point(1, 0);
            assertTupleEq("rotation(pi/4) * p", Transforms.rotation(Math.PI / 4).multiply(p),
                    Tuple.point(0.7071, 0.7071));
            assertTupleEq("rotation(pi/2) * p", Transforms.rotation(Math.PI / 2).multiply(p),
                    Tuple.point(0, 1));
            assertTupleEq("rotation(pi) * p", Transforms.rotation(Math.PI).multiply(p),
                    Tuple.point(-1, 0));
        });

        scenario("Transforms: the inverse of a rotation turns the other way", () -> {
            Tuple p = Tuple.point(1, 0);
            assertTupleEq("inverse(rotation(pi/4)) * p",
                    Transforms.rotation(Math.PI / 4).inverse().multiply(p), Tuple.point(0.7071, -0.7071));
            assertTupleEq("rotation(-pi/4) * p", Transforms.rotation(-Math.PI / 4).multiply(p),
                    Tuple.point(0.7071, -0.7071));
        });

        scenario("Transforms: a rotation preserves length", () -> {
            Tuple v = Tuple.vector(3, 4);
            assertDoubleEq("magnitude(rotation(1.2) * v)", Transforms.rotation(1.2).multiply(v).magnitude(), 5);
            assertDoubleEq("magnitude(rotation(-2.8) * v)", Transforms.rotation(-2.8).multiply(v).magnitude(), 5);
        });

        scenario("Transforms: shearing moves x in proportion to y", () -> {
            Matrix s = Transforms.shearing(1, 0);
            Tuple p = Tuple.point(2, 3);
            assertTupleEq("s * p", s.multiply(p), Tuple.point(5, 3));
        });

        scenario("Transforms: shearing moves y in proportion to x", () -> {
            Matrix s = Transforms.shearing(0, 1);
            Tuple p = Tuple.point(2, 3);
            assertTupleEq("s * p", s.multiply(p), Tuple.point(2, 5));
        });

        scenario("Transforms: individual transformations are applied in sequence", () -> {
            Tuple p = Tuple.point(1, 0);
            Matrix a = Transforms.rotation(Math.PI / 2);
            Matrix b = Transforms.scaling(5, 5);
            Matrix c = Transforms.translation(10, 5);
            Tuple p2 = a.multiply(p);
            Tuple p3 = b.multiply(p2);
            Tuple p4 = c.multiply(p3);
            assertTupleEq("p2", p2, Tuple.point(0, 1));
            assertTupleEq("p3", p3, Tuple.point(0, 5));
            assertTupleEq("p4", p4, Tuple.point(10, 10));
        });

        scenario("Transforms: chained transformations must be applied in reverse order", () -> {
            Tuple p = Tuple.point(1, 0);
            Matrix a = Transforms.rotation(Math.PI / 2);
            Matrix b = Transforms.scaling(5, 5);
            Matrix c = Transforms.translation(10, 5);
            Matrix t = c.multiply(b).multiply(a);
            assertTupleEq("T * p", t.multiply(p), Tuple.point(10, 10));
        });

        scenario("Transforms: the other order is a different transform", () -> {
            Tuple p = Tuple.point(1, 0);
            Matrix a = Transforms.rotation(Math.PI / 2);
            Matrix b = Transforms.scaling(5, 5);
            Matrix c = Transforms.translation(10, 5);
            Matrix t = a.multiply(b).multiply(c);
            assertTupleEq("T * p", t.multiply(p), Tuple.point(-25, 55));
        });

        scenario("Transforms: rotating about a point that isn't the origin", () -> {
            Matrix t = Transforms.translation(4, 4).multiply(Transforms.rotation(Math.PI / 2))
                    .multiply(Transforms.translation(-4, -4));
            assertTupleEq("T * point(6, 4)", t.multiply(Tuple.point(6, 4)), Tuple.point(4, 6));
            assertTupleEq("T * point(4, 4)", t.multiply(Tuple.point(4, 4)), Tuple.point(4, 4));
        });
    }

    // features/chapter04-scale.feature
    private static void registerScale() {
        scenario("Scale: the identity, a translation and a rotation don't stretch", () -> {
            assertDoubleEq("approx_scale(identity())", Transforms.approxScale(Matrix.identity()), 1);
            assertDoubleEq("approx_scale(translation(7, 9))",
                    Transforms.approxScale(Transforms.translation(7, 9)), 1);
            assertDoubleEq("approx_scale(rotation(1.1))", Transforms.approxScale(Transforms.rotation(1.1)), 1);
        });

        scenario("Scale: a uniform scale is reported exactly", () -> {
            assertDoubleEq("approx_scale(scaling(2, 2))", Transforms.approxScale(Transforms.scaling(2, 2)), 2);
            assertDoubleEq("approx_scale(scaling(0.5, 0.5))",
                    Transforms.approxScale(Transforms.scaling(0.5, 0.5)), 0.5);
            assertDoubleEq("approx_scale(scaling(3, 3) * rotation(0.7))",
                    Transforms.approxScale(Transforms.scaling(3, 3).multiply(Transforms.rotation(0.7))), 3);
            assertDoubleEq("approx_scale(translation(5, 5) * scaling(3, 3))",
                    Transforms.approxScale(Transforms.translation(5, 5).multiply(Transforms.scaling(3, 3))), 3);
        });

        scenario("Scale: a reflection is not a negative scale", () -> {
            assertDoubleEq("approx_scale(scaling(-2, 2))", Transforms.approxScale(Transforms.scaling(-2, 2)), 2);
        });

        scenario("Scale: a non-uniform scale is reported as the geometric mean", () -> {
            assertDoubleEq("approx_scale(scaling(4, 1))", Transforms.approxScale(Transforms.scaling(4, 1)), 2);
            assertDoubleEq("approx_scale(scaling(4, 1) * rotation(0.4))",
                    Transforms.approxScale(Transforms.scaling(4, 1).multiply(Transforms.rotation(0.4))), 2);
            assertDoubleEq("approx_scale(scaling(9, 1))", Transforms.approxScale(Transforms.scaling(9, 1)), 3);
        });

        scenario("Scale: a shear that preserves area reports 1", () -> {
            assertDoubleEq("approx_scale(shearing(1, 0))", Transforms.approxScale(Transforms.shearing(1, 0)), 1);
            assertDoubleEq("approx_scale(shearing(0.5, 0.5))",
                    Transforms.approxScale(Transforms.shearing(0.5, 0.5)), 0.8660);
        });

        scenario("Scale: a collapsed transform reports 0", () -> {
            assertDoubleEq("approx_scale(scaling(0, 1))", Transforms.approxScale(Transforms.scaling(0, 1)), 0);
            assertDoubleEq("approx_scale(matrix3(1, 2, 0, 2, 4, 0, 0, 0, 1))",
                    Transforms.approxScale(Matrix.matrix3(1, 2, 0, 2, 4, 0, 0, 0, 1)), 0);
        });
    }

    // features/chapter04-shapes.feature
    private static void registerShapes() {
        scenario("Shapes: a segment between pixel centers is a thick line", () -> {
            Shape s = new Segment(Tuple.point(2.5, 2.5), Tuple.point(11.5, 5.5), 1);
            CoverageBuffer cov = Rasterizer.rasterize(s, 16, 10);
            assertDoubleEq("coverage_at(cov, 2, 2)", cov.coverageAt(2, 2), 0.484375);
            assertDoubleEq("coverage_at(cov, 6, 3)", cov.coverageAt(6, 3), 0.6875);
            assertDoubleEq("coverage_at(cov, 7, 3)", cov.coverageAt(7, 3), 0.359375);
            assertDoubleEq("ink(cov)", cov.ink(), 9.4063, 0.0001);
        });

        scenario("Shapes: a segment need not start on a pixel center", () -> {
            Shape s = new Segment(Tuple.point(1, 3.5), Tuple.point(7, 3.5), 1);
            CoverageBuffer cov = Rasterizer.rasterize(s, 10, 10);
            assertDoubleEq("coverage_at(cov, 0, 3)", cov.coverageAt(0, 3), 0);
            assertDoubleEq("coverage_at(cov, 1, 3)", cov.coverageAt(1, 3), 1);
            assertDoubleEq("coverage_at(cov, 6, 3)", cov.coverageAt(6, 3), 1);
            assertDoubleEq("coverage_at(cov, 7, 3)", cov.coverageAt(7, 3), 0);
            assertDoubleEq("coverage_at(cov, 3, 2)", cov.coverageAt(3, 2), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 6);
        });

        scenario("Shapes: a segment of no length is a square", () -> {
            Shape s = new Segment(Tuple.point(3.5, 3.5), Tuple.point(3.5, 3.5), 1);
            CoverageBuffer cov = Rasterizer.rasterize(s, 8, 8);
            assertDoubleEq("coverage_at(cov, 3, 3)", cov.coverageAt(3, 3), 1);
            assertDoubleEq("ink(cov)", cov.ink(), 1);
        });

        scenario("Shapes: a union of nothing is inside nowhere", () -> {
            Shape s = new Union(List.of());
            assertTrue("!inside(s, 0, 0)", !s.inside(0, 0));
            assertDoubleEq("ink(rasterize(s, 4, 4))", Rasterizer.rasterize(s, 4, 4).ink(), 0);
        });

        scenario("Shapes: a union is inside when any of its parts is", () -> {
            Shape s = new Union(List.of(new Circle(2, 2, 1), new Rectangle(5, 0, 7, 4)));
            assertTrue("inside(s, 2, 2)", s.inside(2, 2));
            assertTrue("inside(s, 6, 1)", s.inside(6, 1));
            assertTrue("!inside(s, 4, 2)", !s.inside(4, 2));
            assertDoubleEq("ink(rasterize(s, 8, 8))", Rasterizer.rasterize(s, 8, 8).ink(), 11.25);
        });

        scenario("Shapes: a circle seen through a scale is an ellipse", () -> {
            Shape s = new Transformed(new Circle(0, 0, 4), Transforms.scaling(2, 1));
            assertTrue("inside(s, 7.9, 0)", s.inside(7.9, 0));
            assertTrue("!inside(s, 8.1, 0)", !s.inside(8.1, 0));
            assertTrue("inside(s, 0, 3.9)", s.inside(0, 3.9));
            assertTrue("!inside(s, 0, 4.1)", !s.inside(0, 4.1));
            assertTrue("inside(s, 5.6, 1.4)", s.inside(5.6, 1.4));
            assertTrue("!inside(s, 5.6, 2.9)", !s.inside(5.6, 2.9));
        });

        scenario("Shapes: the transform is applied in the order the matrix says", () -> {
            Shape s = new Transformed(new Circle(0, 0, 4),
                    Transforms.translation(10, 10).multiply(Transforms.scaling(2, 1)));
            assertTrue("inside(s, 10, 10)", s.inside(10, 10));
            assertTrue("inside(s, 17.9, 10)", s.inside(17.9, 10));
            assertTrue("!inside(s, 18.1, 10)", !s.inside(18.1, 10));
            assertTrue("inside(s, 10, 13.9)", s.inside(10, 13.9));
            assertTrue("!inside(s, 10, 14.1)", !s.inside(10, 14.1));
        });

        scenario("Shapes: a shape seen through a collapsed transform is empty", () -> {
            Shape s = new Transformed(new Circle(0, 0, 4), Transforms.scaling(0, 1));
            assertTrue("!inside(s, 0, 0)", !s.inside(0, 0));
            assertDoubleEq("ink(rasterize(s, 10, 10))", Rasterizer.rasterize(s, 10, 10).ink(), 0);
        });

        scenario("Shapes: a pen in shape space scales with the shape", () -> {
            Shape s = new Transformed(new ThickLine(5, 0, 5, 9, 1), Transforms.scaling(3, 1));
            CoverageBuffer cov = Rasterizer.rasterize(s, 24, 10);
            assertDoubleEq("coverage_at(cov, 14, 4)", cov.coverageAt(14, 4), 0);
            assertDoubleEq("coverage_at(cov, 15, 4)", cov.coverageAt(15, 4), 1);
            assertDoubleEq("coverage_at(cov, 16, 4)", cov.coverageAt(16, 4), 1);
            assertDoubleEq("coverage_at(cov, 17, 4)", cov.coverageAt(17, 4), 1);
            assertDoubleEq("coverage_at(cov, 18, 4)", cov.coverageAt(18, 4), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 27);
        });

        scenario("Shapes: a pen in device space does not", () -> {
            Matrix m = Transforms.scaling(3, 1);
            Shape s = new Segment(m.multiply(Tuple.point(5.5, 0.5)), m.multiply(Tuple.point(5.5, 9.5)), 1);
            CoverageBuffer cov = Rasterizer.rasterize(s, 24, 10);
            assertDoubleEq("coverage_at(cov, 15, 4)", cov.coverageAt(15, 4), 0);
            assertDoubleEq("coverage_at(cov, 16, 4)", cov.coverageAt(16, 4), 1);
            assertDoubleEq("coverage_at(cov, 17, 4)", cov.coverageAt(17, 4), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 9);
        });

        scenario("Shapes: dividing the width by approx_scale makes the two pens agree", () -> {
            Matrix m = Transforms.scaling(2, 2);
            Shape s = new Transformed(
                    new Segment(Tuple.point(5.5, 0.5), Tuple.point(5.5, 9.5), 1 / Transforms.approxScale(m)), m);
            CoverageBuffer cov = Rasterizer.rasterize(s, 24, 20);
            assertDoubleEq("coverage_at(cov, 9, 5)", cov.coverageAt(9, 5), 0);
            assertDoubleEq("coverage_at(cov, 10, 5)", cov.coverageAt(10, 5), 0.5);
            assertDoubleEq("coverage_at(cov, 11, 5)", cov.coverageAt(11, 5), 0.5);
            assertDoubleEq("coverage_at(cov, 12, 5)", cov.coverageAt(12, 5), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 18);
        });

        scenario("Shapes: under a non-uniform scale the compromise shows", () -> {
            Matrix m = Transforms.scaling(4, 1);
            double w = 1 / Transforms.approxScale(m);
            Shape v = new Transformed(new Segment(Tuple.point(2.5, 0.5), Tuple.point(2.5, 9.5), w), m);
            Shape h = new Transformed(new Segment(Tuple.point(0.5, 5.5), Tuple.point(4.5, 5.5), w), m);
            CoverageBuffer cv = Rasterizer.rasterize(v, 24, 12);
            CoverageBuffer ch = Rasterizer.rasterize(h, 24, 12);
            assertDoubleEq("coverage_at(cv, 8, 5)", cv.coverageAt(8, 5), 0);
            assertDoubleEq("coverage_at(cv, 9, 5)", cv.coverageAt(9, 5), 1);
            assertDoubleEq("coverage_at(cv, 10, 5)", cv.coverageAt(10, 5), 1);
            assertDoubleEq("coverage_at(cv, 11, 5)", cv.coverageAt(11, 5), 0);
            assertDoubleEq("ink(cv)", cv.ink(), 18);
            assertDoubleEq("coverage_at(ch, 10, 4)", ch.coverageAt(10, 4), 0);
            assertDoubleEq("coverage_at(ch, 10, 5)", ch.coverageAt(10, 5), 0.5);
            assertDoubleEq("coverage_at(ch, 10, 6)", ch.coverageAt(10, 6), 0);
            assertDoubleEq("ink(ch)", ch.ink(), 8);
        });

        scenario("Shapes: an outline is one shape, so its corners are painted once", () -> {
            List<Tuple> pts = List.of(
                    Tuple.point(1.5, 1.5), Tuple.point(6.5, 1.5), Tuple.point(6.5, 6.5), Tuple.point(1.5, 6.5));
            Canvas c = new Canvas(8, 8);
            Painter.paintThrough(c, Rasterizer.rasterize(Shapes.outline(pts, Matrix.identity(), 1), 8, 8),
                    new Color(1, 1, 1));
            assertEquals("length(lit_pixels(c))", Lines.litPixels(c).size(), 20);
            assertTupleColorEq(c, 3, 1, new Color(1, 1, 1));
            assertTupleColorEq(c, 1, 3, new Color(1, 1, 1));
            assertTupleColorEq(c, 1, 1, new Color(0.75, 0.75, 0.75));
            assertTupleColorEq(c, 3, 3, new Color(0, 0, 0));
            assertTupleColorEq(c, 0, 1, new Color(0, 0, 0));
            assertDoubleEq("total_ink(c)", Lines.totalInk(c), 19);
        });

        scenario("Shapes: an outline takes its points through the matrix first", () -> {
            List<Tuple> pts = List.of(
                    Tuple.point(1.5, 1.5), Tuple.point(6.5, 1.5), Tuple.point(6.5, 6.5), Tuple.point(1.5, 6.5));
            Canvas c = new Canvas(16, 16);
            Painter.paintThrough(c,
                    Rasterizer.rasterize(Shapes.outline(pts, Transforms.scaling(2, 2), 1), 16, 16),
                    new Color(1, 1, 1));
            assertEquals("length(lit_pixels(c))", Lines.litPixels(c).size(), 76);
            assertTupleColorEq(c, 3, 3, new Color(0.75, 0.75, 0.75));
            assertTupleColorEq(c, 8, 2, new Color(0.5, 0.5, 0.5));
            assertTupleColorEq(c, 8, 3, new Color(0.5, 0.5, 0.5));
            assertTupleColorEq(c, 8, 4, new Color(0, 0, 0));
        });
    }

    private static void assertTupleColorEq(Canvas c, int x, int y, Color expected) {
        Color actual = c.pixelAt(x, y);
        if (!actual.approxEquals(expected)) {
            throw new AssertionError("pixel_at(c, " + x + ", " + y + "): expected " + expected
                    + " but got " + actual);
        }
    }

    // features/chapter04-plate.feature
    private static void registerPlate() {
        scenario("Plate 4: the fan as points", () -> {
            List<Tuple> pts = Figures.fanPoints();
            assertEquals("length(pts)", pts.size(), 13);
            assertTupleEq("pts[0]", pts.get(0), Tuple.point(0, 0));
            assertTupleEq("pts[1]", pts.get(1), Tuple.point(36, 0));
            assertTupleEq("pts[4]", pts.get(4), Tuple.point(0, 36));
            assertTupleEq("pts[7]", pts.get(7), Tuple.point(-36, 0));
            assertTupleEq("pts[2]", pts.get(2), Tuple.point(31.1769, 18));
        });

        scenario("Plate 4: rotate, then translate: the fan turns about its own center", () -> {
            Matrix m = Transforms.translation(104.5, 76.5).multiply(Transforms.rotation(Math.PI / 6));
            List<Tuple> pts = Shapes.transformPoints(Figures.fanPoints(), m);
            assertTupleEq("pts[0]", pts.get(0), Tuple.point(104.5, 76.5));
            assertTupleEq("pts[1]", pts.get(1), Tuple.point(135.6769, 94.5));
            assertTupleEq("pts[4]", pts.get(4), Tuple.point(86.5, 107.6769));
        });

        scenario("Plate 4: translate, then rotate: the fan swings about the canvas corner", () -> {
            Matrix m = Transforms.rotation(Math.PI / 6).multiply(Transforms.translation(104.5, 76.5));
            List<Tuple> pts = Shapes.transformPoints(Figures.fanPoints(), m);
            assertTupleEq("pts[0]", pts.get(0), Tuple.point(52.2497, 118.5009));
            assertTupleEq("pts[1]", pts.get(1), Tuple.point(83.4266, 136.5009));
        });

        scenario("Plate 4: the letter F", () -> {
            List<Tuple> f = Figures.letterF();
            assertEquals("length(f)", f.size(), 10);
            assertTupleEq("f[0]", f.get(0), Tuple.point(-20, -30));
            assertTupleEq("f[1]", f.get(1), Tuple.point(20, -30));
            assertTupleEq("f[5]", f.get(5), Tuple.point(12, -5));
            assertTupleEq("f[9]", f.get(9), Tuple.point(-20, 30));
        });

        scenario("Plate 4: the F at home", () -> {
            List<Tuple> f = Shapes.transformPoints(Figures.letterF(), Transforms.translation(44.5, 44.5));
            assertTupleEq("f[0]", f.get(0), Tuple.point(24.5, 14.5));
            assertTupleEq("f[1]", f.get(1), Tuple.point(64.5, 14.5));
            assertTupleEq("f[9]", f.get(9), Tuple.point(24.5, 74.5));
        });

        scenario("Plate 4: the F, rotated then translated", () -> {
            Matrix m = Transforms.translation(104.5, 76.5).multiply(Transforms.rotation(Math.PI / 6));
            List<Tuple> f = Shapes.transformPoints(Figures.letterF(), m);
            assertTupleEq("f[0]", f.get(0), Tuple.point(102.1795, 40.5192));
            assertTupleEq("f[1]", f.get(1), Tuple.point(136.8205, 60.5192));
            assertTupleEq("f[5]", f.get(5), Tuple.point(117.3923, 78.1699));
            assertTupleEq("f[9]", f.get(9), Tuple.point(72.1795, 92.4808));
        });

        scenario("Plate 4: the F, translated then rotated", () -> {
            Matrix m = Transforms.rotation(Math.PI / 6).multiply(Transforms.translation(104.5, 76.5));
            List<Tuple> f = Shapes.transformPoints(Figures.letterF(), m);
            assertTupleEq("f[0]", f.get(0), Tuple.point(49.9291, 82.5202));
            assertTupleEq("f[1]", f.get(1), Tuple.point(84.5702, 102.5202));
            assertTupleEq("f[5]", f.get(5), Tuple.point(65.142, 120.1708));
            assertTupleEq("f[9]", f.get(9), Tuple.point(19.9291, 134.4817));
        });

        scenario("Plate 4: side_by_side puts the first canvas on the left", () -> {
            Canvas a = new Canvas(2, 3);
            Canvas b = new Canvas(4, 3);
            a.fill(new Color(1, 0, 0));
            b.fill(new Color(0, 0, 1));
            Canvas c = Figures.sideBySide(a, b);
            assertEquals("c.width", c.width, 6);
            assertEquals("c.height", c.height, 3);
            assertTupleColorEq(c, 0, 0, new Color(1, 0, 0));
            assertTupleColorEq(c, 1, 2, new Color(1, 0, 0));
            assertTupleColorEq(c, 2, 0, new Color(0, 0, 1));
            assertTupleColorEq(c, 5, 2, new Color(0, 0, 1));
        });

        scenario("Plate 4: the fan, both orders", () -> {
            Canvas c = Figures.fanBothOrders();
            byte[] ref = readReference("fan-both-orders.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 160);
            assertTriple("ppm_pixel(p6, 104, 76)", Ppm.ppmPixel(p6, 104, 76), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 124, 76)", Ppm.ppmPixel(p6, 124, 76), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 104, 56)", Ppm.ppmPixel(p6, 104, 56), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 125, 88)", Ppm.ppmPixel(p6, 125, 88), new int[] {236, 236, 231}, 1);
            assertTriple("ppm_pixel(p6, 116, 97)", Ppm.ppmPixel(p6, 116, 97), new int[] {236, 236, 231}, 1);
            assertTriple("ppm_pixel(p6, 141, 76)", Ppm.ppmPixel(p6, 141, 76), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 10, 10)", Ppm.ppmPixel(p6, 10, 10), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 212, 118)", Ppm.ppmPixel(p6, 212, 118), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 232, 118)", Ppm.ppmPixel(p6, 232, 118), new int[] {246, 246, 241}, 1);
            assertTriple("ppm_pixel(p6, 233, 130)", Ppm.ppmPixel(p6, 233, 130), new int[] {223, 223, 219}, 1);
            assertTriple("ppm_pixel(p6, 224, 139)", Ppm.ppmPixel(p6, 224, 139), new int[] {236, 236, 231}, 1);
            assertTriple("ppm_pixel(p6, 200, 139)", Ppm.ppmPixel(p6, 200, 139), new int[] {211, 211, 207}, 1);
            assertTriple("ppm_pixel(p6, 310, 10)", Ppm.ppmPixel(p6, 310, 10), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 4: plate 4", () -> {
            Canvas c = Figures.plate04();
            byte[] ref = readReference("plate-04.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 640);
            assertEquals("c.height", c.height, 320);
            assertTriple("ppm_pixel(p6, 48, 28)", Ppm.ppmPixel(p6, 48, 28), new int[] {99, 99, 102}, 1);
            assertTriple("ppm_pixel(p6, 80, 28)", Ppm.ppmPixel(p6, 80, 28), new int[] {111, 111, 115}, 1);
            assertTriple("ppm_pixel(p6, 48, 100)", Ppm.ppmPixel(p6, 48, 100), new int[] {111, 111, 115}, 1);
            assertTriple("ppm_pixel(p6, 10, 10)", Ppm.ppmPixel(p6, 10, 10), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 200, 150)", Ppm.ppmPixel(p6, 200, 150), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 268, 129)", Ppm.ppmPixel(p6, 268, 129), new int[] {237, 237, 233}, 1);
            assertTriple("ppm_pixel(p6, 215, 145)", Ppm.ppmPixel(p6, 215, 145), new int[] {237, 237, 233}, 1);
            assertTriple("ppm_pixel(p6, 239, 101)", Ppm.ppmPixel(p6, 239, 101), new int[] {237, 237, 233}, 1);
            assertTriple("ppm_pixel(p6, 174, 173)", Ppm.ppmPixel(p6, 174, 173), new int[] {217, 217, 213}, 1);
            assertTriple("ppm_pixel(p6, 368, 28)", Ppm.ppmPixel(p6, 368, 28), new int[] {99, 99, 102}, 1);
            assertTriple("ppm_pixel(p6, 500, 60)", Ppm.ppmPixel(p6, 500, 60), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 453, 207)", Ppm.ppmPixel(p6, 453, 207), new int[] {236, 236, 231}, 1);
            assertTriple("ppm_pixel(p6, 431, 229)", Ppm.ppmPixel(p6, 431, 229), new int[] {234, 234, 229}, 1);
            assertTriple("ppm_pixel(p6, 445, 249)", Ppm.ppmPixel(p6, 445, 249), new int[] {234, 234, 229}, 1);
            assertTriple("ppm_pixel(p6, 368, 273)", Ppm.ppmPixel(p6, 368, 273), new int[] {177, 177, 174}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(Path.of("reference/chapter-04", filename));
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
        writeOne("fan-both-orders.ppm", Figures.fanBothOrders());
        writeOne("plate-04.ppm", Figures.plate04());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
