Feature: Kerning
  Some pairs of glyphs sit badly at their advances: the A tucks under the
  T's bar, the V and the A lean apart. The font says how far to pull such
  a pair together, in font units, and kern(font, left, right) reads it:
  0 when the font has no pair, and the order matters. With kerning on,
  layout_run moves the pen by the pair value before placing each glyph
  after the first, and run_advance shrinks by the same amount, so a kerned
  pair is narrower than the sum of its advances by exactly the kern.

  Scenario: The font's kern pairs, in font units
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  kern(font, "T", "A") = -79
    And   kern(font, "A", "V") = -87
    And   kern(font, "A", "T") = -129
    And   kern(font, "V", "E") = 0
    And   kern(font, "H", "a") = 0
    And   kern(font, "space", "T") = -40

  Scenario: A kerned pair is narrower than the unkerned sum by exactly the kern
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  run_advance(font, "Wa", 11, false) = 15.7427 ± 0.0001
    And   run_advance(font, "Wa", 11, true) = 15.5654 ± 0.0001
    And   run_advance(font, "Wa", 11, true) = run_advance(font, "Wa", 11, false) + kern(font, "W", "a") * 11 / 2048
    And   run_advance(font, "Ha", 11, true) = run_advance(font, "Ha", 11, false)

  Scenario: The pen moves by the pair before the second glyph is placed
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  kerned ← layout_run(font, "TAVERN", 64, 12, 70, true)
    And   plain ← layout_run(font, "TAVERN", 64, 12, 70, false)
    Then  kerned[0].x = 12
    And   kerned[1].x = 47.7188 ± 0.0001
    And   kerned[1].x = plain[1].x + kern(font, "T", "A") * 64 / 2048
    And   kerned[2].x = 86.75
    And   kerned[3].x = 127.4688 ± 0.0001
    And   kerned[5].x = 203.25
    And   plain[5].x = 208.4375
    And   run_advance(font, "TAVERN", 64, true) = 236.875
    And   run_advance(font, "TAVERN", 64, false) - run_advance(font, "TAVERN", 64, true) = 5.1875
