Feature: Plate 20
  Three documents from reference/chapter-20/, each drawn by render_svg and
  nothing else. harbor() is harbor.svg on a 480 by 320 canvas and rose()
  is rose.svg on a 400 by 400 canvas: between them they use every element,
  attribute and property this chapter reads. tiger() is tiger.svg, the
  Ghostscript tiger, on a 450 by 450 canvas, and plate_20() is it.

  Scenario: A harbor at dusk
    Given c ← harbor()
    And   ref ← read_file("reference/chapter-20/harbor.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 480
    And   c.height = 320
    And   ppm_pixel(p6, 240, 20) = (24, 18, 51) ± 1
    And   ppm_pixel(p6, 20, 280) = (67, 32, 68) ± 1
    And   ppm_pixel(p6, 418, 156) = (200, 50, 60) ± 1
    And   ppm_pixel(p6, 418, 161) = (244, 239, 230) ± 1
    And   ppm_pixel(p6, 200, 262) = (200, 50, 60) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: A rose window
    Given c ← rose()
    And   ref ← read_file("reference/chapter-20/rose.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 400
    And   c.height = 400
    And   ppm_pixel(p6, 200, 200) = (255, 248, 216) ± 1
    And   ppm_pixel(p6, 385, 385) = (240, 168, 24) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The tiger
    Given c ← plate_20()
    And   ref ← read_file("reference/chapter-20/tiger.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 450
    And   c.height = 450
    And   ppm_pixel(p6, 5, 5) = (255, 255, 255) ± 1
    And   ppm_pixel(p6, 250, 200) = (0, 0, 0) ± 1
    And   ppm_pixel(p6, 170, 330) = (255, 114, 127) ± 1
    And   ppm_pixel(p6, 350, 100) = (204, 114, 38) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
