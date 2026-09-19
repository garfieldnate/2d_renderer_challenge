Feature: Curvature, and where the offset stalls
  second_derivative(c, t) is the Bezier of second differences of the control
  points, and curvature(c, t) = cross(v, a) / |v|^3 with v the derivative and
  a the second derivative: signed like cross, positive where the curve turns
  clockwise on screen, and 1 / |curvature| is the radius of the circle that
  hugs the curve there. The offset at distance d moves at (1 - curvature * d)
  times the curve's speed, so on the inside of a turn it slows, stalls where
  d equals the radius, and runs backward beyond. cusps(c, d) finds the
  parameters where that factor changes sign: between 64 evenly spaced
  samples, bisected 40 times.

  Scenario: The second derivative of a quadratic is constant, a cubic's is linear
    Given q ← quadratic(point(0, 0), point(2, 4), point(4, 0))
    And   c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    Then  second_derivative(q, 0) = vector(0, -16)
    And   second_derivative(q, 0.5) = vector(0, -16)
    And   second_derivative(c, 0) = vector(24, -24)
    And   second_derivative(c, 0.5) = vector(0, -24)
    And   second_derivative(c, 1) = vector(-24, -24)

  Scenario: Curvature is signed like the cross product and its reciprocal is a radius
    Given q ← quadratic(point(0, 0), point(2, 4), point(4, 0))
    And   c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    And   line ← cubic(point(0, 0), point(1, 1), point(2, 2), point(3, 3))
    And   arc ← cubic(point(100, 0), point(100, 55.2285), point(55.2285, 100), point(0, 100))
    Then  curvature(q, 0.5) = -1
    And   curvature(q, 0) = -0.089443
    And   curvature(c, 0.5) = -0.666667
    And   curvature(line, 0.5) = 0
    And   curvature(arc, 0.5) = 0.009938 ± 0.0001
    And   curvature(arc, 0) = 0.009786 ± 0.0001

  Scenario: The offset stalls where d reaches the radius, on the inside of the turn
    Given q ← quadratic(point(0, 0), point(2, 4), point(4, 0))
    Then  length(cusps(q, -0.5)) = 0
    And   length(cusps(q, 2)) = 0
    And   length(cusps(q, -2)) = 2
    And   cusps(q, -2)[0] = 0.308395 ± 0.0001
    And   cusps(q, -2)[1] = 0.691605 ± 0.0001
    And   curvature(q, cusps(q, -2)[0]) = -0.5 ± 0.0001

  Scenario: A wider offset stalls sooner
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    Then  length(cusps(c, -1)) = 0
    And   length(cusps(c, -1.5)) = 0
    And   length(cusps(c, -2)) = 2
    And   cusps(c, -2)[0] = 0.30334 ± 0.0001
    And   cusps(c, -2)[1] = 0.69666 ± 0.0001
