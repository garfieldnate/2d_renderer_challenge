Feature: Bonus: a glow under the title
  For readers who did chapter 23. glow_of(d) is 0.45 × (1 − clamp(d / 10))²,
  where clamp is to [0, 1]: 0.45 inside the letter and on its edge, falling
  to 0 ten pixels out. book_cover_glow() is book_cover() with one step between the
  document and the title's draw_run: every distinct glyph of the title
  baked once by bake_mtsdf at 32 pixels with spread 8, then, for every
  placement of the title in order, draw_effect(c, its baked glyph, 44 / 32,
  the placement's x, its y, color(1, 0.33, 0.085), true, glow_of). Spread 8
  at a scale of 44 / 32 reaches 11 pixels, past the glow's 10, so no texel
  clamped at the spread ever glows. The subtitle gets no glow.

  Scenario: How the glow falls off
    Then  glow_of(-3) = 0.45
    And   glow_of(0) = 0.45
    And   glow_of(5) = 0.1125
    And   glow_of(10) = 0
    And   glow_of(12) = 0

  Scenario: At chapter 23's spread of 4 the clamp would glow, and at 8 it doesn't
    Then  glow_of(4 * 44 / 32) = 0.091125
    And   glow_of(8 * 44 / 32) = 0

  Scenario: The glow sits around the title's letters and nowhere else
    Given ref ← read_file("reference/epilogue/cover-glow.ppm")
    When  c ← book_cover_glow()
    And   p6 ← canvas_to_p6(c)
    Then  ppm_pixel(p6, 44, 499) = (243, 239, 230) ± 1
    And   ppm_pixel(p6, 44, 494) = (114, 67, 57) ± 1
    And   ppm_pixel(p6, 35, 499) = (93, 54, 55) ± 1
    And   ppm_pixel(p6, 60, 540) = (42, 21, 52) ± 1
    And   ppm_pixel(p6, 56, 639) = (255, 155, 82) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
