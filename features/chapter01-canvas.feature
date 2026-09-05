Feature: Canvas
  A rectangle of colors. The origin is the top left corner, x increases to
  the right and y increases downward. Every pixel starts black.

  Scenario: A new canvas is black
    Given c ← canvas(10, 20)
    Then  c.width = 10
    And   c.height = 20
    And   every pixel of c is color(0, 0, 0)

  Scenario: Writing a pixel
    Given c ← canvas(10, 20)
    And   red ← color(1, 0, 0)
    When  write_pixel(c, 2, 3, red)
    Then  pixel_at(c, 2, 3) = red

  Scenario: x is the column and y is the row
    Given c ← canvas(10, 20)
    When  write_pixel(c, 2, 3, color(1, 0, 0))
    Then  pixel_at(c, 3, 2) = color(0, 0, 0)
    And   pixel_at(c, 2, 3) = color(1, 0, 0)

  Scenario: Writing outside the canvas is ignored
    Given c ← canvas(10, 20)
    When  write_pixel(c, -1, 5, color(1, 0, 0))
    And   write_pixel(c, 10, 5, color(1, 0, 0))
    And   write_pixel(c, 5, -1, color(1, 0, 0))
    And   write_pixel(c, 5, 20, color(1, 0, 0))
    Then  every pixel of c is color(0, 0, 0)

  Scenario: A pixel can be written more than once
    Given c ← canvas(10, 20)
    When  write_pixel(c, 2, 3, color(1, 0, 0))
    And   write_pixel(c, 2, 3, color(0, 1, 0))
    Then  pixel_at(c, 2, 3) = color(0, 1, 0)

  Scenario: Filling a canvas
    Given c ← canvas(10, 20)
    When  fill(c, color(0.1, 0.2, 0.3))
    Then  every pixel of c is color(0.1, 0.2, 0.3)
