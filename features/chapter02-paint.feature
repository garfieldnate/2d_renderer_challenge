Feature: Painting through coverage
  paint_through(canvas, coverage, color) moves every pixel of the canvas
  toward the color by the pixel's coverage, using mix. Zero coverage leaves
  a pixel alone; full coverage replaces it.

  Scenario: Half coverage is half the paint
    Given c ← canvas(1, 1)
    And   cov ← coverage_buffer(1, 1)
    When  set_coverage(cov, 0, 0, 0.5)
    And   paint_through(c, cov, color(1, 1, 1))
    Then  pixel_at(c, 0, 0) = color(0.5, 0.5, 0.5)

  Scenario: Paint over something that isn't black
    Given c ← canvas(1, 1)
    And   cov ← coverage_buffer(1, 1)
    When  fill(c, color(0.2, 0.2, 0.2))
    And   set_coverage(cov, 0, 0, 0.25)
    And   paint_through(c, cov, color(1, 0, 0))
    Then  pixel_at(c, 0, 0) = color(0.4, 0.15, 0.15)

  Scenario: Zero leaves it alone and one replaces it
    Given c ← canvas(2, 1)
    And   cov ← coverage_buffer(2, 1)
    When  fill(c, color(0.2, 0.2, 0.2))
    And   set_coverage(cov, 1, 0, 1)
    And   paint_through(c, cov, color(1, 0, 0))
    Then  pixel_at(c, 0, 0) = color(0.2, 0.2, 0.2)
    And   pixel_at(c, 1, 0) = color(1, 0, 0)

  Scenario: The arithmetic is on light, whatever the switch says
    Given linear blending is off
    And   c ← canvas(1, 1)
    And   cov ← coverage_buffer(1, 1)
    When  set_coverage(cov, 0, 0, 0.5)
    And   paint_through(c, cov, color(1, 1, 1))
    And   ppm ← canvas_to_ppm(c)
    Then  pixel_at(c, 0, 0) = color(0.5, 0.5, 0.5)
    And   ppm_pixel(ppm, 0, 0) = (188, 188, 188)

  Scenario: The disc by centers
    Given c ← disc_centers()
    And   ref ← read_file("reference/chapter-02/disc-centers.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 320
    And   ppm_pixel(p6, 160, 160) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 124, 36) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 132, 36) = (243, 196, 89) ± 1
    And   distinct_values(p6) = 5
    And   max_channel_difference(p6, ref) ≤ 1
