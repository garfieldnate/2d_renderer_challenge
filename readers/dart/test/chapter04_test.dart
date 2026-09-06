import 'dart:math' as math;
import '../lib/renderer.dart';
import 'harness.dart';

void runChapter04Tests() {
  // features/chapter04-tuples.feature
  feature('chapter04-tuples');

  test('A point has w = 1', () {
    final p = point(4, -4);
    expectClose(p.x, 4);
    expectClose(p.y, -4);
    expectClose(p.w, 1);
  });

  test('A vector has w = 0', () {
    final v = vector(4, -4);
    expectClose(v.x, 4);
    expectClose(v.y, -4);
    expectClose(v.w, 0);
  });

  test('The difference of two points is the vector between them', () {
    final a = point(3, 2);
    final b = point(5, 6);
    expectTupClose(b - a, vector(2, 4));
    expectTupClose(a - b, vector(-2, -4));
  });

  test('A point plus a vector is a point', () {
    final p = point(3, -2);
    final v = vector(-2, 3);
    expectTupClose(p + v, point(1, 1));
    expectTupClose(p - v, point(5, -5));
  });

  test('A vector plus a vector is a vector', () {
    final a = vector(3, -2);
    final b = vector(-2, 3);
    expectTupClose(a + b, vector(1, 1));
    expectTupClose(a - b, vector(5, -5));
  });

  test('Negating, scaling and dividing a vector', () {
    final v = vector(1, -2);
    expectTupClose(-v, vector(-1, 2));
    expectTupClose(v * 3.5, vector(3.5, -7));
    expectTupClose(v * 0.5, vector(0.5, -1));
    expectTupClose(v / 2, vector(0.5, -1));
  });

  test('The magnitude of a vector', () {
    expectClose(magnitude(vector(1, 0)), 1);
    expectClose(magnitude(vector(0, 1)), 1);
    expectClose(magnitude(vector(3, 4)), 5);
    expectClose(magnitude(vector(-3, -4)), 5);
    expectClose(magnitude(vector(-1, -2)), 2.2361);
  });

  test('Normalizing a vector', () {
    expectTupClose(normalize(vector(4, 0)), vector(1, 0));
    expectTupClose(normalize(vector(1, 2)), vector(0.4472, 0.8944));
    expectClose(magnitude(normalize(vector(1, 2))), 1);
  });

  test('The dot product of two vectors', () {
    final a = vector(1, 2);
    final b = vector(2, 3);
    expectClose(dot(a, b), 8);
    expectClose(dot(a, vector(-2, 1)), 0);
  });

  test('magnitude and dot look at x and y only', () {
    expectClose(magnitude(point(3, 4)), 5);
    expectClose(dot(point(1, 2), point(2, 3)), 8);
  });

  test('The cross product of two vectors is a number', () {
    final a = vector(1, 0);
    final b = vector(0, 1);
    expectClose(cross(a, b), 1);
    expectClose(cross(b, a), -1);
    expectClose(cross(a, a), 0);
    expectClose(cross(vector(2, 3), vector(4, 5)), -2);
  });

  test('The sign of the cross product says which side of a line a point is on', () {
    final a = point(0, 0);
    final b = point(10, 0);
    expectClose(cross(b - a, point(5, 3) - a), 30);
    expectClose(cross(b - a, point(5, -3) - a), -30);
    expectClose(cross(b - a, point(20, 0) - a), 0);
  });

  // features/chapter04-matrices.feature
  feature('chapter04-matrices');

  test('Constructing and inspecting a matrix', () {
    final M = matrixFromRows([
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9],
    ]);
    expectClose(M.at(0, 0), 1);
    expectClose(M.at(0, 2), 3);
    expectClose(M.at(1, 0), 4);
    expectClose(M.at(1, 1), 5);
    expectClose(M.at(2, 0), 7);
    expectClose(M.at(2, 2), 9);
    expectMatrixClose(M, matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9));
  });

  test('Matrix equality with identical matrices', () {
    final A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
    final B = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
    expectMatrixClose(A, B);
  });

  test('Matrix equality with different matrices', () {
    final A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
    final B = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 8);
    expectFalse(matricesClose(A, B));
  });

  test('Multiplying two matrices', () {
    final A = matrixFromRows([
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9],
    ]);
    final B = matrixFromRows([
      [2, -1, 0],
      [1, 3, 1],
      [0, 1, 2],
    ]);
    final product = (A * B) as Matrix3;
    expectMatrixClose(
        product,
        matrixFromRows([
          [4, 8, 8],
          [13, 17, 17],
          [22, 26, 26],
        ]));
  });

  test('Matrix multiplication is not commutative', () {
    final A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
    final B = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
    expectFalse(matricesClose(A * B as Matrix3, B * A as Matrix3));
  });

  test('A matrix multiplied by a point', () {
    final A = matrixFromRows([
      [1, 2, 3],
      [4, 5, 6],
      [0, 0, 1],
    ]);
    final p = point(1, 2);
    expectTupClose(A * p as Tup, point(8, 20));
  });

  test('A matrix multiplied by a vector ignores the last column', () {
    final A = matrixFromRows([
      [1, 2, 3],
      [4, 5, 6],
      [0, 0, 1],
    ]);
    final v = vector(1, 2);
    expectTupClose(A * v as Tup, vector(5, 14));
  });

  test('Multiplying by the identity matrix changes nothing', () {
    final A = matrix3(0, 1, 2, 1, 2, 4, 2, 4, 8);
    final p = point(1, 2);
    expectMatrixClose(A * identity() as Matrix3, A);
    expectMatrixClose(identity() * A as Matrix3, A);
    expectTupClose(identity() * p as Tup, p);
  });

  test('Transposing a matrix', () {
    final A = matrixFromRows([
      [0, 9, 3],
      [9, 8, 0],
      [1, 8, 5],
    ]);
    expectMatrixClose(
        transpose(A),
        matrixFromRows([
          [0, 9, 1],
          [9, 8, 8],
          [3, 0, 5],
        ]));
  });

  test('Transposing the identity matrix', () {
    expectMatrixClose(transpose(identity()), identity());
  });

  test('The determinant of a 3 by 3 matrix', () {
    final A = matrixFromRows([
      [1, 2, 6],
      [-5, 8, -4],
      [2, 6, 4],
    ]);
    expectClose(determinant(A), -196);
  });

  test('The determinant of a transform is the area factor', () {
    expectClose(determinant(identity()), 1);
    expectClose(determinant(scaling(2, 3)), 6);
    expectClose(determinant(rotation(0.7)), 1);
    expectClose(determinant(translation(4, 9)), 1);
    expectClose(determinant(scaling(-1, 1)), -1);
  });

  test('Testing an invertible matrix for invertibility', () {
    final A = matrixFromRows([
      [3, 0, 2],
      [2, 0, -2],
      [0, 1, 1],
    ]);
    expectClose(determinant(A), 10);
    expectTrue(is_invertible(A));
  });

  test('Testing a non-invertible matrix for invertibility', () {
    final A = matrixFromRows([
      [1, 2, 3],
      [2, 4, 6],
      [0, 0, 1],
    ]);
    expectClose(determinant(A), 0);
    expectFalse(is_invertible(A));
  });

  test('Invertibility is an exact test against zero', () {
    expectTrue(is_invertible(scaling(0.0001, 1)));
    expectClose(determinant(scaling(0.0001, 1)), 0.0001);
    expectTupClose(inverse(scaling(0.0001, 1)) * point(0.0001, 3) as Tup, point(1, 3));
  });

  test('Calculating the inverse of a matrix', () {
    final A = matrixFromRows([
      [3, 0, 2],
      [2, 0, -2],
      [0, 1, 1],
    ]);
    final B = inverse(A);
    expectClose(B.at(0, 0), 0.2);
    expectClose(B.at(1, 2), 1);
    expectClose(B.at(2, 1), -0.3);
    expectMatrixClose(
        B,
        matrixFromRows([
          [0.2, 0.2, 0],
          [-0.2, 0.3, 1],
          [0.2, -0.3, 0],
        ]));
    expectMatrixClose(A * B as Matrix3, identity());
  });

  test('Multiplying a product by its inverse', () {
    final A = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
    final B = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
    final C = A * B as Matrix3;
    expectMatrixClose(C * inverse(B) as Matrix3, A);
  });

  test('The inverse of a transform is a transform', () {
    final A = translation(5, -3) * rotation(math.pi / 6) as Matrix3;
    final A2 = A * scaling(2, 3) as Matrix3;
    final B = inverse(A2);
    expectClose(B.at(2, 0), 0);
    expectClose(B.at(2, 1), 0);
    expectClose(B.at(2, 2), 1);
    expectClose(B.at(0, 0), 0.4330);
    expectClose(B.at(0, 2), -1.4151);
    expectClose(B.at(1, 2), 1.6994);
    expectMatrixClose(B * A2 as Matrix3, identity());
  });

  // features/chapter04-transforms.feature
  feature('chapter04-transforms');

  test('Multiplying by a translation matrix', () {
    final t = translation(5, -3);
    final p = point(-3, 4);
    expectTupClose(t * p as Tup, point(2, 1));
  });

  test('The inverse of a translation moves the other way', () {
    final t = translation(5, -3);
    final p = point(-3, 4);
    expectTupClose(inverse(t) * p as Tup, point(-8, 7));
  });

  test('Translation does not affect vectors', () {
    final t = translation(5, -3);
    final v = vector(-3, 4);
    expectTupClose(t * v as Tup, v);
  });

  test('A scaling matrix applied to a point', () {
    final s = scaling(2, 3);
    final p = point(-4, 6);
    expectTupClose(s * p as Tup, point(-8, 18));
  });

  test('A scaling matrix applied to a vector', () {
    final s = scaling(2, 3);
    final v = vector(-4, 6);
    expectTupClose(s * v as Tup, vector(-8, 18));
  });

  test('The inverse of a scaling shrinks', () {
    final s = scaling(2, 3);
    final v = vector(-4, 6);
    expectTupClose(inverse(s) * v as Tup, vector(-2, 2));
  });

  test('Reflection is scaling by a negative value', () {
    final s = scaling(-1, 1);
    final p = point(2, 3);
    expectTupClose(s * p as Tup, point(-2, 3));
  });

  test('A positive rotation turns x toward y', () {
    final p = point(1, 0);
    expectTupClose(rotation(math.pi / 4) * p as Tup, point(0.7071, 0.7071));
    expectTupClose(rotation(math.pi / 2) * p as Tup, point(0, 1));
    expectTupClose(rotation(math.pi) * p as Tup, point(-1, 0));
  });

  test('The inverse of a rotation turns the other way', () {
    final p = point(1, 0);
    expectTupClose(inverse(rotation(math.pi / 4)) * p as Tup, point(0.7071, -0.7071));
    expectTupClose(rotation(-math.pi / 4) * p as Tup, point(0.7071, -0.7071));
  });

  test('A rotation preserves length', () {
    final v = vector(3, 4);
    expectClose(magnitude(rotation(1.2) * v as Tup), 5);
    expectClose(magnitude(rotation(-2.8) * v as Tup), 5);
  });

  test('Shearing moves x in proportion to y', () {
    final s = shearing(1, 0);
    final p = point(2, 3);
    expectTupClose(s * p as Tup, point(5, 3));
  });

  test('Shearing moves y in proportion to x', () {
    final s = shearing(0, 1);
    final p = point(2, 3);
    expectTupClose(s * p as Tup, point(2, 5));
  });

  test('Individual transformations are applied in sequence', () {
    final p = point(1, 0);
    final A = rotation(math.pi / 2);
    final B = scaling(5, 5);
    final C = translation(10, 5);
    final p2 = A * p as Tup;
    final p3 = B * p2 as Tup;
    final p4 = C * p3 as Tup;
    expectTupClose(p2, point(0, 1));
    expectTupClose(p3, point(0, 5));
    expectTupClose(p4, point(10, 10));
  });

  test('Chained transformations must be applied in reverse order', () {
    final p = point(1, 0);
    final A = rotation(math.pi / 2);
    final B = scaling(5, 5);
    final C = translation(10, 5);
    final T = mmAll([C, B, A]);
    expectTupClose(T * p as Tup, point(10, 10));
  });

  test('The other order is a different transform', () {
    final p = point(1, 0);
    final A = rotation(math.pi / 2);
    final B = scaling(5, 5);
    final C = translation(10, 5);
    final T = mmAll([A, B, C]);
    expectTupClose(T * p as Tup, point(-25, 55));
  });

  test('Rotating about a point that isn\'t the origin', () {
    final T = mmAll([translation(4, 4), rotation(math.pi / 2), translation(-4, -4)]);
    expectTupClose(T * point(6, 4) as Tup, point(4, 6));
    expectTupClose(T * point(4, 4) as Tup, point(4, 4));
  });

  // features/chapter04-scale.feature
  feature('chapter04-scale');

  test('The identity, a translation and a rotation don\'t stretch', () {
    expectClose(approx_scale(identity()), 1);
    expectClose(approx_scale(translation(7, 9)), 1);
    expectClose(approx_scale(rotation(1.1)), 1);
  });

  test('A uniform scale is reported exactly', () {
    expectClose(approx_scale(scaling(2, 2)), 2);
    expectClose(approx_scale(scaling(0.5, 0.5)), 0.5);
    expectClose(approx_scale(scaling(3, 3) * rotation(0.7) as Matrix3), 3);
    expectClose(approx_scale(translation(5, 5) * scaling(3, 3) as Matrix3), 3);
  });

  test('A reflection is not a negative scale', () {
    expectClose(approx_scale(scaling(-2, 2)), 2);
  });

  test('A non-uniform scale is reported as the geometric mean', () {
    expectClose(approx_scale(scaling(4, 1)), 2);
    expectClose(approx_scale(scaling(4, 1) * rotation(0.4) as Matrix3), 2);
    expectClose(approx_scale(scaling(9, 1)), 3);
  });

  test('A shear that preserves area reports 1', () {
    expectClose(approx_scale(shearing(1, 0)), 1);
    expectClose(approx_scale(shearing(0.5, 0.5)), 0.8660);
  });

  test('A collapsed transform reports 0', () {
    expectClose(approx_scale(scaling(0, 1)), 0);
    expectClose(approx_scale(matrix3(1, 2, 0, 2, 4, 0, 0, 0, 1)), 0);
  });

  // features/chapter04-drawing.feature
  feature('chapter04-drawing');

  test('A segment between pixel centers is a thick line', () {
    final s = segment(point(2.5, 2.5), point(11.5, 5.5), 1);
    final cov = rasterize(s, 16, 10);
    expectClose(coverage_at(cov, 2, 2), 0.484375);
    expectClose(coverage_at(cov, 11, 5), 0.484375);
    expectClose(coverage_at(cov, 6, 3), 0.6875);
    expectClose(coverage_at(cov, 7, 3), 0.359375);
    expectClose(coverage_at(cov, 2, 1), 0);
    expectClose(ink(cov), 9.4063);
  });

  test('A segment need not start on a pixel center', () {
    final s = segment(point(1, 3.5), point(7, 3.5), 1);
    final cov = rasterize(s, 10, 10);
    expectClose(coverage_at(cov, 0, 3), 0);
    expectClose(coverage_at(cov, 1, 3), 1);
    expectClose(coverage_at(cov, 6, 3), 1);
    expectClose(coverage_at(cov, 7, 3), 0);
    expectClose(coverage_at(cov, 3, 2), 0);
    expectClose(ink(cov), 6);
  });

  test('A segment of no length is a square', () {
    final s = segment(point(3.5, 3.5), point(3.5, 3.5), 1);
    final cov = rasterize(s, 8, 8);
    expectClose(coverage_at(cov, 3, 3), 1);
    expectClose(ink(cov), 1);
  });

  test('A union of nothing is inside nowhere', () {
    final s = union([]);
    expectFalse(inside(s, 0, 0));
    expectClose(ink(rasterize(s, 4, 4)), 0);
  });

  test('A union is inside when any of its parts is', () {
    final s = union([circle(2, 2, 1), rectangle(5, 0, 7, 4)]);
    expectTrue(inside(s, 2, 2));
    expectTrue(inside(s, 6, 1));
    expectFalse(inside(s, 4, 2));
    expectClose(ink(rasterize(s, 8, 8)), 11.25);
  });

  test('A circle seen through a scale is an ellipse', () {
    final s = transformed(circle(0, 0, 4), scaling(2, 1));
    expectTrue(inside(s, 7.9, 0));
    expectFalse(inside(s, 8.1, 0));
    expectTrue(inside(s, 0, 3.9));
    expectFalse(inside(s, 0, 4.1));
    expectTrue(inside(s, 5.6, 1.4));
    expectFalse(inside(s, 5.6, 2.9));
  });

  test('The transform is applied in the order the matrix says', () {
    final s = transformed(circle(0, 0, 4), translation(10, 10) * scaling(2, 1) as Matrix3);
    expectTrue(inside(s, 10, 10));
    expectTrue(inside(s, 17.9, 10));
    expectFalse(inside(s, 18.1, 10));
    expectTrue(inside(s, 10, 13.9));
    expectFalse(inside(s, 10, 14.1));
  });

  test('A shape seen through a collapsed transform is empty', () {
    final s = transformed(circle(0, 0, 4), scaling(0, 1));
    expectFalse(inside(s, 0, 0));
    expectClose(ink(rasterize(s, 10, 10)), 0);
  });

  test('A pen in shape space scales with the shape', () {
    final s = transformed(thick_line(5, 0, 5, 9, 1), scaling(3, 1));
    final cov = rasterize(s, 24, 10);
    expectClose(coverage_at(cov, 14, 4), 0);
    expectClose(coverage_at(cov, 15, 4), 1);
    expectClose(coverage_at(cov, 16, 4), 1);
    expectClose(coverage_at(cov, 17, 4), 1);
    expectClose(coverage_at(cov, 18, 4), 0);
    expectClose(ink(cov), 27);
  });

  test('A pen in device space does not', () {
    final m = scaling(3, 1);
    final s = segment(m * point(5.5, 0.5) as Tup, m * point(5.5, 9.5) as Tup, 1);
    final cov = rasterize(s, 24, 10);
    expectClose(coverage_at(cov, 15, 4), 0);
    expectClose(coverage_at(cov, 16, 4), 1);
    expectClose(coverage_at(cov, 17, 4), 0);
    expectClose(ink(cov), 9);
  });

  test('Dividing the width by approx_scale makes the two pens agree', () {
    final m = scaling(2, 2);
    final s = transformed(segment(point(5.5, 0.5), point(5.5, 9.5), 1 / approx_scale(m)), m);
    final cov = rasterize(s, 24, 20);
    expectClose(coverage_at(cov, 9, 5), 0);
    expectClose(coverage_at(cov, 10, 5), 0.5);
    expectClose(coverage_at(cov, 11, 5), 0.5);
    expectClose(coverage_at(cov, 12, 5), 0);
    expectClose(ink(cov), 18);
  });

  test('Under a non-uniform scale the compromise shows', () {
    final m = scaling(4, 1);
    final w = 1 / approx_scale(m);
    final v = transformed(segment(point(2.5, 0.5), point(2.5, 9.5), w), m);
    final h = transformed(segment(point(0.5, 5.5), point(4.5, 5.5), w), m);
    final cv = rasterize(v, 24, 12);
    final ch = rasterize(h, 24, 12);
    expectClose(coverage_at(cv, 8, 5), 0);
    expectClose(coverage_at(cv, 9, 5), 1);
    expectClose(coverage_at(cv, 10, 5), 1);
    expectClose(coverage_at(cv, 11, 5), 0);
    expectClose(ink(cv), 18);
    expectClose(coverage_at(ch, 10, 4), 0);
    expectClose(coverage_at(ch, 10, 5), 0.5);
    expectClose(coverage_at(ch, 10, 6), 0);
    expectClose(ink(ch), 8);
  });

  test('An outline is one shape, so its corners are painted once', () {
    final pts = [point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)];
    final c = canvas(8, 8);
    paint_through(c, rasterize(outline(pts, identity(), 1), 8, 8), color(1, 1, 1));
    expectEqInt(lit_pixels(c).length, 20);
    expectColorClose(pixel_at(c, 3, 1), color(1, 1, 1));
    expectColorClose(pixel_at(c, 1, 3), color(1, 1, 1));
    expectColorClose(pixel_at(c, 1, 1), color(0.75, 0.75, 0.75));
    expectColorClose(pixel_at(c, 3, 3), color(0, 0, 0));
    expectColorClose(pixel_at(c, 0, 1), color(0, 0, 0));
    expectClose(total_ink(c), 19);
  });

  test('An outline takes its points through the matrix first', () {
    final pts = [point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)];
    final c = canvas(16, 16);
    paint_through(c, rasterize(outline(pts, scaling(2, 2), 1), 16, 16), color(1, 1, 1));
    expectEqInt(lit_pixels(c).length, 76);
    expectColorClose(pixel_at(c, 3, 3), color(0.75, 0.75, 0.75));
    expectColorClose(pixel_at(c, 8, 2), color(0.5, 0.5, 0.5));
    expectColorClose(pixel_at(c, 8, 3), color(0.5, 0.5, 0.5));
    expectColorClose(pixel_at(c, 8, 4), color(0, 0, 0));
  });

  // features/chapter04-plate.feature
  feature('chapter04-plate');

  test('The fan as points', () {
    final pts = fan_points();
    expectEqInt(pts.length, 13);
    expectTupClose(pts[0], point(0, 0));
    expectTupClose(pts[1], point(36, 0));
    expectTupClose(pts[4], point(0, 36));
    expectTupClose(pts[7], point(-36, 0));
    expectTupClose(pts[2], point(31.1769, 18));
  });

  test('Rotate, then translate: the fan turns about its own center', () {
    final m = translation(104.5, 76.5) * rotation(math.pi / 6) as Matrix3;
    final pts = transform_points(fan_points(), m);
    expectTupClose(pts[0], point(104.5, 76.5));
    expectTupClose(pts[1], point(135.6769, 94.5));
    expectTupClose(pts[4], point(86.5, 107.6769));
  });

  test('Translate, then rotate: the fan swings about the canvas corner', () {
    final m = rotation(math.pi / 6) * translation(104.5, 76.5) as Matrix3;
    final pts = transform_points(fan_points(), m);
    expectTupClose(pts[0], point(52.2497, 118.5009));
    expectTupClose(pts[1], point(83.4266, 136.5009));
  });

  test('The letter F', () {
    final f = letter_f();
    expectEqInt(f.length, 10);
    expectTupClose(f[0], point(-20, -30));
    expectTupClose(f[1], point(20, -30));
    expectTupClose(f[5], point(12, -5));
    expectTupClose(f[9], point(-20, 30));
  });

  test('The F at home', () {
    final f = transform_points(letter_f(), translation(44.5, 44.5));
    expectTupClose(f[0], point(24.5, 14.5));
    expectTupClose(f[1], point(64.5, 14.5));
    expectTupClose(f[9], point(24.5, 74.5));
  });

  test('The F, rotated then translated', () {
    final m = translation(104.5, 76.5) * rotation(math.pi / 6) as Matrix3;
    final f = transform_points(letter_f(), m);
    expectTupClose(f[0], point(102.1795, 40.5192));
    expectTupClose(f[1], point(136.8205, 60.5192));
    expectTupClose(f[5], point(117.3923, 78.1699));
    expectTupClose(f[9], point(72.1795, 92.4808));
  });

  test('The F, translated then rotated', () {
    final m = rotation(math.pi / 6) * translation(104.5, 76.5) as Matrix3;
    final f = transform_points(letter_f(), m);
    expectTupClose(f[0], point(49.9291, 82.5202));
    expectTupClose(f[1], point(84.5702, 102.5202));
    expectTupClose(f[5], point(65.142, 120.1708));
    expectTupClose(f[9], point(19.9291, 134.4817));
  });

  test('side_by_side puts the first canvas on the left', () {
    final a = canvas(2, 3);
    final b = canvas(4, 3);
    fill(a, color(1, 0, 0));
    fill(b, color(0, 0, 1));
    final c = side_by_side(a, b);
    expectEqInt(c.width, 6);
    expectEqInt(c.height, 3);
    expectColorClose(pixel_at(c, 0, 0), color(1, 0, 0));
    expectColorClose(pixel_at(c, 1, 2), color(1, 0, 0));
    expectColorClose(pixel_at(c, 2, 0), color(0, 0, 1));
    expectColorClose(pixel_at(c, 5, 2), color(0, 0, 1));
  });

  test('The fan, both orders', () {
    final c = fan_both_orders();
    final ref = read_file('reference/chapter-04/fan-both-orders.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 320);
    expectEqInt(c.height, 160);
    expectRgb(ppm_pixel(p6, 104, 76), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 124, 76), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 104, 56), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 125, 88), 236, 236, 231, 1);
    expectRgb(ppm_pixel(p6, 116, 97), 236, 236, 231, 1);
    expectRgb(ppm_pixel(p6, 141, 76), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 10, 10), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 212, 118), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 232, 118), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 233, 130), 223, 223, 219, 1);
    expectRgb(ppm_pixel(p6, 224, 139), 236, 236, 231, 1);
    expectRgb(ppm_pixel(p6, 200, 139), 211, 211, 207, 1);
    expectRgb(ppm_pixel(p6, 310, 10), 39, 39, 44, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });

  test('Plate 4', () {
    final c = plate_04();
    final ref = read_file('reference/chapter-04/plate-04.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 640);
    expectEqInt(c.height, 320);
    expectRgb(ppm_pixel(p6, 48, 28), 99, 99, 102, 1);
    expectRgb(ppm_pixel(p6, 80, 28), 111, 111, 115, 1);
    expectRgb(ppm_pixel(p6, 48, 100), 111, 111, 115, 1);
    expectRgb(ppm_pixel(p6, 10, 10), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 200, 150), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 268, 129), 237, 237, 233, 1);
    expectRgb(ppm_pixel(p6, 215, 145), 237, 237, 233, 1);
    expectRgb(ppm_pixel(p6, 239, 101), 237, 237, 233, 1);
    expectRgb(ppm_pixel(p6, 174, 173), 217, 217, 213, 1);
    expectRgb(ppm_pixel(p6, 368, 28), 99, 99, 102, 1);
    expectRgb(ppm_pixel(p6, 500, 60), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 453, 207), 236, 236, 231, 1);
    expectRgb(ppm_pixel(p6, 431, 229), 234, 234, 229, 1);
    expectRgb(ppm_pixel(p6, 445, 249), 234, 234, 229, 1);
    expectRgb(ppm_pixel(p6, 368, 273), 177, 177, 174, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });
}
