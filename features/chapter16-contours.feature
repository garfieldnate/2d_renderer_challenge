Feature: Contours, implied points and quadratics
  A TrueType contour is a closed loop of points, each on-curve or off-curve.
  Two off-curve points in a row imply an on-curve point at their midpoint
  (the loop wraps, so the last and first are in a row too), and a contour
  may start on an off-curve point. implied_points(contour) makes every
  implied point explicit and rotates the loop to start on-curve.
  contour_curves(contour) is the loop as quadratics, chapter 8's, from each
  on-curve point through the off-curve point after it to the next on-curve
  point; two on-curve points in a row are a straight edge, written as a
  quadratic with its control point at the midpoint so every piece has the
  same shape.

  Scenario: A loop of off-curve points implies a midpoint between each pair
    Given c ← [[0, 0, false], [10, 0, false], [10, 10, false], [0, 10, false]]
    When  pts ← implied_points(c)
    Then  length(pts) = 8
    And   pts[0] = (5, 0, true)
    And   pts[1] = (10, 0, false)
    And   pts[2] = (10, 5, true)
    And   pts[7] = (0, 0, false)
    And   length(contour_curves(c)) = 4
    And   contour_curves(c)[0].points[0] = point(5, 0)
    And   contour_curves(c)[0].points[1] = point(10, 0)
    And   contour_curves(c)[0].points[2] = point(10, 5)

  Scenario: A loop that starts off-curve is rotated to start on-curve
    Given c ← [[10, 0, false], [10, 10, true], [0, 10, true], [0, 0, true]]
    When  pts ← implied_points(c)
    Then  length(pts) = 4
    And   pts[0] = (10, 10, true)
    And   pts[3] = (10, 0, false)

  Scenario: Straight edges become quadratics through their midpoints
    Given c ← [[0, 0, true], [10, 0, true], [5, 8, true]]
    When  curves ← contour_curves(c)
    Then  length(curves) = 3
    And   curves[0].points[1] = point(5, 0)
    And   curves[1].points[1] = point(7.5, 4)
    And   curves[2].points[0] = point(5, 8)
    And   curves[2].points[2] = point(0, 0)

  Scenario: Mixed points: on, off, off, on
    Given c ← [[0, 0, true], [10, 0, false], [10, 10, false], [0, 10, true]]
    When  curves ← contour_curves(c)
    Then  length(implied_points(c)) = 5
    And   implied_points(c)[2] = (10, 5, true)
    And   length(curves) = 3
    And   curves[0].points[2] = point(10, 5)
    And   curves[1].points[0] = point(10, 5)
    And   curves[2].points[1] = point(0, 5)

  Scenario: The dot of the i is mostly implied
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  dot ← font.glyphs["i"].contours[1]
    Then  length(dot) = 9
    And   length(implied_points(dot)) = 16
    And   implied_points(dot)[2] = (168.5, 1445, true)
    And   length(contour_curves(dot)) = 8
    And   contour_curves(dot)[1].points[0] = point(168.5, 1445)
    And   contour_curves(dot)[1].points[1] = point(196, 1476)
    And   contour_curves(dot)[1].points[2] = point(250, 1476)
    And   length(contour_curves(font.glyphs["i"].contours[0])) = 4
    And   length(contour_curves(font.glyphs["o"].contours[0])) = 12
