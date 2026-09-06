#!/usr/bin/env ruby

require 'minitest/autorun'
require_relative 'renderer'

# Chapter 4: Points, Vectors, Transforms

class TestPointsAndVectors < Minitest::Test
  def test_a_point_has_w_1
    p = point(4, -4)
    assert_in_delta p.x, 4, 0.0001
    assert_in_delta p.y, -4, 0.0001
    assert_in_delta p.w, 1, 0.0001
  end

  def test_a_vector_has_w_0
    v = vector(4, -4)
    assert_in_delta v.x, 4, 0.0001
    assert_in_delta v.y, -4, 0.0001
    assert_in_delta v.w, 0, 0.0001
  end

  def test_the_difference_of_two_points_is_the_vector_between_them
    a = point(3, 2)
    b = point(5, 6)
    assert b - a == vector(2, 4)
    assert a - b == vector(-2, -4)
  end

  def test_a_point_plus_a_vector_is_a_point
    p = point(3, -2)
    v = vector(-2, 3)
    assert p + v == point(1, 1)
    assert p - v == point(5, -5)
  end

  def test_a_vector_plus_a_vector_is_a_vector
    a = vector(3, -2)
    b = vector(-2, 3)
    assert a + b == vector(1, 1)
    assert a - b == vector(5, -5)
  end

  def test_negating_scaling_and_dividing_a_vector
    v = vector(1, -2)
    assert(-v == vector(-1, 2))
    assert v * 3.5 == vector(3.5, -7)
    assert v * 0.5 == vector(0.5, -1)
    assert v / 2 == vector(0.5, -1)
  end

  def test_the_magnitude_of_a_vector
    assert_in_delta magnitude(vector(1, 0)), 1, 0.0001
    assert_in_delta magnitude(vector(0, 1)), 1, 0.0001
    assert_in_delta magnitude(vector(3, 4)), 5, 0.0001
    assert_in_delta magnitude(vector(-3, -4)), 5, 0.0001
    assert_in_delta magnitude(vector(-1, -2)), 2.2361, 0.0001
  end

  def test_normalizing_a_vector
    assert normalize(vector(4, 0)) == vector(1, 0)
    assert normalize(vector(1, 2)) == vector(0.4472, 0.8944)
    assert_in_delta magnitude(normalize(vector(1, 2))), 1, 0.0001
  end

  def test_the_dot_product_of_two_vectors
    a = vector(1, 2)
    b = vector(2, 3)
    assert_in_delta dot(a, b), 8, 0.0001
    assert_in_delta dot(a, vector(-2, 1)), 0, 0.0001
  end

  def test_the_cross_product_of_two_vectors_is_a_number
    a = vector(1, 0)
    b = vector(0, 1)
    assert_in_delta cross(a, b), 1, 0.0001
    assert_in_delta cross(b, a), -1, 0.0001
    assert_in_delta cross(a, a), 0, 0.0001
    assert_in_delta cross(vector(2, 3), vector(4, 5)), -2, 0.0001
  end

  def test_the_sign_of_the_cross_product_says_which_side_of_a_line_a_point_is_on
    a = point(0, 0)
    b = point(10, 0)
    assert_in_delta cross(b - a, point(5, 3) - a), 30, 0.0001
    assert_in_delta cross(b - a, point(5, -3) - a), -30, 0.0001
    assert_in_delta cross(b - a, point(20, 0) - a), 0, 0.0001
  end
end

