#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative 'renderer'

# Chapter 5: Paths and Insideness

class TestPaths < Minitest::Test
  def test_an_empty_path
    p = path
    assert_equal 0, subpaths(p).length
    assert_equal 0, edges(p).length
    b = bounds(p)
    assert_in_delta b[0], 0, 0.0001
    assert_in_delta b[1], 0, 0.0001
    assert_in_delta b[2], 0, 0.0001
    assert_in_delta b[3], 0, 0.0001
  end

  def test_a_triangle_closed
    p = path
    move_to(p, point(1, 1))
    line_to(p, point(9, 1))
    line_to(p, point(5, 8))
    close(p)
    assert_equal 1, subpaths(p).length
    assert_equal true, subpaths(p)[0].closed
    assert_equal 3, subpaths(p)[0].points.length
    assert subpaths(p)[0].points[2] == point(5, 8)
    assert_equal 3, edges(p).length
    e = edges(p)[2]
    assert e[0] == point(5, 8)
    assert e[1] == point(1, 1)
    b = bounds(p)
    assert_in_delta b[0], 1, 0.0001
    assert_in_delta b[1], 1, 0.0001
    assert_in_delta b[2], 9, 0.0001
    assert_in_delta b[3], 8, 0.0001
  end

  def test_a_triangle_left_open_still_has_three_edges
    p = path
    move_to(p, point(1, 1))
    line_to(p, point(9, 1))
    line_to(p, point(5, 8))
    assert_equal false, subpaths(p)[0].closed
    assert_equal 3, edges(p).length
    e = edges(p)[2]
    assert e[0] == point(5, 8)
    assert e[1] == point(1, 1)
  end

  def test_move_to_starts_a_second_subpath
    p = path
    move_to(p, point(0, 0))
    line_to(p, point(10, 0))
    line_to(p, point(10, 10))
    line_to(p, point(0, 10))
    close(p)
    move_to(p, point(3, 3))
    line_to(p, point(3, 7))
    line_to(p, point(7, 7))
    line_to(p, point(7, 3))
    close(p)
    assert_equal 2, subpaths(p).length
    assert subpaths(p)[1].points[0] == point(3, 3)
    assert_equal 8, edges(p).length
    b = bounds(p)
    assert_in_delta b[0], 0, 0.0001
    assert_in_delta b[1], 0, 0.0001
    assert_in_delta b[2], 10, 0.0001
    assert_in_delta b[3], 10, 0.0001
  end

  def test_line_to_after_a_close_starts_a_new_subpath_where_the_closed_one_began
    p = path
    move_to(p, point(1, 1))
    line_to(p, point(4, 1))
    line_to(p, point(4, 4))
    close(p)
    line_to(p, point(9, 9))
    assert_equal 2, subpaths(p).length
    assert_equal false, subpaths(p)[1].closed
    assert_equal 2, subpaths(p)[1].points.length
    assert subpaths(p)[1].points[0] == point(1, 1)
    assert subpaths(p)[1].points[1] == point(9, 9)
  end

  def test_line_to_with_nothing_to_extend_behaves_as_move_to
    p = path
    line_to(p, point(2, 3))
    assert_equal 1, subpaths(p).length
    assert_equal 1, subpaths(p)[0].points.length
    assert subpaths(p)[0].points[0] == point(2, 3)
  end

  def test_a_subpath_of_one_point_has_no_edges_and_closing_nothing_does_nothing
    p = path
    close(p)
    move_to(p, point(1, 1))
    move_to(p, point(2, 2))
    assert_equal 2, subpaths(p).length
    assert_equal 0, edges(p).length
    b = bounds(p)
    assert_in_delta b[0], 1, 0.0001
    assert_in_delta b[1], 1, 0.0001
    assert_in_delta b[2], 2, 0.0001
    assert_in_delta b[3], 2, 0.0001
  end

  def test_a_subpath_of_two_points_has_two_edges_and_encloses_nothing
    p = path
    move_to(p, point(1, 1))
    line_to(p, point(9, 9))
    assert_equal 2, edges(p).length
    assert_equal 0, winding_at(p, 3, 5)
  end

  def test_polygon_is_a_closed_subpath_through_its_points
    p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    assert_equal 1, subpaths(p).length
    assert_equal true, subpaths(p)[0].closed
    assert_equal 4, edges(p).length
  end

  def test_circle_path_is_a_polygon_standing_in_for_a_circle
    p = circle_path(10, 10, 5, 8)
    assert_equal 8, subpaths(p)[0].points.length
    assert subpaths(p)[0].points[0] == point(15, 10)
    assert subpaths(p)[0].points[1] == point(13.5355, 13.5355)
    assert subpaths(p)[0].points[2] == point(10, 15)
    b = bounds(p)
    assert_in_delta b[0], 5, 0.0001
    assert_in_delta b[1], 5, 0.0001
    assert_in_delta b[2], 15, 0.0001
    assert_in_delta b[3], 15, 0.0001
  end
