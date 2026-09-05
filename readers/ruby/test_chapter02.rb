#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative 'renderer'

# Chapter 2: Coverage Tests

class TestShapes < Minitest::Test
  def test_a_point_inside_a_circle
    s = circle(8, 8, 5)
    assert inside(s, 8, 8) == true
    assert inside(s, 12, 8) == true
    assert inside(s, 13, 8) == true
    assert inside(s, 13.01, 8) == false
    assert inside(s, 11.6, 11.6) == false
  end

  def test_a_point_inside_a_rectangle
    s = rectangle(1.25, 2.0, 4.75, 5.0)
    assert inside(s, 3, 3) == true
    assert inside(s, 1.25, 2.0) == true
    assert inside(s, 4.75, 5.0) == true
    assert inside(s, 1.2, 3) == false
    assert inside(s, 3, 5.1) == false
  end

  def test_a_point_inside_a_half_plane
    s = half_plane(2.5, 0, 1, 0)
    assert inside(s, 2.5, 7) == true
    assert inside(s, 3, -4) == true
    assert inside(s, 2.4, 0) == false
  end

  def test_the_normal_picks_the_side
    s = half_plane(2.5, 0, -1, 0)
    assert inside(s, 2.4, 0) == true
    assert inside(s, 3, 0) == false
  end
end

class TestCoverageBuffer < Minitest::Test
  def test_a_new_coverage_buffer_is_empty
    cov = coverage_buffer(4, 3)
    assert_equal cov.width, 4
    assert_equal cov.height, 3
    assert_in_delta coverage_at(cov, 2, 1), 0, 0.0001
    assert_in_delta ink(cov), 0, 0.0001
  end

  def test_setting_coverage
    cov = coverage_buffer(4, 3)
    set_coverage(cov, 2, 1, 0.75)
    assert_in_delta coverage_at(cov, 2, 1), 0.75, 0.0001
    assert_in_delta coverage_at(cov, 1, 2), 0, 0.0001
    assert_in_delta ink(cov), 0.75, 0.0001
  end

  def test_setting_coverage_outside_the_buffer_is_ignored
    cov = coverage_buffer(4, 3)
    set_coverage(cov, -1, 1, 1)
    set_coverage(cov, 4, 1, 1)
    set_coverage(cov, 1, 3, 1)
    assert_in_delta ink(cov), 0, 0.0001
    assert_in_delta coverage_at(cov, -1, 1), 0, 0.0001
    assert_in_delta coverage_at(cov, 4, 1), 0, 0.0001
    assert_in_delta coverage_at(cov, 1, 3), 0, 0.0001
  end

  def test_the_center_of_pixel_x_y_is_x_plus_half_y_plus_half
    s = half_plane(2.5, 0, 1, 0)
    assert_equal center_inside(s, 2, 4), 1
    assert_equal center_inside(s, 1, 4), 0
    t = half_plane(2.6, 0, 1, 0)
    assert_equal center_inside(t, 2, 4), 0
  end

  def test_the_center_question_is_not_at_least_half
    s = half_plane(2.55, 0, 1, 0)
    assert_equal center_inside(s, 2, 4), 0
    assert_in_delta coverage(s, 2, 4), 0.5, 0.0001
  end

  def test_a_buffer_need_not_be_square
    s = rectangle(0, 0, 2, 1)
    cov = rasterize_centers(s, 4, 2)
    assert_equal cov.width, 4
    assert_equal cov.height, 2
    assert_in_delta coverage_at(cov, 1, 0), 1, 0.0001
    assert_in_delta coverage_at(cov, 0, 1), 0, 0.0001
    assert_in_delta ink(cov), 2, 0.0001
  end

  def test_a_rectangle_by_asking_each_center
    s = rectangle(1.25, 2.0, 4.75, 5.0)
    cov = rasterize_centers(s, 8, 8)
    assert_in_delta coverage_at(cov, 1, 4), 1, 0.0001
    assert_in_delta coverage_at(cov, 4, 1), 0, 0.0001
    assert_in_delta coverage_at(cov, 4, 4), 1, 0.0001
    assert_in_delta coverage_at(cov, 0, 3), 0, 0.0001
    assert_in_delta coverage_at(cov, 5, 3), 0, 0.0001
    assert_in_delta coverage_at(cov, 2, 1), 0, 0.0001
    assert_in_delta coverage_at(cov, 2, 5), 0, 0.0001
    assert_in_delta ink(cov), 12, 0.0001
  end

  def test_a_disc_by_asking_each_center
    s = circle(8, 8, 5)
    cov = rasterize_centers(s, 16, 16)
    assert_equal cov.width, 16
    assert_equal cov.height, 16
    assert_in_delta coverage_at(cov, 8, 8), 1, 0.0001
    assert_in_delta coverage_at(cov, 3, 8), 1, 0.0001
    assert_in_delta coverage_at(cov, 12, 8), 1, 0.0001
    assert_in_delta coverage_at(cov, 2, 8), 0, 0.0001
    assert_in_delta coverage_at(cov, 13, 8), 0, 0.0001
    assert_in_delta coverage_at(cov, 4, 4), 1, 0.0001
    assert_in_delta coverage_at(cov, 3, 4), 0, 0.0001
    assert_in_delta ink(cov), 80, 0.0001
  end
