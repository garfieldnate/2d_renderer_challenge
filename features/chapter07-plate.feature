Feature: Plate 7
  The renders of chapter 7. needles() sets the same twelve thin triangles by
  chapter 6's aliased fill on the left and this chapter's exact fill on the
  right. soft_square() fills a small square whose edges land on pixel centers.
  star_exact() fills chapter 5's star both ways. spiral_smooth() is chapter
  6's spiral of stars, now smooth. sunburst() is the payoff, and plate_07()
  is it.

  Scenario: The needles, aliased against exact
    Given c ← needles()
    And   ref ← read_file("reference/chapter-07/needles.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 480
    And   c.height = 240
    And   ink(fill_path_aliased(needle_path(), "nonzero", 60, 60)) = 268.0
    And   ink(fill_path(needle_path(), "nonzero", 60, 60)) = polygon_area(needle_path())
    And   ppm_pixel(p6, 120, 120) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 360, 120) = (94, 78, 51) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The soft square
    Given c ← soft_square()
    And   ref ← read_file("reference/chapter-07/soft-square.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 192
    And   c.height = 192
    And   ppm_pixel(p6, 96, 96) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 36, 36) = (134, 109, 59) ± 1
    And   ppm_pixel(p6, 12, 12) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The star, exact, both rules
    Given c ← star_exact()
    And   ref ← read_file("reference/chapter-07/star-exact.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 160
    And   ppm_pixel(p6, 80, 80) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 240, 80) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The spiral, smooth
    Given c ← spiral_smooth()
    And   ref ← read_file("reference/chapter-07/spiral-smooth.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 320
    And   ppm_pixel(p6, 180, 160) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 160, 160) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 7
    Given c ← plate_07()
    And   ref ← read_file("reference/chapter-07/plate-07.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 480
    And   c.height = 480
    And   ppm_pixel(p6, 240, 60) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 440, 240) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 439, 257) = (124, 196, 237) ± 1
    And   ppm_pixel(p6, 436, 274) = (237, 137, 149) ± 1
    And   ppm_pixel(p6, 229, 210) = (246, 243, 234) ± 1
    And   ppm_pixel(p6, 240, 240) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 20, 20) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