end

class TestWinding < Minitest::Test
  def test_crossings_from_inside_and_outside_a_square
    p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    assert_equal 1, crossings(p, 5, 5)
    assert_equal 0, crossings(p, 15, 5)
    assert_equal 2, crossings(p, -1, 5)
  end

  def test_a_clockwise_square_winds_once
    p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    assert_equal 1, winding_at(p, 5, 5)
    assert_equal 0, winding_at(p, 15, 5)
    assert_equal 0, winding_at(p, -1, 5)
    assert_equal 0, winding_at(p, 5, -1)
    assert_equal 0, winding_at(p, 5, 11)
  end

  def test_the_same_square_the_other_way_round_winds_minus_once
    p = polygon(point(0, 0), point(0, 10), point(10, 10), point(10, 0))
    assert_equal(-1, winding_at(p, 5, 5))
    assert_equal 1, crossings(p, 5, 5)
  end

  def test_a_ray_through_a_vertex_counts_it_once
    p = polygon(point(5, 0), point(10, 5), point(5, 10), point(0, 5))
    assert_equal 1, crossings(p, 2, 5)
    assert_equal 1, winding_at(p, 2, 5)
    assert_equal 2, crossings(p, -1, 5)
    assert_equal 0, winding_at(p, -1, 5)
    assert_equal 0, winding_at(p, 12, 5)
    assert_equal 1, winding_at(p, 5, 5)
  end

  def test_the_boundary_belongs_to_the_top_and_the_left
    p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    assert_equal 1, winding_at(p, 5, 0)
    assert_equal 1, winding_at(p, 0, 5)
    assert_equal 1, winding_at(p, 0, 0)
    assert_equal 0, winding_at(p, 5, 10)
    assert_equal 0, winding_at(p, 10, 5)
    assert_equal 0, winding_at(p, 10, 10)
  end

  def test_two_rectangles_that_share_an_edge_cover_it_once
    p = path
    move_to(p, point(0, 0))
    line_to(p, point(5, 0))
    line_to(p, point(5, 10))
    line_to(p, point(0, 10))
    close(p)
    move_to(p, point(5, 0))
    line_to(p, point(10, 0))
    line_to(p, point(10, 10))
    line_to(p, point(5, 10))
    close(p)
    assert_equal 1, winding_at(p, 2, 5)
    assert_equal 1, winding_at(p, 5, 5)
    assert_equal 1, winding_at(p, 8, 5)
  end

  def test_a_diamond_wound_twice_has_winding_number_2
    p = path
    move_to(p, point(5, 0))
    line_to(p, point(10, 5))
    line_to(p, point(5, 10))
    line_to(p, point(0, 5))
    line_to(p, point(5, 0))
    line_to(p, point(10, 5))
    line_to(p, point(5, 10))
    line_to(p, point(0, 5))
    close(p)
    assert_equal 8, edges(p).length
    assert_equal 2, winding_at(p, 5, 5)
    assert_equal 2, crossings(p, 5, 5)
    assert_equal 0, winding_at(p, 12, 5)
  end

  def test_the_polygon_circle
    p = circle_path(10, 10, 5, 8)
    assert_equal 1, winding_at(p, 10, 10)
    assert_equal 1, winding_at(p, 14.9, 10)
    assert_equal 0, winding_at(p, 15, 10)
    assert_equal 1, winding_at(p, 10, 5.1)
    assert_equal 0, winding_at(p, 10, 4.9)
  end

  def test_the_pentagrams_center_winds_twice
    p = star
    assert_equal 2, winding_at(p, 80.5, 80.5)
    assert_equal 2, crossings(p, 80.5, 80.5)
    assert_equal 1, winding_at(p, 80.5, 20)
    assert_equal 1, winding_at(p, 30, 60)
    assert_equal 3, crossings(p, 30, 60)
    assert_equal 0, winding_at(p, 80.5, 120)
    assert_equal 2, crossings(p, 80.5, 120)
    assert_equal 0, winding_at(p, 10, 10)
  end
