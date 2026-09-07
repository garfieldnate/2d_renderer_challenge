Feature: Tight bounds
  curve_bounds(c) is the smallest axis-aligned box that holds the curve
  itself, as (min x, min y, max x, max y). It is not the box around the
  control points, which is usually too big: a Bezier stays inside its control
  points, so the curve turns back before it reaches them. The tight box is
  found by evaluating the curve at its ends and at every parameter where it
  turns around in x or y, which is where a component of the derivative is zero.

  Scenario: The curve stays well inside its control points
    Given c ← cubic(point(0, 0), point(1, 3), point(3, -2), point(4, 1))
    Then  curve_bounds(c) = (0, 0, 4, 1)

  Scenario: An arch peaks below its control points
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    Then  curve_bounds(c) = (0, 0, 4, 3)

  Scenario: A quadratic's bounds come from its one turning point
    Given q ← quadratic(point(0, 0), point(2, 4), point(4, 0))
    Then  curve_bounds(q) = (0, 0, 4, 2)
