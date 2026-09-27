Feature: Plate 21
  Every mode of render_svg_with draws exactly the bytes chapter 20's
  render_svg draws. Only fills and strokes count; the fills that build a
  clip's coverage are not counted, and a shape with a clip has its window
  or tiles turned into a canvas-sized coverage, multiplied by the clip and
  painted with draw_coverage_counted. tile_work(text, width, height) renders the document
  in the "tiled" mode and, for every tile, counts how many of its fills and
  strokes classified that tile partial and how many solid: tile_work[ty][tx]
  is the pair (partial, solid). work_map() is 910 by 450 paper: the tiger
  as the "tiled" walker draws it at (0, 0), and from x = 460 one square per
  tile of it: the pixels whose x mod 16 or y mod 16 is 0 or 15 are left
  as paper, so each square is its tile's 16 pixels inset by one on every
  side and then cut by the canvas; the rest of the tile is magenta mixed into paper at
  0.15 + 0.85 × partial / the largest partial count of any tile when the
  tile's partial count is above 0; cyan mixed in at 0.6 when it's 0 and
  its solid count isn't; paper when both are 0. The mixes are in linear
  light, with chapter 16's inks. plate_21() is work_map().

  Scenario: The tiger, tiled, drawn byte for byte as chapter 20 drew it
    Given st ← stats()
    And   text ← read_file("reference/chapter-20/tiger.svg")
    When  c ← render_svg_with(text, 450, 450, "tiled", st)
    Then  st.cells = 816480
    And   st.copies = 207872
    And   max_channel_difference(canvas_to_p6(c), canvas_to_p6(render_svg(text, 450, 450))) = 0
    And   max_channel_difference(canvas_to_p6(c), read_file("reference/chapter-20/tiger.ppm")) ≤ 1

  Scenario: The harbor and the rose, every way, byte for byte
    Given harbor ← read_file("reference/chapter-20/harbor.svg")
    And   rose ← read_file("reference/chapter-20/rose.svg")
    When  h ← canvas_to_p6(render_svg(harbor, 480, 320))
    And   r ← canvas_to_p6(render_svg(rose, 400, 400))
    Then  max_channel_difference(canvas_to_p6(render_svg_with(harbor, 480, 320, "bounded", stats())), h) = 0
    And   max_channel_difference(canvas_to_p6(render_svg_with(harbor, 480, 320, "tiled", stats())), h) = 0
    And   max_channel_difference(canvas_to_p6(render_svg_with(rose, 400, 400, "bounded", stats())), r) = 0
    And   max_channel_difference(canvas_to_p6(render_svg_with(rose, 400, 400, "tiled", stats())), r) = 0

  Scenario: Where the tiger's work is
    Given w ← tile_work(read_file("reference/chapter-20/tiger.svg"), 450, 450)
    Then  length(w) = 29
    And   length(w[0]) = 29
    And   w[0][0] = (0, 0)
    And   w[14][3] = (31, 0)
    And   w[12][12] = (23, 1)
    And   w[2][21] = (0, 2)

  Scenario: Plate 21
    Given c ← plate_21()
    And   ref ← read_file("reference/chapter-21/work_map.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 910
    And   c.height = 450
    And   ppm_pixel(p6, 250, 200) = (0, 0, 0) ± 1
    And   ppm_pixel(p6, 455, 5) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 516, 232) = (237, 124, 196) ± 1
    And   ppm_pixel(p6, 660, 200) = (213, 112, 176) ± 1
    And   ppm_pixel(p6, 804, 40) = (100, 180, 196) ± 1
    And   ppm_pixel(p6, 460, 0) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
