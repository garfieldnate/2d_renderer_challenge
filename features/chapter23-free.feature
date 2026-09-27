Feature: Chapters 13, 14 and 22 for free
  Every one of these is one line, applied at every pixel of a field.
  field_offset(f, r) is d - r: the shape grown by r, or shrunk when r is
  negative. field_stroke(f, width) is |d| - width / 2: a band width wide
  centered on the edge, with round joins and round caps. field_union(a,
  b) is min(a, b), field_intersection(a, b) is max(a, b),
  field_difference(a, b) is max(a, -b), and field_xor(a, b) is
  max(min(a, b), -max(a, b)). cubic_field(c, width, height) is the field
  of distance_to_cubic, with no sign, since one curve has no inside.
  s_curve() is cubic(point(30, 150), point(40, 20), point(160, 180),
  point(170, 50)). plate_glyph_field() is the field of chapter 22's
  plate_glyph() on a 200 by 200 canvas: the least distance_to_quadratic
  to the glyph's quadratics, each through text_matrix(font, 200, 40,
  140) by chapter 8's transform_curve, made negative where glyph_path
  through the same matrix, flattened to 0.01, winds nonzero around the
  point.

  Scenario: One line each
    Given a ← field_of(3, 1, [-2, 1, 3])
    And   b ← field_of(3, 1, [1, -4, 2])
    Then  field_union(a, b).values = [-2, -4, 2]
    And   field_intersection(a, b).values = [1, 1, 3]
    And   field_difference(a, b).values = [-1, 4, 3]
    And   field_xor(a, b).values = [-1, -1, 2]
    And   field_offset(a, 2).values = [-4, -1, 1]
    And   field_stroke(a, 2).values = [1, 0, 2]

  Scenario: A stroke by field and chapter 13's round stroke
    Given sp ← transform_path(star(), translation(19.5, 19.5))
    When  by_path ← fill_path(stroke_to_path(sp, 10, "round", "round", 4), "nonzero", 200, 200)
    And   by_field ← field_coverage(field_stroke(polygon_field(sp, "nonzero", 200, 200), 10))
    Then  max_coverage_difference(by_path, by_field) ≤ 0.42
    And   ink(by_path) = 5906.224083
    And   ink(by_field) = 5901.860165

  Scenario: A curve's stroke by field and chapter 14's
    When  by_path ← fill_path(stroke_curve_to_path(s_curve(), 20, "round", 0.05), "nonzero", 200, 200)
    And   by_field ← field_coverage(field_stroke(cubic_field(s_curve(), 200, 200), 20))
    Then  max_coverage_difference(by_path, by_field) ≤ 0.08
    And   ink(by_field) - ink(by_path) = 4.120488 ± 0.001

  Scenario: Chapter 22's plate by field
    When  by_path ← fill_path(combine(plate_glyph(), "nonzero", plate_star(), "evenodd", "xor"), "nonzero", 200, 200)
    And   by_field ← field_coverage(field_xor(plate_glyph_field(), polygon_field(plate_star(), "evenodd", 200, 200)))
    Then  max_coverage_difference(by_path, by_field) ≤ 0.42
    And   ink(by_field) - ink(by_path) = 2.279815 ± 0.001