class TestMatrices < Minitest::Test
  def test_constructing_and_inspecting_a_matrix
    m = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
    assert_in_delta m[0, 0], 1, 0.0001
    assert_in_delta m[0, 2], 3, 0.0001
    assert_in_delta m[1, 0], 4, 0.0001
    assert_in_delta m[1, 1], 5, 0.0001
    assert_in_delta m[2, 0], 7, 0.0001
    assert_in_delta m[2, 2], 9, 0.0001
    assert m == matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
  end

  def test_matrix_equality_with_identical_matrices
    a = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
    b = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
    assert a == b
  end

  def test_matrix_equality_with_different_matrices
    a = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
    b = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 8)
    assert a != b
  end

  def test_multiplying_two_matrices
    a = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
    b = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2)
    assert a * b == matrix3(4, 8, 8, 13, 17, 17, 22, 26, 26)
  end

  def test_matrix_multiplication_is_not_commutative
    a = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
    b = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2)
    assert a * b != b * a
  end

  def test_a_matrix_multiplied_by_a_point
    a = matrix3(1, 2, 3, 4, 5, 6, 0, 0, 1)
    p = point(1, 2)
    assert a * p == point(8, 20)
  end

  def test_a_matrix_multiplied_by_a_vector_ignores_the_last_column
    a = matrix3(1, 2, 3, 4, 5, 6, 0, 0, 1)
    v = vector(1, 2)
    assert a * v == vector(5, 14)
  end

  def test_multiplying_by_the_identity_matrix_changes_nothing
    a = matrix3(0, 1, 2, 1, 2, 4, 2, 4, 8)
    p = point(1, 2)
    assert a * identity == a
    assert identity * a == a
    assert identity * p == p
  end

  def test_transposing_a_matrix
    a = matrix3(0, 9, 3, 9, 8, 0, 1, 8, 5)
    assert transpose(a) == matrix3(0, 9, 1, 9, 8, 8, 3, 0, 5)
  end

  def test_transposing_the_identity_matrix
    assert transpose(identity) == identity
  end

  def test_the_determinant_of_a_3_by_3_matrix
    a = matrix3(1, 2, 6, -5, 8, -4, 2, 6, 4)
    assert_in_delta determinant(a), -196, 0.0001
  end

  def test_the_determinant_of_a_transform_is_the_area_factor
    assert_in_delta determinant(identity), 1, 0.0001
    assert_in_delta determinant(scaling(2, 3)), 6, 0.0001
    assert_in_delta determinant(rotation(0.7)), 1, 0.0001
    assert_in_delta determinant(translation(4, 9)), 1, 0.0001
    assert_in_delta determinant(scaling(-1, 1)), -1, 0.0001
  end

  def test_testing_an_invertible_matrix_for_invertibility
    a = matrix3(3, 0, 2, 2, 0, -2, 0, 1, 1)
    assert_in_delta determinant(a), 10, 0.0001
    assert_equal true, is_invertible(a)
  end

  def test_testing_a_non_invertible_matrix_for_invertibility
    a = matrix3(1, 2, 3, 2, 4, 6, 0, 0, 1)
    assert_in_delta determinant(a), 0, 0.0001
    assert_equal false, is_invertible(a)
  end

  def test_calculating_the_inverse_of_a_matrix
    a = matrix3(3, 0, 2, 2, 0, -2, 0, 1, 1)
    b = inverse(a)
    assert_in_delta b[0, 0], 0.2, 0.0001
    assert_in_delta b[1, 2], 1, 0.0001
    assert_in_delta b[2, 1], -0.3, 0.0001
    assert b == matrix3(0.2, 0.2, 0, -0.2, 0.3, 1, 0.2, -0.3, 0)
    assert a * b == identity
  end

  def test_multiplying_a_product_by_its_inverse
    a = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
    b = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2)
    c = a * b
    assert c * inverse(b) == a
  end

  def test_the_inverse_of_a_transform_is_a_transform
    a = translation(5, -3) * rotation(Math::PI / 6) * scaling(2, 3)
    b = inverse(a)
    assert_in_delta b[2, 0], 0, 0.0001
    assert_in_delta b[2, 1], 0, 0.0001
    assert_in_delta b[2, 2], 1, 0.0001
    assert_in_delta b[0, 0], 0.4330, 0.0001
    assert_in_delta b[0, 2], -1.4151, 0.0001
    assert_in_delta b[1, 2], 1.6994, 0.0001
    assert b * a == identity
  end
end

