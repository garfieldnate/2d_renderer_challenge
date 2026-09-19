Feature: The font file
  A font arrives as JSON. load_font(text) reads it: units_per_em, ascender,
  descender and line_gap in font units; cmap, codepoint to glyph name; and
  glyphs by name, each with an advance, its contours as lists of [x, y, on]
  points in font units with y up, and its components, each another glyph's
  name with a six-number transform. glyph_name(font, codepoint) looks a
  character up and answers .notdef for one the font lacks; glyph_advance
  and glyph_count read what they say. The book's font is Roboto Regular,
  cut down to 177 glyphs.

  Scenario: The font's vertical metrics
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  font.units_per_em = 2048
    And   font.ascender = 1900
    And   font.descender = -500
    And   font.line_gap = 0
    And   glyph_count(font) = 177

  Scenario: Characters map to glyph names, and a missing one maps to .notdef
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  glyph_name(font, 65) = "A"
    And   glyph_name(font, 233) = "eacute"
    And   glyph_name(font, 64257) = "f_i"
    And   glyph_name(font, 9731) = ".notdef"

  Scenario: Advances are in font units
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  glyph_advance(font, "A") = 1336
    And   glyph_advance(font, "space") = 507
    And   glyph_advance(font, ".notdef") = 908
    And   glyph_advance(font, "i") = 497

  Scenario: A glyph is contours of flagged points
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  g ← font.glyphs["i"]
    Then  length(g.contours) = 2
    And   length(g.contours[0]) = 4
    And   g.contours[0][0] = (341, 0, true)
    And   length(g.contours[1]) = 9
    And   g.contours[1][1] = (141, 1414, false)
    And   length(g.components) = 0
