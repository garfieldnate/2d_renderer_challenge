Feature: Shapes are questions
  A shape is anything that can answer one question: is this point inside you?
  Three shapes to start with. The circle and the rectangle include their
  boundary. The half-plane is everything on the side its normal points to,
  boundary included.

  Scenario: A point inside a circle
    Given s ← circle(8, 8, 5)
    Then  inside(s, 8, 8) = true
    And   inside(s, 12, 8) = true
    And   inside(s, 13, 8) = true
    And   inside(s, 13.01, 8) = false
    And   inside(s, 11.6, 11.6) = false

  Scenario: A point inside a rectangle
    Given s ← rectangle(1.25, 2.0, 4.75, 5.0)
    Then  inside(s, 3, 3) = true
    And   inside(s, 1.25, 2.0) = true
    And   inside(s, 4.75, 5.0) = true
    And   inside(s, 1.2, 3) = false
    And   inside(s, 3, 5.1) = false

  Scenario: A point inside a half-plane
    Given s ← half_plane(2.5, 0, 1, 0)
    Then  inside(s, 2.5, 7) = true
    And   inside(s, 3, -4) = true
    And   inside(s, 2.4, 0) = false

  Scenario: The normal picks the side
    Given s ← half_plane(2.5, 0, -1, 0)
    Then  inside(s, 2.4, 0) = true
    And   inside(s, 3, 0) = false
