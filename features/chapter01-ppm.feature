Feature: PPM output
  The plain-text P3 format. Three header lines, then decimal channel values.

  Scenario: The PPM header
    Given c ← canvas(5, 3)
    When  ppm ← canvas_to_ppm(c)
    Then  lines 1-3 of ppm are
      """
      P3
      5 3
      255
      """

  Scenario: Colors out of range are clamped, not wrapped
    Given c ← canvas(2, 1)
    When  write_pixel(c, 0, 0, color(1.5, 0, -0.5))
    And   ppm ← canvas_to_ppm(c)
    Then  line 4 of ppm is "255 0 0  0 0 0"

  Scenario: No line exceeds 70 characters
    Given c ← canvas(40, 2) filled with color(1, 0.8, 0.6)
    When  ppm ← canvas_to_ppm(c)
    Then  every line of ppm is at most 70 characters

  Scenario: The file ends with a newline
    Given c ← canvas(5, 3)
    When  ppm ← canvas_to_ppm(c)
    Then  ppm ends with a newline character
