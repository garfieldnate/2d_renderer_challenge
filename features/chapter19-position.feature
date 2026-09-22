Feature: Positioning, in either direction, and where the cursor may stand
  position(font, buffer, size, x, y, direction, kerning) turns a shaped
  buffer into chapter 18's placements, one per entry in the buffer's own
  order. For "ltr" the pen starts at x and walks right, exactly as
  layout_run's does, kern pairs included. For "rtl" the pen starts at x
  plus the buffer's advance and walks left, so the first entry lands at
  the right end and the run still occupies x to x + advance. A mark never
  moves the pen: it is placed at its base's origin plus its offset scaled
  to pixels, dy turned over. buffer_advance(font, buffer, size, kerning)
  is the pen's total movement: every non-mark's advance, plus the kern
  pair between consecutive non-marks. caret_offsets(buffer, length) lists
  the character offsets a cursor may stand at: every cluster start, then
  the text's length. caret_positions(font, buffer, length, size, x,
  direction, kerning) is the x of each, in the same order: the pen where
  each cluster's first glyph is placed, then the pen after the last glyph.
  For rtl the first position is the run's right end and the last is x.

  Scenario: A buffer straight from the cmap positions exactly as layout_run lays it out
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  run ← position(font, glyph_buffer(font, "TAVERN"), 64, 12, 70, "ltr", true)
    Then  length(run) = 6
    And   run[1].name = "A"
    And   run[1].x = layout_run(font, "TAVERN", 64, 12, 70, true)[1].x
    And   run[5].x = 203.25
    And   buffer_advance(font, glyph_buffer(font, "TAVERN"), 64, true) = run_advance(font, "TAVERN", 64, true)

  Scenario: A shaped Latin run is narrower by the ligature
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  b ← shape(font, "office")
    And   run ← position(font, b, 64, 20, 70, "ltr", true)
    Then  buffer_advance(font, b, 64, true) = 161.5625
    And   run_advance(font, "office", 64, true) = 163.875
    And   run[2].name = "f_i"
    And   run[2].x = 78.7188 ± 0.0001
    And   run[4].x = 147.6563 ± 0.0001

  Scenario: Right to left, the first glyph lands at the right end
    Given font ← load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    When  b ← shape(font, "كِتاب")
    And   run ← position(font, b, 64, 20, 64, "rtl", false)
    Then  buffer_advance(font, b, 64, false) = 129.5313 ± 0.0001
    And   run[0].name = "kaf.init"
    And   run[0].x = 119.0625
    And   run[0].y = 64
    And   run[2].name = "teh.medi"
    And   run[2].x = 99.75
    And   run[3].x = 80.25
    And   run[4].name = "beh"
    And   run[4].x = 20
    And   run[0].x + pen_advance(font, "kaf.init", 64) = 20 + buffer_advance(font, b, 64, false)

  Scenario: A mark sits at its base's origin plus its offset, whichever way the pen walks
    Given font ← load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    When  b ← shape(font, "كِتاب")
    And   rtl ← position(font, b, 64, 20, 64, "rtl", false)
    And   ltr ← position(font, b, 64, 20, 64, "ltr", false)
    Then  rtl[1].name = "kasra"
    And   rtl[1].x = 112.4375
    And   rtl[1].y = 68.6875
    And   rtl[1].x = rtl[0].x - 212 * 64 / 2048
    And   ltr[0].x = 20
    And   ltr[1].x = 13.375
    And   ltr[1].y = 68.6875
    And   ltr[2].x = 50.4688 ± 0.0001
    And   ltr[4].x = 89.2813 ± 0.0001

  Scenario: The cursor may stand at cluster boundaries and nowhere else
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  b ← shape(font, "office")
    Then  caret_offsets(b, 6) = [0, 1, 2, 4, 5, 6]
    And   caret_positions(font, b, 6, 64, 20, "ltr", true) = [20, 56.5, 78.7188, 114.1563, 147.6563, 181.5625] ± 0.0001

  Scenario: Cursor positions in a right-to-left run run from right to left
    Given font ← load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    When  b ← shape(font, "كِتاب")
    Then  caret_offsets(b, 5) = [0, 2, 3, 4, 5]
    And   caret_positions(font, b, 5, 64, 20, "rtl", false) = [149.5313, 119.0625, 99.75, 80.25, 20] ± 0.0001
    And   caret_positions(font, b, 5, 64, 20, "rtl", false)[0] = 20 + buffer_advance(font, b, 64, false)

  Scenario: A mark between two glyphs neither moves the pen nor breaks their kern pair
    Given toy ← load_font('{"units_per_em": 1000, "ascender": 800, "descender": -200, "line_gap": 0, "cmap": {"97": "a", "98": "b", "99": "c", "42": "dot"}, "glyphs": {".notdef": {"advance": 500, "contours": [], "components": []}, "a": {"advance": 600, "contours": [], "components": []}, "b": {"advance": 600, "contours": [], "components": []}, "c": {"advance": 600, "contours": [], "components": []}, "a_b": {"advance": 900, "contours": [], "components": []}, "a_b_c": {"advance": 1200, "contours": [], "components": []}, "a_b_a": {"advance": 1500, "contours": [], "components": []}, "dot": {"advance": 0, "contours": [], "components": []}}, "kern": [["a", "b", -100]], "ligatures": [[["a", "b"], "a_b"], [["a", "b", "c"], "a_b_c"], [["a_b", "a"], "a_b_a"]], "marks": {"dot": ["above", 0, 0]}, "anchors": {"a": {"above": [300, 700]}}}')
    When  b ← shape(toy, "a*b")
    And   run ← position(toy, b, 10, 10, 50, "ltr", true)
    Then  length(b) = 3
    And   b[1].glyph = "dot"
    And   b[1].cluster = 0
    And   b[1].dx = 300
    And   b[1].dy = 700
    And   b[2].glyph = "b"
    And   buffer_advance(toy, b, 10, true) = 11
    And   buffer_advance(toy, b, 10, false) = 12
    And   run[1].x = 13
    And   run[1].y = 43
    And   run[2].x = 15
    And   run[2].y = 50
