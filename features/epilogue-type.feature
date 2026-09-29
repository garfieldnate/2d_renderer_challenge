Feature: The cover's type
  The title is chapter 18's layout_paragraph of "The 2D Renderer Challenge"
  in Roboto at 44 pixels to the em, from (40, 530), 400 wide, aligned
  "left", kerning on. The subtitle is layout_run of "A test-driven guide to
  drawing every pixel yourself" at 15 pixels from (40, 640), kerning on.

  Scenario: The title breaks after "Renderer"
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  break_lines(font, "The 2D Renderer Challenge", 44, 400, true) = ["The 2D Renderer", "Challenge"]
    And   run_advance(font, "The 2D Renderer", 44, true) = 324.628906
    And   run_advance(font, "The 2D Renderer Challenge", 44, true) = 529.267578
    And   line_height(font, 44) = 51.5625

  Scenario: The second line starts at the margin, one line height down, and the space it broke at isn't placed
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  title ← layout_paragraph(font, "The 2D Renderer Challenge", 44, 40, 530, 400, "left", true)
    Then  length(title) = 24
    And   title[14].name = "r"
    And   title[14].x = 349.740234
    And   title[14].y = 530
    And   title[15].name = "C"
    And   title[15].x = 40
    And   title[15].y = 581.5625

  Scenario: The subtitle fits on one line
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  sub ← layout_run(font, "A test-driven guide to drawing every pixel yourself", 15, 40, 640, true)
    Then  length(sub) = 51
    And   run_advance(font, "A test-driven guide to drawing every pixel yourself", 15, true) = 328.630371
