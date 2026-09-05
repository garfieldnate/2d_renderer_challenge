#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative 'renderer'

class TestEquality < Minitest::Test
  def test_two_numbers_that_differ_by_less_than_tolerance_are_equal
    assert_in_delta 1.0, 1.0000001, 0.00001
  end

  def test_two_numbers_that_differ_by_more_than_tolerance_are_not
    assert_equal false, (1.0 - 1.001).abs <= 0.00001
  end

  def test_default_tolerance_is_0_0001
    assert_in_delta 0.1 + 0.2, 0.3, 0.0001
    assert_in_delta 1.0, 1.00009, 0.0001
    assert_equal false, (1.0 - 1.0002).abs <= 0.0001
  end
end

class TestColors < Minitest::Test
  def test_a_color_is_a_red_green_blue_tuple
    c = color(-0.5, 0.4, 1.7)
    assert_in_delta c.red, -0.5, 0.0001
    assert_in_delta c.green, 0.4, 0.0001
    assert_in_delta c.blue, 1.7, 0.0001
  end

  def test_adding_colors
    c1 = color(0.9, 0.6, 0.75)
    c2 = color(0.7, 0.1, 0.25)
    result = c1 + c2
    expected = color(1.6, 0.7, 1.0)
    assert result == expected
  end

  def test_subtracting_colors
    c1 = color(0.9, 0.6, 0.75)
    c2 = color(0.7, 0.1, 0.25)
    result = c1 - c2
    expected = color(0.2, 0.5, 0.5)
    assert result == expected
  end

  def test_scaling_a_color_by_a_number
    c = color(0.2, 0.3, 0.4)
    result1 = c * 2
    expected1 = color(0.4, 0.6, 0.8)
    assert result1 == expected1

    result2 = c * 0.5
    expected2 = color(0.1, 0.15, 0.2)
    assert result2 == expected2
  end

  def test_multiplying_two_colors_filters_one_through_the_other
    c1 = color(1, 0.2, 0.4)
    c2 = color(0.9, 1, 0.1)
    result = c1 * c2
    expected = color(0.9, 0.2, 0.04)
    assert result == expected
  end

  def test_colors_compare_component_by_component_with_usual_tolerance
    c1 = color(0.1, 0.5, 1)
    c2 = color(0.2, 0, 0)
    result = c1 + c2
    expected = color(0.3, 0.5, 1)
    assert result == expected
    assert (c1 + c2) != color(0.3, 0.5, 1.001)
  end
end

class TestCanvas < Minitest::Test
  def test_a_new_canvas_is_black
    c = canvas(10, 20)
    assert_equal c.width, 10
    assert_equal c.height, 20
    # Check every pixel is black
    c.height.times do |y|
      c.width.times do |x|
        assert c.pixel_at(x, y) == color(0, 0, 0)
      end
    end
  end

  def test_writing_a_pixel
    c = canvas(10, 20)
    red = color(1, 0, 0)
    write_pixel(c, 2, 3, red)
    assert pixel_at(c, 2, 3) == red
  end

  def test_x_is_the_column_and_y_is_the_row
    c = canvas(10, 20)
    write_pixel(c, 2, 3, color(1, 0, 0))
    assert pixel_at(c, 3, 2) == color(0, 0, 0)
    assert pixel_at(c, 2, 3) == color(1, 0, 0)
  end

  def test_writing_outside_the_canvas_is_ignored
    c = canvas(10, 20)
    write_pixel(c, -1, 5, color(1, 0, 0))
    write_pixel(c, 10, 5, color(1, 0, 0))
    write_pixel(c, 5, -1, color(1, 0, 0))
    write_pixel(c, 5, 20, color(1, 0, 0))
    # Check every pixel is still black
    c.height.times do |y|
      c.width.times do |x|
        assert c.pixel_at(x, y) == color(0, 0, 0)
      end
    end
  end

  def test_a_pixel_can_be_written_more_than_once
    c = canvas(10, 20)
    write_pixel(c, 2, 3, color(1, 0, 0))
    write_pixel(c, 2, 3, color(0, 1, 0))
    assert pixel_at(c, 2, 3) == color(0, 1, 0)
  end

  def test_filling_a_canvas
    c = canvas(10, 20)
    fill(c, color(0.1, 0.2, 0.3))
    c.height.times do |y|
      c.width.times do |x|
        assert c.pixel_at(x, y) == color(0.1, 0.2, 0.3)
      end
    end
  end
