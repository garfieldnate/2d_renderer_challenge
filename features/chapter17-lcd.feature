Feature: LCD: three coverages per pixel
  A pixel on an LCD is three stripes, red, green and blue, side by side.
  lcd_coverage(font, name, size, x, y, w, h) rasterizes the glyph three
  times wider, one coverage per stripe, into a buffer 3 w wide and h tall,
  and runs lcd_filter along every row: each value replaced by the average
  of itself and its two neighbours, zeros beyond the ends, the three taps
  summing to one so ink is spread across neighbouring stripes but never
  lost. paint_lcd(canvas, cov3, color) composites it, red through the first
  stripe of each pixel, green the second, blue the third, each channel
  mixed on its own.

  Scenario: The filter's taps sum to one and spread a spike over three stripes
    Then  LCD_TAPS = (0.333333, 0.333333, 0.333333)
    And   lcd_filter([0, 0, 3, 0, 0]) = [0, 1, 1, 1, 0]
    And   lcd_filter([1, 1, 1]) = [0.666667, 1, 0.666667]
    And   lcd_filter([6]) = [2]
    And   length(lcd_filter([])) = 0

  Scenario: Three coverages per pixel carry three times the ink
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  cov3 ← lcd_coverage(font, "l", 11, 4, 11, 10, 14)
    And   gray ← fill_path(glyph_path(font, "l", text_matrix(font, 11, 4, 11), 0.1), "nonzero", 10, 14)
    Then  cov3.width = 30
    And   cov3.height = 14
    And   ink(cov3) = 24.592896 ± 0.0001
    And   ink(gray) = 8.197632 ± 0.0001
    And   coverage_at(gray, 4, 5) = 0.1621 ± 0.0001
    And   coverage_at(gray, 5, 5) = 0.8315 ± 0.0001
    And   coverage_at(cov3, 13, 5) = 0.1621 ± 0.0001
    And   coverage_at(cov3, 14, 5) = 0.4954 ± 0.0001
    And   coverage_at(cov3, 15, 5) = 0.8288 ± 0.0001
    And   coverage_at(cov3, 16, 5) = 0.8315 ± 0.0001
    And   coverage_at(cov3, 17, 5) = 0.4982 ± 0.0001
    And   coverage_at(cov3, 18, 5) = 0.1649 ± 0.0001
    And   coverage_at(cov3, 12, 5) = 0

  Scenario: Each channel takes its own stripe
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   c ← canvas(10, 14)
    When  fill(c, color(1, 1, 1))
    And   paint_lcd(c, lcd_coverage(font, "l", 11, 4, 11, 10, 14), color(0, 0, 0))
    Then  pixel_at(c, 4, 5) = color(1, 0.8379, 0.5046) ± 0.0001
    And   pixel_at(c, 5, 5) = color(0.1712, 0.1685, 0.5018) ± 0.0001
    And   pixel_at(c, 6, 5) = color(0.8351, 1, 1) ± 0.0001
    And   pixel_at(c, 8, 5) = color(1, 1, 1)
