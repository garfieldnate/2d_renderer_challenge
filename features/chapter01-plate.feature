Feature: Plate 1
  Two ramps, black to white and red to green, each mixed both ways.
  The browser's way on top, the light's way beneath.

  Scenario: The plate
    Given c ← plate_01()
    Then  c.width = 400
    And   c.height = 180
    When  ppm ← canvas_to_ppm(c)
    Then  ppm_pixel(ppm, 0, 20) = (0, 0, 0) ± 1
    And   ppm_pixel(ppm, 399, 20) = (255, 255, 255) ± 1
    And   ppm_pixel(ppm, 200, 20) = (128, 128, 128) ± 1
    And   ppm_pixel(ppm, 200, 65) = (188, 188, 188) ± 1
    And   ppm_pixel(ppm, 200, 42) = (0, 0, 0) ± 1
    And   ppm_pixel(ppm, 0, 110) = (218, 0, 0) ± 1
    And   ppm_pixel(ppm, 399, 110) = (0, 149, 39) ± 1
    And   ppm_pixel(ppm, 200, 110) = (109, 75, 19) ± 1
    And   ppm_pixel(ppm, 200, 155) = (160, 108, 26) ± 1
    And   ppm_pixel(ppm, 200, 87) = (0, 0, 0) ± 1
    And   ppm_pixel(ppm, 200, 132) = (0, 0, 0) ± 1
    And   ppm_pixel(ppm, 200, 177) = (0, 0, 0) ± 1
    And   ref ← read_file("reference/chapter-01/plate-01.ppm")
    And   max_channel_difference(ppm, ref) ≤ 1
    And   linear blending is on
