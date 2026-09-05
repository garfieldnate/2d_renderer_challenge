Feature: Coverage is not opacity
  Painting the same shape twice through the same coverage doesn't give you the
  shape twice. It gives you a thicker edge.

  Scenario: Half coverage, painted twice, is three quarters
    Given c ← canvas(1, 1)
    And   cov ← coverage_buffer(1, 1)
    When  set_coverage(cov, 0, 0, 0.5)
    And   paint_through(c, cov, color(1, 1, 1))
    And   paint_through(c, cov, color(1, 1, 1))
    Then  pixel_at(c, 0, 0) = color(0.75, 0.75, 0.75)

  Scenario: The disc, once and twice
    Given c ← painted_twice()
    And   ref ← read_file("reference/chapter-02/painted-twice.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 480
    And   c.height = 240
    And   ppm_pixel(p6, 120, 120) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 360, 120) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 93, 27) = (157, 127, 64) ± 1
    And   ppm_pixel(p6, 333, 27) = (194, 156, 74) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