end

class TestCoverage < Minitest::Test
  def test_the_sixty_four_sample_points
    s = half_plane(2.5, 0, 1, 0)
    assert_in_delta coverage(s, 2, 4), 0.5, 0.0001
    assert_in_delta coverage(s, 1, 4), 0, 0.0001
    assert_in_delta coverage(s, 3, 4), 1, 0.0001
  end

  def test_a_rectangle_is_covered_exactly_when_its_edges_land_on_sample_boundaries
    s = rectangle(1.25, 2.0, 4.75, 5.0)
    cov = rasterize(s, 8, 8)
    assert_in_delta coverage_at(cov, 0, 2), 0, 0.0001
    assert_in_delta coverage_at(cov, 1, 2), 0.75, 0.0001
    assert_in_delta coverage_at(cov, 2, 2), 1, 0.0001
    assert_in_delta coverage_at(cov, 3, 2), 1, 0.0001
    assert_in_delta coverage_at(cov, 4, 2), 0.75, 0.0001
    assert_in_delta coverage_at(cov, 5, 2), 0, 0.0001
    assert_in_delta coverage_at(cov, 2, 1), 0, 0.0001
    assert_in_delta coverage_at(cov, 2, 5), 0, 0.0001
    assert_in_delta ink(cov), 10.5, 0.0001
  end

  def test_neither_need_the_buffer_be_square_here
    s = rectangle(0, 0, 2, 1)
    cov = rasterize(s, 4, 2)
    assert_equal cov.width, 4
    assert_equal cov.height, 2
    assert_in_delta coverage_at(cov, 1, 0), 1, 0.0001
    assert_in_delta coverage_at(cov, 2, 0), 0, 0.0001
    assert_in_delta coverage_at(cov, 0, 1), 0, 0.0001
    assert_in_delta ink(cov), 2, 0.0001
  end

  def test_a_half_plane_through_a_pixel_center_covers_half_of_it
    s = half_plane(2.5, 4.5, 0.6, 0.8)
    assert_in_delta coverage(s, 2, 4), 0.5, 0.0001
  end

  def test_except_when_the_grid_conspires
    s = half_plane(2.5, 4.5, 1, 1)
    assert_in_delta coverage(s, 2, 4), 0.5625, 0.0001
  end

  def test_a_disc_is_only_ever_approximately_covered
    s = circle(8, 8, 5)
    cov = rasterize(s, 16, 16)
    assert_in_delta coverage_at(cov, 8, 8), 1, 0.0001
    assert_in_delta coverage_at(cov, 3, 8), 0.96875, 0.0001
    assert_in_delta coverage_at(cov, 12, 8), 0.96875, 0.0001
    assert_in_delta coverage_at(cov, 4, 4), 0.5625, 0.0001
    assert_in_delta coverage_at(cov, 3, 4), 0, 0.0001
    assert_in_delta ink(cov), 78.5398, 0.1
  end

  def test_the_disc_by_coverage
    c = disc_coverage()
    ref = read_file("reference/chapter-02/disc-coverage.ppm")
    p6 = canvas_to_p6(c)
    assert_equal c.width, 320
    assert_equal c.height, 320

    # Check specific pixels
    pixel = ppm_pixel(p6, 160, 160)
    assert_in_delta pixel[0], 243, 1
    assert_in_delta pixel[1], 196, 1
    assert_in_delta pixel[2], 89, 1

    pixel = ppm_pixel(p6, 124, 36)
    assert_in_delta pixel[0], 157, 1
    assert_in_delta pixel[1], 127, 1
    assert_in_delta pixel[2], 64, 1

    diff = max_channel_difference(p6, ref)
    assert diff <= 1
  end
