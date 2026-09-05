Feature: Mixing two colors
  mix(a, b, t) is the color a fraction t of the way from a to b. With linear
  blending on, which is the default, the arithmetic happens on the light
  values the colors already hold. With it off, the arithmetic happens on the
  encoded file values instead, which is what web browsers do.

  Scenario: Halfway between black and white
    Given a ← color(0, 0, 0)
    And   b ← color(1, 1, 1)
    Then  mix(a, b, 0.5) = color(0.5, 0.5, 0.5)

  Scenario: The ends of a mix are its inputs
    Given a ← color(0.7, 0, 0)
    And   b ← color(0, 0.3, 0.02)
    Then  mix(a, b, 0) = a
    And   mix(a, b, 1) = b

  Scenario: Red to green, in light
    Given a ← color(0.7, 0, 0)
    And   b ← color(0, 0.3, 0.02)
    Then  mix(a, b, 0.5) = color(0.35, 0.15, 0.01)
    And   mix(a, b, 0.25) = color(0.525, 0.075, 0.005)

  Scenario: Halfway between black and white, the way browsers do it
    Given linear blending is off
    And   a ← color(0, 0, 0)
    And   b ← color(1, 1, 1)
    Then  mix(a, b, 0.5) = color(0.2140, 0.2140, 0.2140)

  Scenario: Red to green, the way browsers do it
    Given linear blending is off
    And   a ← color(0.7, 0, 0)
    And   b ← color(0, 0.3, 0.02)
    Then  mix(a, b, 0.5) = color(0.1527, 0.0693, 0.0067)

  Scenario: The light's way never clamps
    Given a ← color(1.5, 0.5, -0.2)
    And   b ← color(0, 0, 0)
    Then  mix(a, b, 0) = color(1.5, 0.5, -0.2)
    And   mix(a, b, 0.5) = color(0.75, 0.25, -0.1)

  Scenario: The switch can be passed instead of set
    Given a ← color(0, 0, 0)
    And   b ← color(1, 1, 1)
    Then  mix(a, b, 0.5, true) = color(0.5, 0.5, 0.5)
    And   mix(a, b, 0.5, false) = color(0.2140, 0.2140, 0.2140)
    And   linear blending is on

  Scenario: The browser's way clamps each end before encoding it
    Given linear blending is off
    And   a ← color(1.5, 0.5, -0.2)
    And   b ← color(0, 0, 0)
    Then  mix(a, b, 0) = color(1, 0.5, 0)
    And   mix(a, b, 0.5) = color(0.2140, 0.1113, 0.0000)

  Scenario: The ends of a mix are its inputs either way, when they're in range
    Given linear blending is off
    And   a ← color(0.7, 0, 0)
    And   b ← color(0, 0.3, 0.02)
    Then  mix(a, b, 0) = a
    And   mix(a, b, 1) = b
