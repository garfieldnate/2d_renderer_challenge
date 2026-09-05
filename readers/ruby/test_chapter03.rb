#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative 'renderer'

# Chapter 3: Lines Tests

class TestBresenhamLine < Minitest::Test
  def test_lit_pixels_reads_like_a_page
    c = canvas(10, 10)
    write_pixel(c, 5, 0, color(1, 1, 1))
    write_pixel(c, 0, 2, color(1, 1, 1))
    write_pixel(c, 2, 2, color(0.5, 0, 0))
    assert_equal lit_pixels(c), [[5, 0], [0, 2], [2, 2]]
  end

  def test_a_diagonal
    c = canvas(10, 10)
    line_bresenham(c, 0, 0, 5, 5, color(1, 1, 1))
    assert_equal lit_pixels(c), [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [5, 5]]
  end

  def test_a_horizontal_line_lights_one_row_and_nothing_else
    c = canvas(10, 10)
    line_bresenham(c, 0, 3, 7, 3, color(1, 1, 1))
    assert_equal lit_pixels(c), [[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3]]
  end

  def test_a_shallow_line_steps_along_x
    c = canvas(10, 10)
    line_bresenham(c, 0, 0, 7, 3, color(1, 1, 1))
    assert_equal lit_pixels(c), [[0, 0], [1, 0], [2, 1], [3, 1], [4, 2], [5, 2], [6, 3], [7, 3]]
  end

  def test_a_steep_line_steps_along_y
    c = canvas(10, 10)
    line_bresenham(c, 1, 1, 3, 7, color(1, 1, 1))
    assert_equal lit_pixels(c), [[1, 1], [1, 2], [2, 3], [2, 4], [2, 5], [3, 6], [3, 7]]
  end

  def test_pixels_dont_depend_on_which_end_you_start_from
    c1 = canvas(10, 10)
    c2 = canvas(10, 10)
    line_bresenham(c1, 1, 1, 3, 7, color(1, 1, 1))
    line_bresenham(c2, 3, 7, 1, 1, color(1, 1, 1))
    assert_equal lit_pixels(c1), lit_pixels(c2)
    assert_equal max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2)), 0
  end

  def test_a_line_going_up_and_to_the_right
    c = canvas(10, 10)
    line_bresenham(c, 0, 6, 7, 3, color(1, 1, 1))
    assert_equal [[6, 3], [7, 3], [4, 4], [5, 4], [2, 5], [3, 5], [0, 6], [1, 6]], lit_pixels(c)
  end

  def test_at_an_exact_half_the_line_stays_on_its_row_one_step_longer
    c = canvas(10, 10)
    line_bresenham(c, 0, 0, 4, 2, color(1, 1, 1))
    assert_equal lit_pixels(c), [[0, 0], [1, 0], [2, 1], [3, 1], [4, 2]]
  end

  def test_a_line_of_one_point
    c = canvas(10, 10)
    line_bresenham(c, 3, 3, 3, 3, color(1, 1, 1))
    assert_equal lit_pixels(c), [[3, 3]]
  end

  def test_a_line_may_run_off_the_canvas
    c = canvas(10, 10)
    line_bresenham(c, 0, 0, 12, 6, color(1, 1, 1))
    assert_equal lit_pixels(c).length, 10
  end
end

