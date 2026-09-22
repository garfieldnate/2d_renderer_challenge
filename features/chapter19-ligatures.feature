Feature: Ligatures: substitution
  A font's ligatures are rules: these glyphs in a row become that glyph.
  apply_ligatures(font, buffer) walks the buffer from the start; at each
  position it tries the font's rules, longest first, and when the glyphs
  there match a rule's parts it replaces them with the result, which takes
  the first part's cluster, then moves on past the result. The result is
  never fed back into another rule. Roboto's file has two rules, f i to
  f_i and f l to f_l, so office comes out as five glyphs, and the cursor
  can no longer stand between the f and the i.

  Scenario: f + i produces one glyph with a two-character cluster
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  b ← apply_ligatures(font, glyph_buffer(font, "office"))
    Then  length(b) = 5
    And   b[1].glyph = "f"
    And   b[1].cluster = 1
    And   b[2].glyph = "f_i"
    And   b[2].cluster = 2
    And   b[3].glyph = "c"
    And   b[3].cluster = 4
    And   clusters(b) = [0, 1, 2, 4, 5]

  Scenario: The walk is greedy from the left and a result is not fed back in
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  apply_ligatures(font, glyph_buffer(font, "waffle"))[3].glyph = "f_l"
    And   apply_ligatures(font, glyph_buffer(font, "waffle"))[3].cluster = 3
    And   clusters(apply_ligatures(font, glyph_buffer(font, "waffle"))) = [0, 1, 2, 3, 5]
    And   apply_ligatures(font, glyph_buffer(font, "fig"))[0].glyph = "f_i"
    And   apply_ligatures(font, glyph_buffer(font, "fig"))[0].cluster = 0
    And   apply_ligatures(font, glyph_buffer(font, "fig"))[1].cluster = 2
    And   length(apply_ligatures(font, glyph_buffer(font, "off"))) = 3

  Scenario: A ligature is narrower than its parts
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  glyph_advance(font, "f_i") = 1134
    And   glyph_advance(font, "f") + glyph_advance(font, "i") = 1208
