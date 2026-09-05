Feature: The gray match
  The chapter's opening figure, rendered by you. A checkerboard of black and
  white pixels emits half the light of solid white. Beside it, two solid
  grays: the one at file value 128 and the one at file value 188.

  Scenario: The gray match
    Given c ← gray_match()
    Then  c.width = 300
    And   c.height = 100
    And   pixel_at(c, 0, 0) = color(1, 1, 1)
    And   pixel_at(c, 1, 0) = color(0, 0, 0)
    And   pixel_at(c, 0, 1) = color(0, 0, 0)
    And   pixel_at(c, 1, 1) = color(1, 1, 1)
    And   pixel_at(c, 150, 50) = color(0.2159, 0.2159, 0.2159)
    And   pixel_at(c, 250, 50) = color(0.5, 0.5, 0.5)
    And   exactly 5000 pixels of c are color(1, 1, 1)

  Scenario: The gray match, as a file
    Given c ← gray_match()
    When  ppm ← canvas_to_ppm(c)
    Then  ppm_pixel(ppm, 0, 0) = (255, 255, 255) ± 1
    And   ppm_pixel(ppm, 1, 0) = (0, 0, 0) ± 1
    And   ppm_pixel(ppm, 150, 50) = (128, 128, 128) ± 1
    And   ppm_pixel(ppm, 250, 50) = (188, 188, 188) ± 1
    And   ref ← read_file("reference/chapter-01/gray-match.ppm")
    And   max_channel_difference(ppm, ref) ≤ 1

  Scenario: One pixel in four
    Given c ← quarter_match()
    Then  c.width = 200
    And   c.height = 100
    And   pixel_at(c, 0, 0) = color(1, 1, 1)
    And   pixel_at(c, 1, 0) = color(0, 0, 0)
    And   pixel_at(c, 2, 2) = color(1, 1, 1)
    And   pixel_at(c, 3, 1) = color(1, 1, 1)
    And   pixel_at(c, 150, 50) = color(0.25, 0.25, 0.25)
    And   exactly 2500 pixels of c are color(1, 1, 1)
    When  ppm ← canvas_to_ppm(c)
    Then  ppm_pixel(ppm, 150, 50) = (137, 137, 137) ± 1
    And   ref ← read_file("reference/chapter-01/quarter-match.ppm")
    And   max_channel_difference(ppm, ref) ≤ 1
