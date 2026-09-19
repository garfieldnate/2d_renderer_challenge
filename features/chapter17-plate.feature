Feature: Plate 17
  subpixel_strip() draws l at 11 pixels with its pen at x = 4, 4.25, 4.5
  and 4.75 in four 10 by 14 panels, black on white, magnified eight times.
  smoothing_demo() is a 72 by 42 white canvas: Hamburg at 11 pixels in
  black, pen starting at x = 2, three times: on the baseline y = 11 with
  paint_bitmap linear; on y = 25 with linear = false; on y = 39 with every
  glyph's embolden(font, name, 11, 1/3) bitmap painted linear; each glyph
  at its nearest quarter and the pen stepped by pen_advance; the whole
  magnified four times. lcd_plate() sets ea at 13
  pixels twice, grayscale above and LCD below, magnified six times;
  plate_17() is it magnified again. pen_advance(font, name, size) is a
  glyph's advance in pixels, and draw_text steps the pen by it, each glyph
  at its nearest quarter.

  Scenario: The pen advance in pixels
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  pen_advance(font, "H", 11) = 7.8418 ± 0.0001
    And   pen_advance(font, "space", 11) = 2.7231 ± 0.0001

  Scenario: The same stem at four quarters
    Given c ← subpixel_strip()
    And   ref ← read_file("reference/chapter-17/subpixels.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 112
    And   ppm_pixel(p6, 40, 60) = (114, 114, 114) ± 1
    And   ppm_pixel(p6, 120, 60) = (84, 84, 84) ± 1
    And   ppm_pixel(p6, 280, 60) = (202, 202, 202) ± 1
    And   ppm_pixel(p6, 10, 10) = (255, 255, 255)
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Three ways to smooth
    Given c ← smoothing_demo()
    And   ref ← read_file("reference/chapter-17/smoothing.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 288
    And   c.height = 168
    And   ppm_pixel(p6, 150, 20) = (250, 250, 250) ± 1
    And   ppm_pixel(p6, 150, 76) = (243, 243, 243) ± 1
    And   ppm_pixel(p6, 150, 132) = (174, 174, 174) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Grayscale above, stripes below
    Given c ← lcd_plate()
    And   ref ← read_file("reference/chapter-17/lcd.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 144
    And   c.height = 192
    And   ppm_pixel(p6, 60, 40) = (46, 46, 46) ± 1
    And   ppm_pixel(p6, 60, 136) = (123, 51, 126) ± 1
    And   ppm_pixel(p6, 5, 5) = (255, 255, 255)
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 17
    Given c ← plate_17()
    And   ref ← read_file("reference/chapter-17/plate-17.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 288
    And   c.height = 384
    And   max_channel_difference(p6, ref) ≤ 1
