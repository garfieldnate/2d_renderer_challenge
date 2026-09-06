import '../lib/renderer.dart';
import 'harness.dart';

void runChapter05Tests() {
  // features/chapter05-paths.feature
  feature('chapter05-paths');

  test('An empty path', () {
    final p = path();
    expectEqInt(subpaths(p).length, 0);
    expectEqInt(edges(p).length, 0);
    expectBoundsClose(bounds(p), Bounds(0, 0, 0, 0));
  });

  test('A triangle, closed', () {
    final p = path();
    move_to(p, point(1, 1));
    line_to(p, point(9, 1));
    line_to(p, point(5, 8));
    close(p);
    expectEqInt(subpaths(p).length, 1);
    expectTrue(subpaths(p)[0].closed);
    expectEqInt(subpaths(p)[0].points.length, 3);
    expectTupClose(subpaths(p)[0].points[2], point(5, 8));
    expectEqInt(edges(p).length, 3);
    final e = edges(p)[2];
    expectTupClose(e.a, point(5, 8));
    expectTupClose(e.b, point(1, 1));
    expectBoundsClose(bounds(p), Bounds(1, 1, 9, 8));
  });

  test('A triangle left open still has three edges', () {
    final p = path();
    move_to(p, point(1, 1));
    line_to(p, point(9, 1));
    line_to(p, point(5, 8));
    expectFalse(subpaths(p)[0].closed);
    expectEqInt(edges(p).length, 3);
    final e = edges(p)[2];
    expectTupClose(e.a, point(5, 8));
    expectTupClose(e.b, point(1, 1));
  });

  test('move_to starts a second subpath', () {
    final p = path();
    move_to(p, point(0, 0));
    line_to(p, point(10, 0));
    line_to(p, point(10, 10));
    line_to(p, point(0, 10));
    close(p);
    move_to(p, point(3, 3));
    line_to(p, point(3, 7));
    line_to(p, point(7, 7));
    line_to(p, point(7, 3));
    close(p);
    expectEqInt(subpaths(p).length, 2);
    expectTupClose(subpaths(p)[1].points[0], point(3, 3));
    expectEqInt(edges(p).length, 8);
    expectBoundsClose(bounds(p), Bounds(0, 0, 10, 10));
  });

  test('line_to after a close starts a new subpath where the closed one began', () {
    final p = path();
    move_to(p, point(1, 1));
    line_to(p, point(4, 1));
    line_to(p, point(4, 4));
    close(p);
    line_to(p, point(9, 9));
    expectEqInt(subpaths(p).length, 2);
    expectFalse(subpaths(p)[1].closed);
    expectEqInt(subpaths(p)[1].points.length, 2);
    expectTupClose(subpaths(p)[1].points[0], point(1, 1));
    expectTupClose(subpaths(p)[1].points[1], point(9, 9));
  });

  test('line_to with nothing to extend behaves as move_to', () {
    final p = path();
    line_to(p, point(2, 3));
    expectEqInt(subpaths(p).length, 1);
    expectEqInt(subpaths(p)[0].points.length, 1);
    expectTupClose(subpaths(p)[0].points[0], point(2, 3));
  });

  test('A subpath of one point has no edges, and closing nothing does nothing', () {
    final p = path();
    close(p);
    move_to(p, point(1, 1));
    move_to(p, point(2, 2));
    expectEqInt(subpaths(p).length, 2);
    expectEqInt(edges(p).length, 0);
    expectBoundsClose(bounds(p), Bounds(1, 1, 2, 2));
  });

  test('A subpath of two points has two edges and encloses nothing', () {
    final p = path();
    move_to(p, point(1, 1));
    line_to(p, point(9, 9));
    expectEqInt(edges(p).length, 2);
    expectEqInt(winding_at(p, 3, 5), 0);
  });

  test('polygon is a closed subpath through its points', () {
    final p = polygon([point(0, 0), point(10, 0), point(10, 10), point(0, 10)]);
    expectEqInt(subpaths(p).length, 1);
    expectTrue(subpaths(p)[0].closed);
    expectEqInt(edges(p).length, 4);
  });

  test('circle_path is a polygon standing in for a circle', () {
    final p = circle_path(10, 10, 5, 8);
    expectEqInt(subpaths(p)[0].points.length, 8);
    expectTupClose(subpaths(p)[0].points[0], point(15, 10));
    expectTupClose(subpaths(p)[0].points[1], point(13.5355, 13.5355));
    expectTupClose(subpaths(p)[0].points[2], point(10, 15));
    expectBoundsClose(bounds(p), Bounds(5, 5, 15, 15));
  });

  // features/chapter05-winding.feature
  feature('chapter05-winding');

  test('Crossings from inside and outside a square', () {
    final p = polygon([point(0, 0), point(10, 0), point(10, 10), point(0, 10)]);
    expectEqInt(crossings(p, 5, 5), 1);
    expectEqInt(crossings(p, 15, 5), 0);
    expectEqInt(crossings(p, -1, 5), 2);
  });

  test('A clockwise square winds once', () {
    final p = polygon([point(0, 0), point(10, 0), point(10, 10), point(0, 10)]);
    expectEqInt(winding_at(p, 5, 5), 1);
    expectEqInt(winding_at(p, 15, 5), 0);
    expectEqInt(winding_at(p, -1, 5), 0);
    expectEqInt(winding_at(p, 5, -1), 0);
    expectEqInt(winding_at(p, 5, 11), 0);
  });

  test('The same square the other way round winds minus once', () {
    final p = polygon([point(0, 0), point(0, 10), point(10, 10), point(10, 0)]);
    expectEqInt(winding_at(p, 5, 5), -1);
    expectEqInt(crossings(p, 5, 5), 1);
  });

  test('A ray through a vertex counts it once', () {
    final p = polygon([point(5, 0), point(10, 5), point(5, 10), point(0, 5)]);
    expectEqInt(crossings(p, 2, 5), 1);
    expectEqInt(winding_at(p, 2, 5), 1);
    expectEqInt(crossings(p, -1, 5), 2);
    expectEqInt(winding_at(p, -1, 5), 0);
    expectEqInt(winding_at(p, 12, 5), 0);
    expectEqInt(winding_at(p, 5, 5), 1);
  });

  test('The boundary belongs to the top and the left', () {
    final p = polygon([point(0, 0), point(10, 0), point(10, 10), point(0, 10)]);
    expectEqInt(winding_at(p, 5, 0), 1);
    expectEqInt(winding_at(p, 0, 5), 1);
    expectEqInt(winding_at(p, 0, 0), 1);
    expectEqInt(winding_at(p, 5, 10), 0);
    expectEqInt(winding_at(p, 10, 5), 0);
    expectEqInt(winding_at(p, 10, 10), 0);
  });

  test('Two rectangles that share an edge cover it once', () {
    final p = path();
    move_to(p, point(0, 0));
    line_to(p, point(5, 0));
    line_to(p, point(5, 10));
    line_to(p, point(0, 10));
    close(p);
    move_to(p, point(5, 0));
    line_to(p, point(10, 0));
    line_to(p, point(10, 10));
    line_to(p, point(5, 10));
    close(p);
    expectEqInt(winding_at(p, 2, 5), 1);
    expectEqInt(winding_at(p, 5, 5), 1);
    expectEqInt(winding_at(p, 8, 5), 1);
  });

  test('A diamond wound twice has winding number 2', () {
    final p = path();
    move_to(p, point(5, 0));
    line_to(p, point(10, 5));
    line_to(p, point(5, 10));
    line_to(p, point(0, 5));
    line_to(p, point(5, 0));
    line_to(p, point(10, 5));
    line_to(p, point(5, 10));
    line_to(p, point(0, 5));
    close(p);
    expectEqInt(edges(p).length, 8);
    expectEqInt(winding_at(p, 5, 5), 2);
    expectEqInt(crossings(p, 5, 5), 2);
    expectEqInt(winding_at(p, 12, 5), 0);
  });

  test('The polygon circle', () {
    final p = circle_path(10, 10, 5, 8);
    expectEqInt(winding_at(p, 10, 10), 1);
    expectEqInt(winding_at(p, 14.9, 10), 1);
    expectEqInt(winding_at(p, 15, 10), 0);
    expectEqInt(winding_at(p, 10, 5.1), 1);
    expectEqInt(winding_at(p, 10, 4.9), 0);
  });

  test('The pentagram\'s center winds twice', () {
    final p = star();
    expectEqInt(winding_at(p, 80.5, 80.5), 2);
    expectEqInt(crossings(p, 80.5, 80.5), 2);
    expectEqInt(winding_at(p, 80.5, 20), 1);
    expectEqInt(winding_at(p, 30, 60), 1);
    expectEqInt(crossings(p, 30, 60), 3);
    expectEqInt(winding_at(p, 80.5, 120), 0);
    expectEqInt(crossings(p, 80.5, 120), 2);
    expectEqInt(winding_at(p, 10, 10), 0);
  });

  // features/chapter05-rules.feature
  feature('chapter05-rules');

  test('A single loop is inside under both rules', () {
    final p = polygon([point(0, 0), point(10, 0), point(10, 10), point(0, 10)]);
    expectTrue(inside_nonzero(p, 5, 5));
    expectTrue(inside_evenodd(p, 5, 5));
    expectFalse(inside_nonzero(p, 15, 5));
    expectFalse(inside_evenodd(p, 15, 5));
  });

  test('An inner loop the other way round is a hole under both rules', () {
    final p = path();
    move_to(p, point(0, 0));
    line_to(p, point(10, 0));
    line_to(p, point(10, 10));
    line_to(p, point(0, 10));
    close(p);
    move_to(p, point(3, 3));
    line_to(p, point(3, 7));
    line_to(p, point(7, 7));
    line_to(p, point(7, 3));
    close(p);
    expectEqInt(winding_at(p, 5, 5), 0);
    expectEqInt(winding_at(p, 1, 1), 1);
    expectFalse(inside_nonzero(p, 5, 5));
    expectFalse(inside_evenodd(p, 5, 5));
    expectTrue(inside_nonzero(p, 1, 1));
  });

  test('An inner loop the same way round is a hole only under even-odd', () {
    final p = path();
    move_to(p, point(0, 0));
    line_to(p, point(10, 0));
    line_to(p, point(10, 10));
    line_to(p, point(0, 10));
    close(p);
    move_to(p, point(3, 3));
    line_to(p, point(7, 3));
    line_to(p, point(7, 7));
    line_to(p, point(3, 7));
    close(p);
    expectEqInt(winding_at(p, 5, 5), 2);
    expectTrue(inside_nonzero(p, 5, 5));
    expectFalse(inside_evenodd(p, 5, 5));
  });

  test('A loop wound twice vanishes under even-odd', () {
    final p = path();
    move_to(p, point(5, 0));
    line_to(p, point(10, 5));
    line_to(p, point(5, 10));
    line_to(p, point(0, 5));
    line_to(p, point(5, 0));
    line_to(p, point(10, 5));
    line_to(p, point(5, 10));
    line_to(p, point(0, 5));
    close(p);
    expectTrue(inside_nonzero(p, 5, 5));
    expectFalse(inside_evenodd(p, 5, 5));
  });

  test('The pentagram\'s center is inside under nonzero and outside under even-odd', () {
    final p = star();
    expectTrue(inside_nonzero(p, 80.5, 80.5));
    expectFalse(inside_evenodd(p, 80.5, 80.5));
    expectTrue(inside_nonzero(p, 80.5, 20));
    expectTrue(inside_evenodd(p, 80.5, 20));
    expectFalse(inside_nonzero(p, 80.5, 120));
    expectFalse(inside_evenodd(p, 80.5, 120));
  });

  test('A filled path is a shape', () {
    final s = filled(polygon([point(2, 2), point(6, 2), point(6, 6), point(2, 6)]), 'nonzero');
    final cov = rasterize(s, 8, 8);
    expectTrue(inside(s, 3, 3));
    expectFalse(inside(s, 7, 3));
    expectClose(coverage_at(cov, 3, 3), 1);
    expectClose(coverage_at(cov, 1, 3), 0);
    expectClose(coverage_at(cov, 6, 3), 0);
    expectClose(ink(cov), 16);
  });

  test('A filled path takes the rule seriously', () {
    final p = star();
    final a = filled(p, 'nonzero');
    final b = filled(p, 'evenodd');
    final ca = rasterize(a, 160, 160);
    final cb = rasterize(b, 160, 160);
    expectClose(coverage_at(ca, 80, 80), 1);
    expectClose(coverage_at(cb, 80, 80), 0);
    expectClose(coverage_at(ca, 80, 20), 1);
    expectClose(coverage_at(cb, 80, 20), 1);
    expectClose(coverage_at(ca, 80, 10), 0.0625);
    expectClose(coverage_at(cb, 80, 10), 0.0625);
    expectClose(ink(ca), 5499.9375);
    expectClose(ink(cb), 3800.375);
  });

  test('Rasterizing within the bounds gives the same coverage', () {
    final p = star();
    final s = filled(p, 'evenodd');
    final full = rasterize(s, 160, 160);
    final within = rasterize_within(s, bounds(p), 160, 160);
    expectClose(ink(within), ink(full));
    expectClose(coverage_at(within, 80, 20), coverage_at(full, 80, 20));
    expectClose(coverage_at(within, 13, 58), coverage_at(full, 13, 58));
    expectClose(coverage_at(within, 10, 10), 0);
  });

  test('The box is inclusive of the pixels it touches, and clipped to the buffer', () {
    final s = filled(
        polygon([point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)]), 'nonzero');
    final cov = rasterize_within(s, Bounds(1.5, 1.5, 6.5, 6.5), 8, 8);
    final big = rasterize_within(s, Bounds(-5, -5, 20, 20), 8, 8);
    expectClose(coverage_at(cov, 1, 1), 0.25);
    expectClose(coverage_at(cov, 6, 6), 0.25);
    expectClose(coverage_at(cov, 3, 3), 1);
    expectClose(ink(cov), 25);
    expectClose(ink(big), 25);
  });

  // features/chapter05-plate.feature
  feature('chapter05-plate');

  test('The pentagram', () {
    final p = star();
    expectEqInt(subpaths(p).length, 1);
    expectEqInt(edges(p).length, 5);
    expectTupClose(subpaths(p)[0].points[0], point(80.5, 10.5));
    expectTupClose(subpaths(p)[0].points[1], point(121.645, 137.1312));
    expectTupClose(subpaths(p)[0].points[2], point(13.926, 58.8688));
    expectTupClose(subpaths(p)[0].points[3], point(147.074, 58.8688));
    expectTupClose(subpaths(p)[0].points[4], point(39.355, 137.1312));
    expectBoundsClose(bounds(p), Bounds(13.926, 10.5, 147.074, 137.1312));
  });

  test('The star by the center question', () {
    final c = star_centers();
    final ref = read_file('reference/chapter-05/star-centers.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 320);
    expectEqInt(c.height, 160);
    expectRgb(ppm_pixel(p6, 80, 80), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 240, 80), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 80, 20), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 240, 20), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 30, 60), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 190, 60), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 80, 120), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 80, 10), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 10, 10), 39, 39, 44, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });

  test('The star by coverage', () {
    final c = star_coverage();
    final ref = read_file('reference/chapter-05/star-coverage.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 320);
    expectEqInt(c.height, 160);
    expectRgb(ppm_pixel(p6, 80, 80), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 240, 80), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 80, 20), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 240, 20), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 80, 120), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 80, 10), 77, 65, 48, 1);
    expectRgb(ppm_pixel(p6, 240, 10), 77, 65, 48, 1);
    expectRgb(ppm_pixel(p6, 80, 11), 199, 160, 76, 1);
    expectRgb(ppm_pixel(p6, 14, 58), 101, 83, 52, 1);
    expectRgb(ppm_pixel(p6, 174, 58), 101, 83, 52, 1);
    expectRgb(ppm_pixel(p6, 10, 10), 39, 39, 44, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });

  test('Plate 5', () {
    final c = plate_05();
    final ref = read_file('reference/chapter-05/plate-05.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 640);
    expectEqInt(c.height, 640);
    expectRgb(ppm_pixel(p6, 160, 160), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 480, 160), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 160, 480), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 480, 480), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 160, 40), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 480, 360), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 160, 20), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 160, 341), 77, 65, 48, 1);
    expectRgb(ppm_pixel(p6, 480, 341), 77, 65, 48, 1);
    expectRgb(ppm_pixel(p6, 348, 437), 101, 83, 52, 1);
    expectRgb(ppm_pixel(p6, 20, 20), 39, 39, 44, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });
}
