Feature: Colors
  A color is three floating point numbers. Values may leave the 0-1 range
  during a calculation; they are clamped once, on the way out to a file.

  Scenario: A color is a red, green, blue tuple
    Given c ← color(-0.5, 0.4, 1.7)
    Then  c.red = -0.5
    And   c.green = 0.4
    And   c.blue = 1.7

  Scenario: Adding colors
    Given c1 ← color(0.9, 0.6, 0.75)
    And   c2 ← color(0.7, 0.1, 0.25)
    Then  c1 + c2 = color(1.6, 0.7, 1.0)

  Scenario: Subtracting colors
    Given c1 ← color(0.9, 0.6, 0.75)
    And   c2 ← color(0.7, 0.1, 0.25)
    Then  c1 - c2 = color(0.2, 0.5, 0.5)

  Scenario: Scaling a color
    Given c ← color(0.2, 0.3, 0.4)
    Then  c * 2 = color(0.4, 0.6, 0.8)

  Scenario: Multiplying colors filters one through the other
    Given c1 ← color(1, 0.2, 0.4)
    And   c2 ← color(0.9, 1, 0.1)
    Then  c1 * c2 = color(0.9, 0.2, 0.04)
