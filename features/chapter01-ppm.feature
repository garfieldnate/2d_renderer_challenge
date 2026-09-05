Feature: PPM output
  The plain-text P3 format: three header lines, then every pixel as three
  decimal numbers, left to right, top to bottom. The canvas holds light, so
  each channel is clamped to 0-1, encoded, scaled to 0-255 and rounded to
  the nearest whole number on its way into the file.

  Scenario: The PPM header
    Given c ← canvas(5, 3)
    When  ppm ← canvas_to_ppm(c)
    Then  lines 1-3 of ppm are
      """
      P3
      5 3
      255
      """

  Scenario: Pixel values are encoded, not scaled
    Given c ← canvas(3, 1)
    When  write_pixel(c, 0, 0, color(1, 0, 0))
    And   write_pixel(c, 1, 0, color(0, 0.5, 0))
    And   write_pixel(c, 2, 0, color(0, 0, 0.216))
    And   ppm ← canvas_to_ppm(c)
    Then  line 4 of ppm is "255 0 0 0 188 0 0 0 128"

  Scenario: Colors out of range are clamped, not wrapped
    Given c ← canvas(2, 1)
    When  write_pixel(c, 0, 0, color(1.5, 0, -0.5))
    And   ppm ← canvas_to_ppm(c)
    Then  line 4 of ppm is "255 0 0 0 0 0"

  Scenario: Every row starts a new line, and no line exceeds 70 characters
    Given c ← canvas(10, 2)
    When  fill(c, color(1, 0.8, 0.6))
    And   ppm ← canvas_to_ppm(c)
    Then  lines 4-7 of ppm are
      """
      255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231
      203 255 231 203 255 231 203 255 231 203 255 231 203
      255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231
      203 255 231 203 255 231 203 255 231 203 255 231 203
      """
    And   every line of ppm is at most 70 characters

  Scenario: A line of exactly 70 characters is allowed
    Given c ← canvas(8, 1)
    When  fill(c, color(1, 0.1, 0))
    And   write_pixel(c, 7, 0, color(1, 1, 1))
    And   ppm ← canvas_to_ppm(c)
    Then  lines 4-5 of ppm are
      """
      255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 255
      255
      """

  Scenario: The file ends with a newline
    Given c ← canvas(5, 3)
    When  ppm ← canvas_to_ppm(c)
    Then  ppm ends with a newline character

  Scenario: Reading a pixel back out of the text
    Given c ← canvas(3, 2)
    When  write_pixel(c, 2, 1, color(0, 0.5, 1))
    And   ppm ← canvas_to_ppm(c)
    Then  ppm_pixel(ppm, 2, 1) = (0, 188, 255)
    And   ppm_pixel(ppm, 1, 1) = (0, 0, 0)

  Scenario: Counting the distinct values in a file
    Given c ← canvas(3, 1)
    When  write_pixel(c, 0, 0, color(1, 0, 0))
    And   write_pixel(c, 1, 0, color(0, 0.5, 0))
    And   write_pixel(c, 2, 0, color(0, 0, 0.216))
    And   ppm ← canvas_to_ppm(c)
    Then  distinct_values(ppm) = 4

  Scenario: Comparing two files
    Given c1 ← canvas(2, 1)
    And   c2 ← canvas(2, 1)
    When  write_pixel(c2, 0, 0, color(0.5, 0, 0))
    And   ppm1 ← canvas_to_ppm(c1)
    And   ppm2 ← canvas_to_ppm(c2)
    Then  max_channel_difference(ppm1, ppm1) = 0
    And   max_channel_difference(ppm1, ppm2) = 188

  Scenario: Files of different sizes are as different as it gets
    Given c1 ← canvas(5, 3)
    And   c2 ← canvas(3, 5)
    When  ppm1 ← canvas_to_ppm(c1)
    And   ppm2 ← canvas_to_ppm(c2)
    Then  max_channel_difference(ppm1, ppm2) = 255
