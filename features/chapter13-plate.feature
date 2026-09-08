Feature: Plate 13
  joins_plate() strokes a chevron three ways — miter, round, bevel — each the
  outline in magenta over the gray fill of it; plate_13() is it magnified.
  caps_demo() strokes one horizontal segment with butt, round and square caps.

  Scenario: The three joins
    Given c ← joins_plate()
    And   ref ← read_file("reference/chapter-13/joins.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 480
    And   c.height = 160
    And   ppm_pixel(p6, 55, 80) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 80, 128) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 5, 150) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 13
    Given c ← plate_13()
    And   ref ← read_file("reference/chapter-13/plate-13.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 960
    And   c.height = 320
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The three caps
    Given c ← caps_demo()
    And   ref ← read_file("reference/chapter-13/caps.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 480
    And   c.height = 80
    And   ppm_pixel(p6, 80, 40) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 240, 40) = (206, 206, 212) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
