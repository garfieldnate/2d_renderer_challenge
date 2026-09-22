Feature: The glyph buffer and its clusters
  Shaping works on a buffer of glyphs, not on the string. glyph_buffer(font,
  text) is the starting point: one entry per character through the cmap,
  each carrying its cluster, the index of the character it came from.
  Every later step keeps the clusters honest: when two characters become
  one glyph the glyph takes the first one's cluster, and when a mark
  attaches to a base it takes the base's. clusters(buffer) lists the
  distinct clusters in order. A cluster boundary is where a cursor may
  stand, and that is the whole reason the buffer carries them.

  Scenario: One entry per character, each its own cluster
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  b ← glyph_buffer(font, "office")
    Then  length(b) = 6
    And   b[0].glyph = "o"
    And   b[0].cluster = 0
    And   b[3].glyph = "i"
    And   b[3].cluster = 3
    And   clusters(b) = [0, 1, 2, 3, 4, 5]
    And   glyph_buffer(font, "a☃")[1].glyph = ".notdef"
    And   length(glyph_buffer(font, "")) = 0
