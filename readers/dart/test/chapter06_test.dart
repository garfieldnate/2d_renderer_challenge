import '../lib/renderer.dart';
import 'harness.dart';

void runChapter06Tests() {
  // features/chapter06-edges.feature
  feature('chapter06-edges');

  test('A rectangle has two edges in its table', () {
    final p = polygon([point(2, 2), point(6, 2), point(6, 6), point(2, 6)]);
    final t = edge_table(p);
    expectEqInt(t.length, 2);
    expectClose(t[0].yTop, 2);
    expectClose(t[0].yBottom, 6);
    expectClose(t[0].xTop, 2);
    expectClose(t[0].slope, 0);
    expectEqInt(t[0].direction, -1);
    expectClose(t[1].xTop, 6);
    expectEqInt(t[1].direction, 1);
  });

  test('A triangle\'s edges carry their slopes', () {
    final p = polygon([point(0, 0), point(10, 0), point(5, 10)]);
    final t = edge_table(p);
    expectEqInt(t.length, 2);
    expectClose(t[0].xTop, 0);
    expectClose(t[0].slope, 0.5);
    expectEqInt(t[0].direction, -1);
    expectClose(t[1].xTop, 10);
    expectClose(t[1].slope, -0.5);
    expectEqInt(t[1].direction, 1);
  });

  test('The table is sorted by top, then by x at the top', () {
    final p = path();
    move_to(p, point(2, 2));
    line_to(p, point(4, 1));
    line_to(p, point(6, 3));
    line_to(p, point(8, 1));
    line_to(p, point(9, 6));
    line_to(p, point(1, 6));
    close(p);
    final t = edge_table(p);
    expectEqInt(t.length, 5);
    expectClose(t[0].yTop, 1);
    expectClose(t[0].xTop, 4);
    expectClose(t[1].yTop, 1);
    expectClose(t[1].xTop, 4);
    expectClose(t[2].yTop, 1);
    expectClose(t[2].xTop, 8);
    expectClose(t[3].yTop, 1);
    expectClose(t[3].xTop, 8);
    expectClose(t[4].yTop, 2);
    expectClose(t[4].xTop, 2);
  });

  test('A horizontal edge is dropped, not clamped', () {
    final p = polygon([point(0, 0), point(10, 0), point(10, 5), point(0, 5)]);
    final t = edge_table(p);
    expectEqInt(t.length, 2);
    expectClose(t[0].xTop, 0);
    expectClose(t[1].xTop, 10);
  });

  test('An edge knows where it crosses a height', () {
    final p = polygon([point(0, 0), point(10, 0), point(5, 10)]);
    final t = edge_table(p);
    expectClose(x_at(t[0], 4), 2);
    expectClose(x_at(t[1], 4), 8);
    expectClose(x_at(t[0], 0.5), 0.25);
  });

  test('The edge table is the same whichever way the path was drawn', () {
    final a = polygon([point(0, 0), point(10, 0), point(5, 10)]);
    final b = polygon([point(0, 0), point(5, 10), point(10, 0)]);
    final ta = edge_table(a);
    final tb = edge_table(b);
    expectClose(ta[0].xTop, tb[0].xTop);
    expectClose(ta[0].slope, tb[0].slope);
    expectEqInt(ta[0].direction, -1);
    expectEqInt(tb[0].direction, 1);
  });

  // features/chapter06-spans.feature
  feature('chapter06-spans');

  test('Crossings on a row, sorted by x', () {
    final p = polygon([point(2, 2), point(6, 2), point(6, 6), point(2, 6)]);
    final xs = crossings_on_row(edge_table(p), 3.5);
    expectCrossings(xs, [Crossing(2, -1), Crossing(6, 1)]);
    expectEqInt(crossings_on_row(edge_table(p), 1.5).length, 0);
    expectEqInt(crossings_on_row(edge_table(p), 6).length, 0);
    expectEqInt(crossings_on_row(edge_table(p), 2).length, 2);
  });

  test('The star\'s crossings through its middle', () {
    final p = star();
    final xs = crossings_on_row(edge_table(p), 80.5);
    expectEqInt(xs.length, 4);
    expectClose(xs[0].x, 43.6988);
    expectEqInt(xs[0].direction, -1);
    expectClose(xs[1].x, 57.7556);
    expectEqInt(xs[1].direction, -1);
    expectClose(xs[2].x, 103.2444);
    expectEqInt(xs[2].direction, 1);
    expectClose(xs[3].x, 117.3012);
    expectEqInt(xs[3].direction, 1);
  });

  test('Spans from crossings under each rule', () {
    final xs = [Crossing(1, 1), Crossing(3, 1), Crossing(5, -1), Crossing(7, -1)];
    expectSpans(spans_from_crossings(xs, 'nonzero'), [Span(1, 7)]);
    expectSpans(spans_from_crossings(xs, 'evenodd'), [Span(1, 3), Span(5, 7)]);
    expectSpans(spans_from_crossings([], 'nonzero'), []);
  });

  test('The spans of an axis-aligned rectangle are exact', () {
    final p = polygon([point(1.25, 2), point(4.75, 2), point(4.75, 5), point(1.25, 5)]);
    expectSpans(spans(p, 'nonzero', 1), []);
    expectSpans(spans(p, 'nonzero', 2), [Span(1.25, 4.75)]);
    expectSpans(spans(p, 'nonzero', 4), [Span(1.25, 4.75)]);
    expectSpans(spans(p, 'nonzero', 5), []);
  });

  test('A rectangle whose edges sit on sample heights', () {
    final p = polygon([point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5)]);
    expectSpans(spans(p, 'nonzero', 1), []);
    expectSpans(spans(p, 'nonzero', 2), [Span(1.5, 4.5)]);
    expectSpans(spans(p, 'nonzero', 4), [Span(1.5, 4.5)]);
    expectSpans(spans(p, 'nonzero', 5), []);
  });

  final triangleRows = <List<double>>[
    [0, 0.25, 9.75],
    [1, 0.75, 9.25],
    [4, 2.25, 7.75],
    [9, 4.75, 5.25],
  ];
  for (final row in triangleRows) {
    test('A triangle\'s spans narrow by one per row: row=${row[0].toInt()}', () {
      final p = polygon([point(0, 0), point(10, 0), point(5, 10)]);
      expectSpans(spans(p, 'nonzero', row[0].toInt()), [Span(row[1], row[2])]);
    });
  }

  test('The row past the triangle\'s apex has no span', () {
    final p = polygon([point(0, 0), point(10, 0), point(5, 10)]);
    expectSpans(spans(p, 'nonzero', 10), []);
  });

  test('A flat top is not a span of its own', () {
    final p = polygon([point(0, 0), point(10, 0), point(10, 5), point(0, 5)]);
    expectEqInt(edge_table(p).length, 2);
    expectSpans(spans(p, 'nonzero', 0), [Span(0, 10)]);
    expectSpans(spans(p, 'nonzero', 4), [Span(0, 10)]);
    expectSpans(spans(p, 'nonzero', 5), []);
  });

  test('A ring is two spans under even-odd and one under nonzero', () {
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
    expectSpans(spans(p, 'nonzero', 5), [Span(0, 10)]);
    expectSpans(spans(p, 'evenodd', 5), [Span(0, 3), Span(7, 10)]);
  });

  test('The star\'s spans through its middle', () {
    final p = star();
    expectSpans(spans(p, 'nonzero', 80), [Span(43.6988, 117.3012)]);
    expectSpans(spans(p, 'evenodd', 80), [Span(43.6988, 57.7556), Span(103.2444, 117.3012)]);
  });

  test('fill_span fills the pixels whose centers are in the span', () {
    final cov = coverage_buffer(8, 3);
    fill_span(cov, 1, 1.25, 4.75);
    expectClose(coverage_at(cov, 0, 1), 0);
    expectClose(coverage_at(cov, 1, 1), 1);
    expectClose(coverage_at(cov, 4, 1), 1);
    expectClose(coverage_at(cov, 5, 1), 0);
    expectClose(coverage_at(cov, 2, 0), 0);
    expectClose(ink(cov), 4);
  });

  test('The span is half-open at its right end', () {
    final cov = coverage_buffer(8, 3);
    fill_span(cov, 1, 1.5, 4.5);
    expectClose(coverage_at(cov, 1, 1), 1);
    expectClose(coverage_at(cov, 3, 1), 1);
    expectClose(coverage_at(cov, 4, 1), 0);
    expectClose(ink(cov), 3);
  });

  test('A span may run off either side of the buffer', () {
    final a = coverage_buffer(8, 3);
    final b = coverage_buffer(8, 3);
    final c = coverage_buffer(8, 3);
    fill_span(a, 1, -3, 2.5);
    fill_span(b, 1, 6.5, 20);
    fill_span(c, 1, 2.5, 2.5);
    expectClose(ink(a), 2);
    expectClose(coverage_at(a, 1, 1), 1);
    expectClose(ink(b), 2);
    expectClose(coverage_at(b, 6, 1), 1);
    expectClose(ink(c), 0);
  });

  // features/chapter06-sweep.feature
  feature('chapter06-sweep');

  test('Two buffers that differ', () {
    final a = coverage_buffer(3, 3);
    final b = coverage_buffer(3, 3);
    set_coverage(a, 1, 1, 1);
    set_coverage(b, 1, 1, 0.25);
    expectClose(max_coverage_difference(a, b), 0.75);
    expectClose(max_coverage_difference(a, a), 0);
  });

  test('Buffers of different sizes are as different as it gets', () {
    final a = coverage_buffer(3, 3);
    final b = coverage_buffer(3, 4);
    expectClose(max_coverage_difference(a, b), 1);
  });

  test('A rectangle', () {
    final p = polygon([point(2, 2), point(6, 2), point(6, 6), point(2, 6)]);
    final cov = fill_path_aliased(p, 'nonzero', 8, 8);
    expectClose(coverage_at(cov, 2, 2), 1);
    expectClose(coverage_at(cov, 5, 5), 1);
    expectClose(coverage_at(cov, 6, 5), 0);
    expectClose(coverage_at(cov, 5, 6), 0);
    expectClose(coverage_at(cov, 1, 2), 0);
    expectClose(ink(cov), 16);
    expectClose(max_coverage_difference(cov, rasterize_centers(filled(p, 'nonzero'), 8, 8)), 0);
  });

  test('A triangle', () {
    final p = polygon([point(0, 0), point(10, 0), point(5, 10)]);
    final cov = fill_path_aliased(p, 'nonzero', 20, 20);
    expectClose(coverage_at(cov, 0, 0), 1);
    expectClose(coverage_at(cov, 9, 0), 1);
    expectClose(coverage_at(cov, 10, 0), 0);
    expectClose(coverage_at(cov, 4, 8), 1);
    expectClose(coverage_at(cov, 3, 8), 0);
    expectClose(coverage_at(cov, 5, 9), 0);
    expectClose(ink(cov), 50);
    expectClose(max_coverage_difference(cov, rasterize_centers(filled(p, 'nonzero'), 20, 20)), 0);
  });

  test('The same triangle drawn the other way round', () {
    final a = polygon([point(0, 0), point(10, 0), point(5, 10)]);
    final b = polygon([point(0, 0), point(5, 10), point(10, 0)]);
    final ca = fill_path_aliased(a, 'nonzero', 20, 20);
    final cb = fill_path_aliased(b, 'nonzero', 20, 20);
    expectClose(max_coverage_difference(ca, cb), 0);
  });

  test('A polygon circle', () {
    final p = circle_path(10.3, 9.7, 7, 12);
    final cov = fill_path_aliased(p, 'nonzero', 20, 20);
    expectClose(ink(cov), 145);
    expectClose(max_coverage_difference(cov, rasterize_centers(filled(p, 'nonzero'), 20, 20)), 0);
  });

  test('The star, both rules, matches chapter 5 pixel for pixel', () {
    final p = star();
    final nz = fill_path_aliased(p, 'nonzero', 160, 160);
    final eo = fill_path_aliased(p, 'evenodd', 160, 160);
    expectClose(ink(nz), 5480);
    expectClose(ink(eo), 3780);
    expectClose(coverage_at(nz, 80, 80), 1);
    expectClose(coverage_at(eo, 80, 80), 0);
    expectClose(max_coverage_difference(nz, rasterize_centers(filled(p, 'nonzero'), 160, 160)), 0);
    expectClose(max_coverage_difference(eo, rasterize_centers(filled(p, 'evenodd'), 160, 160)), 0);
  });

  test('An edge that starts on a sample height is active there, and one that ends there is not', () {
    final p = polygon([point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5)]);
    final cov = fill_path_aliased(p, 'nonzero', 8, 8);
    expectClose(coverage_at(cov, 2, 1), 0);
    expectClose(coverage_at(cov, 2, 2), 1);
    expectClose(coverage_at(cov, 2, 4), 1);
    expectClose(coverage_at(cov, 2, 5), 0);
    expectClose(coverage_at(cov, 1, 3), 1);
    expectClose(coverage_at(cov, 4, 3), 0);
    expectClose(ink(cov), 9);
    expectClose(max_coverage_difference(cov, rasterize_centers(filled(p, 'nonzero'), 8, 8)), 0);
  });

  test('A polygon larger than the buffer fills it', () {
    final p = polygon([point(-5, -5), point(30, -5), point(30, 30), point(-5, 30)]);
    final cov = fill_path_aliased(p, 'nonzero', 8, 8);
    expectClose(ink(cov), 64);
  });

  test('An empty path fills nothing', () {
    final p = path();
    final cov = fill_path_aliased(p, 'nonzero', 8, 8);
    expectClose(ink(cov), 0);
  });

  test('transform_path takes every point through the matrix and keeps the flags', () {
    final p = polygon([point(1.25, 2), point(4.75, 2), point(4.75, 5), point(1.25, 5)]);
    final q = transform_path(p, translation(10, 20));
    expectEqInt(subpaths(q).length, 1);
    expectTrue(subpaths(q)[0].closed);
    expectTupClose(subpaths(q)[0].points[0], point(11.25, 22));
    expectTupClose(subpaths(q)[0].points[2], point(14.75, 25));
    expectTupClose(subpaths(p)[0].points[0], point(1.25, 2));
  });

  test('A transformed star fills where the transform put it', () {
    final m = mmAll([translation(10, 10), scaling(0.11, 0.11), translation(-80.5, -80.5)]);
    final p = transform_path(star(), m);
    final nz = fill_path_aliased(p, 'nonzero', 20, 20);
    final eo = fill_path_aliased(p, 'evenodd', 20, 20);
    expectBoundsClose(bounds(p), Bounds(2.6769, 2.3, 17.3231, 16.2294));
    expectClose(ink(nz), 60);
    expectClose(ink(eo), 40);
    expectClose(max_coverage_difference(nz, rasterize_centers(filled(p, 'nonzero'), 20, 20)), 0);
  });

  // features/chapter06-plate.feature
  feature('chapter06-plate');

  test('The unit star', () {
    final p = unit_star();
    expectEqInt(edges(p).length, 5);
    expectTupClose(subpaths(p)[0].points[0], point(0, -1));
    expectTupClose(subpaths(p)[0].points[1], point(0.5878, 0.809));
    expectTupClose(subpaths(p)[0].points[2], point(-0.9511, -0.309));
    expectBoundsClose(bounds(p), Bounds(-0.9511, -1, 0.9511, 0.809));
  });

  test('The spiral', () {
    final c = spiral();
    final ref = read_file('reference/chapter-06/spiral.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 320);
    expectEqInt(c.height, 320);
    expectRgb(ppm_pixel(p6, 180, 160), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 183, 171), 124, 196, 237, 1);
    expectRgb(ppm_pixel(p6, 179, 183), 237, 137, 149, 1);
    expectRgb(ppm_pixel(p6, 104, 139), 237, 137, 149, 1);
    expectRgb(ppm_pixel(p6, 230, 111), 124, 196, 237, 1);
    expectRgb(ppm_pixel(p6, 32, 137), 124, 196, 237, 1);
    expectRgb(ppm_pixel(p6, 34, 104), 237, 137, 149, 1);
    expectRgb(ppm_pixel(p6, 160, 160), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 5, 5), 39, 39, 44, 1);
    expectRgb(ppm_pixel(p6, 300, 20), 39, 39, 44, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });

  test('Plate 6', () {
    final c = plate_06();
    final ref = read_file('reference/chapter-06/plate-06.ppm');
    final p6 = canvas_to_p6(c);
    expectEqInt(c.width, 640);
    expectEqInt(c.height, 640);
    expectRgb(ppm_pixel(p6, 360, 320), 243, 196, 89, 1);
    expectRgb(ppm_pixel(p6, 68, 208), 237, 137, 149, 1);
    expectRgb(ppm_pixel(p6, 320, 320), 39, 39, 44, 1);
    expectTrue(max_channel_difference(p6, ref) <= 1);
  });
}
