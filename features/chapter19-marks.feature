Feature: Marks: positioning
  A vowel mark has no width and no place of its own: it rides on the
  letter before it. The file's marks section gives each mark glyph an
  anchor class, "above" or "below", and its own anchor point in font
  units; the anchors section gives each base glyph an anchor per class.
  attach_marks(font, buffer) finds every mark's base, the nearest non-mark
  before it, and sets the mark's offset dx, dy to the base's anchor of the
  mark's class minus the mark's anchor, so the two anchors coincide; the
  mark joins the base's cluster. A mark whose base has no anchor of its
  class, or with no base before it, keeps its cluster at offset (0, 0).
  is_mark(font, name) says whether a glyph is in the marks table. shape(
  font, text) is the pipeline for one run: the buffer, then forms when
  the font has them, then ligatures, then marks when the font has them.
  Roboto has neither forms nor marks, so shaping Latin is ligatures alone.

  Scenario: The anchors, in font units
    Given font ← load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    Then  font.marks["kasra"] = ("below", 512, 0)
    And   font.marks["fatha"] = ("above", 512, 1200)
    And   font.anchors["kaf.init"]["below"] = (300, -150)
    And   font.anchors["kaf.init"]["above"] = (250, 1550)
    And   font.anchors["beh"]["above"] = (900, 1000)
    And   glyph_advance(font, "kasra") = 0
    And   is_mark(font, "kasra") = true
    And   is_mark(font, "kaf") = false

  Scenario: A mark's anchor lands on its base's, and it joins the base's cluster
    Given font ← load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    When  b ← shape(font, "كِتاب")
    Then  length(b) = 5
    And   b[0].glyph = "kaf.init"
    And   b[0].cluster = 0
    And   b[1].glyph = "kasra"
    And   b[1].cluster = 0
    And   b[1].dx = -212
    And   b[1].dy = -150
    And   b[2].glyph = "teh.medi"
    And   b[2].cluster = 2
    And   b[2].dx = 0
    And   clusters(b) = [0, 2, 3, 4]

  Scenario: Two marks on one base both take its anchor; a mark with no base stays put
    Given font ← load_font(read_file("reference/chapter-19/dejavu-arabic.json"))
    When  b ← shape(font, "بَّ")
    Then  length(b) = 3
    And   b[1].glyph = "fatha"
    And   b[1].dx = 388
    And   b[1].dy = -200
    And   b[2].glyph = "shadda"
    And   b[2].dx = 388
    And   b[2].dy = -200
    And   b[2].cluster = 0
    And   shape(font, "ِب")[0].glyph = "kasra"
    And   shape(font, "ِب")[0].cluster = 0
    And   shape(font, "ِب")[0].dx = 0
    And   shape(font, "ِب")[1].cluster = 1

  Scenario: Shaping Latin is ligatures alone
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  b ← shape(font, "office")
    Then  length(b) = 5
    And   b[2].glyph = "f_i"
    And   b[2].cluster = 2
    And   is_mark(font, "f_i") = false
