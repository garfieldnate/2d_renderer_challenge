Feature: Curves without flattening
  Give a quadratic's control points p0, p1 and p2 the coordinates (0, 0),
  (1/2, 0) and (1, 1) and interpolate across the triangle: with det =
  cross(p1 - p0, p2 - p0), s = cross(q - p0, p2 - p0) / det and t =
  cross(p1 - p0, q - p0) / det, loop_blinn_uv(c, q) is (u, v, s) with u
  = s / 2 + t and v = t, or none when det = 0. inside_curve(c, q) is
  s > 0 and u² - v < 0, which holds exactly between the curve and its
  chord p0 to p2. curve_sign(c) is 1 when det > 0 and -1 otherwise.
  loop_blinn_stencil(curves, anchor, width, height) takes closed
  contours of quadratics: first the fan of chords, stencil_triangle(s,
  anchor, p0, p2) for every curve in order, then, for every curve with
  det ≠ 0, every pixel of the control triangle's bounding box (taken as in
  stencil_triangle) whose center is inside_curve gets curve_sign added and
  counts as a fragment. glyph_stencil(font, name, m, width, height) is
  loop_blinn_stencil of the glyph's quadratics through m, chapter 23's
  glyph_curves, anchored at the first curve's first point. Nothing is ever
  flattened.

  Scenario: The control points carry (0, 0), (1/2, 0) and (1, 1)
    Given c ← quadratic(point(0, 0), point(10, 0), point(10, 10))
    Then  loop_blinn_uv(c, point(0, 0)) = (0, 0, 0)
    And   loop_blinn_uv(c, point(10, 0)) = (0.5, 0, 1)
    And   loop_blinn_uv(c, point(10, 10)) = (1, 1, 0)
    And   loop_blinn_uv(c, point(7, 3)) = (0.5, 0.3, 0.4)
    And   loop_blinn_uv(quadratic(point(0, 0), point(5, 0), point(10, 0)), point(3, 1)) = none

  Scenario: u² - v < 0 is the sliver between the curve and its chord
    Given c ← quadratic(point(0, 0), point(10, 0), point(10, 10))
    Then  inside_curve(c, point(7, 3)) = true
    And   inside_curve(c, point(9, 1)) = false
    And   inside_curve(c, point(4, 4)) = false
    And   inside_curve(c, point(7.5, 2.4)) = false
    And   inside_curve(c, point(7.5, 2.6)) = true
    And   curve_sign(c) = 1
    And   curve_sign(quadratic(point(10, 10), point(10, 0), point(0, 0))) = -1

  Scenario: A glyph without flattening agrees with one flattened to a thousandth of a pixel
    Given f ← roboto()
    And   m ← text_matrix(f, 200, 40, 140)
    When  lb ← glyph_stencil(f, "g", m, 200, 200)
    Then  winding_mismatches(lb, glyph_path(f, "g", m, 0.001)) = 0
    And   lb.fragments = 22813
    And   winding_mismatches(glyph_stencil(f, "ampersand", m, 200, 200), glyph_path(f, "ampersand", m, 0.001)) = 0
