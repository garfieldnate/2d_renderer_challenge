Feature: Breaking lines
  break_lines(font, text, size, measure, kerning) breaks a paragraph into
  lines no wider than the measure, greedily: the words are the runs of
  non-space characters, and each word in turn joins the current line if
  the line with it, one space between, has a run_advance no greater than
  the measure; otherwise it starts a new line. A line's width is measured
  with the same kerning the run will be laid out with, so the pair across
  a space counts. A word wider than the measure sits alone on its line and
  overflows. Only spaces are break opportunities.

  Scenario: Greedy breaking at three measures
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   text ← "the quick brown fox jumps over the lazy dog"
    Then  break_lines(font, text, 11, 100, true) = ["the quick brown fox", "jumps over the lazy", "dog"]
    And   break_lines(font, text, 11, 60, true) = ["the quick", "brown fox", "jumps over", "the lazy dog"]
    And   break_lines(font, text, 11, 150, true) = ["the quick brown fox jumps", "over the lazy dog"]
    And   run_advance(font, "the quick brown fox", 11, true) ≤ 100
    And   100 ≤ run_advance(font, "the quick brown fox jumps", 11, true)

  Scenario: A line exactly as wide as the measure fits
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   text ← "the quick brown fox jumps over the lazy dog"
    And   measure ← run_advance(font, "the quick", 11, true)
    Then  measure = 44.521 ± 0.0001
    And   break_lines(font, text, 11, measure, true)[0] = "the quick"
    And   length(break_lines(font, text, 11, measure, true)) = 6
    And   break_lines(font, text, 11, measure - 0.01, true)[0] = "the"
    And   length(break_lines(font, text, 11, measure - 0.01, true)) = 7

  Scenario: A word wider than the measure sits alone and overflows
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  break_lines(font, "a supercalifragilistic word", 11, 40, true) = ["a", "supercalifragilistic", "word"]
    And   40 ≤ run_advance(font, "supercalifragilistic", 11, true)

  Scenario: No text is no lines, and runs of spaces are one break
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  length(break_lines(font, "", 11, 100, true)) = 0
    And   break_lines(font, "  two  spaces ", 11, 100, true) = ["two spaces"]
    And   break_lines(font, "one", 11, 1, true) = ["one"]