end

class TestTwoRules < Minitest::Test
  def test_a_single_loop_is_inside_under_both_rules
    p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    assert_equal true, inside_nonzero(p, 5, 5)
    assert_equal true, inside_evenodd(p, 5, 5)
    assert_equal false, inside_nonzero(p, 15, 5)
    assert_equal false, inside_evenodd(p, 15, 5)
  end

  def test_an_inner_loop_the_other_way_round_is_a_hole_under_both_rules
    p = path
    move_to(p, point(0, 0))
    line_to(p, point(10, 0))
    line_to(p, point(10, 10))
    line_to(p, point(0, 10))
    close(p)
    move_to(p, point(3, 3))
    line_to(p, point(3, 7))
    line_to(p, point(7, 7))
    line_to(p, point(7, 3))
    close(p)
    assert_equal 0, winding_at(p, 5, 5)
    assert_equal 1, winding_at(p, 1, 1)
    assert_equal false, inside_nonzero(p, 5, 5)
    assert_equal false, inside_evenodd(p, 5, 5)
    assert_equal true, inside_nonzero(p, 1, 1)
  end

  def test_an_inner_loop_the_same_way_round_is_a_hole_only_under_even_odd
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
    assert_equal 2, winding_at(p, 5, 5)
    assert_equal true, inside_nonzero(p, 5, 5)
    assert_equal false, inside_evenodd(p, 5, 5)
  end

  def test_a_loop_wound_twice_vanishes_under_even_odd
    p = path
    move_to(p, point(5, 0))
    line_to(p, point(10, 5))
    line_to(p, point(5, 10))
    line_to(p, point(0, 5))
    line_to(p, point(5, 0))
    line_to(p, point(10, 5))
    line_to(p, point(5, 10))
    line_to(p, point(0, 5))
    close(p)
    assert_equal true, inside_nonzero(p, 5, 5)
    assert_equal false, inside_evenodd(p, 5, 5)
  end

  def test_the_pentagrams_center_is_inside_under_nonzero_and_outside_under_even_odd
    p = star
    assert_equal true, inside_nonzero(p, 80.5, 80.5)
    assert_equal false, inside_evenodd(p, 80.5, 80.5)
    assert_equal true, inside_nonzero(p, 80.5, 20)
    assert_equal true, inside_evenodd(p, 80.5, 20)
    assert_equal false, inside_nonzero(p, 80.5, 120)
    assert_equal false, inside_evenodd(p, 80.5, 120)
  end

  def test_a_filled_path_is_a_shape
    s = filled(polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6)), "nonzero")
    cov = rasterize(s, 8, 8)
    assert_equal true, inside(s, 3, 3)
    assert_equal false, inside(s, 7, 3)
    assert_in_delta coverage_at(cov, 3, 3), 1, 0.0001
    assert_in_delta coverage_at(cov, 1, 3), 0, 0.0001
    assert_in_delta coverage_at(cov, 6, 3), 0, 0.0001
    assert_in_delta ink(cov), 16, 0.0001
  end

  def test_a_filled_path_takes_the_rule_seriously
    p = star
    a = filled(p, "nonzero")
    b = filled(p, "evenodd")
    ca = rasterize(a, 160, 160)
    cb = rasterize(b, 160, 160)
    assert_in_delta coverage_at(ca, 80, 80), 1, 0.0001
    assert_in_delta coverage_at(cb, 80, 80), 0, 0.0001
    assert_in_delta coverage_at(ca, 80, 20), 1, 0.0001
    assert_in_delta coverage_at(cb, 80, 20), 1, 0.0001
    assert_in_delta coverage_at(ca, 80, 10), 0.0625, 0.0001
    assert_in_delta coverage_at(cb, 80, 10), 0.0625, 0.0001
    assert_in_delta ink(ca), 5499.9375, 0.0001
    assert_in_delta ink(cb), 3800.375, 0.0001
  end

  def test_rasterizing_within_the_bounds_gives_the_same_coverage
    p = star
    s = filled(p, "evenodd")
    full = rasterize(s, 160, 160)
    within = rasterize_within(s, bounds(p), 160, 160)
    assert_in_delta ink(within), ink(full), 0.0001
    assert_in_delta coverage_at(within, 80, 20), coverage_at(full, 80, 20), 0.0001
    assert_in_delta coverage_at(within, 13, 58), coverage_at(full, 13, 58), 0.0001
    assert_in_delta coverage_at(within, 10, 10), 0, 0.0001
  end

  def test_the_box_is_inclusive_of_the_pixels_it_touches_and_clipped_to_the_buffer
    s = filled(polygon(point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)), "nonzero")
    cov = rasterize_within(s, [1.5, 1.5, 6.5, 6.5], 8, 8)
    big = rasterize_within(s, [-5, -5, 20, 20], 8, 8)
    assert_in_delta coverage_at(cov, 1, 1), 0.25, 0.0001
    assert_in_delta coverage_at(cov, 6, 6), 0.25, 0.0001
    assert_in_delta coverage_at(cov, 3, 3), 1, 0.0001
    assert_in_delta ink(cov), 25, 0.0001
    assert_in_delta ink(big), 25, 0.0001
  end
