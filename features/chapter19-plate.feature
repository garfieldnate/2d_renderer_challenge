Feature: Plate 19
  The renders use chapter 16's inks and hairlines (butt caps, round
  joins, 1 wide unless said), every glyph drawn through chapter 18's
  draw_run, and the Arabic font is reference/chapter-19/dejavu-arabic.json.
  ligature_demo() is 260 by 100 paper: office shaped in Roboto and
  positioned ltr at a 64 pixel em from (20, 70) with kerning, the f_i in
  magenta and the rest gray, a dim hairline along the baseline from x = 4
  to 256, and a cyan hairline from 4 to 16 below the baseline at every
  caret position. forms_demo() is 320 by 110 paper: the glyphs beh,
  beh.init, beh.medi and beh.fina at a 64 pixel em in gray, the k-th
  (from 0) with its origin at (16 + 76 k, 60), a dim hairline along y =
  60 from 4 left of the origin to 68 right of it, and the words isol,
  init, medi and fina set in Roboto at 11 pixels in cyan by layout_run
  from (16 + 76 k, 90) with kerning. word_demo() is 260 by 100 paper:
  kitab with its kasra shaped in DejaVu Sans and positioned rtl at a 64
  pixel em from (20, 64) without kerning, the letters gray and the mark
  magenta, a dim baseline from x = 4 to 256, and cyan carets from 4 to 16
  below the baseline. mixed_demo() is 300 by 60 paper: the text "Book: "
  + kitab + ", again." itemized, each item shaped in its script's font
  (Roboto for latin, DejaVu Sans for arabic) and positioned in its own
  direction at a 28 pixel em with kerning on the baseline y = 40, the
  first from x = 12 and each next from where the one before it ended (x
  plus its buffer_advance); a dim baseline from x = 4 to 296 and a cyan
  hairline from 3 to 10 below the baseline where each item begins; marks
  magenta. cluster_plate() is 540 by 210 paper, two bands: office in
  Roboto with its run from x = 20, and kitab with its kasra in DejaVu
  Sans, rtl, with its run from x = 290, both at a 52 pixel em. In a band
  the top row's baseline is y = 80: each character's glyph from the cmap
  alone sits in a dim box (every box here is a hairline rectangle, stroked
  1 wide, not filled) from 46 above the baseline to 12 below, as wide
  as the glyph's advance or 12 if that is less, the glyph centered in the
  box, the first box at the band's x and each next box 14 past the one
  before it. The bottom row's baseline is y = 180: the run shaped and
  positioned with kerning, one cyan box per cluster spanning from its
  first non-mark glyph's origin to its last one's origin plus advance,
  the same heights; glyphs whose names changed from the top row, and
  marks, are magenta, the rest gray; and a magenta hairline 0.75 wide
  runs from the bottom center of each character's box to the top center
  of the box of the cluster that character belongs to (the largest
  cluster start not past its index). plate_19() is cluster_plate().

  Scenario: The ligature and where the cursor may stand
    Given c ← ligature_demo()
    And   ref ← read_file("reference/chapter-19/ligature.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 260
    And   c.height = 100
    And   ppm_pixel(p6, 106, 50) = (237, 124, 196) ± 1
    And   ppm_pixel(p6, 120, 50) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 56, 80) = (124, 225, 243) ± 1
    And   ppm_pixel(p6, 5, 5) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: One letter, four forms
    Given c ← forms_demo()
    And   ref ← read_file("reference/chapter-19/forms.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 110
    And   ppm_pixel(p6, 50, 55) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 180, 55) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 5, 5) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: A word, right to left, with its mark attached
    Given c ← word_demo()
    And   ref ← read_file("reference/chapter-19/word.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 260
    And   c.height = 100
    And   ppm_pixel(p6, 88, 50) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 133, 72) = (237, 124, 196) ± 1
    And   ppm_pixel(p6, 5, 5) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Two scripts on one line, and the comma that jumped
    Given c ← mixed_demo()
    And   ref ← read_file("reference/chapter-19/mixed.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 300
    And   c.height = 60
    And   ppm_pixel(p6, 24, 30) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 155, 30) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 191, 30) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 5, 5) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 19
    Given c ← plate_19()
    And   ref ← read_file("reference/chapter-19/plate-19.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 540
    And   c.height = 210
    And   ppm_pixel(p6, 24, 165) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 75, 165) = (237, 124, 196) ± 1
    And   ppm_pixel(p6, 296, 165) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 345, 165) = (237, 124, 196) ± 1
    And   ppm_pixel(p6, 5, 5) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
