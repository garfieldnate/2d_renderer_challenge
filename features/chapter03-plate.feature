Feature: Plate 3
  Twelve rays from the center of a 160 by 160 canvas to points 72 pixels
  out, every 30 degrees, drawn three ways.

  Scenario: The ray endpoints
    Then  ray_ends() = [(152, 80), (142, 116), (116, 142), (80, 152), (44, 142), (18, 116), (8, 80), (18, 44), (44, 18), (80, 8), (116, 18), (142, 44)]

  Scenario: Bresenham's fan
    Given c ← fan_bresenham()
    And   ref ← read_file("reference/chapter-03/fan-bresenham.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 160
    And   c.height = 160
    And   ppm_pixel(p6, 80, 80) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 120, 80) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 10, 10) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 100, 91) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 100, 92) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 103, 120) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 102, 120) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 104, 120) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Wu's fan
    Given c ← fan_wu()
    And   ref ← read_file("reference/chapter-03/fan-wu.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  ppm_pixel(p6, 80, 80) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 120, 80) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 100, 91) = (163, 163, 161) ± 1
    And   ppm_pixel(p6, 100, 92) = (199, 199, 196) ± 1
    And   ppm_pixel(p6, 103, 120) = (220, 220, 216) ± 1
    And   ppm_pixel(p6, 104, 120) = (130, 130, 129) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The fan as twelve thin rectangles
    Given c ← fan_coverage()
    And   ref ← read_file("reference/chapter-03/fan-coverage.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 320
    And   ppm_pixel(p6, 160, 160) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 10, 10) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 240, 160) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 240, 158) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 200, 183) = (177, 177, 174) ± 1
    And   ppm_pixel(p6, 200, 185) = (209, 209, 205) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 3
    Given c ← plate_03()
    And   ref ← read_file("reference/chapter-03/plate-03.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 640
    And   c.height = 320
    And   ppm_pixel(p6, 160, 160) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 480, 160) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 10, 10) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 200, 183) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 200, 185) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 520, 183) = (163, 163, 161) ± 1
    And   ppm_pixel(p6, 520, 185) = (199, 199, 196) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
