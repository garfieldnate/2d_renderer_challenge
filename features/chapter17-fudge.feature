Feature: The fudge, named
  Text is the one place physically correct blending looks wrong: black
  text on white composited in linear light comes out thin and pale, so
  every text stack cheats. The book names two cheats. The first is
  chapter 1's switch: paint_bitmap with linear = false blends in encoded
  space, the way browsers and operating systems do. The second is stem
  darkening: embolden(font, name, size, amount) is the glyph's coverage
  with its outline pushed out, the fill plus chapter 13's stroke of the
  outline amount wide, added and clamped to 1, in a bitmap grown a pixel
  all round. Neither is correct. Both are what you are used to seeing.

  Scenario: Encoded-space blending is darker at the same coverage
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   a ← canvas(10, 14)
    And   b ← canvas(10, 14)
    When  fill(a, color(1, 1, 1))
    And   fill(b, color(1, 1, 1))
    And   paint_bitmap(a, glyph_bitmap(font, "l", 11, 0), 4, 11, color(0, 0, 0), true)
    And   paint_bitmap(b, glyph_bitmap(font, "l", 11, 0), 4, 11, color(0, 0, 0), false)
    Then  pixel_at(a, 4, 6) = color(0.8379, 0.8379, 0.8379)
    And   pixel_at(b, 4, 6) = color(0.6701, 0.6701, 0.6701)
    And   pixel_at(a, 5, 6) = color(0.1685, 0.1685, 0.1685)
    And   pixel_at(b, 5, 6) = color(0.0241, 0.0241, 0.0241)

  Scenario: Emboldening adds ink and grows the bitmap by a pixel all round
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  plain ← glyph_bitmap(font, "l", 11, 0)
    And   bold ← embolden(font, "l", 11, 0.333333)
    Then  bold.width = 4
    And   bold.height = 11
    And   bold.left = -1
    And   bold.top = -10
    And   ink(plain.coverage) = 8.197632 ± 0.0001
    And   ink(bold.coverage) = 12.9527 ± 0.001
    And   coverage_at(bold.coverage, 2, 6) = 1
    And   coverage_at(bold.coverage, 1, 6) = 0.4909 ± 0.001
    And   coverage_at(bold.coverage, 0, 6) = 0

  Scenario: More emboldening, more ink
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  ink(embolden(font, "o", 11, 0.5).coverage) = 25.300 ± 0.01
    And   ink(glyph_bitmap(font, "o", 11, 0).coverage) = 14.041 ± 0.01
    And   ink(embolden(font, "o", 11, 0.5).coverage) ≥ ink(embolden(font, "o", 11, 0.25).coverage)
