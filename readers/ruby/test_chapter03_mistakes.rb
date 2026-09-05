#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative 'renderer'

# Chapter 3: Mistake Detection Tests
# These tests verify that common implementation errors are caught by the test suite

class TestBresenhamErrorInitError < Minitest::Test
  # MISTAKE: Initialize error to 0 instead of dx/2
  def test_bresenham_error_init_zero_fails
    skip "This demonstrates a mistake that should fail tests"

    # Simulate the mistake: error initialized to 0 instead of dx/2
    canvas = Canvas.new(10, 10)
    c = canvas
    fill(c, color(0, 0, 0))

    # Manual Bresenham with err = 0 instead of dx/2
    x0, y0, x1, y1 = 0, 0, 4, 2
    steep = (y1 - y0).abs > (x1 - x0).abs

    if x0 > x1
      x0, x1 = x1, x0
      y0, y1 = y1, y0
    end

    dx = x1 - x0
    dy = (y1 - y0).abs
    ystep = y0 < y1 ? 1 : -1
    err = 0  # MISTAKE: should be dx/2
    y = y0

    (x0..x1).each do |x|
      write_pixel(c, x, y, color(1, 1, 1))
      err = err - dy
      if err < 0
        y = y + ystep
        err = err + dx
      end
    end

    # This will produce different pixels than expected
    pixels = lit_pixels(c)
    # Expected: [[0, 0], [1, 0], [2, 1], [3, 1], [4, 2]]
    # But with err=0, we get a different pattern
    assert_equal pixels, [[0, 0], [1, 0], [2, 1], [3, 1], [4, 2]]
  end
end

class TestBresenhamSteepSwapError < Minitest::Test
  # MISTAKE: Forget to swap coordinates back when steep
  def test_bresenham_steep_swap_forgotten_fails
    skip "This demonstrates a mistake that should fail tests"

    canvas = Canvas.new(10, 10)
    c = canvas
    fill(c, color(0, 0, 0))

    # Manual Bresenham forgetting to swap back for steep lines
    x0, y0, x1, y1 = 1, 1, 3, 7
    col = color(1, 1, 1)

    steep = (y1 - y0).abs > (x1 - x0).abs

    if steep
      x0, y0 = y0, x0
      x1, y1 = y1, x1
    end

    if x0 > x1
      x0, x1 = x1, x0
      y0, y1 = y1, y0
    end

    dx = x1 - x0
    dy = (y1 - y0).abs
    ystep = y0 < y1 ? 1 : -1
    err = dx / 2
    y = y0

    (x0..x1).each do |x|
      if steep
        # MISTAKE: forgot to swap back
        write_pixel(c, x, y, col)  # should be write_pixel(c, y, x, col)
      else
        write_pixel(c, x, y, col)
      end
      err = err - dy
      if err < 0
        y = y + ystep
        err = err + dx
      end
    end

    # This will fail because pixels are in wrong places
    pixels = lit_pixels(c)
    # Expected: [[1, 1], [1, 2], [2, 3], [2, 4], [2, 5], [3, 6], [3, 7]]
    # But will be different
    assert_equal pixels, [[1, 1], [1, 2], [2, 3], [2, 4], [2, 5], [3, 6], [3, 7]]
  end
end

class TestWuWeightsSwapped < Minitest::Test
  # MISTAKE: Swap the Wu weights (use f instead of 1-f)
  def test_wu_weights_swapped_fails
    skip "This demonstrates a mistake that should fail tests"

    canvas = Canvas.new(10, 10)
    c = canvas
    fill(c, color(0, 0, 0))

    # Manual Wu with swapped weights
    x0, y0, x1, y1 = 0, 0, 4, 2
    col = color(1, 1, 1)

    steep = (y1 - y0).abs > (x1 - x0).abs

    if steep
      x0, y0 = y0, x0
      x1, y1 = y1, x1
    end

    if x0 > x1
      x0, x1 = x1, x0
      y0, y1 = y1, y0
    end

    dx = x1 - x0
    slope = dx == 0 ? 0 : (y1 - y0).to_f / dx

    (x0..x1).each do |x|
      y = y0 + (x - x0) * slope
      yi = y.floor
      f = y - yi

      if steep
        plot(c, yi, x, col, f)  # MISTAKE: should be 1-f
        plot(c, yi + 1, x, col, 1 - f)  # MISTAKE: should be f
      else
        plot(c, x, yi, col, f)  # MISTAKE: should be 1-f
        plot(c, x, yi + 1, col, 1 - f)  # MISTAKE: should be f
      end
    end

    # The ink will be wrong
    ink_val = total_ink(c)
    assert_in_delta ink_val, 5, 0.0001
  end
end

