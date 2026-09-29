Feature: The cover's document
  reference/epilogue/cover.svg is a 480 by 680 viewBox of chapter 20's SVG,
  drawn by render_svg on a 480 by 680 canvas. In document order: a rectangle
  over the whole page filled with a linear gradient from top to bottom; a
  group clipped by a rounded rectangle, 400 by 400 at (40, 40) with corners
  of radius 24, holding a square of radial gradient and the whole Ghostscript
  tiger, its 900-unit drawing scaled by 0.5 about (248, 250); the panel's
  frame, the same rounded rectangle stroked 2 wide; a line from (40, 472) to
  (440, 472), 3 wide, dashed 14 on and 9 off with round caps; and a group at
  opacity 0.5 of eight crop-mark arms, each its own path, 1 wide and 16 long.
  The document has no text: the title is set on top of it afterwards.

  Scenario: The document, drawn by chapter 20 and nothing else
    Given ref ← read_file("reference/epilogue/cover-art.ppm")
    When  c ← render_svg(read_file("reference/epilogue/cover.svg"), 480, 680)
    And   p6 ← canvas_to_p6(c)
    Then  c.width = 480
    And   c.height = 680
    And   ppm_pixel(p6, 240, 8) = (21, 19, 42) ± 1
    And   ppm_pixel(p6, 240, 670) = (46, 22, 54) ± 1
    And   ppm_pixel(p6, 60, 60) = (207, 121, 77) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The clip rounds the panel's corner, and the rule is dashed
    When  p6 ← canvas_to_p6(render_svg(read_file("reference/epilogue/cover.svg"), 480, 680))
    Then  ppm_pixel(p6, 41, 41) = (23, 19, 43) ± 1
    And   ppm_pixel(p6, 47, 472) = (255, 154, 82) ± 1
    And   ppm_pixel(p6, 58, 472) = (40, 21, 51) ± 1

  Scenario: The crop marks are one group, so where two arms cross is no brighter than one arm
    When  p6 ← canvas_to_p6(render_svg(read_file("reference/epilogue/cover.svg"), 480, 680))
    Then  ppm_pixel(p6, 24, 24) = (180, 176, 171) ± 1
    And   ppm_pixel(p6, 24, 20) = (180, 176, 171) ± 1
    And   ppm_pixel(p6, 20, 24) = (180, 176, 171) ± 1
    And   ppm_pixel(p6, 23, 20) = (22, 19, 42) ± 1
