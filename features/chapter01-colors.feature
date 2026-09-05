Feature: Colors
  A color is three floating point numbers, each measuring light: 0 is none,
  1 is as much as the display can make. Values may leave the 0-1 range during
  a calculation. They are clamped once, on the way out to a file.

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

  Scenario: Scaling a color by a number
    Given c ← color(0.2, 0.3, 0.4)
    Then  c * 2 = color(0.4, 0.6, 0.8)
    And   c * 0.5 = color(0.1, 0.15, 0.2)

  Scenario: Multiplying two colors filters one through the other
    Given c1 ← color(1, 0.2, 0.4)
    And   c2 ← color(0.9, 1, 0.1)
    Then  c1 * c2 = color(0.9, 0.2, 0.04)

  Scenario: Colors compare component by component, with the usual tolerance
    Given c1 ← color(0.1, 0.5, 1)
    And   c2 ← color(0.2, 0, 0)
    Then  c1 + c2 = color(0.3, 0.5, 1)
    And   c1 + c2 ≠ color(0.3, 0.5, 1.001)