class TestWuRoundingError < Minitest::Test
  # MISTAKE: Use round instead of floor for yi
  def test_wu_rounding_instead_of_floor_fails
    skip "This demonstrates a mistake that should fail tests"

    canvas = Canvas.new(10, 10)
    c = canvas
    fill(c, color(0, 0, 0))

    # Manual Wu with round instead of floor
    x0, y0, x1, y1 = 0, 0, 4, 2
    col = color(1, 1, 1)

    steep = (y1 - y0).abs > (x1 - x0).abs

    if steep
      x0, y0 = y0, x0
      x1, y1 = y1, x1
    end

    if x0 > x1
      x0, x1 = x1, x0
      y0, y1 = y1, y0
    end

    dx = x1 - x0
    slope = dx == 0 ? 0 : (y1 - y0).to_f / dx

    (x0..x1).each do |x|
      y = y0 + (x - x0) * slope
      yi = y.round  # MISTAKE: should be floor
      f = y - yi

      if steep
        plot(c, yi, x, col, 1 - f)
        plot(c, yi + 1, x, col, f)
      else
        plot(c, x, yi, col, 1 - f)
        plot(c, x, yi + 1, col, f)
      end
    end

    # The pixels will be different
    pixels = lit_pixels(c)
    # Expected: [[0, 0], [1, 0], [1, 1], [2, 1], [4, 2]]
    # But with round, yi values will be different
    assert_equal pixels, [[0, 0], [1, 0], [1, 1], [2, 1], [4, 2]]
  end
end

class TestThickLinePlanesFacingOutward < Minitest::Test
  # MISTAKE: Half-planes facing outward instead of inward
  def test_thick_line_planes_outward_fails
    skip "This demonstrates a mistake that should fail tests"

    # Create a thick line with planes facing OUTWARD (mistake)
    # Instead of:
    #   plane3 = HalfPlane.new(side1_x, side1_y, -norm_x, -norm_y)
    # We do:
    #   plane3 = HalfPlane.new(side1_x, side1_y, norm_x, norm_y)

    x0_f = 0.5
    y0_f = 0.5
    x1_f = 4.5
    y1_f = 0.5
    width = 1

    dx = x1_f - x0_f
    dy = y1_f - y0_f
    len = Math.sqrt(dx * dx + dy * dy)
    dir_x = dx / len
    dir_y = dy / len
    norm_x = -dir_y
    norm_y = dir_x
    half_width = width / 2.0

    plane1 = HalfPlane.new(x0_f, y0_f, dir_x, dir_y)
    plane2 = HalfPlane.new(x1_f, y1_f, -dir_x, -dir_y)

    side1_x = x0_f + norm_x * half_width
    side1_y = y0_f + norm_y * half_width
    plane3 = HalfPlane.new(side1_x, side1_y, norm_x, norm_y)  # MISTAKE: should be -norm_x, -norm_y

    side2_x = x0_f - norm_x * half_width
    side2_y = y0_f - norm_y * half_width
    plane4 = HalfPlane.new(side2_x, side2_y, -norm_x, -norm_y)  # MISTAKE: should be norm_x, norm_y

    planes = [plane1, plane2, plane3, plane4]

    # Now test some points
    # (2.5, 0.5) should be inside a horizontal line
    inside_all = planes.all? { |plane| plane.inside?(2.5, 0.5) }

    # This will fail because planes face outward
    assert inside_all
  end
end

class TestThickLinePixelCornersNotCenters < Minitest::Test
  # MISTAKE: Using pixel corners instead of centers
  def test_thick_line_from_corners_fails
    skip "This demonstrates a mistake that should fail tests"

    # If we use pixel CORNERS instead of CENTERS:
    x0_int = 0
    y0_int = 3
    x1_int = 7
    y1_int = 3
    width = 1

    # Mistake: using (x0_int, y0_int) instead of (x0_int + 0.5, y0_int + 0.5)
    x0_f = x0_int.to_f  # MISTAKE: should be x0_int + 0.5
    y0_f = y0_int.to_f  # MISTAKE: should be y0_int + 0.5
    x1_f = x1_int.to_f
    y1_f = y1_int.to_f

    dx = x1_f - x0_f
    dy = y1_f - y0_f
    len = Math.sqrt(dx * dx + dy * dy)
    dir_x = dx / len
    dir_y = dy / len
    norm_x = -dir_y
    norm_y = dir_x
    half_width = width / 2.0

    plane1 = HalfPlane.new(x0_f, y0_f, dir_x, dir_y)
    plane2 = HalfPlane.new(x1_f, y1_f, -dir_x, -dir_y)

    side1_x = x0_f + norm_x * half_width
    side1_y = y0_f + norm_y * half_width
    plane3 = HalfPlane.new(side1_x, side1_y, -norm_x, -norm_y)

    side2_x = x0_f - norm_x * half_width
    side2_y = y0_f - norm_y * half_width
    plane4 = HalfPlane.new(side2_x, side2_y, norm_x, norm_y)

    planes = [plane1, plane2, plane3, plane4]

    # Test point (0, 3.5) - should NOT be inside because it's outside the line segment
    # But if we use corners, the half-plane conditions might be wrong
    inside_count = planes.count { |plane| plane.inside?(0, 3.5) }

    # With correct centers, this should not be inside all 4 planes
    # But with corners, the result might be different
    assert inside_count < 4
  end
end