end

class TestP6Format < Minitest::Test
  def test_the_header_then_the_bytes
    c = canvas(2, 1)
    write_pixel(c, 0, 0, color(1, 0, 0))
    write_pixel(c, 1, 0, color(0, 0.5, 0))
    p6 = canvas_to_p6(c)

    assert p6.start_with?("P6\n2 1\n255\n")
    assert_equal p6.length, 17

    # "byte 12 of p6" means the 12th byte (1-indexed) = index 11 (0-indexed)
    assert_equal p6.bytes[11], 255
    assert_equal p6.bytes[12], 0
    assert_equal p6.bytes[15], 188
  end

  def test_the_same_pixel_comes_back_out_of_either_format
    c = canvas(2, 1)
    write_pixel(c, 1, 0, color(0, 0.5, 0))
    p3 = canvas_to_ppm(c)
    p6 = canvas_to_p6(c)

    pixel_p6 = ppm_pixel(p6, 1, 0)
    pixel_p3 = ppm_pixel(p3, 1, 0)

    assert_equal pixel_p6[0], 0
    assert_equal pixel_p6[1], 188
    assert_equal pixel_p6[2], 0

    assert_equal pixel_p3[0], 0
    assert_equal pixel_p3[1], 188
    assert_equal pixel_p3[2], 0

    diff = max_channel_difference(p3, p6)
    assert_equal diff, 0

    values = distinct_values(p6)
    assert_equal values, 2
  end

  def test_rows_go_top_to_bottom
    c = canvas(1, 2)
    write_pixel(c, 0, 0, color(1, 0, 0))
    write_pixel(c, 0, 1, color(0, 0, 1))
    p6 = canvas_to_p6(c)

    assert_equal p6.bytes[11], 255
    assert_equal p6.bytes[16], 255

    pixel0 = ppm_pixel(p6, 0, 0)
    assert_equal pixel0, [255, 0, 0]

    pixel1 = ppm_pixel(p6, 0, 1)
    assert_equal pixel1, [0, 0, 255]
  end

  def test_the_binary_writer_clamps_too
    c = canvas(2, 1)
    write_pixel(c, 0, 0, color(1.5, 0, -0.5))
    p6 = canvas_to_p6(c)

    assert_equal p6.bytes[11], 255
    assert_equal p6.bytes[12], 0
    assert_equal p6.bytes[13], 0

    pixel = ppm_pixel(p6, 0, 0)
    assert_equal pixel, [255, 0, 0]
  end

  def test_pixel_bytes_that_look_like_whitespace_are_still_pixel_bytes
    c = canvas(2, 1)
    write_pixel(c, 0, 0, color(0.00304, 0.01444, 0.00304))
    write_pixel(c, 1, 0, color(1, 1, 1))
    p6 = canvas_to_p6(c)

    assert_equal p6.length, 17
    assert_equal p6.bytes[11], 10
    assert_equal p6.bytes[12], 32

    pixel0 = ppm_pixel(p6, 0, 0)
    assert_equal pixel0, [10, 32, 10]

    pixel1 = ppm_pixel(p6, 1, 0)
    assert_equal pixel1, [255, 255, 255]

    diff = max_channel_difference(canvas_to_ppm(c), p6)
    assert_equal diff, 0
  end

  def test_sizes_still_have_to_match
    c1 = canvas(2, 1)
    c2 = canvas(1, 2)
    p6a = canvas_to_p6(c1)
    p6b = canvas_to_p6(c2)

    diff = max_channel_difference(p6a, p6b)
    assert_equal diff, 255
  end
