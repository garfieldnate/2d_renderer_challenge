Feature: Arabic: joining, and the positional forms
  An Arabic letter has up to four shapes, and which one you draw depends
  on its neighbours. The font file for this chapter is DejaVu Sans, cut
  down to its Arabic, reference/chapter-19/dejavu-arabic.json, with three
  optional sections the loader from chapter 16 reads when they're there.
  joining is Unicode's joining type per codepoint: "dual" letters join on
  both sides, "right" letters (alef, dal, reh, waw and their kin) join
  only to the letter before them, "none" never joins, and "transparent"
  characters (the vowel marks) are invisible to the letters either side.
  joining_type(font, codepoint) reads it, "none" for a character not
  listed. arabic_forms(font, text) answers each character's form: it joins
  backward when it is dual or right and the nearest non-transparent
  character before it is dual; forward when it is dual and the nearest
  non-transparent character after it is dual or right; both is "medi",
  backward alone "fina", forward alone "init", neither "isol". forms is
  GSUB's init, medi and fina substitutions, forms[glyph][form], and
  apply_forms(font, text, buffer) swaps each glyph for its form's when the
  table has one; a glyph with no entry for its form keeps its name.

  Scenario: The joining types
    Given font ← load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    Then  joining_type(font, 1603) = "dual"
    And   joining_type(font, 1575) = "right"
    And   joining_type(font, 1616) = "transparent"
    And   joining_type(font, 1569) = "none"
    And   joining_type(font, 1600) = "dual"
    And   joining_type(font, 32) = "none"
    And   joining_type(font, 65) = "none"

  Scenario: An Arabic letter selects its form by its neighbours
    Given font ← load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    Then  arabic_forms(font, "ب") = ["isol"]
    And   arabic_forms(font, "بب") = ["init", "fina"]
    And   arabic_forms(font, "ببب") = ["init", "medi", "fina"]
    And   arabic_forms(font, "باب") = ["init", "fina", "isol"]
    And   arabic_forms(font, "ب ب") = ["isol", "isol", "isol"]
    And   arabic_forms(font, "سلام") = ["init", "medi", "fina", "isol"]

  Scenario: A vowel mark is transparent: the letters join across it
    Given font ← load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    Then  arabic_forms(font, "كِتاب") = ["init", "isol", "medi", "fina", "isol"]
    And   arabic_forms(font, "كتاب") = ["init", "medi", "fina", "isol"]

  Scenario: The forms table swaps glyphs, and leaves alone what it has no form for
    Given font ← load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    And   text ← "كِتاب"
    When  b ← apply_forms(font, text, glyph_buffer(font, text))
    Then  b[0].glyph = "kaf.init"
    And   b[1].glyph = "kasra"
    And   b[2].glyph = "teh.medi"
    And   b[3].glyph = "alef.fina"
    And   b[4].glyph = "beh"
    And   b[4].cluster = 4
    And   font.forms["kaf"]["medi"] = "kaf.medi"
    And   font.forms["alef"]["fina"] = "alef.fina"
    And   glyph_advance(font, "kaf") = 1688
    And   glyph_advance(font, "kaf.init") = 975

  Scenario: Lam and alef ligate after their forms are chosen
    Given font ← load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    And   text ← "سلام"
    When  b ← apply_ligatures(font, apply_forms(font, text, glyph_buffer(font, text)))
    Then  length(b) = 3
    And   b[0].glyph = "seen.init"
    And   b[1].glyph = "lam_alef.fina"
    And   b[1].cluster = 1
    And   b[2].glyph = "meem"
    And   b[2].cluster = 3
    And   font.ligatures[1] = (("lam.medi", "alef.fina"), "lam_alef.fina")
