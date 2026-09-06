#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative 'renderer'

# Chapter 6: Filling a Polygon

class TestEdgeTable < Minitest::Test
  def test_a_rectangle_has_two_edges_in_its_table
    p = polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6))
    t = edge_table(p)
    assert_equal 2, t.length
    assert_in_delta t[0].y_top, 2, 0.0001
    assert_in_delta t[0].y_bottom, 6, 0.0001
    assert_in_delta t[0].x_top, 2, 0.0001
    assert_in_delta t[0].slope, 0, 0.0001
    assert_equal(-1, t[0].direction)
    assert_in_delta t[1].x_top, 6, 0.0001
    assert_equal 1, t[1].direction
  end

  def test_a_triangles_edges_carry_their_slopes
    p = polygon(point(0, 0), point(10, 0), point(5, 10))
    t = edge_table(p)
    assert_equal 2, t.length
    assert_in_delta t[0].x_top, 0, 0.0001
    assert_in_delta t[0].slope, 0.5, 0.0001
    assert_equal(-1, t[0].direction)
    assert_in_delta t[1].x_top, 10, 0.0001
    assert_in_delta t[1].slope, -0.5, 0.0001
    assert_equal 1, t[1].direction
  end

  def test_the_table_is_sorted_by_top_then_by_x_at_the_top
    p = path
    move_to(p, point(2, 2))
    line_to(p, point(4, 1))
    line_to(p, point(6, 3))
    line_to(p, point(8, 1))
    line_to(p, point(9, 6))
    line_to(p, point(1, 6))
    close(p)
    t = edge_table(p)
    assert_equal 5, t.length
    assert_in_delta t[0].y_top, 1, 0.0001
    assert_in_delta t[0].x_top, 4, 0.0001
    assert_in_delta t[1].y_top, 1, 0.0001
    assert_in_delta t[1].x_top, 4, 0.0001
    assert_in_delta t[2].y_top, 1, 0.0001
    assert_in_delta t[2].x_top, 8, 0.0001
    assert_in_delta t[3].y_top, 1, 0.0001
    assert_in_delta t[3].x_top, 8, 0.0001
    assert_in_delta t[4].y_top, 2, 0.0001
    assert_in_delta t[4].x_top, 2, 0.0001
  end

  def test_a_horizontal_edge_is_dropped_not_clamped
    p = polygon(point(0, 0), point(10, 0), point(10, 5), point(0, 5))
    t = edge_table(p)
    assert_equal 2, t.length
    assert_in_delta t[0].x_top, 0, 0.0001
    assert_in_delta t[1].x_top, 10, 0.0001
  end

  def test_an_edge_knows_where_it_crosses_a_height
    p = polygon(point(0, 0), point(10, 0), point(5, 10))
    t = edge_table(p)
    assert_in_delta x_at(t[0], 4), 2, 0.0001
    assert_in_delta x_at(t[1], 4), 8, 0.0001
    assert_in_delta x_at(t[0], 0.5), 0.25, 0.0001
  end

  def test_the_edge_table_is_the_same_whichever_way_the_path_was_drawn
    a = polygon(point(0, 0), point(10, 0), point(5, 10))
    b = polygon(point(0, 0), point(5, 10), point(10, 0))
    ta = edge_table(a)
    tb = edge_table(b)
    assert_in_delta ta[0].x_top, tb[0].x_top, 0.0001
    assert_in_delta ta[0].slope, tb[0].slope, 0.0001
    assert_equal(-1, ta[0].direction)
    assert_equal 1, tb[0].direction
  end
end