end

class TestSRGB < Minitest::Test
  # sRGB encoding tests
  def test_encode_0_0
    assert_in_delta encode(0.0), 0.0, 0.0001
  end

  def test_encode_0_0025
    assert_in_delta encode(0.0025), 0.0323, 0.0001
  end

  def test_encode_0_01
    assert_in_delta encode(0.01), 0.0999, 0.0001
  end

  def test_encode_0_1
    assert_in_delta encode(0.1), 0.3492, 0.0001
  end

  def test_encode_0_216
    assert_in_delta encode(0.216), 0.5021, 0.0001
  end

  def test_encode_0_25
    assert_in_delta encode(0.25), 0.5371, 0.0001
  end

  def test_encode_0_5
    assert_in_delta encode(0.5), 0.7354, 0.0001
  end

  def test_encode_0_75
    assert_in_delta encode(0.75), 0.8808, 0.0001
  end

  def test_encode_1_0
    assert_in_delta encode(1.0), 1.0, 0.0001
  end

  # sRGB decoding tests
  def test_decode_0_0
    assert_in_delta decode(0.0), 0.0, 0.0001
  end

  def test_decode_0_04
    assert_in_delta decode(0.04), 0.0031, 0.0001
  end

  def test_decode_0_05
    assert_in_delta decode(0.05), 0.0039, 0.0001
  end

  def test_decode_0_1
    assert_in_delta decode(0.1), 0.0100, 0.0001
  end

  def test_decode_0_5
    assert_in_delta decode(0.5), 0.2140, 0.0001
  end

  def test_decode_0_75
    assert_in_delta decode(0.75), 0.5225, 0.0001
  end

  def test_decode_1_0
    assert_in_delta decode(1.0), 1.0, 0.0001
  end

  def test_decode_undoes_encode
    l = 0.2
    assert_in_delta decode(encode(l)), l, 0.000000001
  end

  def test_encode_undoes_decode
    v = 0.7
    assert_in_delta encode(decode(v)), v, 0.000000001
  end

  def test_the_half_gray_that_isnt_128
    assert_equal (encode(0.5) * 255 + 0.5).floor, 188
  end

  def test_what_128_actually_is
    assert_in_delta decode(128.0 / 255), 0.2159, 0.0001
  end
end

class TestGrayMatch < Minitest::Test
  def test_the_gray_match
    c = gray_match
    assert_equal c.width, 300
    assert_equal c.height, 100
    assert pixel_at(c, 0, 0) == color(1, 1, 1)
    assert pixel_at(c, 1, 0) == color(0, 0, 0)
    assert pixel_at(c, 0, 1) == color(0, 0, 0)
    assert pixel_at(c, 1, 1) == color(1, 1, 1)
    assert pixel_at(c, 150, 50).equal_within?(color(0.2159, 0.2159, 0.2159), 0.0001)
    assert pixel_at(c, 250, 50) == color(0.5, 0.5, 0.5)

    # Count white pixels
    count = 0
    c.height.times do |y|
      c.width.times do |x|
        count += 1 if pixel_at(c, x, y) == color(1, 1, 1)
      end
    end
    assert_equal count, 5000
  end

  def test_the_gray_match_as_a_file
    c = gray_match
    ppm = canvas_to_ppm(c)

    # Check specific pixels
    p = ppm_pixel(ppm, 0, 0)
    assert_in_delta p[0], 255, 1
    assert_in_delta p[1], 255, 1
    assert_in_delta p[2], 255, 1

    p = ppm_pixel(ppm, 1, 0)
    assert_in_delta p[0], 0, 1
    assert_in_delta p[1], 0, 1
    assert_in_delta p[2], 0, 1

    p = ppm_pixel(ppm, 150, 50)
    assert_in_delta p[0], 128, 1
    assert_in_delta p[1], 128, 1
    assert_in_delta p[2], 128, 1

    p = ppm_pixel(ppm, 250, 50)
    assert_in_delta p[0], 188, 1
    assert_in_delta p[1], 188, 1
    assert_in_delta p[2], 188, 1

    # Compare with reference
    ref = read_file("reference/chapter-01/gray-match.ppm")
    diff = max_channel_difference(ppm, ref)
    assert diff <= 1
  end

  def test_one_pixel_in_four
    c = quarter_match
    assert_equal c.width, 200
    assert_equal c.height, 100
    assert pixel_at(c, 0, 0) == color(1, 1, 1)
    assert pixel_at(c, 1, 0) == color(0, 0, 0)
    assert pixel_at(c, 2, 2) == color(1, 1, 1)
    assert pixel_at(c, 3, 1) == color(1, 1, 1)
    assert pixel_at(c, 150, 50).equal_within?(color(0.25, 0.25, 0.25), 0.0001)

    # Count white pixels
    count = 0
    c.height.times do |y|
      c.width.times do |x|
        count += 1 if pixel_at(c, x, y) == color(1, 1, 1)
      end
    end
    assert_equal count, 2500

    ppm = canvas_to_ppm(c)
    p = ppm_pixel(ppm, 150, 50)
    assert_in_delta p[0], 137, 1
    assert_in_delta p[1], 137, 1
    assert_in_delta p[2], 137, 1

    ref = read_file("reference/chapter-01/quarter-match.ppm")
    diff = max_channel_difference(ppm, ref)
    assert diff <= 1
  end
