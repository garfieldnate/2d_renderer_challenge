Feature: Plate 16
  glyph_plate() fills Roboto's a at a 300 pixel em and draws its control
  polygon over it: on-curve points as filled squares, off-curve points as
  hollow circles, implied on-curve points as smaller squares; plate_16() is
  it magnified. composite_demo() draws eacute with its two components in two
  inks and its bounds as a hairline box. sizes() draws g at 12, 24, 48 and
  96 pixels on one baseline. flip_trap() draws R through text_matrix on the
  left and through a scale that forgot to turn y over on the right.

  Scenario: The glyph and its control points
    Given c ← glyph_plate()
    And   ref ← read_file("reference/chapter-16/glyph.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 320
    And   ppm_pixel(p6, 160, 160) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 10, 10) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 16
    Given c ← plate_16()
    And   ref ← read_file("reference/chapter-16/plate-16.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 640
    And   c.height = 640
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: A composite in two inks
    Given c ← composite_demo()
    And   ref ← read_file("reference/chapter-16/composite.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 240
    And   c.height = 240
    And   ppm_pixel(p6, 120, 120) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 120, 30) = (124, 196, 237) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: One glyph at four sizes
    Given c ← sizes()
    And   ref ← read_file("reference/chapter-16/sizes.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 240
    And   c.height = 120
    And   ppm_pixel(p6, 95, 40) = (199, 199, 204) ± 1
    And   ppm_pixel(p6, 230, 110) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The flip, forgotten
    Given c ← flip_trap()
    And   ref ← read_file("reference/chapter-16/flip.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 240
    And   c.height = 120
    And   ppm_pixel(p6, 50, 40) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 170, 80) = (237, 124, 196) ± 1
    And   ppm_pixel(p6, 60, 100) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