class TestSpans < Minitest::Test
  def test_crossings_on_a_row_sorted_by_x
    p = polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6))
    t = edge_table(p)
    xs = crossings_on_row(t, 3.5)
    assert_equal 2, xs.length
    assert_in_delta xs[0][0], 2, 0.0001
    assert_equal(-1, xs[0][1])
    assert_in_delta xs[1][0], 6, 0.0001
    assert_equal 1, xs[1][1]
    assert_equal [], crossings_on_row(t, 1.5)
    assert_equal [], crossings_on_row(t, 6)
    assert_equal 2, crossings_on_row(t, 2).length
  end

  def test_the_stars_crossings_through_its_middle
    p = star
    xs = crossings_on_row(edge_table(p), 80.5)
    assert_equal 4, xs.length
    assert_in_delta xs[0][0], 43.6988, 0.0001
    assert_equal(-1, xs[0][1])
    assert_in_delta xs[1][0], 57.7556, 0.0001
    assert_equal(-1, xs[1][1])
    assert_in_delta xs[2][0], 103.2444, 0.0001
    assert_equal 1, xs[2][1]
    assert_in_delta xs[3][0], 117.3012, 0.0001
    assert_equal 1, xs[3][1]
  end

  def test_spans_from_crossings_under_each_rule
    xs = [[1, 1], [3, 1], [5, -1], [7, -1]]
    nz = spans_from_crossings(xs, "nonzero")
    assert_equal 1, nz.length
    assert_in_delta nz[0][0], 1, 0.0001
    assert_in_delta nz[0][1], 7, 0.0001
    eo = spans_from_crossings(xs, "evenodd")
    assert_equal 2, eo.length
    assert_in_delta eo[0][0], 1, 0.0001
    assert_in_delta eo[0][1], 3, 0.0001
    assert_in_delta eo[1][0], 5, 0.0001
    assert_in_delta eo[1][1], 7, 0.0001
    assert_equal [], spans_from_crossings([], "nonzero")
  end

  def test_the_spans_of_an_axis_aligned_rectangle_are_exact
    p = polygon(point(1.25, 2), point(4.75, 2), point(4.75, 5), point(1.25, 5))
    assert_equal [], spans(p, "nonzero", 1)
    s2 = spans(p, "nonzero", 2)
    assert_equal 1, s2.length
    assert_in_delta s2[0][0], 1.25, 0.0001
    assert_in_delta s2[0][1], 4.75, 0.0001
    s4 = spans(p, "nonzero", 4)
    assert_equal 1, s4.length
    assert_in_delta s4[0][0], 1.25, 0.0001
    assert_in_delta s4[0][1], 4.75, 0.0001
    assert_equal [], spans(p, "nonzero", 5)
  end

  def test_a_rectangle_whose_edges_sit_on_sample_heights
    p = polygon(point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5))
    assert_equal [], spans(p, "nonzero", 1)
    s2 = spans(p, "nonzero", 2)
    assert_equal 1, s2.length
    assert_in_delta s2[0][0], 1.5, 0.0001
    assert_in_delta s2[0][1], 4.5, 0.0001
    s4 = spans(p, "nonzero", 4)
    assert_equal 1, s4.length
    assert_in_delta s4[0][0], 1.5, 0.0001
    assert_in_delta s4[0][1], 4.5, 0.0001
    assert_equal [], spans(p, "nonzero", 5)
  end

  def test_a_triangles_spans_narrow_by_one_per_row_row_0
    check_triangle_span(0, 0.25, 9.75)
  end

  def test_a_triangles_spans_narrow_by_one_per_row_row_1
    check_triangle_span(1, 0.75, 9.25)
  end

  def test_a_triangles_spans_narrow_by_one_per_row_row_4
    check_triangle_span(4, 2.25, 7.75)
  end

  def test_a_triangles_spans_narrow_by_one_per_row_row_9
    check_triangle_span(9, 4.75, 5.25)
  end

  def check_triangle_span(row, x0, x1)
    p = polygon(point(0, 0), point(10, 0), point(5, 10))
    s = spans(p, "nonzero", row)
    assert_equal 1, s.length
    assert_in_delta s[0][0], x0, 0.0001
    assert_in_delta s[0][1], x1, 0.0001
  end

  def test_the_row_past_the_triangles_apex_has_no_span
    p = polygon(point(0, 0), point(10, 0), point(5, 10))
    assert_equal [], spans(p, "nonzero", 10)
  end

  def test_a_flat_top_is_not_a_span_of_its_own
    p = polygon(point(0, 0), point(10, 0), point(10, 5), point(0, 5))
    assert_equal 2, edge_table(p).length
    s0 = spans(p, "nonzero", 0)
    assert_equal 1, s0.length
    assert_in_delta s0[0][0], 0, 0.0001
    assert_in_delta s0[0][1], 10, 0.0001
    s4 = spans(p, "nonzero", 4)
    assert_equal 1, s4.length
    assert_in_delta s4[0][0], 0, 0.0001
    assert_in_delta s4[0][1], 10, 0.0001
    assert_equal [], spans(p, "nonzero", 5)
  end

  def test_a_ring_is_two_spans_under_even_odd_and_one_under_nonzero
    p = path
    move_to(p, point(0, 0))
    line_to(p, point(10, 0))
    line_to(p, point(10, 10))
    line_to(p, point(0, 10))
    close(p)
    move_to(p, point(3, 3))
    line_to(p, point(7, 3))
    line_to(p, point(7, 7))
    line_to(p, point(3, 7))
    close(p)
    nz = spans(p, "nonzero", 5)
    assert_equal 1, nz.length
    assert_in_delta nz[0][0], 0, 0.0001
    assert_in_delta nz[0][1], 10, 0.0001
    eo = spans(p, "evenodd", 5)
    assert_equal 2, eo.length
    assert_in_delta eo[0][0], 0, 0.0001
    assert_in_delta eo[0][1], 3, 0.0001
    assert_in_delta eo[1][0], 7, 0.0001
    assert_in_delta eo[1][1], 10, 0.0001
  end

  def test_the_stars_spans_through_its_middle
    p = star
    nz = spans(p, "nonzero", 80)
    assert_equal 1, nz.length
    assert_in_delta nz[0][0], 43.6988, 0.0001
    assert_in_delta nz[0][1], 117.3012, 0.0001
    eo = spans(p, "evenodd", 80)
    assert_equal 2, eo.length
    assert_in_delta eo[0][0], 43.6988, 0.0001
    assert_in_delta eo[0][1], 57.7556, 0.0001
    assert_in_delta eo[1][0], 103.2444, 0.0001
    assert_in_delta eo[1][1], 117.3012, 0.0001
  end

  def test_fill_span_fills_the_pixels_whose_centers_are_in_the_span
    cov = coverage_buffer(8, 3)
    fill_span(cov, 1, 1.25, 4.75)
    assert_in_delta coverage_at(cov, 0, 1), 0, 0.0001
    assert_in_delta coverage_at(cov, 1, 1), 1, 0.0001
    assert_in_delta coverage_at(cov, 4, 1), 1, 0.0001
    assert_in_delta coverage_at(cov, 5, 1), 0, 0.0001
    assert_in_delta coverage_at(cov, 2, 0), 0, 0.0001
    assert_in_delta ink(cov), 4, 0.0001
  end

  def test_the_span_is_half_open_at_its_right_end
    cov = coverage_buffer(8, 3)
    fill_span(cov, 1, 1.5, 4.5)
    assert_in_delta coverage_at(cov, 1, 1), 1, 0.0001
    assert_in_delta coverage_at(cov, 3, 1), 1, 0.0001
    assert_in_delta coverage_at(cov, 4, 1), 0, 0.0001
    assert_in_delta ink(cov), 3, 0.0001
  end

  def test_a_span_may_run_off_either_side_of_the_buffer
    a = coverage_buffer(8, 3)
    b = coverage_buffer(8, 3)
    c = coverage_buffer(8, 3)
    fill_span(a, 1, -3, 2.5)
    fill_span(b, 1, 6.5, 20)
    fill_span(c, 1, 2.5, 2.5)
    assert_in_delta ink(a), 2, 0.0001
    assert_in_delta coverage_at(a, 1, 1), 1, 0.0001
    assert_in_delta ink(b), 2, 0.0001
    assert_in_delta coverage_at(b, 6, 1), 1, 0.0001
    assert_in_delta ink(c), 0, 0.0001
  end
