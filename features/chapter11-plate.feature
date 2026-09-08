Feature: Plate 11
  two_filters() magnifies the 8x8 sprite 20x, nearest on the left and bilinear
  on the right; plate_11() is it. three_filters() adds bicubic. The sprite is
  built as a canvas, written to a PPM and read back, so the round trip is
  exercised.

  Scenario: The sprite round-trips through a PPM
    Given s ← sprite()
    Then  s.width = 8
    And   s.height = 8
    And   length(mip_chain(s)) = 4

  Scenario: Two filters, nearest against bilinear
    Given c ← two_filters()
    And   ref ← read_file("reference/chapter-11/two-filters.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 160
    And   ppm_pixel(p6, 50, 50) = (249, 247, 237) ± 1
    And   ppm_pixel(p6, 10, 10) = (69, 69, 80) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 11
    Given c ← plate_11()
    And   ref ← read_file("reference/chapter-11/plate-11.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 160
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Three filters, adding bicubic
    Given c ← three_filters()
    And   ref ← read_file("reference/chapter-11/three-filters.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 384
    And   c.height = 128
    And   max_channel_difference(p6, ref) ≤ 1