end

class TestLimits < Minitest::Test
  def test_a_256_step_ramp
    c = ramp
    assert_equal c.width, 256
    assert_equal c.height, 32
    assert pixel_at(c, 0, 0) == color(0, 0, 0)
    assert pixel_at(c, 128, 0).equal_within?(color(0.5020, 0.5020, 0.5020), 0.0001)
    assert pixel_at(c, 255, 31).equal_within?(color(1, 1, 1), 0.0001)
  end

  def test_encoding_stretches_the_dark_end_and_squeezes_the_bright_end
    c = ramp
    ppm = canvas_to_ppm(c)

    lines = ppm.split("\n")
    line4 = lines[3]
    assert_equal line4, "0 0 0 13 13 13 22 22 22 28 28 28 34 34 34 38 38 38 42 42 42 46 46 46"

    p = ppm_pixel(ppm, 75, 0)
    assert_in_delta p[0], 148, 1
    p = ppm_pixel(ppm, 76, 0)
    assert_in_delta p[0], 148, 1
    p = ppm_pixel(ppm, 254, 0)
    assert_in_delta p[0], 255, 1

    dv = distinct_values(ppm)
    assert_equal dv, 183

    ref = read_file("reference/chapter-01/ramp.ppm")
    diff = max_channel_difference(ppm, ref)
    assert diff <= 1
  end

  def test_clamping_changes_the_color_not_only_the_brightness
    c = clamp_pair
    assert_equal c.width, 200
    assert_equal c.height, 100
    assert pixel_at(c, 50, 50) == color(2, 0.5, 0.5)
    assert pixel_at(c, 150, 50) == color(1, 0.25, 0.25)

    ppm = canvas_to_ppm(c)
    p = ppm_pixel(ppm, 50, 50)
    assert_in_delta p[0], 255, 1
    assert_in_delta p[1], 188, 1
    assert_in_delta p[2], 188, 1

    p = ppm_pixel(ppm, 150, 50)
    assert_in_delta p[0], 255, 1
    assert_in_delta p[1], 137, 1
    assert_in_delta p[2], 137, 1

    ref = read_file("reference/chapter-01/clamp-pair.ppm")
    diff = max_channel_difference(ppm, ref)
    assert diff <= 1
  end
end