end

class TestSweep < Minitest::Test
  def test_two_buffers_that_differ
    a = coverage_buffer(3, 3)
    b = coverage_buffer(3, 3)
    set_coverage(a, 1, 1, 1)
    set_coverage(b, 1, 1, 0.25)
    assert_in_delta max_coverage_difference(a, b), 0.75, 0.0001
    assert_in_delta max_coverage_difference(a, a), 0, 0.0001
  end

  def test_buffers_of_different_sizes_are_as_different_as_it_gets
    a = coverage_buffer(3, 3)
    b = coverage_buffer(3, 4)
    assert_in_delta max_coverage_difference(a, b), 1, 0.0001
  end

  def test_a_rectangle
    p = polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6))
    cov = fill_path_aliased(p, "nonzero", 8, 8)
    assert_in_delta coverage_at(cov, 2, 2), 1, 0.0001
    assert_in_delta coverage_at(cov, 5, 5), 1, 0.0001
    assert_in_delta coverage_at(cov, 6, 5), 0, 0.0001
    assert_in_delta coverage_at(cov, 5, 6), 0, 0.0001
    assert_in_delta coverage_at(cov, 1, 2), 0, 0.0001
    assert_in_delta ink(cov), 16, 0.0001
    assert_in_delta max_coverage_difference(cov, rasterize_centers(filled(p, "nonzero"), 8, 8)), 0, 0.0001
  end

  def test_a_triangle
    p = polygon(point(0, 0), point(10, 0), point(5, 10))
    cov = fill_path_aliased(p, "nonzero", 20, 20)
    assert_in_delta coverage_at(cov, 0, 0), 1, 0.0001
    assert_in_delta coverage_at(cov, 9, 0), 1, 0.0001
    assert_in_delta coverage_at(cov, 10, 0), 0, 0.0001
    assert_in_delta coverage_at(cov, 4, 8), 1, 0.0001
    assert_in_delta coverage_at(cov, 3, 8), 0, 0.0001
    assert_in_delta coverage_at(cov, 5, 9), 0, 0.0001
    assert_in_delta ink(cov), 50, 0.0001
    assert_in_delta max_coverage_difference(cov, rasterize_centers(filled(p, "nonzero"), 20, 20)), 0, 0.0001
  end

  def test_the_same_triangle_drawn_the_other_way_round
    a = polygon(point(0, 0), point(10, 0), point(5, 10))
    b = polygon(point(0, 0), point(5, 10), point(10, 0))
    ca = fill_path_aliased(a, "nonzero", 20, 20)
    cb = fill_path_aliased(b, "nonzero", 20, 20)
    assert_in_delta max_coverage_difference(ca, cb), 0, 0.0001
  end

  def test_a_polygon_circle
    p = circle_path(10.3, 9.7, 7, 12)
    cov = fill_path_aliased(p, "nonzero", 20, 20)
    assert_in_delta ink(cov), 145, 0.0001
    assert_in_delta max_coverage_difference(cov, rasterize_centers(filled(p, "nonzero"), 20, 20)), 0, 0.0001
  end

  def test_the_star_both_rules_matches_chapter_5_pixel_for_pixel
    p = star
    nz = fill_path_aliased(p, "nonzero", 160, 160)
    eo = fill_path_aliased(p, "evenodd", 160, 160)
    assert_in_delta ink(nz), 5480, 0.0001
    assert_in_delta ink(eo), 3780, 0.0001
    assert_in_delta coverage_at(nz, 80, 80), 1, 0.0001
    assert_in_delta coverage_at(eo, 80, 80), 0, 0.0001
    assert_in_delta max_coverage_difference(nz, rasterize_centers(filled(p, "nonzero"), 160, 160)), 0, 0.0001
    assert_in_delta max_coverage_difference(eo, rasterize_centers(filled(p, "evenodd"), 160, 160)), 0, 0.0001
  end

  def test_an_edge_that_starts_on_a_sample_height_is_active_there_and_one_that_ends_there_is_not
    p = polygon(point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5))
    cov = fill_path_aliased(p, "nonzero", 8, 8)
    assert_in_delta coverage_at(cov, 2, 1), 0, 0.0001
    assert_in_delta coverage_at(cov, 2, 2), 1, 0.0001
    assert_in_delta coverage_at(cov, 2, 4), 1, 0.0001
    assert_in_delta coverage_at(cov, 2, 5), 0, 0.0001
    assert_in_delta coverage_at(cov, 1, 3), 1, 0.0001
    assert_in_delta coverage_at(cov, 4, 3), 0, 0.0001
    assert_in_delta ink(cov), 9, 0.0001
    assert_in_delta max_coverage_difference(cov, rasterize_centers(filled(p, "nonzero"), 8, 8)), 0, 0.0001
  end

  def test_a_polygon_larger_than_the_buffer_fills_it
    p = polygon(point(-5, -5), point(30, -5), point(30, 30), point(-5, 30))
    cov = fill_path_aliased(p, "nonzero", 8, 8)
    assert_in_delta ink(cov), 64, 0.0001
  end

  def test_an_empty_path_fills_nothing
    p = path
    cov = fill_path_aliased(p, "nonzero", 8, 8)
    assert_in_delta ink(cov), 0, 0.0001
  end

  def test_transform_path_takes_every_point_through_the_matrix_and_keeps_the_flags
    p = polygon(point(1.25, 2), point(4.75, 2), point(4.75, 5), point(1.25, 5))
    q = transform_path(p, translation(10, 20))
    assert_equal 1, subpaths(q).length
    assert_equal true, subpaths(q)[0].closed
    assert subpaths(q)[0].points[0] == point(11.25, 22)
    assert subpaths(q)[0].points[2] == point(14.75, 25)
    assert subpaths(p)[0].points[0] == point(1.25, 2)
  end

  def test_a_transformed_star_fills_where_the_transform_put_it
    p = transform_path(star, translation(10, 10) * scaling(0.11, 0.11) * translation(-80.5, -80.5))
    nz = fill_path_aliased(p, "nonzero", 20, 20)
    eo = fill_path_aliased(p, "evenodd", 20, 20)
    b = bounds(p)
    assert_in_delta b[0], 2.6769, 0.0001
    assert_in_delta b[1], 2.3, 0.0001
    assert_in_delta b[2], 17.3231, 0.0001
    assert_in_delta b[3], 16.2294, 0.0001
    assert_in_delta ink(nz), 60, 0.0001
    assert_in_delta ink(eo), 40, 0.0001
    assert_in_delta max_coverage_difference(nz, rasterize_centers(filled(p, "nonzero"), 20, 20)), 0, 0.0001
  end
