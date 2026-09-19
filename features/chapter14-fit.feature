Feature: Fitting a cubic to the offset
  fit_offset(c, d) is one cubic that starts and ends at the curve's offset
  points with the curve's own end tangents, its two handle lengths solved so
  that it passes through the offset point at t = 0.5 when its own t is 0.5.
  When the end tangents are parallel that solve has no answer and both
  handles are a third of the chord. offset_error(c, d, fitted) is the
  largest miss over 17 matched parameters t = i / 16. distance_to_curve(c, p)
  is the honest measure of anything: the nearest of 65 samples at t = i / 64,
  refined by 32 rounds of ternary search on the bracket from the sample
  before it to the sample after it, clamped to 0 and 1 at the ends.

  Scenario: The fit of a straight curve is exact
    Given line ← cubic(point(0, 0), point(1, 1), point(2, 2), point(3, 3))
    When  f ← fit_offset(line, 1)
    Then  f.points[0] = point(-0.707107, 0.707107)
    And   f.points[1] = point(0.292893, 1.707107)
    And   f.points[3] = point(2.292893, 3.707107)
    And   offset_error(line, 1, f) = 0

  Scenario: The fit of a quarter circle lands its handles on the offset circle
    Given arc ← cubic(point(100, 0), point(100, 55.2285), point(55.2285, 100), point(0, 100))
    When  f ← fit_offset(arc, 10)
    Then  f.points[0] = point(90, 0)
    And   f.points[1] = point(90, 49.7056) ± 0.001
    And   f.points[2] = point(49.7056, 90) ± 0.001
    And   f.points[3] = point(0, 90)
    And   offset_error(arc, 10, f) = 0.012092 ± 0.0001

  Scenario: A U-turn cannot be fitted in one piece, and the miss says so
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    When  f ← fit_offset(c, 1)
    Then  f.points[0] = point(-1, 0)
    And   f.points[1] = point(-1, 2)
    And   f.points[2] = point(5, 2)
    And   f.points[3] = point(5, 0)
    And   offset_error(c, 1, f) = 2.5

  Scenario: The distance from a point to a curve
    Given line ← cubic(point(0, 0), point(1, 1), point(2, 2), point(3, 3))
    And   q ← quadratic(point(0, 0), point(2, 4), point(4, 0))
    And   arc ← cubic(point(100, 0), point(100, 55.2285), point(55.2285, 100), point(0, 100))
    Then  distance_to_curve(line, point(3, 0)) = 2.121320
    And   distance_to_curve(line, point(5, 5)) = 2.828427
    And   distance_to_curve(q, point(2, 5)) = 3
    And   distance_to_curve(q, point(2, 0)) = 1.732051
    And   distance_to_curve(arc, point(0, 0)) = 100 ± 0.03