class TestWuLine < Minitest::Test
  def test_a_half_step_lights_two_pixels_equally
    c = canvas(10, 10)
    line_wu(c, 0, 0, 4, 2, color(1, 1, 1))
    assert pixel_at(c, 0, 0) == color(1, 1, 1)
    assert pixel_at(c, 1, 0) == color(0.5, 0.5, 0.5)
    assert pixel_at(c, 1, 1) == color(0.5, 0.5, 0.5)
    assert pixel_at(c, 2, 1) == color(1, 1, 1)
    assert pixel_at(c, 2, 2) == color(0, 0, 0)
    assert pixel_at(c, 4, 2) == color(1, 1, 1)
    assert_in_delta total_ink(c), 5, 0.0001
  end

  def test_a_diagonal_has_uniform_weights
    c = canvas(10, 10)
    line_wu(c, 0, 0, 5, 5, color(1, 1, 1))
    assert_equal lit_pixels(c), [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [5, 5]]
    assert pixel_at(c, 3, 3) == color(1, 1, 1)
    assert_in_delta total_ink(c), 6, 0.0001
  end

  def test_a_horizontal_line_has_weight_1_on_its_row_and_0_on_the_neighbors
    c = canvas(10, 10)
    line_wu(c, 0, 3, 7, 3, color(1, 1, 1))
    assert_equal lit_pixels(c), [[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3]]
    assert pixel_at(c, 3, 3) == color(1, 1, 1)
    assert pixel_at(c, 3, 2) == color(0, 0, 0)
    assert pixel_at(c, 3, 4) == color(0, 0, 0)
    assert_in_delta total_ink(c), 8, 0.0001
  end

  def test_a_steep_line_weights_across_columns
    c = canvas(10, 10)
    line_wu(c, 1, 1, 3, 7, color(1, 1, 1))
    assert pixel_at(c, 1, 1) == color(1, 1, 1)
    assert pixel_at(c, 1, 2).equal_within?(color(0.6667, 0.6667, 0.6667), 0.001)
    assert pixel_at(c, 2, 2).equal_within?(color(0.3333, 0.3333, 0.3333), 0.001)
    assert pixel_at(c, 2, 4) == color(1, 1, 1)
    assert pixel_at(c, 3, 7) == color(1, 1, 1)
    assert_in_delta total_ink(c), 7, 0.0001
  end

  def test_weights_dont_depend_on_which_end_you_start_from
    c1 = canvas(10, 10)
    c2 = canvas(10, 10)
    line_wu(c1, 1, 1, 3, 7, color(1, 1, 1))
    line_wu(c2, 3, 7, 1, 1, color(1, 1, 1))
    assert_equal max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2)), 0
  end

  def test_a_line_that_starts_above_the_canvas
    c = canvas(10, 10)
    line_wu(c, 0, -1, 8, 3, color(1, 1, 1))
    assert pixel_at(c, 1, 0) == color(0.5, 0.5, 0.5)
    assert pixel_at(c, 2, 0) == color(1, 1, 1)
    assert_in_delta total_ink(c), 7.5, 0.0001
  end

  def test_a_wu_line_of_one_point
    c = canvas(10, 10)
    line_wu(c, 3, 3, 3, 3, color(1, 1, 1))
    assert_equal lit_pixels(c), [[3, 3]]
    assert pixel_at(c, 3, 3) == color(1, 1, 1)
  end

  def test_sevenths
    c = canvas(10, 10)
    line_wu(c, 0, 0, 7, 3, color(1, 1, 1))
    assert pixel_at(c, 1, 0).equal_within?(color(0.5714, 0.5714, 0.5714), 0.001)
    assert pixel_at(c, 1, 1).equal_within?(color(0.4286, 0.4286, 0.4286), 0.001)
    assert pixel_at(c, 2, 0).equal_within?(color(0.1429, 0.1429, 0.1429), 0.001)
    assert pixel_at(c, 2, 1).equal_within?(color(0.8571, 0.8571, 0.8571), 0.001)
    assert_in_delta total_ink(c), 8, 0.0001
  end

  def test_ink_depends_on_the_angle_horizontal
    c = canvas(20, 20)
    line_wu(c, 2, 2, 12, 2, color(1, 1, 1))
    assert_in_delta total_ink(c), 11, 0.0001
  end

  def test_ink_depends_on_the_angle_diagonal_1
    c = canvas(20, 20)
    line_wu(c, 2, 2, 10, 8, color(1, 1, 1))
    assert_in_delta total_ink(c), 9, 0.0001
  end

  def test_ink_depends_on_the_angle_diagonal_2
    c = canvas(20, 20)
    line_wu(c, 2, 2, 8, 10, color(1, 1, 1))
    assert_in_delta total_ink(c), 9, 0.0001
  end

  def test_ink_depends_on_the_angle_vertical
    c = canvas(20, 20)
    line_wu(c, 2, 2, 2, 12, color(1, 1, 1))
    assert_in_delta total_ink(c), 11, 0.0001
  end
end