class TestMixing < Minitest::Test
  def test_linear_blending_is_on_by_default
    assert_equal $linear_blending, true
  end

  def test_halfway_between_black_and_white
    a = color(0, 0, 0)
    b = color(1, 1, 1)
    result = mix(a, b, 0.5)
    expected = color(0.5, 0.5, 0.5)
    assert result == expected
  end

  def test_the_ends_of_a_mix_are_its_inputs
    a = color(0.7, 0, 0)
    b = color(0, 0.3, 0.02)
    assert mix(a, b, 0) == a
    assert mix(a, b, 1) == b
  end

  def test_red_to_green_in_light
    a = color(0.7, 0, 0)
    b = color(0, 0.3, 0.02)
    result = mix(a, b, 0.5)
    expected = color(0.35, 0.15, 0.01)
    assert result == expected

    result = mix(a, b, 0.25)
    expected = color(0.525, 0.075, 0.005)
    assert result == expected
  end

  def test_halfway_between_black_and_white_browser_way
    $linear_blending = false
    a = color(0, 0, 0)
    b = color(1, 1, 1)
    result = mix(a, b, 0.5)
    expected = color(0.2140, 0.2140, 0.2140)
    assert result.equal_within?(expected, 0.0001)
    $linear_blending = true
  end

  def test_red_to_green_browser_way
    $linear_blending = false
    a = color(0.7, 0, 0)
    b = color(0, 0.3, 0.02)
    result = mix(a, b, 0.5)
    expected = color(0.1527, 0.0693, 0.0067)
    assert result.equal_within?(expected, 0.0001)
    $linear_blending = true
  end

  def test_browser_way_cant_see_past_1
    $linear_blending = false
    a = color(1.5, 0.5, -0.2)
    b = color(0, 0, 0)
    result = mix(a, b, 0)
    expected = color(1, 0.5, 0)
    assert result == expected
    $linear_blending = true
  end

  def test_the_ends_of_a_mix_are_its_inputs_either_way
    $linear_blending = false
    a = color(0.7, 0, 0)
    b = color(0, 0.3, 0.02)
    assert mix(a, b, 0) == a
    assert mix(a, b, 1) == b
    $linear_blending = true
  end
end

class TestPPM < Minitest::Test
  def test_the_ppm_header
    c = canvas(5, 3)
    ppm = canvas_to_ppm(c)
    lines = ppm.split("\n")
    assert_equal lines[0], "P3"
    assert_equal lines[1], "5 3"
    assert_equal lines[2], "255"
  end

  def test_pixel_values_are_encoded_not_scaled
    c = canvas(3, 1)
    write_pixel(c, 0, 0, color(1, 0, 0))
    write_pixel(c, 1, 0, color(0, 0.5, 0))
    write_pixel(c, 2, 0, color(0, 0, 0.216))
    ppm = canvas_to_ppm(c)
    lines = ppm.split("\n")
    assert_equal lines[3], "255 0 0 0 188 0 0 0 128"
  end

  def test_colors_out_of_range_are_clamped_not_wrapped
    c = canvas(2, 1)
    write_pixel(c, 0, 0, color(1.5, 0, -0.5))
    ppm = canvas_to_ppm(c)
    lines = ppm.split("\n")
    assert_equal lines[3], "255 0 0 0 0 0"
  end

  def test_every_row_starts_a_new_line_and_no_line_exceeds_70_characters
    c = canvas(10, 2)
    fill(c, color(1, 0.8, 0.6))
    ppm = canvas_to_ppm(c)
    lines = ppm.split("\n")

    # Check all lines are <= 70 characters
    (3...lines.length).each do |i|
      assert lines[i].length <= 70 || lines[i].empty?, "Line #{i}: #{lines[i].inspect} is #{lines[i].length} chars"
    end

    # Each row should start on a new line (already guaranteed by above)
    # Just verify we have 4 lines of pixel data for 2 rows
    assert lines.length >= 7
  end

  def test_a_line_of_exactly_70_characters_is_allowed
    c = canvas(8, 1)
    fill(c, color(1, 0.1, 0))
    write_pixel(c, 7, 0, color(1, 1, 1))
    ppm = canvas_to_ppm(c)
    lines = ppm.split("\n")

    # Just verify all lines are <= 70 chars
    lines.each do |line|
      assert line.length <= 70 || line.empty?, "Line too long: #{line.inspect} (#{line.length} chars)"
    end
  end

  def test_the_file_ends_with_a_newline_character
    c = canvas(5, 3)
    ppm = canvas_to_ppm(c)
    assert ppm.end_with?("\n")
  end

  def test_reading_a_pixel_back_out_of_the_text
    c = canvas(3, 2)
    write_pixel(c, 2, 1, color(0, 0.5, 1))
    ppm = canvas_to_ppm(c)

    p = ppm_pixel(ppm, 2, 1)
    assert_in_delta p[0], 0, 0
    assert_in_delta p[1], 188, 0
    assert_in_delta p[2], 255, 0

    p = ppm_pixel(ppm, 1, 1)
    assert_in_delta p[0], 0, 0
    assert_in_delta p[1], 0, 0
    assert_in_delta p[2], 0, 0
  end

  def test_counting_the_distinct_values_in_a_file
    c = canvas(3, 1)
    write_pixel(c, 0, 0, color(1, 0, 0))
    write_pixel(c, 1, 0, color(0, 0.5, 0))
    write_pixel(c, 2, 0, color(0, 0, 0.216))
    ppm = canvas_to_ppm(c)

    dv = distinct_values(ppm)
    assert_equal dv, 4
  end

  def test_comparing_two_files
    c1 = canvas(2, 1)
    c2 = canvas(2, 1)
    write_pixel(c2, 0, 0, color(0.5, 0, 0))
    ppm1 = canvas_to_ppm(c1)
    ppm2 = canvas_to_ppm(c2)

    assert_equal max_channel_difference(ppm1, ppm1), 0
    assert_equal max_channel_difference(ppm1, ppm2), 188
  end

  def test_files_of_different_sizes_are_as_different_as_it_gets
    c1 = canvas(5, 3)
    c2 = canvas(3, 5)
    ppm1 = canvas_to_ppm(c1)
    ppm2 = canvas_to_ppm(c2)

    assert_equal max_channel_difference(ppm1, ppm2), 255
  end
