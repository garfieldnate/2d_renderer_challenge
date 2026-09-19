Feature: Plate 14
  two_strokes() strokes the hairpin twice, 60 wide with butt caps: flattened
  and stroked with chapter 13's stroker on the left, one outline from the
  offset curves on the right, each outline drawn over its fill in magenta.
  fold_demo() is the right-hand outline filled nonzero on the left and
  even-odd on the right. offsets_plate() draws arch() with its offsets at
  15, 30, 45 and 60 on both sides, warm on the inside where they fold, cool
  outside, the curve in white and every cusp a magenta dot; plate_14() is it
  magnified.

  Scenario: Two strokes
    Given c ← two_strokes()
    And   ref ← read_file("reference/chapter-14/two-strokes.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 160
    And   ppm_pixel(p6, 80, 40) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 240, 40) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 80, 100) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The fold under two rules
    Given c ← fold_demo()
    And   ref ← read_file("reference/chapter-14/fold.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 160
    And   ppm_pixel(p6, 80, 40) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 240, 40) = (206, 206, 212) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The offsets
    Given c ← offsets_plate()
    And   ref ← read_file("reference/chapter-14/offsets.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 270
    And   ppm_pixel(p6, 160, 66) = (243, 243, 246) ± 1
    And   ppm_pixel(p6, 160, 36) = (137, 203, 243) ± 1
    And   ppm_pixel(p6, 10, 10) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 14
    Given c ← plate_14()
    And   ref ← read_file("reference/chapter-14/plate-14.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 640
    And   c.height = 540
    And   max_channel_difference(p6, ref) ≤ 1