end

class TestPaintThrough < Minitest::Test
  def test_half_coverage_is_half_the_paint
    c = canvas(1, 1)
    cov = coverage_buffer(1, 1)
    set_coverage(cov, 0, 0, 0.5)
    paint_through(c, cov, color(1, 1, 1))

    pixel = pixel_at(c, 0, 0)
    assert_in_delta pixel.red, 0.5, 0.0001
    assert_in_delta pixel.green, 0.5, 0.0001
    assert_in_delta pixel.blue, 0.5, 0.0001
  end

  def test_paint_over_something_that_isnt_black
    c = canvas(1, 1)
    cov = coverage_buffer(1, 1)
    fill(c, color(0.2, 0.2, 0.2))
    set_coverage(cov, 0, 0, 0.25)
    paint_through(c, cov, color(1, 0, 0))

    pixel = pixel_at(c, 0, 0)
    assert_in_delta pixel.red, 0.4, 0.0001
    assert_in_delta pixel.green, 0.15, 0.0001
    assert_in_delta pixel.blue, 0.15, 0.0001
  end

  def test_zero_leaves_it_alone_and_one_replaces_it
    c = canvas(2, 1)
    cov = coverage_buffer(2, 1)
    fill(c, color(0.2, 0.2, 0.2))
    set_coverage(cov, 1, 0, 1)
    paint_through(c, cov, color(1, 0, 0))

    pixel0 = pixel_at(c, 0, 0)
    assert_in_delta pixel0.red, 0.2, 0.0001
    assert_in_delta pixel0.green, 0.2, 0.0001
    assert_in_delta pixel0.blue, 0.2, 0.0001

    pixel1 = pixel_at(c, 1, 0)
    assert_in_delta pixel1.red, 1, 0.0001
    assert_in_delta pixel1.green, 0, 0.0001
    assert_in_delta pixel1.blue, 0, 0.0001
  end

  def test_the_arithmetic_is_on_light
    $linear_blending = false
    c = canvas(1, 1)
    cov = coverage_buffer(1, 1)
    set_coverage(cov, 0, 0, 0.5)
    paint_through(c, cov, color(1, 1, 1))
    ppm = canvas_to_ppm(c)

    pixel = pixel_at(c, 0, 0)
    assert_in_delta pixel.red, 0.5, 0.0001
    assert_in_delta pixel.green, 0.5, 0.0001
    assert_in_delta pixel.blue, 0.5, 0.0001

    pixel_bytes = ppm_pixel(ppm, 0, 0)
    assert_equal pixel_bytes, [188, 188, 188]
    $linear_blending = true
  end

  def test_the_disc_by_centers
    c = disc_centers()
    ref = read_file("reference/chapter-02/disc-centers.ppm")
    p6 = canvas_to_p6(c)
    assert_equal c.width, 320
    assert_equal c.height, 320

    pixel = ppm_pixel(p6, 160, 160)
    assert_in_delta pixel[0], 243, 1
    assert_in_delta pixel[1], 196, 1
    assert_in_delta pixel[2], 89, 1

    pixel = ppm_pixel(p6, 124, 36)
    assert_in_delta pixel[0], 39, 1
    assert_in_delta pixel[1], 39, 1
    assert_in_delta pixel[2], 44, 1

    pixel = ppm_pixel(p6, 132, 36)
    assert_in_delta pixel[0], 243, 1
    assert_in_delta pixel[1], 196, 1
    assert_in_delta pixel[2], 89, 1

    values = distinct_values(p6)
    assert_equal values, 5

    diff = max_channel_difference(p6, ref)
    assert diff <= 1
  end
end

