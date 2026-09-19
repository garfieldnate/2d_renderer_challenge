Feature: The offset point
  tangent_at(c, t) is the unit tangent of a curve, normal_at(c, t) is that
  tangent turned a quarter turn toward +y, which on the y-down canvas is the
  right-hand side of travel and chapter 13's +h side, and offset_point(c, t,
  d) is the point d along the normal. Positive d is the right-hand side.
  Where a handle sits on its anchor the derivative is zero there, and the
  direction is taken a hair further into the curve instead.

  Scenario: The normal is the tangent turned toward +y
    Given q ← quadratic(point(0, 0), point(2, 4), point(4, 0))
    Then  tangent_at(q, 0) = vector(0.447214, 0.894427)
    And   normal_at(q, 0) = vector(-0.894427, 0.447214)
    And   tangent_at(q, 0.5) = vector(1, 0)
    And   normal_at(q, 0.5) = vector(0, 1)

  Scenario: Offsetting a straight curve gives the parallel line
    Given line ← cubic(point(0, 0), point(1, 1), point(2, 2), point(3, 3))
    Then  offset_point(line, 0, 1) = point(-0.707107, 0.707107)
    And   offset_point(line, 0.5, sqrt(2)) = point(0.5, 2.5)
    And   offset_point(line, 1, -1) = point(3.707107, 2.292893)

  Scenario: Positive d is below a rightward tangent, negative is above
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    Then  point_at(c, 0.5) = point(2, 3)
    And   offset_point(c, 0.5, 1) = point(2, 4)
    And   offset_point(c, 0.5, -1) = point(2, 2)

  Scenario: Offsetting a circle moves it to another circle about the same center
    Given arc ← cubic(point(100, 0), point(100, 55.2285), point(55.2285, 100), point(0, 100))
    Then  magnitude(offset_point(arc, 0.5, 10) - point(0, 0)) = 90 ± 0.05
    And   magnitude(offset_point(arc, 0.25, -10) - point(0, 0)) = 110 ± 0.05
    And   magnitude(offset_point(arc, 0, 10) - point(0, 0)) = 90 ± 0.0001

  Scenario: A handle sitting on its anchor still has a direction
    Given stalled ← cubic(point(0, 0), point(0, 0), point(4, 4), point(4, 0))
    Then  offset_point(stalled, 0, 1) = point(-0.707107, 0.707107) ± 0.001