end

class TestPlate6 < Minitest::Test
  def test_the_unit_star
    p = unit_star
    assert_equal 5, edges(p).length
    assert subpaths(p)[0].points[0] == point(0, -1)
    assert subpaths(p)[0].points[1] == point(0.5878, 0.809)
    assert subpaths(p)[0].points[2] == point(-0.9511, -0.309)
    b = bounds(p)
    assert_in_delta b[0], -0.9511, 0.0001
    assert_in_delta b[1], -1, 0.0001
    assert_in_delta b[2], 0.9511, 0.0001
    assert_in_delta b[3], 0.809, 0.0001
  end

  def test_the_spiral
    c = spiral
    ref = read_file("reference/chapter-06/spiral.ppm")
    p6 = canvas_to_p6(c)

    assert_equal 320, c.width
    assert_equal 320, c.height
    check_pixel(p6, 180, 160, 243, 196, 89)
    check_pixel(p6, 183, 171, 124, 196, 237)
    check_pixel(p6, 179, 183, 237, 137, 149)
    check_pixel(p6, 104, 139, 237, 137, 149)
    check_pixel(p6, 230, 111, 124, 196, 237)
    check_pixel(p6, 32, 137, 124, 196, 237)
    check_pixel(p6, 34, 104, 237, 137, 149)
    check_pixel(p6, 160, 160, 39, 39, 44)
    check_pixel(p6, 5, 5, 39, 39, 44)
    check_pixel(p6, 300, 20, 39, 39, 44)

    diff = max_channel_difference(p6, ref)
    assert diff <= 1, "max_channel_difference was #{diff}"
  end

  def test_plate_06
    c = plate_06
    ref = read_file("reference/chapter-06/plate-06.ppm")
    p6 = canvas_to_p6(c)

    assert_equal 640, c.width
    assert_equal 640, c.height
    check_pixel(p6, 360, 320, 243, 196, 89)
    check_pixel(p6, 68, 208, 237, 137, 149)
    check_pixel(p6, 320, 320, 39, 39, 44)

    diff = max_channel_difference(p6, ref)
    assert diff <= 1, "max_channel_difference was #{diff}"
  end

  def check_pixel(p6, x, y, r, g, b)
    px = ppm_pixel(p6, x, y)
    assert_in_delta px[0], r, 1
    assert_in_delta px[1], g, 1
    assert_in_delta px[2], b, 1
  end
end