class TestThickLine < Minitest::Test
  def test_inside_a_thick_line
    s = thick_line(0, 0, 4, 0, 1)
    assert inside(s, 2.5, 0.5) == true
    assert inside(s, 2.5, 1.0) == true
    assert inside(s, 2.5, 1.01) == false
    assert inside(s, 0.5, 0.5) == true
    assert inside(s, 0.4, 0.5) == false
    assert inside(s, 4.5, 0.5) == true
    assert inside(s, 4.6, 0.5) == false
  end

  def test_a_horizontal_thick_line_covers_its_row_with_half_pixels_at_the_ends
    s = thick_line(0, 3, 7, 3, 1)
    cov = rasterize(s, 10, 10)
    assert_in_delta coverage_at(cov, 0, 3), 0.5, 0.0001
    assert_in_delta coverage_at(cov, 1, 3), 1, 0.0001
    assert_in_delta coverage_at(cov, 6, 3), 1, 0.0001
    assert_in_delta coverage_at(cov, 7, 3), 0.5, 0.0001
    assert_in_delta coverage_at(cov, 8, 3), 0, 0.0001
    assert_in_delta coverage_at(cov, 3, 2), 0, 0.0001
    assert_in_delta coverage_at(cov, 3, 4), 0, 0.0001
    assert_in_delta ink(cov), 7, 0.0001
  end

  def test_a_line_of_no_length_is_a_square
    s = thick_line(3, 3, 3, 3, 1)
    cov = rasterize(s, 8, 8)
    assert_in_delta coverage_at(cov, 3, 3), 1, 0.0001
    assert_in_delta ink(cov), 1, 0.0001
  end

  def test_a_wider_line
    s = thick_line(0, 3, 7, 3, 3)
    cov = rasterize(s, 10, 10)
    assert_in_delta coverage_at(cov, 3, 2), 1, 0.0001
    assert_in_delta coverage_at(cov, 3, 3), 1, 0.0001
    assert_in_delta coverage_at(cov, 3, 4), 1, 0.0001
    assert_in_delta coverage_at(cov, 3, 1), 0, 0.0001
    assert_in_delta coverage_at(cov, 3, 5), 0, 0.0001
    assert_in_delta coverage_at(cov, 0, 3), 0.5, 0.0001
    assert_in_delta ink(cov), 21, 0.0001
  end

  def test_an_off_axis_line_runs_through_pixel_centers_not_corners
    s = thick_line(2, 2, 11, 5, 1)
    cov = rasterize(s, 16, 10)
    assert_in_delta coverage_at(cov, 2, 2), 0.484375, 0.0001
    assert_in_delta coverage_at(cov, 11, 5), 0.484375, 0.0001
    assert_in_delta coverage_at(cov, 6, 3), 0.6875, 0.0001
    assert_in_delta coverage_at(cov, 7, 3), 0.359375, 0.0001
    assert_in_delta coverage_at(cov, 2, 1), 0, 0.0001
    assert_in_delta ink(cov), 9.4063, 0.0001
  end

  def test_ink_is_length_horizontal
    s = thick_line(2, 2, 12, 2, 1)
    cov = rasterize(s, 20, 20)
    assert_in_delta ink(cov), 10, 0.0001
  end

  def test_ink_is_length_diagonal_1
    s = thick_line(2, 2, 10, 8, 1)
    cov = rasterize(s, 20, 20)
    assert_in_delta ink(cov), 10, 0.0001
  end

  def test_ink_is_length_diagonal_2
    s = thick_line(2, 2, 8, 10, 1)
    cov = rasterize(s, 20, 20)
    assert_in_delta ink(cov), 10, 0.0001
  end

  def test_ink_is_length_vertical
    s = thick_line(2, 2, 2, 12, 1)
    cov = rasterize(s, 20, 20)
    assert_in_delta ink(cov), 10, 0.0001
  end

  def test_except_that_the_grid_is_blind_along_the_diagonal
    s = thick_line(2, 2, 9, 9, 1)
    cov = rasterize(s, 20, 20)
    # Check both exact value and tolerance
    ink_val = ink(cov)
    assert_in_delta ink_val, 9.7188, 0.0001
    assert_in_delta ink_val, 9.8995, 0.25
  end
end

