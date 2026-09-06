import '../lib/renderer.dart';
import 'harness.dart';

void runChapter03Tests() {
  // features/chapter03-bresenham.feature
  feature('chapter03-bresenham');

  test('lit_pixels reads like a page', () {
    final c = canvas(10, 10);
    write_pixel(c, 5, 0, color(1, 1, 1));
    write_pixel(c, 0, 2, color(1, 1, 1));
    write_pixel(c, 2, 2, color(0.5, 0, 0));
    expectIntPoints(lit_pixels(c), [IntPoint(5, 0), IntPoint(0, 2), IntPoint(2, 2)]);
  });

  test('A diagonal', () {
    final c = canvas(10, 10);
    line_bresenham(c, 0, 0, 5, 5, color(1, 1, 1));
    expectIntPoints(lit_pixels(c),
        [IntPoint(0, 0), IntPoint(1, 1), IntPoint(2, 2), IntPoint(3, 3), IntPoint(4, 4), IntPoint(5, 5)]);
  });

  test('A horizontal line lights one row and nothing else', () {
    final c = canvas(10, 10);
    line_bresenham(c, 0, 3, 7, 3, color(1, 1, 1));
    expectIntPoints(lit_pixels(c), [
      IntPoint(0, 3),
      IntPoint(1, 3),
      IntPoint(2, 3),
      IntPoint(3, 3),
      IntPoint(4, 3),
      IntPoint(5, 3),
      IntPoint(6, 3),
      IntPoint(7, 3),
    ]);
  });

  test('A shallow line steps along x', () {
    final c = canvas(10, 10);
    line_bresenham(c, 0, 0, 7, 3, color(1, 1, 1));
    expectIntPoints(lit_pixels(c), [
      IntPoint(0, 0),
      IntPoint(1, 0),
      IntPoint(2, 1),
      IntPoint(3, 1),
      IntPoint(4, 2),
      IntPoint(5, 2),
      IntPoint(6, 3),
      IntPoint(7, 3),
    ]);
  });

  test('A steep line steps along y', () {
    final c = canvas(10, 10);
    line_bresenham(c, 1, 1, 3, 7, color(1, 1, 1));
    expectIntPoints(lit_pixels(c), [
      IntPoint(1, 1),
      IntPoint(1, 2),
      IntPoint(2, 3),
      IntPoint(2, 4),
      IntPoint(2, 5),
      IntPoint(3, 6),
      IntPoint(3, 7),
    ]);
  });

  test('The pixels don\'t depend on which end you start from', () {
    final c1 = canvas(10, 10);
    final c2 = canvas(10, 10);
    line_bresenham(c1, 1, 1, 3, 7, color(1, 1, 1));
    line_bresenham(c2, 3, 7, 1, 1, color(1, 1, 1));
    expectIntPoints(lit_pixels(c1), lit_pixels(c2));
    expectEqInt(max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2)), 0);
  });

  test('A line going up and to the right', () {
    final c = canvas(10, 10);
    line_bresenham(c, 0, 6, 7, 3, color(1, 1, 1));
    expectIntPoints(lit_pixels(c), [
      IntPoint(6, 3),
      IntPoint(7, 3),
      IntPoint(4, 4),
      IntPoint(5, 4),
      IntPoint(2, 5),
      IntPoint(3, 5),
      IntPoint(0, 6),
      IntPoint(1, 6),
    ]);
  });

  test('At an exact half the line stays on its row one step longer', () {
    final c = canvas(10, 10);
    line_bresenham(c, 0, 0, 4, 2, color(1, 1, 1));
    expectIntPoints(lit_pixels(c), [IntPoint(0, 0), IntPoint(1, 0), IntPoint(2, 1), IntPoint(3, 1), IntPoint(4, 2)]);
  });

  test('A line of one point', () {
    final c = canvas(10, 10);
    line_bresenham(c, 3, 3, 3, 3, color(1, 1, 1));
    expectIntPoints(lit_pixels(c), [IntPoint(3, 3)]);
  });

  test('A line may run off the canvas', () {
    final c = canvas(10, 10);
    line_bresenham(c, 0, 0, 12, 6, color(1, 1, 1));
    expectEqInt(lit_pixels(c).length, 10);
  });

  // features/chapter03-wu.feature
  feature('chapter03-wu');

  test('A half step lights two pixels equally', () {
    final c = canvas(10, 10);
    line_wu(c, 0, 0, 4, 2, color(1, 1, 1));
    expectColorClose(pixel_at(c, 0, 0), color(1, 1, 1));
    expectColorClose(pixel_at(c, 1, 0), color(0.5, 0.5, 0.5));
    expectColorClose(pixel_at(c, 1, 1), color(0.5, 0.5, 0.5));
    expectColorClose(pixel_at(c, 2, 1), color(1, 1, 1));
    expectColorClose(pixel_at(c, 2, 2), color(0, 0, 0));
    expectColorClose(pixel_at(c, 4, 2), color(1, 1, 1));
    expectClose(total_ink(c), 5);
  });

  test('The weights are applied in light, whatever the switch says', () {
    setLinearBlending(false);
    final c = canvas(10, 10);
    line_wu(c, 0, 0, 4, 2, color(1, 1, 1));
    expectColorClose(pixel_at(c, 1, 0), color(0.5, 0.5, 0.5));
    expectColorClose(pixel_at(c, 1, 1), color(0.5, 0.5, 0.5));
  });

  test('A diagonal has uniform weights', () {
    final c = canvas(10, 10);
    line_wu(c, 0, 0, 5, 5, color(1, 1, 1));
    expectIntPoints(lit_pixels(c),
        [IntPoint(0, 0), IntPoint(1, 1), IntPoint(2, 2), IntPoint(3, 3), IntPoint(4, 4), IntPoint(5, 5)]);
    expectColorClose(pixel_at(c, 3, 3), color(1, 1, 1));
    expectClose(total_ink(c), 6);
  });

  test('A horizontal line has weight 1 on its row and 0 on the neighbors', () {
    final c = canvas(10, 10);
    line_wu(c, 0, 3, 7, 3, color(1, 1, 1));
    expectIntPoints(lit_pixels(c), [
      IntPoint(0, 3),
      IntPoint(1, 3),
      IntPoint(2, 3),
      IntPoint(3, 3),
      IntPoint(4, 3),
      IntPoint(5, 3),
      IntPoint(6, 3),
      IntPoint(7, 3),
    ]);
    expectColorClose(pixel_at(c, 3, 3), color(1, 1, 1));
    expectColorClose(pixel_at(c, 3, 2), color(0, 0, 0));
    expectColorClose(pixel_at(c, 3, 4), color(0, 0, 0));
    expectClose(total_ink(c), 8);
  });

  test('A steep line weights across columns', () {
    final c = canvas(10, 10);
    line_wu(c, 1, 1, 3, 7, color(1, 1, 1));
    expectColorClose(pixel_at(c, 1, 1), color(1, 1, 1));
    expectColorClose(pixel_at(c, 1, 2), color(0.6667, 0.6667, 0.6667));
    expectColorClose(pixel_at(c, 2, 2), color(0.3333, 0.3333, 0.3333));
    expectColorClose(pixel_at(c, 2, 4), color(1, 1, 1));
    expectColorClose(pixel_at(c, 3, 7), color(1, 1, 1));
    expectClose(total_ink(c), 7);
  });

  test('The weights don\'t depend on which end you start from', () {
    final c1 = canvas(10, 10);
    final c2 = canvas(10, 10);
    line_wu(c1, 1, 1, 3, 7, color(1, 1, 1));
    line_wu(c2, 3, 7, 1, 1, color(1, 1, 1));
    expectEqInt(max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2)), 0);
  });

  test('A line that starts above the canvas', () {
    final c = canvas(10, 10);
    line_wu(c, 0, -1, 8, 3, color(1, 1, 1));
    expectColorClose(pixel_at(c, 1, 0), color(0.5, 0.5, 0.5));
    expectColorClose(pixel_at(c, 2, 0), color(1, 1, 1));
    expectClose(total_ink(c), 7.5);
  });

  test('A Wu line of one point', () {
    final c = canvas(10, 10);
    line_wu(c, 3, 3, 3, 3, color(1, 1, 1));
    expectIntPoints(lit_pixels(c), [IntPoint(3, 3)]);
    expectColorClose(pixel_at(c, 3, 3), color(1, 1, 1));
  });

  test('Sevenths', () {
    final c = canvas(10, 10);
    line_wu(c, 0, 0, 7, 3, color(1, 1, 1));
    expectColorClose(pixel_at(c, 1, 0), color(0.5714, 0.5714, 0.5714));
    expectColorClose(pixel_at(c, 1, 1), color(0.4286, 0.4286, 0.4286));
    expectColorClose(pixel_at(c, 2, 0), color(0.1429, 0.1429, 0.1429));
    expectColorClose(pixel_at(c, 2, 1), color(0.8571, 0.8571, 0.8571));
    expectClose(total_ink(c), 8);
  });

  final inkOutline = <List<int>>[
    [12, 2, 11],
    [10, 8, 9],
    [8, 10, 9],
    [2, 12, 11],
  ];
  for (final row in inkOutline) {
    test('The ink depends on the angle: x1=${row[0]}, y1=${row[1]}', () {
      final c = canvas(20, 20);
      line_wu(c, 2, 2, row[0], row[1], color(1, 1, 1));
      expectClose(total_ink(c), row[2].toDouble());
    });
  }

  // features/chapter03-quad.feature
  feature('chapter03-quad');

  test('Inside a thick line', () {
    final s = thick_line(0, 0, 4, 0, 1);
    expectTrue(inside(s, 2.5, 0.5));
    expectTrue(inside(s, 2.5, 1.0));
    expectFalse(inside(s, 2.5, 1.01));
    expectTrue(inside(s, 0.5, 0.5));
    expectFalse(inside(s, 0.4, 0.5));
    expectTrue(inside(s, 4.5, 0.5));
    expectFalse(inside(s, 4.6, 0.5));
  });

  test('A horizontal thick line covers its row, with half pixels at the ends', () {
    final s = thick_line(0, 3, 7, 3, 1);
    final cov = rasterize(s, 10, 10);
    expectClose(coverage_at(cov, 0, 3), 0.5);
    expectClose(coverage_at(cov, 1, 3), 1);
    expectClose(coverage_at(cov, 6, 3), 1);
    expectClose(coverage_at(cov, 7, 3), 0.5);
    expectClose(coverage_at(cov, 8, 3), 0);
    expectClose(coverage_at(cov, 3, 2), 0);
    expectClose(coverage_at(cov, 3, 4), 0);
    expectClose(ink(cov), 7);
  });

  test('A line of no length is a square', () {
    final s = thick_line(3, 3, 3, 3, 1);
    final cov = rasterize(s, 8, 8);
    expectClose(coverage_at(cov, 3, 3), 1);
    expectClose(ink(cov), 1);
  });

  test('A wider line', () {
    final s = thick_line(0, 3, 7, 3, 3);
    final cov = rasterize(s, 10, 10);
    expectClose(coverage_at(cov, 3, 2), 1);
    expectClose(coverage_at(cov, 3, 3), 1);
    expectClose(coverage_at(cov, 3, 4), 1);
    expectClose(coverage_at(cov, 3, 1), 0);
    expectClose(coverage_at(cov, 3, 5), 0);
    expectClose(coverage_at(cov, 0, 3), 0.5);
    expectClose(ink(cov), 21);
  });

  test('An off-axis line runs through pixel centers, not corners', () {
    final s = thick_line(2, 2, 11, 5, 1);
    final cov = rasterize(s, 16, 10);
    expectClose(coverage_at(cov, 2, 2), 0.484375);
    expectClose(coverage_at(cov, 11, 5), 0.484375);
    expectClose(coverage_at(cov, 6, 3), 0.6875);
    expectClose(coverage_at(cov, 7, 3), 0.359375);
    expectClose(coverage_at(cov, 2, 1), 0);
    expectClose(ink(cov), 9.4063);
  });

  final inkAngles = <List<int>>[
    [12, 2],
    [10, 8],
    [8, 10],
    [2, 12],
  ];
  for (final row in inkAngles) {
    test('The ink is the length, whatever the angle: x1=${row[0]}, y1=${row[1]}', () {
      final s = thick_line(2, 2, row[0].toDouble(), row[1].toDouble(), 1);
      final cov = rasterize(s, 20, 20);
      expectClose(ink(cov), 10);
    });
  }

  test('Except that the grid is blind along the diagonal', () {
    final s = thick_line(2, 2, 9, 9, 1);
    final cov = rasterize(s, 20, 20);
    expectClose(ink(cov), 9.71875);
    expectClose(ink(cov), 9.8995, 0.25);
  });

  // features/chapter03-plate.feature
  feature('chapter03-plate');

  test('The ray endpoints', () {
    expectIntPoints(ray_ends(), [
      IntPoint(152, 80),
      IntPoint(142, 116),
      IntPoint(116, 142),
      IntPoint(80, 152),
      IntPoint(44, 142),
      IntPoint(18, 116),
      IntPoint(8, 80),
      IntPoint(18, 44),
      IntPoint(44, 18),
      IntPoint(80, 8),
      IntPoint(116, 18),
      IntPoint(142, 44),
    ]);
  });

  test('Bresenham\'s fan', () {
    final c = fan_bresenham();
    final ref = read_file('reference/chapter-03/fan-bresenham.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 160);
    expectEqInt(c.height, 160);
    expectRgb(ppm_pixel(p6, 80, 80), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 120, 80), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 10, 10), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 100, 91), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 100, 92), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 103, 120), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 102, 120), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 104, 120), 39, 39, 44, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });

  test('Wu\'s fan', () {
    final c = fan_wu();
    final ref = read_file('reference/chapter-03/fan-wu.ppm');
    final p6 = canvas_to_p6(c);
    expectRgb(ppm_pixel(p6, 80, 80), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 120, 80), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 100, 91), 163, 163, 161, 1);
    expectRgb(ppm_pixel(p6, 100, 92), 199, 199, 196, 1);
    expectRgb(ppm_pixel(p6, 103, 120), 220, 220, 216, 1);
    expectRgb(ppm_pixel(p6, 104, 120), 130, 130, 129, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });

  test('The fan as twelve thin rectangles', () {
    final c = fan_coverage();
    final ref = read_file('reference/chapter-03/fan-coverage.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 320);
    expectEqInt(c.height, 320);
    expectRgb(ppm_pixel(p6, 160, 160), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 10, 10), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 240, 160), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 240, 158), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 200, 183), 177, 177, 174, 1);
    expectRgb(ppm_pixel(p6, 200, 185), 209, 209, 205, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });

  test('Plate 3', () {
    final c = plate_03();
    final ref = read_file('reference/chapter-03/plate-03.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 640);
    expectEqInt(c.height, 320);
    expectRgb(ppm_pixel(p6, 160, 160), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 480, 160), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 10, 10), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 200, 183), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 200, 185), 246, 246, 241, 1);
    expectRgb(ppm_pixel(p6, 520, 183), 163, 163, 161, 1);
    expectRgb(ppm_pixel(p6, 520, 185), 199, 199, 196, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });
}
