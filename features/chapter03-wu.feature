Feature: Wu's line
  Two pixels per step along the longer axis, weighted by where the ideal line
  falls between them, painted with mix. Integer endpoints only, for now.
  total_ink(c) is the sum of every pixel's red channel, which for a white
  line on black is how much paint went down.

  Scenario: A half step lights two pixels equally
    Given c ← canvas(10, 10)
    When  line_wu(c, 0, 0, 4, 2, color(1, 1, 1))
    Then  pixel_at(c, 0, 0) = color(1, 1, 1)
    And   pixel_at(c, 1, 0) = color(0.5, 0.5, 0.5)
    And   pixel_at(c, 1, 1) = color(0.5, 0.5, 0.5)
    And   pixel_at(c, 2, 1) = color(1, 1, 1)
    And   pixel_at(c, 2, 2) = color(0, 0, 0)
    And   pixel_at(c, 4, 2) = color(1, 1, 1)
    And   total_ink(c) = 5

  Scenario: A diagonal has uniform weights
    Given c ← canvas(10, 10)
    When  line_wu(c, 0, 0, 5, 5, color(1, 1, 1))
    Then  lit_pixels(c) = [(0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5)]
    And   pixel_at(c, 3, 3) = color(1, 1, 1)
    And   total_ink(c) = 6

  Scenario: A horizontal line has weight 1 on its row and 0 on the neighbors
    Given c ← canvas(10, 10)
    When  line_wu(c, 0, 3, 7, 3, color(1, 1, 1))
    Then  lit_pixels(c) = [(0, 3), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3)]
    And   pixel_at(c, 3, 3) = color(1, 1, 1)
    And   pixel_at(c, 3, 2) = color(0, 0, 0)
    And   pixel_at(c, 3, 4) = color(0, 0, 0)
    And   total_ink(c) = 8

  Scenario: A steep line weights across columns
    Given c ← canvas(10, 10)
    When  line_wu(c, 1, 1, 3, 7, color(1, 1, 1))
    Then  pixel_at(c, 1, 1) = color(1, 1, 1)
    And   pixel_at(c, 1, 2) = color(0.6667, 0.6667, 0.6667)
    And   pixel_at(c, 2, 2) = color(0.3333, 0.3333, 0.3333)
    And   pixel_at(c, 2, 4) = color(1, 1, 1)
    And   pixel_at(c, 3, 7) = color(1, 1, 1)
    And   total_ink(c) = 7

  Scenario: The weights don't depend on which end you start from
    Given c1 ← canvas(10, 10)
    And   c2 ← canvas(10, 10)
    When  line_wu(c1, 1, 1, 3, 7, color(1, 1, 1))
    And   line_wu(c2, 3, 7, 1, 1, color(1, 1, 1))
    Then  max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2)) = 0

  Scenario: A line that starts above the canvas
    Given c ← canvas(10, 10)
    When  line_wu(c, 0, -1, 8, 3, color(1, 1, 1))
    Then  pixel_at(c, 1, 0) = color(0.5, 0.5, 0.5)
    And   pixel_at(c, 2, 0) = color(1, 1, 1)
    And   total_ink(c) = 7.5

  Scenario: A Wu line of one point
    Given c ← canvas(10, 10)
    When  line_wu(c, 3, 3, 3, 3, color(1, 1, 1))
    Then  lit_pixels(c) = [(3, 3)]
    And   pixel_at(c, 3, 3) = color(1, 1, 1)

  Scenario: Sevenths
    Given c ← canvas(10, 10)
    When  line_wu(c, 0, 0, 7, 3, color(1, 1, 1))
    Then  pixel_at(c, 1, 0) = color(0.5714, 0.5714, 0.5714)
    And   pixel_at(c, 1, 1) = color(0.4286, 0.4286, 0.4286)
    And   pixel_at(c, 2, 0) = color(0.1429, 0.1429, 0.1429)
    And   pixel_at(c, 2, 1) = color(0.8571, 0.8571, 0.8571)
    And   total_ink(c) = 8

  Scenario Outline: The ink depends on the angle
    Given c ← canvas(20, 20)
    When  line_wu(c, 2, 2, <x1>, <y1>, color(1, 1, 1))
    Then  total_ink(c) = <ink>

    Examples:
      | x1 | y1 | ink |
      | 12 | 2  | 11  |
      | 10 | 8  | 9   |
      | 8  | 10 | 9   |
      | 2  | 12 | 11  |
