Feature: Aligning
  layout_line(font, text, size, x, y, measure, align, kerning) lays a line
  out inside a measure that starts at x. The slack is the measure minus
  the line's run_advance. "left" leaves the slack on the right, "right"
  puts it on the left, "center" splits it, and "justify" spreads it over
  the line's spaces, each gap growing by slack / spaces, so the line ends
  exactly at the measure. A line with no space can't be justified and is
  laid out left. layout_paragraph(font, text, size, x, y, measure, align,
  kerning) breaks the text and lays out every line, the first baseline at
  y and each next one line_height below; when the alignment is justify,
  the last line is laid out left. It answers one flat list of placements.

  Scenario: Four alignments of one short line
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  run_advance(font, "to be", 11, true) = 24.4814 ± 0.0001
    And   layout_line(font, "to be", 11, 10, 20, 60, "left", true)[0].x = 10
    And   layout_line(font, "to be", 11, 10, 20, 60, "left", true)[4].x = 28.6538 ± 0.0001
    And   layout_line(font, "to be", 11, 10, 20, 60, "right", true)[0].x = 45.5186 ± 0.0001
    And   layout_line(font, "to be", 11, 10, 20, 60, "right", true)[4].x = 64.1724 ± 0.0001
    And   layout_line(font, "to be", 11, 10, 20, 60, "center", true)[0].x = 27.7593 ± 0.0001
    And   layout_line(font, "to be", 11, 10, 20, 60, "center", true)[4].x = 46.4131 ± 0.0001
    And   layout_line(font, "to be", 11, 10, 20, 60, "right", true)[4].x + pen_advance(font, "e", 11) = 70 ± 0.0001

  Scenario: Justify stretches the spaces, not the letters
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  run ← layout_line(font, "to be", 11, 10, 20, 60, "justify", true)
    Then  run[0].x = 10
    And   run[1].x = 13.4858 ± 0.0001
    And   run[2].name = "space"
    And   run[2].x = 19.7593 ± 0.0001
    And   run[3].x = 58.001 ± 0.0001
    And   run[4].x = 64.1724 ± 0.0001
    And   run[4].x + pen_advance(font, "e", 11) = 70 ± 0.0001
    And   layout_line(font, "to", 11, 10, 20, 60, "justify", true)[1].x = 13.4858 ± 0.0001

  Scenario: A paragraph stacks its lines by line_height and leaves the last line ragged
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  run ← layout_paragraph(font, "the quick brown fox jumps over the lazy dog", 11, 10, 20, 100, "justify", true)
    Then  length(run) = 41
    And   run[0].name = "t"
    And   run[0].x = 10
    And   run[0].y = 20
    And   run[18].name = "x"
    And   run[18].x + pen_advance(font, "x", 11) = 110 ± 0.0001
    And   run[19].name = "j"
    And   run[19].x = 10
    And   run[19].y = 20 + line_height(font, 11)
    And   run[19].y = 32.8906 ± 0.0001
    And   run[38].name = "d"
    And   run[38].x = 10
    And   run[38].y = 45.7813 ± 0.0001
    And   run[40].name = "g"
    And   run[40].x = 22.4771 ± 0.0001

  Scenario: The last line stays left even when it has spaces to stretch
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  run ← layout_paragraph(font, "the quick brown fox jumps over the lazy dog", 11, 10, 20, 150, "justify", true)
    Then  break_lines(font, "the quick brown fox jumps over the lazy dog", 11, 150, true) = ["the quick brown fox jumps", "over the lazy dog"]
    And   length(run) = 42
    And   run[24].name = "s"
    And   run[24].x + pen_advance(font, "s", 11) = 160 ± 0.0001
    And   run[25].name = "o"
    And   run[25].x = 10
    And   run[25].y = 32.8906 ± 0.0001
    And   run[41].name = "g"
    And   run[41].x = 86.436 ± 0.0001
    And   run[41].x + pen_advance(font, "g", 11) = 10 + run_advance(font, "over the lazy dog", 11, true) ± 0.0001