class TestMagnify < Minitest::Test
  def test_every_pixel_becomes_a_block
    c = canvas(2, 1)
    write_pixel(c, 0, 0, color(1, 0, 0))
    write_pixel(c, 1, 0, color(0, 0.5, 0))
    m = magnify(c, 3)

    assert_equal m.width, 6
    assert_equal m.height, 3

    pixel = pixel_at(m, 0, 0)
    assert pixel == color(1, 0, 0)

    pixel = pixel_at(m, 2, 2)
    assert pixel == color(1, 0, 0)

    pixel = pixel_at(m, 3, 0)
    assert pixel == color(0, 0.5, 0)

    pixel = pixel_at(m, 5, 2)
    assert pixel == color(0, 0.5, 0)

    # Count red pixels
    red_count = 0
    m.height.times do |y|
      m.width.times do |x|
        p = pixel_at(m, x, y)
        if p.red == 1 && p.green == 0 && p.blue == 0
          red_count += 1
        end
      end
    end
    assert_equal red_count, 9
  end

  def test_magnifying_by_one_changes_nothing
    c = canvas(2, 1)
    write_pixel(c, 1, 0, color(0, 0.5, 0))
    m = magnify(c, 1)

    diff = max_channel_difference(canvas_to_p6(c), canvas_to_p6(m))
    assert_equal diff, 0
  end
end

class TestCoverageTwice < Minitest::Test
  def test_half_coverage_painted_twice_is_three_quarters
    c = canvas(1, 1)
    cov = coverage_buffer(1, 1)
    set_coverage(cov, 0, 0, 0.5)
    paint_through(c, cov, color(1, 1, 1))
    paint_through(c, cov, color(1, 1, 1))

    pixel = pixel_at(c, 0, 0)
    assert_in_delta pixel.red, 0.75, 0.0001
    assert_in_delta pixel.green, 0.75, 0.0001
    assert_in_delta pixel.blue, 0.75, 0.0001
  end

  def test_the_disc_once_and_twice
    c = painted_twice()
    ref = read_file("reference/chapter-02/painted-twice.ppm")
    p6 = canvas_to_p6(c)
    assert_equal c.width, 480
    assert_equal c.height, 240

    pixel = ppm_pixel(p6, 120, 120)
    assert_in_delta pixel[0], 243, 1
    assert_in_delta pixel[1], 196, 1
    assert_in_delta pixel[2], 89, 1

    pixel = ppm_pixel(p6, 360, 120)
    assert_in_delta pixel[0], 243, 1
    assert_in_delta pixel[1], 196, 1
    assert_in_delta pixel[2], 89, 1

    pixel = ppm_pixel(p6, 93, 27)
    assert_in_delta pixel[0], 157, 1
    assert_in_delta pixel[1], 127, 1
    assert_in_delta pixel[2], 64, 1

    pixel = ppm_pixel(p6, 333, 27)
    assert_in_delta pixel[0], 194, 1
    assert_in_delta pixel[1], 156, 1
    assert_in_delta pixel[2], 74, 1

    diff = max_channel_difference(p6, ref)
    assert diff <= 1
  end
end

class TestPlate02 < Minitest::Test
  def test_the_plate
    c = plate_02()
    ref = read_file("reference/chapter-02/plate-02.ppm")
    p6 = canvas_to_p6(c)
    assert_equal c.width, 480
    assert_equal c.height, 240

    pixel = ppm_pixel(p6, 120, 120)
    assert_in_delta pixel[0], 243, 1
    assert_in_delta pixel[1], 196, 1
    assert_in_delta pixel[2], 89, 1

    pixel = ppm_pixel(p6, 360, 120)
    assert_in_delta pixel[0], 243, 1
    assert_in_delta pixel[1], 196, 1
    assert_in_delta pixel[2], 89, 1

    pixel = ppm_pixel(p6, 93, 27)
    assert_in_delta pixel[0], 39, 1
    assert_in_delta pixel[1], 39, 1
    assert_in_delta pixel[2], 44, 1

    pixel = ppm_pixel(p6, 333, 27)
    assert_in_delta pixel[0], 157, 1
    assert_in_delta pixel[1], 127, 1
    assert_in_delta pixel[2], 64, 1

    diff = max_channel_difference(p6, ref)
    assert diff <= 1
  end
end
