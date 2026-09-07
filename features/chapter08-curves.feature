Feature: A curve is its control points
  quadratic(p0, p1, p2) and cubic(p0, p1, p2, p3) hold a Bezier curve as its
  control points. point_at(c, t) is the point on the curve at parameter t,
  found by de Casteljau's repeated interpolation. split_at(c, t) breaks the
  curve into the two curves that together retrace it, the piece before t and
  the piece after. derivative(c, t) is the tangent vector there.
  transform_curve(c, m) takes every control point through a matrix.

  Scenario: A quadratic evaluated along its length
    Given q ← quadratic(point(0, 0), point(2, 4), point(4, 0))
    Then  point_at(q, 0) = point(0, 0)
    And   point_at(q, 1) = point(4, 0)
    And   point_at(q, 0.5) = point(2, 2)
    And   point_at(q, 0.25) = point(1, 1.5)

  Scenario: A cubic evaluated at its middle
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    Then  point_at(c, 0.5) = point(2, 3)
    And   point_at(c, 0.25) = point(0.625, 2.25)

  Scenario: The derivative is the tangent, and it can point backward
    Given q ← quadratic(point(0, 0), point(2, 4), point(4, 0))
    Then  derivative(q, 0) = vector(4, 8)
    And   derivative(q, 0.5) = vector(4, 0)
    And   derivative(q, 1) = vector(4, -8)

  Scenario: Splitting and rejoining reproduces the curve
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    When  left ← split_at(c, 0.25)[0]
    And   right ← split_at(c, 0.25)[1]
    Then  point_at(left, 1) = point_at(c, 0.25)
    And   point_at(right, 0) = point_at(c, 0.25)
    And   point_at(left, 0.4) = point_at(c, 0.1)
    And   point_at(right, 0.4) = point_at(c, 0.55)
    And   point_at(right, 1) = point(4, 0)

  Scenario: A curve taken through a matrix
    Given q ← quadratic(point(0, 0), point(2, 4), point(4, 0))
    When  t ← transform_curve(q, translation(10, 20))
    Then  point_at(t, 0) = point(10, 20)
    And   point_at(t, 0.5) = point(12, 22)