end

class TestPlate5 < Minitest::Test
  def test_the_pentagram
    p = star
    assert_equal 1, subpaths(p).length
    assert_equal 5, edges(p).length
    assert subpaths(p)[0].points[0] == point(80.5, 10.5)
    assert subpaths(p)[0].points[1] == point(121.645, 137.1312)
    assert subpaths(p)[0].points[2] == point(13.926, 58.8688)
    assert subpaths(p)[0].points[3] == point(147.074, 58.8688)
    assert subpaths(p)[0].points[4] == point(39.355, 137.1312)
    b = bounds(p)
    assert_in_delta b[0], 13.926, 0.0001
    assert_in_delta b[1], 10.5, 0.0001
    assert_in_delta b[2], 147.074, 0.0001
    assert_in_delta b[3], 137.1312, 0.0001
  end

  def test_the_star_by_the_center_question
    c = star_centers
    ref = read_file("reference/chapter-05/star-centers.ppm")
    p6 = canvas_to_p6(c)

    assert_equal 320, c.width
    assert_equal 160, c.height
    assert_in_delta ppm_pixel(p6, 80, 80)[0], 243, 1
    assert_in_delta ppm_pixel(p6, 80, 80)[1], 196, 1
    assert_in_delta ppm_pixel(p6, 80, 80)[2], 89, 1
    assert_in_delta ppm_pixel(p6, 240, 80)[0], 39, 1
    assert_in_delta ppm_pixel(p6, 240, 80)[1], 39, 1
    assert_in_delta ppm_pixel(p6, 240, 80)[2], 44, 1
    assert_in_delta ppm_pixel(p6, 80, 20)[0], 243, 1
    assert_in_delta ppm_pixel(p6, 80, 20)[1], 196, 1
    assert_in_delta ppm_pixel(p6, 80, 20)[2], 89, 1
    assert_in_delta ppm_pixel(p6, 240, 20)[0], 243, 1
    assert_in_delta ppm_pixel(p6, 240, 20)[1], 196, 1
    assert_in_delta ppm_pixel(p6, 240, 20)[2], 89, 1
    assert_in_delta ppm_pixel(p6, 30, 60)[0], 243, 1
    assert_in_delta ppm_pixel(p6, 30, 60)[1], 196, 1
    assert_in_delta ppm_pixel(p6, 30, 60)[2], 89, 1
    assert_in_delta ppm_pixel(p6, 190, 60)[0], 243, 1
    assert_in_delta ppm_pixel(p6, 190, 60)[1], 196, 1
    assert_in_delta ppm_pixel(p6, 190, 60)[2], 89, 1
    assert_in_delta ppm_pixel(p6, 80, 120)[0], 39, 1
    assert_in_delta ppm_pixel(p6, 80, 120)[1], 39, 1
    assert_in_delta ppm_pixel(p6, 80, 120)[2], 44, 1
    assert_in_delta ppm_pixel(p6, 80, 10)[0], 39, 1
    assert_in_delta ppm_pixel(p6, 80, 10)[1], 39, 1
    assert_in_delta ppm_pixel(p6, 80, 10)[2], 44, 1
    assert_in_delta ppm_pixel(p6, 10, 10)[0], 39, 1
    assert_in_delta ppm_pixel(p6, 10, 10)[1], 39, 1
    assert_in_delta ppm_pixel(p6, 10, 10)[2], 44, 1

    diff = max_channel_difference(p6, ref)
    assert diff <= 1, "max_channel_difference was #{diff}"
  end

  def test_the_star_by_coverage
    c = star_coverage
    ref = read_file("reference/chapter-05/star-coverage.ppm")
    p6 = canvas_to_p6(c)

    assert_equal 320, c.width
    assert_equal 160, c.height
    assert_in_delta ppm_pixel(p6, 80, 80)[0], 243, 1
    assert_in_delta ppm_pixel(p6, 80, 80)[1], 196, 1
    assert_in_delta ppm_pixel(p6, 80, 80)[2], 89, 1
    assert_in_delta ppm_pixel(p6, 240, 80)[0], 39, 1
    assert_in_delta ppm_pixel(p6, 240, 80)[1], 39, 1
    assert_in_delta ppm_pixel(p6, 240, 80)[2], 44, 1
    assert_in_delta ppm_pixel(p6, 80, 20)[0], 243, 1
    assert_in_delta ppm_pixel(p6, 80, 20)[1], 196, 1
    assert_in_delta ppm_pixel(p6, 80, 20)[2], 89, 1
    assert_in_delta ppm_pixel(p6, 240, 20)[0], 243, 1
    assert_in_delta ppm_pixel(p6, 240, 20)[1], 196, 1
    assert_in_delta ppm_pixel(p6, 240, 20)[2], 89, 1
    assert_in_delta ppm_pixel(p6, 80, 120)[0], 39, 1
    assert_in_delta ppm_pixel(p6, 80, 120)[1], 39, 1
    assert_in_delta ppm_pixel(p6, 80, 120)[2], 44, 1
    assert_in_delta ppm_pixel(p6, 80, 10)[0], 77, 1
    assert_in_delta ppm_pixel(p6, 80, 10)[1], 65, 1
    assert_in_delta ppm_pixel(p6, 80, 10)[2], 48, 1
    assert_in_delta ppm_pixel(p6, 240, 10)[0], 77, 1
    assert_in_delta ppm_pixel(p6, 240, 10)[1], 65, 1
    assert_in_delta ppm_pixel(p6, 240, 10)[2], 48, 1
    assert_in_delta ppm_pixel(p6, 80, 11)[0], 199, 1
    assert_in_delta ppm_pixel(p6, 80, 11)[1], 160, 1
    assert_in_delta ppm_pixel(p6, 80, 11)[2], 76, 1
    assert_in_delta ppm_pixel(p6, 14, 58)[0], 101, 1
    assert_in_delta ppm_pixel(p6, 14, 58)[1], 83, 1
    assert_in_delta ppm_pixel(p6, 14, 58)[2], 52, 1
    assert_in_delta ppm_pixel(p6, 174, 58)[0], 101, 1
    assert_in_delta ppm_pixel(p6, 174, 58)[1], 83, 1
    assert_in_delta ppm_pixel(p6, 174, 58)[2], 52, 1
    assert_in_delta ppm_pixel(p6, 10, 10)[0], 39, 1
    assert_in_delta ppm_pixel(p6, 10, 10)[1], 39, 1
    assert_in_delta ppm_pixel(p6, 10, 10)[2], 44, 1

    diff = max_channel_difference(p6, ref)
    assert diff <= 1, "max_channel_difference was #{diff}"
  end

  def test_plate_05
    c = plate_05
    ref = read_file("reference/chapter-05/plate-05.ppm")
    p6 = canvas_to_p6(c)

    assert_equal 640, c.width
    assert_equal 640, c.height
    assert_in_delta ppm_pixel(p6, 160, 160)[0], 243, 1
    assert_in_delta ppm_pixel(p6, 160, 160)[1], 196, 1
    assert_in_delta ppm_pixel(p6, 160, 160)[2], 89, 1
    assert_in_delta ppm_pixel(p6, 480, 160)[0], 39, 1
    assert_in_delta ppm_pixel(p6, 480, 160)[1], 39, 1
    assert_in_delta ppm_pixel(p6, 480, 160)[2], 44, 1
    assert_in_delta ppm_pixel(p6, 160, 480)[0], 243, 1
    assert_in_delta ppm_pixel(p6, 160, 480)[1], 196, 1
    assert_in_delta ppm_pixel(p6, 160, 480)[2], 89, 1
    assert_in_delta ppm_pixel(p6, 480, 480)[0], 39, 1
    assert_in_delta ppm_pixel(p6, 480, 480)[1], 39, 1
    assert_in_delta ppm_pixel(p6, 480, 480)[2], 44, 1
    assert_in_delta ppm_pixel(p6, 160, 40)[0], 243, 1
    assert_in_delta ppm_pixel(p6, 160, 40)[1], 196, 1
    assert_in_delta ppm_pixel(p6, 160, 40)[2], 89, 1
    assert_in_delta ppm_pixel(p6, 480, 360)[0], 243, 1
    assert_in_delta ppm_pixel(p6, 480, 360)[1], 196, 1
    assert_in_delta ppm_pixel(p6, 480, 360)[2], 89, 1
    assert_in_delta ppm_pixel(p6, 160, 20)[0], 39, 1
    assert_in_delta ppm_pixel(p6, 160, 20)[1], 39, 1
    assert_in_delta ppm_pixel(p6, 160, 20)[2], 44, 1
    assert_in_delta ppm_pixel(p6, 160, 341)[0], 77, 1
    assert_in_delta ppm_pixel(p6, 160, 341)[1], 65, 1
    assert_in_delta ppm_pixel(p6, 160, 341)[2], 48, 1
    assert_in_delta ppm_pixel(p6, 480, 341)[0], 77, 1
    assert_in_delta ppm_pixel(p6, 480, 341)[1], 65, 1
    assert_in_delta ppm_pixel(p6, 480, 341)[2], 48, 1
    assert_in_delta ppm_pixel(p6, 348, 437)[0], 101, 1
    assert_in_delta ppm_pixel(p6, 348, 437)[1], 83, 1
    assert_in_delta ppm_pixel(p6, 348, 437)[2], 52, 1
    assert_in_delta ppm_pixel(p6, 20, 20)[0], 39, 1
    assert_in_delta ppm_pixel(p6, 20, 20)[1], 39, 1
    assert_in_delta ppm_pixel(p6, 20, 20)[2], 44, 1

    diff = max_channel_difference(p6, ref)
    assert diff <= 1, "max_channel_difference was #{diff}"
  end
end