class TestTransforms < Minitest::Test
  def test_multiplying_by_a_translation_matrix
    t = translation(5, -3)
    p = point(-3, 4)
    assert t * p == point(2, 1)
  end

  def test_the_inverse_of_a_translation_moves_the_other_way
    t = translation(5, -3)
    p = point(-3, 4)
    assert inverse(t) * p == point(-8, 7)
  end

  def test_translation_does_not_affect_vectors
    t = translation(5, -3)
    v = vector(-3, 4)
    assert t * v == v
  end

  def test_a_scaling_matrix_applied_to_a_point
    s = scaling(2, 3)
    p = point(-4, 6)
    assert s * p == point(-8, 18)
  end

  def test_a_scaling_matrix_applied_to_a_vector
    s = scaling(2, 3)
    v = vector(-4, 6)
    assert s * v == vector(-8, 18)
  end

  def test_the_inverse_of_a_scaling_shrinks
    s = scaling(2, 3)
    v = vector(-4, 6)
    assert inverse(s) * v == vector(-2, 2)
  end

  def test_reflection_is_scaling_by_a_negative_value
    s = scaling(-1, 1)
    p = point(2, 3)
    assert s * p == point(-2, 3)
  end

  def test_a_positive_rotation_turns_x_toward_y
    p = point(1, 0)
    assert rotation(Math::PI / 4) * p == point(0.7071, 0.7071)
    assert rotation(Math::PI / 2) * p == point(0, 1)
    assert rotation(Math::PI) * p == point(-1, 0)
  end

  def test_the_inverse_of_a_rotation_turns_the_other_way
    p = point(1, 0)
    assert inverse(rotation(Math::PI / 4)) * p == point(0.7071, -0.7071)
    assert rotation(-Math::PI / 4) * p == point(0.7071, -0.7071)
  end

  def test_a_rotation_preserves_length
    v = vector(3, 4)
    assert_in_delta magnitude(rotation(1.2) * v), 5, 0.0001
    assert_in_delta magnitude(rotation(-2.8) * v), 5, 0.0001
  end

  def test_shearing_moves_x_in_proportion_to_y
    s = shearing(1, 0)
    p = point(2, 3)
    assert s * p == point(5, 3)
  end

  def test_shearing_moves_y_in_proportion_to_x
    s = shearing(0, 1)
    p = point(2, 3)
    assert s * p == point(2, 5)
  end

  def test_individual_transformations_are_applied_in_sequence
    p = point(1, 0)
    a = rotation(Math::PI / 2)
    b = scaling(5, 5)
    c = translation(10, 5)

    p2 = a * p
    p3 = b * p2
    p4 = c * p3

    assert p2 == point(0, 1)
    assert p3 == point(0, 5)
    assert p4 == point(10, 10)
  end

  def test_chained_transformations_must_be_applied_in_reverse_order
    p = point(1, 0)
    a = rotation(Math::PI / 2)
    b = scaling(5, 5)
    c = translation(10, 5)

    t = c * b * a
    assert t * p == point(10, 10)
  end

  def test_the_other_order_is_a_different_transform
    p = point(1, 0)
    a = rotation(Math::PI / 2)
    b = scaling(5, 5)
    c = translation(10, 5)

    t = a * b * c
    assert t * p == point(-25, 55)
  end

  def test_rotating_about_a_point_that_isnt_the_origin
    t = translation(4, 4) * rotation(Math::PI / 2) * translation(-4, -4)
    assert t * point(6, 4) == point(4, 6)
    assert t * point(4, 4) == point(4, 4)
  end
end

class TestApproxScale < Minitest::Test
  def test_the_identity_a_translation_and_a_rotation_dont_stretch
    assert_in_delta approx_scale(identity), 1, 0.0001
    assert_in_delta approx_scale(translation(7, 9)), 1, 0.0001
    assert_in_delta approx_scale(rotation(1.1)), 1, 0.0001
  end

  def test_a_uniform_scale_is_reported_exactly
    assert_in_delta approx_scale(scaling(2, 2)), 2, 0.0001
    assert_in_delta approx_scale(scaling(0.5, 0.5)), 0.5, 0.0001
    assert_in_delta approx_scale(scaling(3, 3) * rotation(0.7)), 3, 0.0001
    assert_in_delta approx_scale(translation(5, 5) * scaling(3, 3)), 3, 0.0001
  end

  def test_a_reflection_is_not_a_negative_scale
    assert_in_delta approx_scale(scaling(-2, 2)), 2, 0.0001
  end

  def test_a_non_uniform_scale_is_reported_as_the_geometric_mean
    assert_in_delta approx_scale(scaling(4, 1)), 2, 0.0001
    assert_in_delta approx_scale(scaling(4, 1) * rotation(0.4)), 2, 0.0001
    assert_in_delta approx_scale(scaling(9, 1)), 3, 0.0001
  end

  def test_a_shear_that_preserves_area_reports_1
    assert_in_delta approx_scale(shearing(1, 0)), 1, 0.0001
    assert_in_delta approx_scale(shearing(0.5, 0.5)), 0.8660, 0.0001
  end

  def test_a_collapsed_transform_reports_0
    assert_in_delta approx_scale(scaling(0, 1)), 0, 0.0001
    assert_in_delta approx_scale(matrix3(1, 2, 0, 2, 4, 0, 0, 0, 1)), 0, 0.0001
  end
