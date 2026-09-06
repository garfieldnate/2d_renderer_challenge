import '../lib/renderer.dart';
import 'harness.dart';

void runChapter02Tests() {
  // features/chapter02-shapes.feature
  feature('chapter02-shapes');

  test('A point inside a circle', () {
    final s = circle(8, 8, 5);
    expectTrue(inside(s, 8, 8));
    expectTrue(inside(s, 12, 8));
    expectTrue(inside(s, 13, 8));
    expectFalse(inside(s, 13.01, 8));
    expectFalse(inside(s, 11.6, 11.6));
  });

  test('A point inside a rectangle', () {
    final s = rectangle(1.25, 2.0, 4.75, 5.0);
    expectTrue(inside(s, 3, 3));
    expectTrue(inside(s, 1.25, 2.0));
    expectTrue(inside(s, 4.75, 5.0));
    expectFalse(inside(s, 1.2, 3));
    expectFalse(inside(s, 3, 5.1));
  });

  test('A point inside a half-plane', () {
    final s = half_plane(2.5, 0, 1, 0);
    expectTrue(inside(s, 2.5, 7));
    expectTrue(inside(s, 3, -4));
    expectFalse(inside(s, 2.4, 0));
  });

  test('The normal picks the side', () {
    final s = half_plane(2.5, 0, -1, 0);
    expectTrue(inside(s, 2.4, 0));
    expectFalse(inside(s, 3, 0));
  });

  // features/chapter02-p6.feature
  feature('chapter02-p6');

  test('The header, then the bytes', () {
    final c = canvas(2, 1);
    write_pixel(c, 0, 0, color(1, 0, 0));
    write_pixel(c, 1, 0, color(0, 0.5, 0));
    final p6 = canvas_to_p6(c);
    expectTrue(ppm_begins_with(p6, 'P6\n2 1\n255\n'));
    expectEqInt(length_bytes(p6), 17);
    expectEqInt(byte_at(p6, 12), 255);
    expectEqInt(byte_at(p6, 13), 0);
    expectEqInt(byte_at(p6, 16), 188);
  });

  test('The same pixel comes back out of either format', () {
    final c = canvas(2, 1);
    write_pixel(c, 1, 0, color(0, 0.5, 0));
    final p3 = canvas_to_ppm(c);
    final p6 = canvas_to_p6(c);
    expectRgb(ppm_pixel(p6, 1, 0), 0, 188, 0);
    expectRgb(ppm_pixel(p3, 1, 0), 0, 188, 0);
    expectEqInt(max_channel_difference(p3, p6), 0);
    expectEqInt(distinct_values(p6), 2);
  });

  test('Rows go top to bottom', () {
    final c = canvas(1, 2);
    write_pixel(c, 0, 0, color(1, 0, 0));
    write_pixel(c, 0, 1, color(0, 0, 1));
    final p6 = canvas_to_p6(c);
    expectEqInt(byte_at(p6, 12), 255);
    expectEqInt(byte_at(p6, 17), 255);
    expectRgb(ppm_pixel(p6, 0, 0), 255, 0, 0);
    expectRgb(ppm_pixel(p6, 0, 1), 0, 0, 255);
  });

  test('The binary writer clamps too', () {
    final c = canvas(2, 1);
    write_pixel(c, 0, 0, color(1.5, 0, -0.5));
    final p6 = canvas_to_p6(c);
    expectEqInt(byte_at(p6, 12), 255);
    expectEqInt(byte_at(p6, 13), 0);
    expectEqInt(byte_at(p6, 14), 0);
    expectRgb(ppm_pixel(p6, 0, 0), 255, 0, 0);
  });

  test('Pixel bytes that look like whitespace are still pixel bytes', () {
    final c = canvas(2, 1);
    write_pixel(c, 0, 0, color(0.00304, 0.01444, 0.00304));
    write_pixel(c, 1, 0, color(1, 1, 1));
    final p6 = canvas_to_p6(c);
    expectEqInt(length_bytes(p6), 17);
    expectEqInt(byte_at(p6, 12), 10);
    expectEqInt(byte_at(p6, 13), 32);
    expectRgb(ppm_pixel(p6, 0, 0), 10, 32, 10);
    expectRgb(ppm_pixel(p6, 1, 0), 255, 255, 255);
    expectEqInt(max_channel_difference(canvas_to_ppm(c), p6), 0);
  });

  test('Sizes still have to match', () {
    final c1 = canvas(2, 1);
    final c2 = canvas(1, 2);
    final p6a = canvas_to_p6(c1);
    final p6b = canvas_to_p6(c2);
    expectEqInt(max_channel_difference(p6a, p6b), 255);
  });

  // features/chapter02-magnify.feature
  feature('chapter02-magnify');

  test('Every pixel becomes a block', () {
    final c = canvas(2, 1);
    write_pixel(c, 0, 0, color(1, 0, 0));
    write_pixel(c, 1, 0, color(0, 0.5, 0));
    final m = magnify(c, 3);
    expectEqInt(m.width, 6);
    expectEqInt(m.height, 3);
    expectColorClose(pixel_at(m, 0, 0), color(1, 0, 0));
    expectColorClose(pixel_at(m, 2, 2), color(1, 0, 0));
    expectColorClose(pixel_at(m, 3, 0), color(0, 0.5, 0));
    expectColorClose(pixel_at(m, 5, 2), color(0, 0.5, 0));
    int redCount = 0;
    for (int y = 0; y < m.height; y++) {
      for (int x = 0; x < m.width; x++) {
        if (colorsClose(pixel_at(m, x, y), color(1, 0, 0))) redCount++;
      }
    }
    expectEqInt(redCount, 9);
  });

  test('Magnifying by one changes nothing', () {
    final c = canvas(2, 1);
    write_pixel(c, 1, 0, color(0, 0.5, 0));
    final m = magnify(c, 1);
    expectEqInt(max_channel_difference(canvas_to_p6(c), canvas_to_p6(m)), 0);
  });

  // features/chapter02-centers.feature
  feature('chapter02-centers');

  test('A new coverage buffer is empty', () {
    final cov = coverage_buffer(4, 3);
    expectEqInt(cov.width, 4);
    expectEqInt(cov.height, 3);
    expectClose(coverage_at(cov, 2, 1), 0);
    expectClose(ink(cov), 0);
  });

  test('Setting coverage', () {
    final cov = coverage_buffer(4, 3);
    set_coverage(cov, 2, 1, 0.75);
    expectClose(coverage_at(cov, 2, 1), 0.75);
    expectClose(coverage_at(cov, 1, 2), 0);
    expectClose(ink(cov), 0.75);
  });

  test('Setting coverage outside the buffer is ignored, and reading it gives 0', () {
    final cov = coverage_buffer(4, 3);
    set_coverage(cov, -1, 1, 1);
    set_coverage(cov, 4, 1, 1);
    set_coverage(cov, 1, 3, 1);
    expectClose(ink(cov), 0);
    expectClose(coverage_at(cov, -1, 1), 0);
    expectClose(coverage_at(cov, 4, 1), 0);
    expectClose(coverage_at(cov, 1, 3), 0);
  });

  test('The center of pixel (x, y) is (x + 0.5, y + 0.5)', () {
    final s = half_plane(2.5, 0, 1, 0);
    final t = half_plane(2.6, 0, 1, 0);
    expectClose(center_inside(s, 2, 4).toDouble(), 1);
    expectClose(center_inside(s, 1, 4).toDouble(), 0);
    expectClose(center_inside(t, 2, 4).toDouble(), 0);
  });

  test('The center question is not "at least half"', () {
    final s = half_plane(2.55, 0, 1, 0);
    expectClose(center_inside(s, 2, 4).toDouble(), 0);
    expectClose(coverage(s, 2, 4).toDouble(), 0.5);
  });

  test('A buffer need not be square', () {
    final s = rectangle(0, 0, 2, 1);
    final cov = rasterize_centers(s, 4, 2);
    expectEqInt(cov.width, 4);
    expectEqInt(cov.height, 2);
    expectClose(coverage_at(cov, 1, 0), 1);
    expectClose(coverage_at(cov, 0, 1), 0);
    expectClose(ink(cov), 2);
  });

  test('A rectangle, by asking each center', () {
    final s = rectangle(1.25, 2.0, 4.75, 5.0);
    final cov = rasterize_centers(s, 8, 8);
    expectClose(coverage_at(cov, 1, 4), 1);
    expectClose(coverage_at(cov, 4, 1), 0);
    expectClose(coverage_at(cov, 4, 4), 1);
    expectClose(coverage_at(cov, 0, 3), 0);
    expectClose(coverage_at(cov, 5, 3), 0);
    expectClose(coverage_at(cov, 2, 1), 0);
    expectClose(coverage_at(cov, 2, 5), 0);
    expectClose(ink(cov), 12);
  });

  test('A disc, by asking each center', () {
    final s = circle(8, 8, 5);
    final cov = rasterize_centers(s, 16, 16);
    expectEqInt(cov.width, 16);
    expectEqInt(cov.height, 16);
    expectClose(coverage_at(cov, 8, 8), 1);
    expectClose(coverage_at(cov, 3, 8), 1);
    expectClose(coverage_at(cov, 12, 8), 1);
    expectClose(coverage_at(cov, 2, 8), 0);
    expectClose(coverage_at(cov, 13, 8), 0);
    expectClose(coverage_at(cov, 4, 4), 1);
    expectClose(coverage_at(cov, 3, 4), 0);
    expectClose(ink(cov), 80);
  });

  // features/chapter02-paint.feature
  feature('chapter02-paint');

  test('Half coverage is half the paint', () {
    final c = canvas(1, 1);
    final cov = coverage_buffer(1, 1);
    set_coverage(cov, 0, 0, 0.5);
    paint_through(c, cov, color(1, 1, 1));
    expectColorClose(pixel_at(c, 0, 0), color(0.5, 0.5, 0.5));
  });

  test('Paint over something that isn\'t black', () {
    final c = canvas(1, 1);
    final cov = coverage_buffer(1, 1);
    fill(c, color(0.2, 0.2, 0.2));
    set_coverage(cov, 0, 0, 0.25);
    paint_through(c, cov, color(1, 0, 0));
    expectColorClose(pixel_at(c, 0, 0), color(0.4, 0.15, 0.15));
  });

  test('Zero leaves it alone and one replaces it', () {
    final c = canvas(2, 1);
    final cov = coverage_buffer(2, 1);
    fill(c, color(0.2, 0.2, 0.2));
    set_coverage(cov, 1, 0, 1);
    paint_through(c, cov, color(1, 0, 0));
    expectColorClose(pixel_at(c, 0, 0), color(0.2, 0.2, 0.2));
    expectColorClose(pixel_at(c, 1, 0), color(1, 0, 0));
  });

  test('The arithmetic is on light, whatever the switch says', () {
    setLinearBlending(false);
    final c = canvas(1, 1);
    final cov = coverage_buffer(1, 1);
    set_coverage(cov, 0, 0, 0.5);
    paint_through(c, cov, color(1, 1, 1));
    final ppm = canvas_to_ppm(c);
    expectColorClose(pixel_at(c, 0, 0), color(0.5, 0.5, 0.5));
    expectRgb(ppm_pixel(ppm, 0, 0), 188, 188, 188);
  });

  test('The disc by centers', () {
    final c = disc_centers();
    final ref = read_file('reference/chapter-02/disc-centers.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 320);
    expectEqInt(c.height, 320);
    expectRgb(ppm_pixel(p6, 160, 160), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 124, 36), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 132, 36), 243, 196, 89, 1);
    expectEqInt(distinct_values(p6), 5);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });

  // features/chapter02-coverage.feature
  feature('chapter02-coverage');

  test('The sixty-four sample points', () {
    final s = half_plane(2.5, 0, 1, 0);
    expectClose(coverage(s, 2, 4).toDouble(), 0.5);
    expectClose(coverage(s, 1, 4).toDouble(), 0);
    expectClose(coverage(s, 3, 4).toDouble(), 1);
  });

  test('A rectangle is covered exactly, when its edges land on sample boundaries', () {
    final s = rectangle(1.25, 2.0, 4.75, 5.0);
    final cov = rasterize(s, 8, 8);
    expectClose(coverage_at(cov, 0, 2), 0);
    expectClose(coverage_at(cov, 1, 2), 0.75);
    expectClose(coverage_at(cov, 2, 2), 1);
    expectClose(coverage_at(cov, 3, 2), 1);
    expectClose(coverage_at(cov, 4, 2), 0.75);
    expectClose(coverage_at(cov, 5, 2), 0);
    expectClose(coverage_at(cov, 2, 1), 0);
    expectClose(coverage_at(cov, 2, 5), 0);
    expectClose(ink(cov), 10.5);
  });

  test('Neither need the buffer be square here', () {
    final s = rectangle(0, 0, 2, 1);
    final cov = rasterize(s, 4, 2);
    expectEqInt(cov.width, 4);
    expectEqInt(cov.height, 2);
    expectClose(coverage_at(cov, 1, 0), 1);
    expectClose(coverage_at(cov, 2, 0), 0);
    expectClose(coverage_at(cov, 0, 1), 0);
    expectClose(ink(cov), 2);
  });

  test('A half-plane through a pixel center covers half of it', () {
    final s = half_plane(2.5, 4.5, 0.6, 0.8);
    expectClose(coverage(s, 2, 4).toDouble(), 0.5);
  });

  test('Except when the grid conspires', () {
    final s = half_plane(2.5, 4.5, 1, 1);
    expectClose(coverage(s, 2, 4).toDouble(), 0.5625);
  });

  test('A disc is only ever approximately covered', () {
    final s = circle(8, 8, 5);
    final cov = rasterize(s, 16, 16);
    expectClose(coverage_at(cov, 8, 8), 1);
    expectClose(coverage_at(cov, 3, 8), 0.96875);
    expectClose(coverage_at(cov, 12, 8), 0.96875);
    expectClose(coverage_at(cov, 4, 4), 0.5625);
    expectClose(coverage_at(cov, 3, 4), 0);
    expectClose(ink(cov), 78.5);
    expectClose(ink(cov), 78.5398, 0.1);
  });

  test('The disc by coverage', () {
    final c = disc_coverage();
    final ref = read_file('reference/chapter-02/disc-coverage.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 320);
    expectEqInt(c.height, 320);
    expectRgb(ppm_pixel(p6, 160, 160), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 124, 36), 157, 127, 64, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });

  // features/chapter02-twice.feature
  feature('chapter02-twice');

  test('Half coverage, painted twice, is three quarters', () {
    final c = canvas(1, 1);
    final cov = coverage_buffer(1, 1);
    set_coverage(cov, 0, 0, 0.5);
    paint_through(c, cov, color(1, 1, 1));
    paint_through(c, cov, color(1, 1, 1));
    expectColorClose(pixel_at(c, 0, 0), color(0.75, 0.75, 0.75));
  });

  test('The disc, once and twice', () {
    final c = painted_twice();
    final ref = read_file('reference/chapter-02/painted-twice.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 480);
    expectEqInt(c.height, 240);
    expectRgb(ppm_pixel(p6, 120, 120), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 360, 120), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 93, 27), 157, 127, 64, 1);
    expectRgb(ppm_pixel(p6, 333, 27), 194, 156, 74, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });

  // features/chapter02-plate.feature
  feature('chapter02-plate');

  test('Plate 2', () {
    final c = plate_02();
    final ref = read_file('reference/chapter-02/plate-02.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 480);
    expectEqInt(c.height, 240);
    expectRgb(ppm_pixel(p6, 120, 120), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 360, 120), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 93, 27), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 333, 27), 157, 127, 64, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });
}
