Feature: Binary PPM
  P6 is P3 with the numbers written as bytes. The header is the same three
  lines with a 6 in place of the 3, followed by exactly one newline, and then
  one byte per channel with nothing between them. From this chapter on, the
  book's reference images are P6, and your PPM readers accept both.

  Scenario: The header, then the bytes
    Given c ← canvas(2, 1)
    When  write_pixel(c, 0, 0, color(1, 0, 0))
    And   write_pixel(c, 1, 0, color(0, 0.5, 0))
    And   p6 ← canvas_to_p6(c)
    Then  p6 begins with "P6\n2 1\n255\n"
    And   length(p6) = 17
    And   byte 12 of p6 = 255
    And   byte 13 of p6 = 0
    And   byte 16 of p6 = 188

  Scenario: The same pixel comes back out of either format
    Given c ← canvas(2, 1)
    When  write_pixel(c, 1, 0, color(0, 0.5, 0))
    And   p3 ← canvas_to_ppm(c)
    And   p6 ← canvas_to_p6(c)
    Then  ppm_pixel(p6, 1, 0) = (0, 188, 0)
    And   ppm_pixel(p3, 1, 0) = (0, 188, 0)
    And   max_channel_difference(p3, p6) = 0
    And   distinct_values(p6) = 2

  Scenario: Sizes still have to match
    Given c1 ← canvas(2, 1)
    And   c2 ← canvas(1, 2)
    When  p6a ← canvas_to_p6(c1)
    And   p6b ← canvas_to_p6(c2)
    Then  max_channel_difference(p6a, p6b) = 255