end

class TestTransformingWhatYouDraw < Minitest::Test
  def test_a_segment_between_pixel_centers_is_a_thick_line
    s = segment(point(2.5, 2.5), point(11.5, 5.5), 1)
    cov = rasterize(s, 16, 10)
    assert_in_delta coverage_at(cov, 2, 2), 0.484375, 0.0001
    assert_in_delta coverage_at(cov, 6, 3), 0.6875, 0.0001
    assert_in_delta coverage_at(cov, 7, 3), 0.359375, 0.0001
    assert_in_delta ink(cov), 9.4063, 0.0001
  end

  def test_a_segment_need_not_start_on_a_pixel_center
    s = segment(point(1, 3.5), point(7, 3.5), 1)
    cov = rasterize(s, 10, 10)
    assert_in_delta coverage_at(cov, 0, 3), 0, 0.0001
    assert_in_delta coverage_at(cov, 1, 3), 1, 0.0001
    assert_in_delta coverage_at(cov, 6, 3), 1, 0.0001
    assert_in_delta coverage_at(cov, 7, 3), 0, 0.0001
    assert_in_delta coverage_at(cov, 3, 2), 0, 0.0001
    assert_in_delta ink(cov), 6, 0.0001
  end

  def test_a_segment_of_no_length_is_a_square
    s = segment(point(3.5, 3.5), point(3.5, 3.5), 1)
    cov = rasterize(s, 8, 8)
    assert_in_delta coverage_at(cov, 3, 3), 1, 0.0001
    assert_in_delta ink(cov), 1, 0.0001
  end

  def test_a_union_of_nothing_is_inside_nowhere
    s = union([])
    assert_equal false, inside(s, 0, 0)
    assert_in_delta ink(rasterize(s, 4, 4)), 0, 0.0001
  end

  def test_a_union_is_inside_when_any_of_its_parts_is
    s = union([circle(2, 2, 1), rectangle(5, 0, 7, 4)])
    assert_equal true, inside(s, 2, 2)
    assert_equal true, inside(s, 6, 1)
    assert_equal false, inside(s, 4, 2)
    assert_in_delta ink(rasterize(s, 8, 8)), 11.25, 0.0001
  end

  def test_a_circle_seen_through_a_scale_is_an_ellipse
    s = transformed(circle(0, 0, 4), scaling(2, 1))
    assert_equal true, inside(s, 7.9, 0)
    assert_equal false, inside(s, 8.1, 0)
    assert_equal true, inside(s, 0, 3.9)
    assert_equal false, inside(s, 0, 4.1)
    assert_equal true, inside(s, 5.6, 1.4)
    assert_equal false, inside(s, 5.6, 2.9)
  end

  def test_the_transform_is_applied_in_the_order_the_matrix_says
    s = transformed(circle(0, 0, 4), translation(10, 10) * scaling(2, 1))
    assert_equal true, inside(s, 10, 10)
    assert_equal true, inside(s, 17.9, 10)
    assert_equal false, inside(s, 18.1, 10)
    assert_equal true, inside(s, 10, 13.9)
    assert_equal false, inside(s, 10, 14.1)
  end

  def test_a_shape_seen_through_a_collapsed_transform_is_empty
    s = transformed(circle(0, 0, 4), scaling(0, 1))
    assert_equal false, inside(s, 0, 0)
    assert_in_delta ink(rasterize(s, 10, 10)), 0, 0.0001
  end

  def test_a_pen_in_shape_space_scales_with_the_shape
    s = transformed(thick_line(5, 0, 5, 9, 1), scaling(3, 1))
    cov = rasterize(s, 24, 10)
    assert_in_delta coverage_at(cov, 14, 4), 0, 0.0001
    assert_in_delta coverage_at(cov, 15, 4), 1, 0.0001
    assert_in_delta coverage_at(cov, 16, 4), 1, 0.0001
    assert_in_delta coverage_at(cov, 17, 4), 1, 0.0001
    assert_in_delta coverage_at(cov, 18, 4), 0, 0.0001
    assert_in_delta ink(cov), 27, 0.0001
  end

  def test_a_pen_in_device_space_does_not
    m = scaling(3, 1)
    s = segment(m * point(5.5, 0.5), m * point(5.5, 9.5), 1)
    cov = rasterize(s, 24, 10)
    assert_in_delta coverage_at(cov, 15, 4), 0, 0.0001
    assert_in_delta coverage_at(cov, 16, 4), 1, 0.0001
    assert_in_delta coverage_at(cov, 17, 4), 0, 0.0001
    assert_in_delta ink(cov), 9, 0.0001
  end

  def test_dividing_the_width_by_approx_scale_makes_the_two_pens_agree
    m = scaling(2, 2)
    s = transformed(segment(point(5.5, 0.5), point(5.5, 9.5), 1.0 / approx_scale(m)), m)
    cov = rasterize(s, 24, 20)
    assert_in_delta coverage_at(cov, 9, 5), 0, 0.0001
    assert_in_delta coverage_at(cov, 10, 5), 0.5, 0.0001
    assert_in_delta coverage_at(cov, 11, 5), 0.5, 0.0001
    assert_in_delta coverage_at(cov, 12, 5), 0, 0.0001
    assert_in_delta ink(cov), 18, 0.0001
  end

  def test_under_a_non_uniform_scale_the_compromise_shows
    m = scaling(4, 1)
    w = 1.0 / approx_scale(m)
    v = transformed(segment(point(2.5, 0.5), point(2.5, 9.5), w), m)
    h = transformed(segment(point(0.5, 5.5), point(4.5, 5.5), w), m)
    cv = rasterize(v, 24, 12)
    ch = rasterize(h, 24, 12)

    assert_in_delta coverage_at(cv, 8, 5), 0, 0.0001
    assert_in_delta coverage_at(cv, 9, 5), 1, 0.0001
    assert_in_delta coverage_at(cv, 10, 5), 1, 0.0001
    assert_in_delta coverage_at(cv, 11, 5), 0, 0.0001
    assert_in_delta ink(cv), 18, 0.0001

    assert_in_delta coverage_at(ch, 10, 4), 0, 0.0001
    assert_in_delta coverage_at(ch, 10, 5), 0.5, 0.0001
    assert_in_delta coverage_at(ch, 10, 6), 0, 0.0001
    assert_in_delta ink(ch), 8, 0.0001
  end

  def test_an_outline_is_one_shape_so_its_corners_are_painted_once
    pts = [point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)]
    c = canvas(8, 8)
    paint_through(c, rasterize(outline(pts, identity, 1), 8, 8), color(1, 1, 1))

    assert_equal 20, lit_pixels(c).length
    assert pixel_at(c, 3, 1) == color(1, 1, 1)
    assert pixel_at(c, 1, 3) == color(1, 1, 1)
    assert pixel_at(c, 1, 1) == color(0.75, 0.75, 0.75)
    assert pixel_at(c, 3, 3) == color(0, 0, 0)
    assert pixel_at(c, 0, 1) == color(0, 0, 0)
    assert_in_delta total_ink(c), 19, 0.0001
  end

  def test_an_outline_takes_its_points_through_the_matrix_first
    pts = [point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)]
    c = canvas(16, 16)
    paint_through(c, rasterize(outline(pts, scaling(2, 2), 1), 16, 16), color(1, 1, 1))

    assert_equal 76, lit_pixels(c).length
    assert pixel_at(c, 3, 3) == color(0.75, 0.75, 0.75)
    assert pixel_at(c, 8, 2) == color(0.5, 0.5, 0.5)
    assert pixel_at(c, 8, 3) == color(0.5, 0.5, 0.5)
    assert pixel_at(c, 8, 4) == color(0, 0, 0)
  end
