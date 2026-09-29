Feature: The cover
  book_cover() is the program printed in the epilogue: chapter 20's render_svg of
  reference/epilogue/cover.svg on a 480 by 680 canvas; then the title, laid
  out as the type feature says, drawn with chapter 18's draw_run at 44 pixels
  in color(0.9, 0.86, 0.79); then the subtitle drawn at 15 pixels in
  color(1, 0.33, 0.085); both draw_runs with linear blending on (the probe at
  (363, 510), on the edge of a letter, is where blending encoded instead shows).
  It returns the canvas.

  Scenario: The cover
    Given ref ← read_file("reference/epilogue/cover.ppm")
    When  c ← book_cover()
    And   p6 ← canvas_to_p6(c)
    Then  c.width = 480
    And   c.height = 680
    And   ppm_pixel(p6, 44, 499) = (243, 239, 230) ± 1
    And   ppm_pixel(p6, 52, 551) = (243, 239, 230) ± 1
    And   ppm_pixel(p6, 60, 540) = (42, 21, 52) ± 1
    And   ppm_pixel(p6, 56, 639) = (255, 155, 82) ± 1
    And   ppm_pixel(p6, 240, 8) = (21, 19, 42) ± 1
    And   ppm_pixel(p6, 363, 510) = (142, 136, 136) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Chapter 21's tiled walker draws the cover's document byte for byte
    Given st ← stats()
    And   text ← read_file("reference/epilogue/cover.svg")
    When  c ← render_svg_with(text, 480, 680, "tiled", st)
    Then  st.cells = 881792
    And   st.copies = 205568
    And   max_channel_difference(canvas_to_p6(c), canvas_to_p6(render_svg(text, 480, 680))) = 0
    And   max_channel_difference(canvas_to_p6(c), read_file("reference/epilogue/cover-art.ppm")) ≤ 1
