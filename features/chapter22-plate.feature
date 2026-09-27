Feature: Plate 22, and a seal
  plate_glyph() is path A: Roboto's g, as chapter 16's glyph_path through
  text_matrix(font, 200, 40, 140), flattened to 0.1 pixel, filled
  nonzero. plate_star() is path B: chapter 5's star through
  translation(49.5, 23.5) × translation(80.5, 80.5) × scaling(0.85, 0.85)
  × translation(-80.5, -80.5), which scales it by 0.85 about its center
  and moves the center to (130, 104), filled even-odd. op_panel(op) is a
  200 by 200 canvas of chapter 16's paper with combine(A, "nonzero", B,
  "evenodd", op) filled nonzero by chapter 7 and painted through in
  chapter 7's orange ink; then hairlines, each chapter 13's
  stroke_to_path(p, 1, "butt", "round", 4) filled nonzero and painted
  through: A in chapter 16's dim, B in dim, and the result in magenta.
  plate_22() is the four panels side by side, left to right "union",
  "intersection", "difference", "xor", 800 by 200.

  text_path(font, text, size, x, y) is one path holding, in order, the
  subpaths of glyph_path(font, name, text_matrix(font, size, px, py), 0.1)
  for every placement (name, px, py) of layout_run(font, text, size, x, y,
  true). rosette(cx, cy, n, r, d) starts from an empty path and, for k
  from 0 to n - 1, combines it by "xor" (both "nonzero") with
  circle_path(cx + d cos(2πk / n), cy + d sin(2πk / n), r, 72). seal() is
  480 by 480, and every step is a combine with both rules "nonzero"
  unless one is named, in this order:
    rim   ← circle_path(240, 240, 200, 120), then "union" with, for k
            from 0 to 39, circle_path(240 + 200 cos(2πk / 40), 240 +
            200 sin(2πk / 40), 16, 24), one at a time
    ring  ← rim "difference" circle_path(240, 240, 168, 120)
    s     ← ring "union" polygon((20, 196), (460, 196), (460, 284),
            (20, 284))
    s     ← s "xor" text_path(Roboto, "BOOLEAN", 84, 52, 270)
    s     ← s "xor" chapter 5's star moved by translation(159.5, 23.5),
            the star's rule "evenodd"
    s     ← s "xor" rosette(240, 352, 16, 44, 36)
  and the canvas is paper, s filled nonzero and painted through in
  orange, then s's hairline 0.75 wide in magenta, made as above.

  Scenario: Plate 22
    Given c ← plate_22()
    And   ref ← read_file("reference/chapter-22/plate-22.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 800
    And   c.height = 200
    And   ppm_pixel(p6, 129, 75) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 129, 114) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 156, 96) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 329, 75) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 329, 114) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 356, 96) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 529, 75) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 529, 114) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 556, 96) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 729, 75) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 729, 114) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 756, 96) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 5, 5) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The seal
    Given c ← seal()
    And   ref ← read_file("reference/chapter-22/seal.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 480
    And   c.height = 480
    And   ppm_pixel(p6, 240, 452) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 240, 40) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 240, 200) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 76, 215) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 430, 240) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 240, 352) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
