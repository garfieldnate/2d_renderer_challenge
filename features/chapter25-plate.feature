Feature: Plate 25, and the chapter's renders
  Inks: pale paper (0.92, 0.9, 0.82), ink (0.05, 0.05, 0.08), cyan (0.2,
  0.75, 0.9), magenta (0.85, 0.2, 0.55); chapter 16's paper (0.02, 0.02,
  0.025); black and white [(0, 0, 0), (255, 255, 255)] as a palette.
  magnify is chapter 2's; panels sit side by side left to right.

    plate_25         ring_canvas() bucketed cyan from (80, 80) at tolerance
                     32, contiguous, no anti-alias, four-way; its pixels
                     x 100 to 159, y 50 to 109, magnified 4 times; beside
                     it ramp_canvas(240, 240) error-diffused to black and
                     white; 480 by 240
    dither_strip     ramp_canvas(256, 32) to black and white by threshold,
                     ordered_dither and error_diffuse, stacked top to
                     bottom; 256 by 96
    halo_demo        ring_canvas() bucketed cyan from (80, 80), four-way,
                     contiguous, four times: tolerance 0; 32; 32 with
                     anti-alias; 160; 640 by 160
    brush_demo       400 by 240 pale paper; wobbly_events() painted in ink
                     with brush(8, 0.5, 0.25, 0.6, 1), one dab per event;
                     then the same events moved down 110, spaced by
                     distance
    paint_by_script  480 by 320, starting black, every step an edit
                     through a history, in this order: the sky, chapter
                     10's paint_fill of marquee(0, 0, 480, 210) with the
                     linear gradient from (0, 0) to (0, 210) with stops
                     (0.05, 0.12, 0.35) at 0 and (0.95, 0.45, 0.2) at 1;
                     the sea, marquee(0, 210, 480, 320) painted through
                     in (0.02, 0.1, 0.2); the sun, one event at (370, 110)
                     with brush(46, 0.55, 0.25, 1, 1) in (1, 0.8, 0.3);
                     the hills, events i from 0 to 20 at (-20 + 26i, 205 -
                     30 sin(i / 3.1) - 12 sin(1.7i)) with brush(34, 0.7,
                     0.2, 0.8, 1) in (0.04, 0.12, 0.06); a magenta stroke
                     from (40, 40) to (460, 300) with brush(30, 0.5, 0.2,
                     1, 1), then undone; six waves, for k from 0 to 5,
                     events j from 0 to 11 at (60 + 60k + 8j, 232 + 14k +
                     2 sin j) with brush(1.6, 0.2, 0.3, 0.7, 0.8) in the
                     sun's colour; the boat, marquee(150, 262, 210, 272)
                     painted through in ink. Then the boat's marquee is
                     floated with the sea's colour as backfill, moved by
                     (40, -6) and dropped. Finally the canvas goes to
                     median_cut(canvas_bytes(c), 16), error_diffuse,
                     canvas_to_bmp8, read_bmp8, and indexed_canvas of what
                     came back
  Every stroke above is paint_stroke with by_distance true.

  Scenario Outline: Each render matches its reference
    Given c ← <render>()
    And   ref ← read_file(<file>)
    When  p6 ← canvas_to_p6(c)
    Then  c.width = <w>
    And   c.height = <h>
    And   max_channel_difference(p6, ref) ≤ 1

    Examples:
      | render          | file                                        | w   | h   |
      | dither_strip    | "reference/chapter-25/dither-strip.ppm"     | 256 | 96  |
      | halo_demo       | "reference/chapter-25/halo-demo.ppm"        | 640 | 160 |
      | brush_demo      | "reference/chapter-25/brush-demo.ppm"       | 400 | 240 |
      | paint_by_script | "reference/chapter-25/paint-by-script.ppm"  | 480 | 320 |

  Scenario: The halo, and the two controls that fight over it
    Given p6 ← canvas_to_p6(halo_demo())
    Then  ppm_pixel(p6, 72, 22) = (177, 175, 172) ± 1
    And   ppm_pixel(p6, 232, 22) = (177, 175, 172) ± 1
    And   ppm_pixel(p6, 392, 22) = (153, 202, 212) ± 1
    And   ppm_pixel(p6, 552, 22) = (124, 225, 243) ± 1
    And   ppm_pixel(p6, 80, 80) = (124, 225, 243) ± 1

  Scenario: The painting
    Given p6 ← canvas_to_p6(paint_by_script())
    Then  ppm_pixel(p6, 10, 300) = (39, 89, 124) ± 1
    And   ppm_pixel(p6, 370, 110) = (247, 217, 145) ± 1

  Scenario: Plate 25
    Given c ← plate_25()
    And   ref ← read_file("reference/chapter-25/plate-25.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 480
    And   c.height = 240
    And   ppm_pixel(p6, 150, 120) = (124, 225, 243) ± 1
    And   ppm_pixel(p6, 236, 120) = (246, 243, 234) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
