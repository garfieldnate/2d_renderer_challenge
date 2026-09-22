Feature: Plate 18
  draw_run(canvas, font, run, size, color, linear) is the seam between
  layout and rendering: every placement goes through chapter 17, its x
  split by subpixel_of into a whole pixel and a quarter, the glyph's
  bitmap for that quarter painted with the pen at that pixel, and its
  baseline rounded to the nearest pixel row, halves up. A run at whole
  pixels draws exactly what chapter 17's draw_text drew. The renders use
  chapter 16's inks (paper, gray, dim, magenta, cyan) and its hairlines
  (butt caps, round joins, 1 wide unless said), and kerning is on unless
  said. Every hairline below is its own stroke, painted in the order
  written; in kern_demo, break_demo and drift_demo the glyphs are drawn
  first and the hairlines over them, and in alignment_plate the hairlines
  are drawn first and the glyphs over them. kern_demo() is 320 by 190 paper: TAVERN at a 64 pixel em from x
  = 12, kerned on the baseline y = 70 and unkerned on y = 160, a dim
  hairline along each baseline from x = 4 to 316, a tick from 3 to 12
  below the baseline at every placement's x and at the run's end, cyan on
  the kerned row and dim on the other, and three magenta hairlines: down from y = 84
  to 180 at each run's end, and along y = 180 between the two ends. break_demo() is 340 by
  150 paper: the through-line, THROUGH_LINE below, as a left paragraph at
  16 pixels from (20, 30) in a 300 measure, and cyan hairlines down x = 20
  and x = 320 from y = 10 to 140. drift_demo() is a 260 by 44 white canvas
  magnified three times: the line "little illicit lilies fill the hill
  until it is still" at 11 pixels from x = 6, black, unkerned, on the
  baseline y = 14 as layout_run lays it out and on y = 34 with the pen
  rounded to a whole pixel after every glyph (pen ← round(pen + advance),
  halves up; the pen is whole after each step, so this is also each
  advance rounded on its own); hairlines 2 wide: cyan from
  y = 3 to 18 and 23 to 38 at the exact run's end, magenta from 23 to 38
  at the rounded run's end, and magenta along y = 40 between the two ends.
  alignment_plate() is 660 by 236 paper: THROUGH_LINE at 14 pixels in a
  300 measure four times, left at (20, 24), right at (340, 24), center at
  (20, 132) and justify at (340, 132), each with a dim hairline 0.5 wide
  along every baseline across the measure and cyan hairlines 0.5 wide
  down both edges of the measure from 14 above the first baseline to 5
  below the last; plate_18() is it.

  THROUGH_LINE is "Rasterization computes coverage. Painting composites
  paint through coverage. Once you hold a coverage buffer, a stroke is a
  fill of a different outline, a clip is a multiplication of two buffers,
  and a glyph is a path somebody else drew."

  Scenario: A run at whole pixels draws what chapter 17 drew
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   a ← canvas(30, 14)
    And   b ← canvas(30, 14)
    When  fill(a, color(1, 1, 1))
    And   fill(b, color(1, 1, 1))
    And   draw_run(a, font, layout_run(font, "Ha", 11, 2, 11, false), 11, color(0, 0, 0), true)
    And   pen ← draw_text(b, font, "Ha", 11, 2, 11, color(0, 0, 0), true)
    Then  max_channel_difference(canvas_to_p6(a), canvas_to_p6(b)) = 0
    And   pixel_at(a, 3, 6) = color(0.0331, 0.0331, 0.0331)

  Scenario: The baseline rounds to a pixel row, halves up
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   a ← canvas(30, 14)
    And   b ← canvas(30, 14)
    When  fill(a, color(1, 1, 1))
    And   fill(b, color(1, 1, 1))
    And   draw_run(a, font, layout_run(font, "Ha", 11, 2.4, 11.5, false), 11, color(0, 0, 0), true)
    And   draw_run(b, font, layout_run(font, "Ha", 11, 2.4, 11.4, false), 11, color(0, 0, 0), true)
    Then  subpixel_of(2.4) = (2, 2)
    And   pixel_at(a, 3, 11) = color(0.4077, 0.4077, 0.4077)
    And   pixel_at(a, 3, 12) = color(1, 1, 1)
    And   pixel_at(b, 3, 11) = color(1, 1, 1)
    And   pixel_at(b, 3, 10) = color(0.4077, 0.4077, 0.4077)

  Scenario: The kern pair the font asks for
    Given c ← kern_demo()
    And   ref ← read_file("reference/chapter-18/kerning.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 190
    And   ppm_pixel(p6, 135, 40) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 135, 130) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 141, 130) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 141, 40) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 251, 180) = (176, 93, 146) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Greedy breaking inside a measure
    Given c ← break_demo()
    And   ref ← read_file("reference/chapter-18/breaking.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 340
    And   c.height = 150
    And   ppm_pixel(p6, 20, 60) = (93, 167, 181) ± 1
    And   ppm_pixel(p6, 31, 28) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 200, 140) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: A rounded pen drifts
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   c ← drift_demo()
    And   ref ← read_file("reference/chapter-18/drift.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  pen_advance(font, "i", 11) = 2.6694 ± 0.0001
    And   20 * round(pen_advance(font, "i", 11)) - run_advance(font, "iiiiiiiiiiiiiiiiiiii", 11, false) = 6.6113 ± 0.0001
    And   c.width = 780
    And   c.height = 132
    And   ppm_pixel(p6, 571, 30) = (124, 225, 243) ± 1
    And   ppm_pixel(p6, 616, 90) = (237, 124, 196) ± 1
    And   ppm_pixel(p6, 600, 120) = (237, 124, 196) ± 1
    And   ppm_pixel(p6, 600, 60) = (255, 255, 255)
    And   ppm_pixel(p6, 21, 40) = (114, 114, 114) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 18
    Given c ← plate_18()
    And   ref ← read_file("reference/chapter-18/plate-18.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 660
    And   c.height = 236
    And   ppm_pixel(p6, 340, 130) = (72, 124, 135) ± 1
    And   ppm_pixel(p6, 24, 20) = (55, 55, 59) ± 1
    And   ppm_pixel(p6, 5, 5) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