end

class TestPlate4 < Minitest::Test
  def test_the_fan_as_points
    pts = fan_points
    assert_equal 13, pts.length
    assert pts[0] == point(0, 0)
    assert pts[1] == point(36, 0)
    assert pts[4] == point(0, 36)
    assert pts[7] == point(-36, 0)
    assert pts[2] == point(31.1769, 18)
  end

  def test_rotate_then_translate_the_fan_turns_about_its_own_center
    m = translation(104.5, 76.5) * rotation(Math::PI / 6)
    pts = transform_points(fan_points, m)
    assert pts[0] == point(104.5, 76.5)
    assert pts[1] == point(135.6769, 94.5)
    assert pts[4] == point(86.5, 107.6769)
  end

  def test_translate_then_rotate_the_fan_swings_about_the_canvas_corner
    m = rotation(Math::PI / 6) * translation(104.5, 76.5)
    pts = transform_points(fan_points, m)
    assert pts[0] == point(52.2497, 118.5009)
    assert pts[1] == point(83.4266, 136.5009)
  end

  def test_the_letter_f
    f = letter_f
    assert_equal 10, f.length
    assert f[0] == point(-20, -30)
    assert f[1] == point(20, -30)
    assert f[5] == point(12, -5)
    assert f[9] == point(-20, 30)
  end

  def test_the_f_at_home
    f = transform_points(letter_f, translation(44.5, 44.5))
    assert f[0] == point(24.5, 14.5)
    assert f[1] == point(64.5, 14.5)
    assert f[9] == point(24.5, 74.5)
  end

  def test_the_f_rotated_then_translated
    m = translation(104.5, 76.5) * rotation(Math::PI / 6)
    f = transform_points(letter_f, m)
    assert f[0] == point(102.1795, 40.5192)
    assert f[1] == point(136.8205, 60.5192)
    assert f[5] == point(117.3923, 78.1699)
    assert f[9] == point(72.1795, 92.4808)
  end

  def test_the_f_translated_then_rotated
    m = rotation(Math::PI / 6) * translation(104.5, 76.5)
    f = transform_points(letter_f, m)
    assert f[0] == point(49.9291, 82.5202)
    assert f[1] == point(84.5702, 102.5202)
    assert f[5] == point(65.142, 120.1708)
    assert f[9] == point(19.9291, 134.4817)
  end

  def test_side_by_side_puts_the_first_canvas_on_the_left
    a = canvas(2, 3)
    b = canvas(4, 3)
    fill(a, color(1, 0, 0))
    fill(b, color(0, 0, 1))
    c = side_by_side(a, b)
    assert_equal 6, c.width
    assert_equal 3, c.height
    assert pixel_at(c, 0, 0) == color(1, 0, 0)
    assert pixel_at(c, 1, 2) == color(1, 0, 0)
    assert pixel_at(c, 2, 0) == color(0, 0, 1)
    assert pixel_at(c, 5, 2) == color(0, 0, 1)
  end

  def test_the_fan_both_orders_dimensions
    c = fan_both_orders
    assert_equal 320, c.width
    assert_equal 160, c.height
  end

  def test_the_fan_both_orders
    c = fan_both_orders
    ref = read_file("reference/chapter-04/fan-both-orders.ppm")
    p6 = canvas_to_p6(c)

    assert_equal 320, c.width
    assert_equal 160, c.height

    px = ppm_pixel(p6, 104, 76)
    assert_in_delta px[0], 246, 1
    assert_in_delta px[1], 246, 1
    assert_in_delta px[2], 241, 1

    px = ppm_pixel(p6, 124, 76)
    assert_in_delta px[0], 246, 1
    assert_in_delta px[1], 246, 1
    assert_in_delta px[2], 241, 1

    px = ppm_pixel(p6, 104, 56)
    assert_in_delta px[0], 246, 1
    assert_in_delta px[1], 246, 1
    assert_in_delta px[2], 241, 1

    px = ppm_pixel(p6, 125, 88)
    assert_in_delta px[0], 236, 1
    assert_in_delta px[1], 236, 1
    assert_in_delta px[2], 231, 1

    px = ppm_pixel(p6, 116, 97)
    assert_in_delta px[0], 236, 1
    assert_in_delta px[1], 236, 1
    assert_in_delta px[2], 231, 1

    px = ppm_pixel(p6, 141, 76)
    assert_in_delta px[0], 39, 1
    assert_in_delta px[1], 39, 1
    assert_in_delta px[2], 44, 1

    px = ppm_pixel(p6, 10, 10)
    assert_in_delta px[0], 39, 1
    assert_in_delta px[1], 39, 1
    assert_in_delta px[2], 44, 1

    px = ppm_pixel(p6, 212, 118)
    assert_in_delta px[0], 246, 1
    assert_in_delta px[1], 246, 1
    assert_in_delta px[2], 241, 1

    px = ppm_pixel(p6, 232, 118)
    assert_in_delta px[0], 246, 1
    assert_in_delta px[1], 246, 1
    assert_in_delta px[2], 241, 1

    px = ppm_pixel(p6, 233, 130)
    assert_in_delta px[0], 223, 1
    assert_in_delta px[1], 223, 1
    assert_in_delta px[2], 219, 1

    px = ppm_pixel(p6, 224, 139)
    assert_in_delta px[0], 236, 1
    assert_in_delta px[1], 236, 1
    assert_in_delta px[2], 231, 1

    px = ppm_pixel(p6, 200, 139)
    assert_in_delta px[0], 211, 1
    assert_in_delta px[1], 211, 1
    assert_in_delta px[2], 207, 1

    px = ppm_pixel(p6, 310, 10)
    assert_in_delta px[0], 39, 1
    assert_in_delta px[1], 39, 1
    assert_in_delta px[2], 44, 1

    assert max_channel_difference(p6, ref) <= 1
  end

  def test_plate_04_dimensions
    c = plate_04
    assert_equal 640, c.width
    assert_equal 320, c.height
  end

  def test_plate_04
    c = plate_04
    ref = read_file("reference/chapter-04/plate-04.ppm")
    p6 = canvas_to_p6(c)

    assert_equal 640, c.width
    assert_equal 320, c.height

    px = ppm_pixel(p6, 48, 28)
    assert_in_delta px[0], 99, 1
    assert_in_delta px[1], 99, 1
    assert_in_delta px[2], 102, 1

    px = ppm_pixel(p6, 80, 28)
    assert_in_delta px[0], 111, 1
    assert_in_delta px[1], 111, 1
    assert_in_delta px[2], 115, 1

    px = ppm_pixel(p6, 48, 100)
    assert_in_delta px[0], 111, 1
    assert_in_delta px[1], 111, 1
    assert_in_delta px[2], 115, 1

    px = ppm_pixel(p6, 10, 10)
    assert_in_delta px[0], 39, 1
    assert_in_delta px[1], 39, 1
    assert_in_delta px[2], 44, 1

    px = ppm_pixel(p6, 200, 150)
    assert_in_delta px[0], 39, 1
    assert_in_delta px[1], 39, 1
    assert_in_delta px[2], 44, 1

    px = ppm_pixel(p6, 268, 129)
    assert_in_delta px[0], 237, 1
    assert_in_delta px[1], 237, 1
    assert_in_delta px[2], 233, 1

    px = ppm_pixel(p6, 215, 145)
    assert_in_delta px[0], 237, 1
    assert_in_delta px[1], 237, 1
    assert_in_delta px[2], 233, 1

    px = ppm_pixel(p6, 239, 101)
    assert_in_delta px[0], 237, 1
    assert_in_delta px[1], 237, 1
    assert_in_delta px[2], 233, 1

    px = ppm_pixel(p6, 174, 173)
    assert_in_delta px[0], 217, 1
    assert_in_delta px[1], 217, 1
    assert_in_delta px[2], 213, 1

    px = ppm_pixel(p6, 368, 28)
    assert_in_delta px[0], 99, 1
    assert_in_delta px[1], 99, 1
    assert_in_delta px[2], 102, 1

    px = ppm_pixel(p6, 500, 60)
    assert_in_delta px[0], 39, 1
    assert_in_delta px[1], 39, 1
    assert_in_delta px[2], 44, 1

    px = ppm_pixel(p6, 453, 207)
    assert_in_delta px[0], 236, 1
    assert_in_delta px[1], 236, 1
    assert_in_delta px[2], 231, 1

    px = ppm_pixel(p6, 431, 229)
    assert_in_delta px[0], 234, 1
    assert_in_delta px[1], 234, 1
    assert_in_delta px[2], 229, 1

    px = ppm_pixel(p6, 445, 249)
    assert_in_delta px[0], 234, 1
    assert_in_delta px[1], 234, 1
    assert_in_delta px[2], 229, 1

    px = ppm_pixel(p6, 368, 273)
    assert_in_delta px[0], 177, 1
    assert_in_delta px[1], 177, 1
    assert_in_delta px[2], 174, 1

    assert max_channel_difference(p6, ref) <= 1
  end
end
