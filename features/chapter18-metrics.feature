Feature: Advances, the pen, and the vertical metrics
  A line of text is a pen walking along a baseline. layout_run(font, text,
  size, x, y, kerning) answers one placement per character, in order: the
  glyph's name and where its origin sits, the first at x on the baseline y
  and each next one a glyph advance further along, in fractional pixels.
  Every character is placed, spaces included, and a character the font
  lacks places .notdef. run_advance(font, text, size, kerning) is how far
  the pen moved in all. ascent, descent and line_height turn the font's
  ascender, descender and line gap into pixels; descent is a positive
  number, and line_height is baseline to baseline. Kerning is the subject
  of the next section; these scenarios pass false for it.

  Scenario: The vertical metrics in pixels
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  ascent(font, 16) = 14.8438 ± 0.0001
    And   descent(font, 16) = 3.9063 ± 0.0001
    And   line_height(font, 16) = 18.75
    And   line_height(font, 14) = 16.4063 ± 0.0001
    And   line_height(font, 16) = ascent(font, 16) + descent(font, 16)

  Scenario: A run is one placement per character, each an advance further along
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  run ← layout_run(font, "Ha", 11, 2, 11, false)
    Then  length(run) = 2
    And   run[0].name = "H"
    And   run[0].x = 2
    And   run[0].y = 11
    And   run[1].name = "a"
    And   run[1].x = 2 + pen_advance(font, "H", 11)
    And   run[1].x = 9.8418 ± 0.0001
    And   run[1].y = 11
    And   run_advance(font, "Ha", 11, false) = 13.8252 ± 0.0001
    And   run_advance(font, "Ha", 11, false) = pen_advance(font, "H", 11) + pen_advance(font, "a", 11)

  Scenario: Spaces are placed, and so is a character the font doesn't have
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  run ← layout_run(font, "a☃b", 11, 0, 0, false)
    Then  length(run) = 3
    And   run[1].name = ".notdef"
    And   run[1].x = 5.9834 ± 0.0001
    And   run[2].name = "b"
    And   run[2].x = 10.8604 ± 0.0001
    And   layout_run(font, "a b", 11, 0, 0, false)[1].name = "space"
    And   layout_run(font, "a b", 11, 0, 0, false)[2].x = 5.9834 + pen_advance(font, "space", 11) ± 0.0001
    And   length(layout_run(font, "", 11, 0, 0, false)) = 0
    And   run_advance(font, "", 11, false) = 0

  Scenario: Without kerning the run's advance is the sum of the glyph advances
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  run_advance(font, "TAVERN", 64, false) = 242.0625
    And   layout_run(font, "TAVERN", 64, 12, 70, false)[5].x = 208.4375