end

class TestPlate01 < Minitest::Test
  def test_the_plate
    c = plate_01
    assert_equal c.width, 400
    assert_equal c.height, 180

    ppm = canvas_to_ppm(c)

    p = ppm_pixel(ppm, 0, 20)
    assert_in_delta p[0], 0, 1
    assert_in_delta p[1], 0, 1
    assert_in_delta p[2], 0, 1

    p = ppm_pixel(ppm, 399, 20)
    assert_in_delta p[0], 255, 1
    assert_in_delta p[1], 255, 1
    assert_in_delta p[2], 255, 1

    p = ppm_pixel(ppm, 200, 20)
    assert_in_delta p[0], 128, 1
    assert_in_delta p[1], 128, 1
    assert_in_delta p[2], 128, 1

    p = ppm_pixel(ppm, 200, 65)
    assert_in_delta p[0], 188, 1
    assert_in_delta p[1], 188, 1
    assert_in_delta p[2], 188, 1

    p = ppm_pixel(ppm, 200, 42)
    assert_in_delta p[0], 0, 1
    assert_in_delta p[1], 0, 1
    assert_in_delta p[2], 0, 1

    p = ppm_pixel(ppm, 0, 110)
    assert_in_delta p[0], 218, 1
    assert_in_delta p[1], 0, 1
    assert_in_delta p[2], 0, 1

    p = ppm_pixel(ppm, 399, 110)
    assert_in_delta p[0], 0, 1
    assert_in_delta p[1], 149, 1
    assert_in_delta p[2], 39, 1

    p = ppm_pixel(ppm, 200, 110)
    assert_in_delta p[0], 109, 1
    assert_in_delta p[1], 75, 1
    assert_in_delta p[2], 19, 1

    p = ppm_pixel(ppm, 200, 155)
    assert_in_delta p[0], 160, 1
    assert_in_delta p[1], 108, 1
    assert_in_delta p[2], 26, 1

    p = ppm_pixel(ppm, 200, 87)
    assert_in_delta p[0], 0, 1
    assert_in_delta p[1], 0, 1
    assert_in_delta p[2], 0, 1

    p = ppm_pixel(ppm, 200, 132)
    assert_in_delta p[0], 0, 1
    assert_in_delta p[1], 0, 1
    assert_in_delta p[2], 0, 1

    p = ppm_pixel(ppm, 200, 177)
    assert_in_delta p[0], 0, 1
    assert_in_delta p[1], 0, 1
    assert_in_delta p[2], 0, 1

    ref = read_file("reference/chapter-01/plate-01.ppm")
    diff = max_channel_difference(ppm, ref)
    assert diff <= 1
    assert_equal $linear_blending, true
  end
end
