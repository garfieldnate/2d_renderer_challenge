Feature: Bresenham's line
  One pixel per step along the longer axis, chosen with integer arithmetic,
  both endpoints included. lit_pixels(c) lists every pixel of a canvas that
  isn't black, in reading order: top row first, left to right.

  Scenario: lit_pixels reads like a page
    Given c ← canvas(10, 10)
    When  write_pixel(c, 5, 0, color(1, 1, 1))
    And   write_pixel(c, 0, 2, color(1, 1, 1))
    And   write_pixel(c, 2, 2, color(0.5, 0, 0))
    Then  lit_pixels(c) = [(5, 0), (0, 2), (2, 2)]

  Scenario: A diagonal
    Given c ← canvas(10, 10)
    When  line_bresenham(c, 0, 0, 5, 5, color(1, 1, 1))
    Then  lit_pixels(c) = [(0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5)]

  Scenario: A horizontal line lights one row and nothing else
    Given c ← canvas(10, 10)
    When  line_bresenham(c, 0, 3, 7, 3, color(1, 1, 1))
    Then  lit_pixels(c) = [(0, 3), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3)]

  Scenario: A shallow line steps along x
    Given c ← canvas(10, 10)
    When  line_bresenham(c, 0, 0, 7, 3, color(1, 1, 1))
    Then  lit_pixels(c) = [(0, 0), (1, 0), (2, 1), (3, 1), (4, 2), (5, 2), (6, 3), (7, 3)]

  Scenario: A steep line steps along y
    Given c ← canvas(10, 10)
    When  line_bresenham(c, 1, 1, 3, 7, color(1, 1, 1))
    Then  lit_pixels(c) = [(1, 1), (1, 2), (2, 3), (2, 4), (2, 5), (3, 6), (3, 7)]

  Scenario: The pixels don't depend on which end you start from
    Given c1 ← canvas(10, 10)
    And   c2 ← canvas(10, 10)
    When  line_bresenham(c1, 1, 1, 3, 7, color(1, 1, 1))
    And   line_bresenham(c2, 3, 7, 1, 1, color(1, 1, 1))
    Then  lit_pixels(c1) = lit_pixels(c2)
    And   max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2)) = 0

  Scenario: A line going up and to the right
    Given c ← canvas(10, 10)
    When  line_bresenham(c, 0, 6, 7, 3, color(1, 1, 1))
    Then  lit_pixels(c) = [(6, 3), (7, 3), (4, 4), (5, 4), (2, 5), (3, 5), (0, 6), (1, 6)]

  Scenario: At an exact half the line stays on its row one step longer
    Given c ← canvas(10, 10)
    When  line_bresenham(c, 0, 0, 4, 2, color(1, 1, 1))
    Then  lit_pixels(c) = [(0, 0), (1, 0), (2, 1), (3, 1), (4, 2)]

  Scenario: A line of one point
    Given c ← canvas(10, 10)
    When  line_bresenham(c, 3, 3, 3, 3, color(1, 1, 1))
    Then  lit_pixels(c) = [(3, 3)]

  Scenario: A line may run off the canvas
    Given c ← canvas(10, 10)
    When  line_bresenham(c, 0, 0, 12, 6, color(1, 1, 1))
    Then  length(lit_pixels(c)) = 10
