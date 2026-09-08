Feature: Plate 10
  paint_fill(c, cov, paint) samples a paint at each covered pixel's center and
  blends it in through the coverage; with a solid paint it is exactly chapter
  2's paint_through. three_gradients() paints a linear, a focal radial and a
  conic gradient from one stop table; plate_10() is it. extend_strip() shows a
  gradient under the three extend modes. A focal gradient whose focal point
  can't reach a pixel returns the last stop there, not black.

  Scenario: A solid paint fills exactly like paint_through
    Given box ← polygon(point(1, 1), point(6, 1), point(6, 6), point(1, 6))
    And   cov ← fill_path(box, "nonzero", 8, 8)
    And   a ← canvas(8, 8)
    And   b ← canvas(8, 8)
    When  fill(a, color(0.02, 0.02, 0.025))
    And   fill(b, color(0.02, 0.02, 0.025))
    And   paint_fill(a, cov, solid(color(0.9, 0.5, 0.2)))
    And   paint_through(b, cov, color(0.9, 0.5, 0.2))
    Then  pixel_at(a, 3, 3) = pixel_at(b, 3, 3)
    And   pixel_at(a, 1, 1) = pixel_at(b, 1, 1)

  Scenario: An unreachable focal pixel takes the last stop, not black
    Given g ← radial_gradient(point(100, 50), 0, point(50, 50), 20, [stop(0, color(0, 0, 0)), stop(1, color(1, 1, 1))], "pad")
    Then  radial_t(g, 110, 50) = none
    And   paint_at(g, 110, 50) = color(1, 1, 1)

  Scenario: The three gradients
    Given c ← three_gradients()
    And   ref ← read_file("reference/chapter-10/three-gradients.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 458
    And   c.height = 150
    And   ppm_pixel(p6, 10, 10) = (68, 40, 108) ± 1
    And   ppm_pixel(p6, 140, 140) = (255, 249, 225) ± 1
    And   ppm_pixel(p6, 209, 55) = (71, 41, 109) ± 1
    And   ppm_pixel(p6, 383, 20) = (65, 39, 108) ± 1
    And   ppm_pixel(p6, 438, 75) = (196, 95, 130) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The extend strip
    Given c ← extend_strip()
    And   ref ← read_file("reference/chapter-10/extend-modes.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 360
    And   c.height = 180
    And   ppm_pixel(p6, 20, 30) = (89, 108, 188) ± 1
    And   ppm_pixel(p6, 340, 30) = (255, 218, 89) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 10
    Given c ← plate_10()
    And   ref ← read_file("reference/chapter-10/plate-10.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 458
    And   c.height = 150
    And   max_channel_difference(p6, ref) ≤ 1