class TestRayEnds < Minitest::Test
  def test_ray_ends
    ends = ray_ends
    expected = [[152, 80], [142, 116], [116, 142], [80, 152], [44, 142], [18, 116], [8, 80], [18, 44], [44, 18], [80, 8], [116, 18], [142, 44]]
    assert_equal ends, expected
  end
end

class TestFanRendering < Minitest::Test
  def test_bresenham_fan_dimensions
    c = fan_bresenham
    p6 = canvas_to_p6(c)
    assert_equal c.width, 160
    assert_equal c.height, 160
  end

  def test_bresenham_fan_pixels
    c = fan_bresenham
    p6 = canvas_to_p6(c)
    # Center point
    pixel = ppm_pixel(p6, 80, 80)
    assert_in_delta pixel[0], 246, 1
    assert_in_delta pixel[1], 246, 1
    assert_in_delta pixel[2], 241, 1
    # Right point
    pixel = ppm_pixel(p6, 120, 80)
    assert_in_delta pixel[0], 246, 1
    assert_in_delta pixel[1], 246, 1
    assert_in_delta pixel[2], 241, 1
    # Top-left point
    pixel = ppm_pixel(p6, 10, 10)
    assert_in_delta pixel[0], 39, 1
    assert_in_delta pixel[1], 39, 1
    assert_in_delta pixel[2], 44, 1
    # Between rays
    pixel = ppm_pixel(p6, 100, 91)
    assert_in_delta pixel[0], 39, 1
    assert_in_delta pixel[1], 39, 1
    assert_in_delta pixel[2], 44, 1
    # On ray
    pixel = ppm_pixel(p6, 100, 92)
    assert_in_delta pixel[0], 246, 1
    assert_in_delta pixel[1], 246, 1
    assert_in_delta pixel[2], 241, 1
    # Steep-ray probes, straddling a step
    pixel = ppm_pixel(p6, 103, 120)
    assert_in_delta pixel[0], 246, 1
    assert_in_delta pixel[1], 246, 1
    assert_in_delta pixel[2], 241, 1
    pixel = ppm_pixel(p6, 102, 120)
    assert_in_delta pixel[0], 39, 1
    assert_in_delta pixel[1], 39, 1
    assert_in_delta pixel[2], 44, 1
    pixel = ppm_pixel(p6, 104, 120)
    assert_in_delta pixel[0], 39, 1
    assert_in_delta pixel[1], 39, 1
    assert_in_delta pixel[2], 44, 1

    ref = read_file("reference/chapter-03/fan-bresenham.ppm")
    assert max_channel_difference(p6, ref) <= 1
  end

  def test_wu_fan_dimensions
    c = fan_wu
    p6 = canvas_to_p6(c)
    # Just verify it creates the right canvas
    assert c.width == 160
    assert c.height == 160
  end

  def test_wu_fan_pixels
    c = fan_wu
    p6 = canvas_to_p6(c)
    # Center point
    pixel = ppm_pixel(p6, 80, 80)
    assert_in_delta pixel[0], 246, 1
    assert_in_delta pixel[1], 246, 1
    assert_in_delta pixel[2], 241, 1
    # Right point
    pixel = ppm_pixel(p6, 120, 80)
    assert_in_delta pixel[0], 246, 1
    assert_in_delta pixel[1], 246, 1
    assert_in_delta pixel[2], 241, 1
    # Between rays (should be smoother than Bresenham)
    pixel = ppm_pixel(p6, 100, 91)
    assert_in_delta pixel[0], 163, 1
    assert_in_delta pixel[1], 163, 1
    assert_in_delta pixel[2], 161, 1
    # On transition
    pixel = ppm_pixel(p6, 100, 92)
    assert_in_delta pixel[0], 199, 1
    assert_in_delta pixel[1], 199, 1
    assert_in_delta pixel[2], 196, 1
    # Steep-ray probes, straddling a step
    pixel = ppm_pixel(p6, 103, 120)
    assert_in_delta pixel[0], 220, 1
    assert_in_delta pixel[1], 220, 1
    assert_in_delta pixel[2], 216, 1
    pixel = ppm_pixel(p6, 104, 120)
    assert_in_delta pixel[0], 130, 1
    assert_in_delta pixel[1], 130, 1
    assert_in_delta pixel[2], 129, 1

    ref = read_file("reference/chapter-03/fan-wu.ppm")
    assert max_channel_difference(p6, ref) <= 1
  end

  def test_fan_coverage_dimensions
    c = fan_coverage
    p6 = canvas_to_p6(c)
    assert_equal c.width, 320
    assert_equal c.height, 320
  end

  def test_fan_coverage_pixels
    c = fan_coverage
    p6 = canvas_to_p6(c)
    ref = read_file("reference/chapter-03/fan-coverage.ppm")

    # Center point (should be bright)
    pixel = ppm_pixel(p6, 160, 160)
    assert_in_delta pixel[0], 246, 1
    assert_in_delta pixel[1], 246, 1
    assert_in_delta pixel[2], 241, 1

    # Background (should be dark)
    pixel = ppm_pixel(p6, 10, 10)
    assert_in_delta pixel[0], 39, 1
    assert_in_delta pixel[1], 39, 1
    assert_in_delta pixel[2], 44, 1

    # Right point
    pixel = ppm_pixel(p6, 240, 160)
    assert_in_delta pixel[0], 246, 1
    assert_in_delta pixel[1], 246, 1
    assert_in_delta pixel[2], 241, 1

    # Between rays
    pixel = ppm_pixel(p6, 240, 158)
    assert_in_delta pixel[0], 39, 1
    assert_in_delta pixel[1], 39, 1
    assert_in_delta pixel[2], 44, 1

    # Mid-ray pixels
    pixel = ppm_pixel(p6, 200, 183)
    assert_in_delta pixel[0], 177, 1
    assert_in_delta pixel[1], 177, 1
    assert_in_delta pixel[2], 174, 1

    pixel = ppm_pixel(p6, 200, 185)
    assert_in_delta pixel[0], 209, 1
    assert_in_delta pixel[1], 209, 1
    assert_in_delta pixel[2], 205, 1

    # Compare with reference
    assert max_channel_difference(p6, ref) <= 1
  end

  def test_plate_03_dimensions
    c = plate_03
    p6 = canvas_to_p6(c)
    assert_equal c.width, 640
    assert_equal c.height, 320
  end

  def test_plate_03_pixels
    c = plate_03
    p6 = canvas_to_p6(c)
    ref = read_file("reference/chapter-03/plate-03.ppm")

    # Center points (should be bright in both fans)
    pixel = ppm_pixel(p6, 160, 160)
    assert_in_delta pixel[0], 246, 1
    assert_in_delta pixel[1], 246, 1
    assert_in_delta pixel[2], 241, 1

    pixel = ppm_pixel(p6, 480, 160)
    assert_in_delta pixel[0], 246, 1
    assert_in_delta pixel[1], 246, 1
    assert_in_delta pixel[2], 241, 1

    # Background (should be dark)
    pixel = ppm_pixel(p6, 10, 10)
    assert_in_delta pixel[0], 39, 1
    assert_in_delta pixel[1], 39, 1
    assert_in_delta pixel[2], 44, 1

    # Between rays in Bresenham (should be dark)
    pixel = ppm_pixel(p6, 200, 183)
    assert_in_delta pixel[0], 39, 1
    assert_in_delta pixel[1], 39, 1
    assert_in_delta pixel[2], 44, 1

    # On ray in Bresenham (should be bright)
    pixel = ppm_pixel(p6, 200, 185)
    assert_in_delta pixel[0], 246, 1
    assert_in_delta pixel[1], 246, 1
    assert_in_delta pixel[2], 241, 1

    # Between rays in Wu (should be smooth)
    pixel = ppm_pixel(p6, 520, 183)
    assert_in_delta pixel[0], 163, 1
    assert_in_delta pixel[1], 163, 1
    assert_in_delta pixel[2], 161, 1

    # On transition in Wu
    pixel = ppm_pixel(p6, 520, 185)
    assert_in_delta pixel[0], 199, 1
    assert_in_delta pixel[1], 199, 1
    assert_in_delta pixel[2], 196, 1

    # Compare with reference
    assert max_channel_difference(p6, ref) <= 1
  end
end
