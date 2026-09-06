Feature: Points and vectors
  A point is a place; a vector is a displacement. Both are (x, y, w) with
  w = 1 for a point and w = 0 for a vector, so that the matrices later in
  the chapter can tell them apart. Coordinates are real numbers.

  Scenario: A point has w = 1
    Given p ← point(4, -4)
    Then  p.x = 4
    And   p.y = -4
    And   p.w = 1

  Scenario: A vector has w = 0
    Given v ← vector(4, -4)
    Then  v.x = 4
    And   v.y = -4
    And   v.w = 0

  Scenario: The difference of two points is the vector between them
    Given a ← point(3, 2)
    And   b ← point(5, 6)
    Then  b - a = vector(2, 4)
    And   a - b = vector(-2, -4)

  Scenario: A point plus a vector is a point
    Given p ← point(3, -2)
    And   v ← vector(-2, 3)
    Then  p + v = point(1, 1)
    And   p - v = point(5, -5)

  Scenario: A vector plus a vector is a vector
    Given a ← vector(3, -2)
    And   b ← vector(-2, 3)
    Then  a + b = vector(1, 1)
    And   a - b = vector(5, -5)

  Scenario: Negating, scaling and dividing a vector
    Given v ← vector(1, -2)
    Then  -v = vector(-1, 2)
    And   v * 3.5 = vector(3.5, -7)
    And   v * 0.5 = vector(0.5, -1)
    And   v / 2 = vector(0.5, -1)

  Scenario: The magnitude of a vector
    Then  magnitude(vector(1, 0)) = 1
    And   magnitude(vector(0, 1)) = 1
    And   magnitude(vector(3, 4)) = 5
    And   magnitude(vector(-3, -4)) = 5
    And   magnitude(vector(-1, -2)) = 2.2361

  Scenario: Normalizing a vector
    Then  normalize(vector(4, 0)) = vector(1, 0)
    And   normalize(vector(1, 2)) = vector(0.4472, 0.8944)
    And   magnitude(normalize(vector(1, 2))) = 1

  Scenario: The dot product of two vectors
    Given a ← vector(1, 2)
    And   b ← vector(2, 3)
    Then  dot(a, b) = 8
    And   dot(a, vector(-2, 1)) = 0

  Scenario: The cross product of two vectors is a number
    Given a ← vector(1, 0)
    And   b ← vector(0, 1)
    Then  cross(a, b) = 1
    And   cross(b, a) = -1
    And   cross(a, a) = 0
    And   cross(vector(2, 3), vector(4, 5)) = -2

  Scenario: The sign of the cross product says which side of a line a point is on
    Given a ← point(0, 0)
    And   b ← point(10, 0)
    Then  cross(b - a, point(5, 3) - a) = 30
    And   cross(b - a, point(5, -3) - a) = -30
    And   cross(b - a, point(20, 0) - a) = 0
