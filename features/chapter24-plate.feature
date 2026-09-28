Feature: Plate 24, and the chapter's renders
  The inks are chapter 16's paper, orange (0.9, 0.55, 0.1), cyan (0.2,
  0.75, 0.9) and magenta (0.85, 0.2, 0.55); mixes are chapter 1's, in
  linear light. winding_color(w) is paper for 0, cyan mixed into paper by
  0.6 for any negative w, and orange mixed in by 0.45 for 1 and by 0.9 for
  2 or more. centred_star() is chapter 5's star moved by (19.5, 19.5).
  curve_terms(curves, width, height) is loop_blinn_stencil's second half
  alone: every curve's sign added where inside_curve holds.

    plate_24        400 by 200: on the left the winding_color of every
                    pixel of stencil_buffer(centred_star(), 200, 200); on
                    the right Roboto's g through text_matrix(font, 700,
                    -120, 420), its bowl filling the panel: every pixel
                    starts as paper, is mixed toward cyan by 0.55 where
                    its curve_terms are positive and toward magenta by
                    0.55 where they're negative, then toward orange by 0.6
                    where glyph_stencil is nonzero
    msaa_demo       five strips, each the 24 by 12 pixels of the sliver
                    from (30, 4) on its 80 by 40 canvas, paper mixed toward
                    orange by the coverage, magnified 8 times by chapter
                    2's magnify and stacked top to bottom: msaa_coverage
                    with 1, 4, 16 and 64 samples, then chapter 7's fill;
                    192 by 480
    spill_map       810 by 400: the rose through run_pipeline on the left,
                    and from x = 410, for every tile that spilled, the
                    tile's 16 pixels inset by one on every side (chapter
                    21's work map) as magenta mixed into paper by 0.2 +
                    0.8 × its spills / the most spills of any tile; paper
                    everywhere else
    tiger_assembly  900 by 900 paper, four panels 450 square, left to
                    right then top to bottom: the tiger's fine stage run in
                    lcg_shuffle(841, 2024) order and stopped after 210,
                    420, 630 and 841 tiles; every finished tile shows its
                    pixels, flattened over white, and every unfinished one
                    stays paper

  Scenario Outline: Each render matches its reference
    Given c ← <render>()
    And   ref ← read_file(<file>)
    When  p6 ← canvas_to_p6(c)
    Then  c.width = <w>
    And   c.height = <h>
    And   max_channel_difference(p6, ref) ≤ 1

    Examples:
      | render         | file                                        | w   | h   |
      | plate_24       | "reference/chapter-24/plate-24.ppm"         | 400 | 200 |
      | msaa_demo      | "reference/chapter-24/msaa-demo.ppm"        | 192 | 480 |
      | spill_map      | "reference/chapter-24/spill-map.ppm"        | 810 | 400 |
      | tiger_assembly | "reference/chapter-24/tiger-assembly.ppm"   | 900 | 900 |

  Scenario: What the plate shows
    Given p6 ← canvas_to_p6(plate_24())
    Then  ppm_pixel(p6, 100, 100) = (233, 187, 86) ± 1
    And   ppm_pixel(p6, 100, 40) = (173, 139, 69) ± 1
    And   ppm_pixel(p6, 5, 5) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 241, 46) = (202, 187, 140) ± 1
    And   ppm_pixel(p6, 258, 46) = (195, 157, 75) ± 1
    And   ppm_pixel(p6, 258, 100) = (184, 97, 152) ± 1

  Scenario: What the other renders show
    Given msaa ← canvas_to_p6(msaa_demo())
    And   spills ← canvas_to_p6(spill_map())
    Then  ppm_pixel(msaa, 10, 10) = (39, 39, 44) ± 1
    And   ppm_pixel(msaa, 10, 90) = (243, 196, 89) ± 1
    And   ppm_pixel(spills, 415, 5) = (39, 39, 44) ± 1
    And   ppm_pixel(spills, 605, 50) = (237, 124, 196) ± 1
