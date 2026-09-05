Feature: Plate 2
  The same circle on the same grid, asked two different questions, magnified
  so you can see the answers.

  Scenario: The plate
    Given c ← plate_02()
    And   ref ← read_file("reference/chapter-02/plate-02.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 480
    And   c.height = 240
    And   ppm_pixel(p6, 120, 120) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 360, 120) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 93, 27) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 333, 27) = (157, 127, 64) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
