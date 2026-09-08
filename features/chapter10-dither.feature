Feature: Ordered dithering
  Eight bits per channel can't hold a slow ramp: whole stretches round to the
  same byte and the ramp shows visible steps. Ordered dithering nudges each
  pixel by a threshold from a 4x4 Bayer matrix before rounding down, so a flat
  value that sits between two bytes is split across both in a fine pattern
  instead of snapping to one. dither_threshold(x, y) is that nudge in [0, 1);
  to_byte_dithered and canvas_to_p6_dithered apply it.

  Scenario: The Bayer matrix and its thresholds
    Given b ← BAYER4
    Then  b[0][0] = 0
    And   b[0][1] = 8
    And   b[1][0] = 12
    And   dither_threshold(0, 0) = 0
    And   dither_threshold(1, 0) = 0.5
    And   dither_threshold(0, 1) = 0.75

  Scenario: One light value dithers to the two bytes around it
    Then  to_byte_dithered(0.5, 0, 0) = 187
    And   to_byte_dithered(0.5, 1, 0) = 188
    And   to_byte(0.5) = 188

  Scenario: A flat patch is one byte plain but two dithered
    Given c ← canvas(16, 16)
    When  fill(c, color(0.5, 0.5, 0.5))
    Then  distinct_values(canvas_to_p6(c)) = 1
    And   distinct_values(canvas_to_p6_dithered(c)) = 2
