Feature: Plate 4
  The same two matrices, rotation(π / 6) and translation(104.5, 76.5),
  multiplied in both orders and applied to two shapes: chapter 3's fan,
  described as points around the origin this time, and a letter F.

  Scenario: The fan as points
    Given pts ← fan_points()
    Then  length(pts) = 13
    And   pts[0] = point(0, 0)
    And   pts[1] = point(36, 0)
    And   pts[4] = point(0, 36)
    And   pts[7] = point(-36, 0)
    And   pts[2] = point(31.1769, 18)

  Scenario: Rotate, then translate: the fan turns about its own center
    Given m ← translation(104.5, 76.5) * rotation(π / 6)
    When  pts ← transform_points(fan_points(), m)
    Then  pts[0] = point(104.5, 76.5)
    And   pts[1] = point(135.6769, 94.5)
    And   pts[4] = point(86.5, 107.6769)

  Scenario: Translate, then rotate: the fan swings about the canvas corner
    Given m ← rotation(π / 6) * translation(104.5, 76.5)
    When  pts ← transform_points(fan_points(), m)
    Then  pts[0] = point(52.2497, 118.5009)
    And   pts[1] = point(83.4266, 136.5009)

  Scenario: The letter F
    Given f ← letter_f()
    Then  length(f) = 10
    And   f[0] = point(-20, -30)
    And   f[1] = point(20, -30)
    And   f[5] = point(12, -5)
    And   f[9] = point(-20, 30)

  Scenario: The F at home
    When  f ← transform_points(letter_f(), translation(44.5, 44.5))
    Then  f[0] = point(24.5, 14.5)
    And   f[1] = point(64.5, 14.5)
    And   f[9] = point(24.5, 74.5)

  Scenario: The F, rotated then translated
    Given m ← translation(104.5, 76.5) * rotation(π / 6)
    When  f ← transform_points(letter_f(), m)
    Then  f[0] = point(102.1795, 40.5192)
    And   f[1] = point(136.8205, 60.5192)
    And   f[5] = point(117.3923, 78.1699)
    And   f[9] = point(72.1795, 92.4808)

  Scenario: The F, translated then rotated
    Given m ← rotation(π / 6) * translation(104.5, 76.5)
    When  f ← transform_points(letter_f(), m)
    Then  f[0] = point(49.9291, 82.5202)
    And   f[1] = point(84.5702, 102.5202)
    And   f[5] = point(65.142, 120.1708)
    And   f[9] = point(19.9291, 134.4817)

  Scenario: side_by_side puts the first canvas on the left
    Given a ← canvas(2, 3)
    And   b ← canvas(4, 3)
    When  fill(a, color(1, 0, 0))
    And   fill(b, color(0, 0, 1))
    And   c ← side_by_side(a, b)
    Then  c.width = 6
    And   c.height = 3
    And   pixel_at(c, 0, 0) = color(1, 0, 0)
    And   pixel_at(c, 1, 2) = color(1, 0, 0)
    And   pixel_at(c, 2, 0) = color(0, 0, 1)
    And   pixel_at(c, 5, 2) = color(0, 0, 1)

  Scenario: The fan, both orders
    Given c ← fan_both_orders()
    And   ref ← read_file("reference/chapter-04/fan-both-orders.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 160
    And   ppm_pixel(p6, 104, 76) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 124, 76) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 104, 56) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 125, 88) = (236, 236, 231) ± 1
    And   ppm_pixel(p6, 116, 97) = (236, 236, 231) ± 1
    And   ppm_pixel(p6, 141, 76) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 10, 10) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 212, 118) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 232, 118) = (246, 246, 241) ± 1
    And   ppm_pixel(p6, 233, 130) = (223, 223, 219) ± 1
    And   ppm_pixel(p6, 224, 139) = (236, 236, 231) ± 1
    And   ppm_pixel(p6, 200, 139) = (211, 211, 207) ± 1
    And   ppm_pixel(p6, 310, 10) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 4
    Given c ← plate_04()
    And   ref ← read_file("reference/chapter-04/plate-04.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 640
    And   c.height = 320
    And   ppm_pixel(p6, 48, 28) = (99, 99, 102) ± 1
    And   ppm_pixel(p6, 80, 28) = (111, 111, 115) ± 1
    And   ppm_pixel(p6, 48, 100) = (111, 111, 115) ± 1
    And   ppm_pixel(p6, 10, 10) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 200, 150) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 268, 129) = (237, 237, 233) ± 1
    And   ppm_pixel(p6, 215, 145) = (237, 237, 233) ± 1
    And   ppm_pixel(p6, 239, 101) = (237, 237, 233) ± 1
    And   ppm_pixel(p6, 174, 173) = (217, 217, 213) ± 1
    And   ppm_pixel(p6, 368, 28) = (99, 99, 102) ± 1
    And   ppm_pixel(p6, 500, 60) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 453, 207) = (236, 236, 231) ± 1
    And   ppm_pixel(p6, 431, 229) = (234, 234, 229) ± 1
    And   ppm_pixel(p6, 445, 249) = (234, 234, 229) ± 1
    And   ppm_pixel(p6, 368, 273) = (177, 177, 174) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
