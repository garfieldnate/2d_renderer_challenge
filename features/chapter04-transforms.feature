Feature: The transforms
  translation, scaling, rotation and shearing each build a matrix. Angles
  are in radians. A positive rotation turns the x axis toward the y axis,
  which on a canvas whose y runs downward is clockwise on the screen.

  Scenario: Multiplying by a translation matrix
    Given t ← translation(5, -3)
    And   p ← point(-3, 4)
    Then  t * p = point(2, 1)

  Scenario: The inverse of a translation moves the other way
    Given t ← translation(5, -3)
    And   p ← point(-3, 4)
    Then  inverse(t) * p = point(-8, 7)

  Scenario: Translation does not affect vectors
    Given t ← translation(5, -3)
    And   v ← vector(-3, 4)
    Then  t * v = v

  Scenario: A scaling matrix applied to a point
    Given s ← scaling(2, 3)
    And   p ← point(-4, 6)
    Then  s * p = point(-8, 18)

  Scenario: A scaling matrix applied to a vector
    Given s ← scaling(2, 3)
    And   v ← vector(-4, 6)
    Then  s * v = vector(-8, 18)

  Scenario: The inverse of a scaling shrinks
    Given s ← scaling(2, 3)
    And   v ← vector(-4, 6)
    Then  inverse(s) * v = vector(-2, 2)

  Scenario: Reflection is scaling by a negative value
    Given s ← scaling(-1, 1)
    And   p ← point(2, 3)
    Then  s * p = point(-2, 3)

  Scenario: A positive rotation turns x toward y
    Given p ← point(1, 0)
    Then  rotation(π / 4) * p = point(0.7071, 0.7071)
    And   rotation(π / 2) * p = point(0, 1)
    And   rotation(π) * p = point(-1, 0)

  Scenario: The inverse of a rotation turns the other way
    Given p ← point(1, 0)
    Then  inverse(rotation(π / 4)) * p = point(0.7071, -0.7071)
    And   rotation(-π / 4) * p = point(0.7071, -0.7071)

  Scenario: A rotation preserves length
    Given v ← vector(3, 4)
    Then  magnitude(rotation(1.2) * v) = 5
    And   magnitude(rotation(-2.8) * v) = 5

  Scenario: Shearing moves x in proportion to y
    Given s ← shearing(1, 0)
    And   p ← point(2, 3)
    Then  s * p = point(5, 3)

  Scenario: Shearing moves y in proportion to x
    Given s ← shearing(0, 1)
    And   p ← point(2, 3)
    Then  s * p = point(2, 5)

  Scenario: Individual transformations are applied in sequence
    Given p ← point(1, 0)
    And   A ← rotation(π / 2)
    And   B ← scaling(5, 5)
    And   C ← translation(10, 5)
    When  p2 ← A * p
    And   p3 ← B * p2
    And   p4 ← C * p3
    Then  p2 = point(0, 1)
    And   p3 = point(0, 5)
    And   p4 = point(10, 10)

  Scenario: Chained transformations must be applied in reverse order
    Given p ← point(1, 0)
    And   A ← rotation(π / 2)
    And   B ← scaling(5, 5)
    And   C ← translation(10, 5)
    When  T ← C * B * A
    Then  T * p = point(10, 10)

  Scenario: The other order is a different transform
    Given p ← point(1, 0)
    And   A ← rotation(π / 2)
    And   B ← scaling(5, 5)
    And   C ← translation(10, 5)
    When  T ← A * B * C
    Then  T * p = point(-25, 55)

  Scenario: Rotating about a point that isn't the origin
    Given T ← translation(4, 4) * rotation(π / 2) * translation(-4, -4)
    Then  T * point(6, 4) = point(4, 6)
    And   T * point(4, 4) = point(4, 4)
