Feature: Canvas
  A rectangle of colors. Origin at the top left, y increasing downward.

  Scenario: A new canvas starts black
    Given c ← canvas(10, 20)
    Then  c.width = 10
    And   c.height = 20
    And   every pixel of c is color(0, 0, 0)

  Scenario: Writing a pixel
    Given c ← canvas(10, 20)
    And   red ← color(1, 0, 0)
    When  write_pixel(c, 2, 3, red)
    Then  pixel_at(c, 2, 3) = red

  Scenario: Writing outside the canvas is ignored
    Given c ← canvas(10, 20)
    When  write_pixel(c, -1, 5, color(1, 0, 0))
    And   write_pixel(c, 10, 5, color(1, 0, 0))
    And   write_pixel(c, 5, 20, color(1, 0, 0))
    Then  every pixel of c is color(0, 0, 0)
