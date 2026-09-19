Feature: A glyph bitmap, positioned to a quarter pixel
  A pen position is fractional. subpixel_of(x) splits it into a whole pixel
  and one of four quarters, the fraction rounded to the nearest quarter and
  carried into the next pixel when it rounds to four. glyph_bitmap(font,
  name, size, subpixel) renders the glyph with its origin at x = subpixel /
  4 into a coverage buffer of its own: columns floor(xmin) to ceil(xmax) - 1
  of its device bounds shifted by that quarter, rows floor(-ymax) to
  ceil(-ymin) - 1, with left and top saying where the buffer sits relative
  to the pen. The same glyph at a different quarter is a different bitmap
  with exactly the same ink. paint_bitmap(canvas, bitmap, x, y, color,
  linear) composites it with the pen at whole pixel (x, y).

  Scenario: A pen position rounds to the nearest quarter pixel
    Then  subpixel_of(10) = (10, 0)
    And   subpixel_of(10.1) = (10, 0)
    And   subpixel_of(10.3) = (10, 1)
    And   subpixel_of(10.5) = (10, 2)
    And   subpixel_of(10.62) = (10, 2)
    And   subpixel_of(10.9) = (11, 0)
    And   subpixel_of(-0.3) = (-1, 3)

  Scenario: A bitmap is just big enough and knows where it sits
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  b ← glyph_bitmap(font, "l", 11, 0)
    Then  b.width = 2
    And   b.height = 9
    And   b.left = 0
    And   b.top = -9
    And   coverage_at(b.coverage, 0, 5) = 0.1621 ± 0.0001
    And   coverage_at(b.coverage, 1, 5) = 0.8315 ± 0.0001
    And   glyph_bitmap(font, "g", 11, 0).top = -6
    And   glyph_bitmap(font, "g", 11, 0).height = 9
    And   glyph_bitmap(font, "space", 11, 0).width = 0

  Scenario: A quarter to the right moves the ink, not the amount of it
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  b1 ← glyph_bitmap(font, "l", 11, 1)
    And   b3 ← glyph_bitmap(font, "l", 11, 3)
    Then  b1.left = 1
    And   coverage_at(b1.coverage, 0, 5) = 0.9121 ± 0.0001
    And   coverage_at(b1.coverage, 1, 5) = 0.0815 ± 0.0001
    And   coverage_at(b3.coverage, 0, 5) = 0.4121 ± 0.0001
    And   coverage_at(b3.coverage, 1, 5) = 0.5815 ± 0.0001
    And   ink(b1.coverage) = ink(glyph_bitmap(font, "l", 11, 0).coverage)
    And   ink(b3.coverage) = 8.197632 ± 0.0001
    And   ink(glyph_bitmap(font, "H", 11, 1).coverage) = ink(glyph_bitmap(font, "H", 11, 0).coverage)

  Scenario: Painting a bitmap lands it at the pen
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   c ← canvas(10, 14)
    When  fill(c, color(1, 1, 1))
    And   paint_bitmap(c, glyph_bitmap(font, "l", 11, 0), 4, 11, color(0, 0, 0), true)
    Then  pixel_at(c, 5, 6) = color(0.1685, 0.1685, 0.1685)
    And   pixel_at(c, 4, 6) = color(0.8379, 0.8379, 0.8379)
    And   pixel_at(c, 6, 6) = color(1, 1, 1)
    And   pixel_at(c, 5, 11) = color(1, 1, 1)
