Feature: Transforming what you draw
  segment(a, b, width) is chapter 3's thick_line with real endpoints: the
  rectangle of that width centered on the segment from point a to point b,
  square ends. union(shapes) is inside when any of its shapes is.
  transformed(shape, m) is the shape seen through m: a point is inside it
  when the inverse of m takes that point inside the original shape.
  outline(points, m, width) is the closed polygon through the points after
  m, every edge a segment of that width in device space, as one shape.

  Scenario: A segment between pixel centers is a thick line
    Given s ← segment(point(2.5, 2.5), point(11.5, 5.5), 1)
    When  cov ← rasterize(s, 16, 10)
    Then  coverage_at(cov, 2, 2) = 0.484375
    And   coverage_at(cov, 11, 5) = 0.484375
    And   coverage_at(cov, 6, 3) = 0.6875
    And   coverage_at(cov, 7, 3) = 0.359375
    And   coverage_at(cov, 2, 1) = 0
    And   ink(cov) = 9.4063

  Scenario: A segment need not start on a pixel center
    Given s ← segment(point(1, 3.5), point(7, 3.5), 1)
    When  cov ← rasterize(s, 10, 10)
    Then  coverage_at(cov, 0, 3) = 0
    And   coverage_at(cov, 1, 3) = 1
    And   coverage_at(cov, 6, 3) = 1
    And   coverage_at(cov, 7, 3) = 0
    And   coverage_at(cov, 3, 2) = 0
    And   ink(cov) = 6

  Scenario: A segment of no length is a square
    Given s ← segment(point(3.5, 3.5), point(3.5, 3.5), 1)
    When  cov ← rasterize(s, 8, 8)
    Then  coverage_at(cov, 3, 3) = 1
    And   ink(cov) = 1

  Scenario: A union of nothing is inside nowhere
    Given s ← union([])
    Then  inside(s, 0, 0) = false
    And   ink(rasterize(s, 4, 4)) = 0

  Scenario: A union is inside when any of its parts is
    Given s ← union([circle(2, 2, 1), rectangle(5, 0, 7, 4)])
    Then  inside(s, 2, 2) = true
    And   inside(s, 6, 1) = true
    And   inside(s, 4, 2) = false
    And   ink(rasterize(s, 8, 8)) = 11.25

  Scenario: A circle seen through a scale is an ellipse
    Given s ← transformed(circle(0, 0, 4), scaling(2, 1))
    Then  inside(s, 7.9, 0) = true
    And   inside(s, 8.1, 0) = false
    And   inside(s, 0, 3.9) = true
    And   inside(s, 0, 4.1) = false
    And   inside(s, 5.6, 1.4) = true
    And   inside(s, 5.6, 2.9) = false

  Scenario: The transform is applied in the order the matrix says
    Given s ← transformed(circle(0, 0, 4), translation(10, 10) * scaling(2, 1))
    Then  inside(s, 10, 10) = true
    And   inside(s, 17.9, 10) = true
    And   inside(s, 18.1, 10) = false
    And   inside(s, 10, 13.9) = true
    And   inside(s, 10, 14.1) = false

  Scenario: A shape seen through a collapsed transform is empty
    Given s ← transformed(circle(0, 0, 4), scaling(0, 1))
    Then  inside(s, 0, 0) = false
    And   ink(rasterize(s, 10, 10)) = 0

  Scenario: A pen in shape space scales with the shape
    Given s ← transformed(thick_line(5, 0, 5, 9, 1), scaling(3, 1))
    When  cov ← rasterize(s, 24, 10)
    Then  coverage_at(cov, 14, 4) = 0
    And   coverage_at(cov, 15, 4) = 1
    And   coverage_at(cov, 16, 4) = 1
    And   coverage_at(cov, 17, 4) = 1
    And   coverage_at(cov, 18, 4) = 0
    And   ink(cov) = 27

  Scenario: A pen in device space does not
    Given m ← scaling(3, 1)
    And   s ← segment(m * point(5.5, 0.5), m * point(5.5, 9.5), 1)
    When  cov ← rasterize(s, 24, 10)
    Then  coverage_at(cov, 15, 4) = 0
    And   coverage_at(cov, 16, 4) = 1
    And   coverage_at(cov, 17, 4) = 0
    And   ink(cov) = 9

  Scenario: Dividing the width by approx_scale makes the two pens agree
    Given m ← scaling(2, 2)
    And   s ← transformed(segment(point(5.5, 0.5), point(5.5, 9.5), 1 / approx_scale(m)), m)
    When  cov ← rasterize(s, 24, 20)
    Then  coverage_at(cov, 9, 5) = 0
    And   coverage_at(cov, 10, 5) = 0.5
    And   coverage_at(cov, 11, 5) = 0.5
    And   coverage_at(cov, 12, 5) = 0
    And   ink(cov) = 18

  Scenario: Under a non-uniform scale the compromise shows
    Given m ← scaling(4, 1)
    And   w ← 1 / approx_scale(m)
    And   v ← transformed(segment(point(2.5, 0.5), point(2.5, 9.5), w), m)
    And   h ← transformed(segment(point(0.5, 5.5), point(4.5, 5.5), w), m)
    When  cv ← rasterize(v, 24, 12)
    And   ch ← rasterize(h, 24, 12)
    Then  coverage_at(cv, 8, 5) = 0
    And   coverage_at(cv, 9, 5) = 1
    And   coverage_at(cv, 10, 5) = 1
    And   coverage_at(cv, 11, 5) = 0
    And   ink(cv) = 18
    And   coverage_at(ch, 10, 4) = 0
    And   coverage_at(ch, 10, 5) = 0.5
    And   coverage_at(ch, 10, 6) = 0
    And   ink(ch) = 8

  Scenario: An outline is one shape, so its corners are painted once
    Given pts ← [point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)]
    And   c ← canvas(8, 8)
    When  paint_through(c, rasterize(outline(pts, identity(), 1), 8, 8), color(1, 1, 1))
    Then  length(lit_pixels(c)) = 20
    And   pixel_at(c, 3, 1) = color(1, 1, 1)
    And   pixel_at(c, 1, 3) = color(1, 1, 1)
    And   pixel_at(c, 1, 1) = color(0.75, 0.75, 0.75)
    And   pixel_at(c, 3, 3) = color(0, 0, 0)
    And   pixel_at(c, 0, 1) = color(0, 0, 0)
    And   total_ink(c) = 19

  Scenario: An outline takes its points through the matrix first
    Given pts ← [point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)]
    And   c ← canvas(16, 16)
    When  paint_through(c, rasterize(outline(pts, scaling(2, 2), 1), 16, 16), color(1, 1, 1))
    Then  length(lit_pixels(c)) = 76
    And   pixel_at(c, 3, 3) = color(0.75, 0.75, 0.75)
    And   pixel_at(c, 8, 2) = color(0.5, 0.5, 0.5)
    And   pixel_at(c, 8, 3) = color(0.5, 0.5, 0.5)
    And   pixel_at(c, 8, 4) = color(0, 0, 0)
