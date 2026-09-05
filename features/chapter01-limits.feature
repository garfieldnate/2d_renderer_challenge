Feature: The edges of the range
  Two small pictures that show what 8 bits and a clamp do to your numbers.

  Scenario: A 256-step ramp
    Given c ← ramp()
    Then  c.width = 256
    And   c.height = 32
    And   pixel_at(c, 0, 0) = color(0, 0, 0)
    And   pixel_at(c, 128, 0) = color(0.5020, 0.5020, 0.5020)
    And   pixel_at(c, 255, 31) = color(1, 1, 1)

  Scenario: Encoding stretches the dark end and squeezes the bright end
    Given c ← ramp()
    When  ppm ← canvas_to_ppm(c)
    Then  line 4 of ppm is "0 0 0 13 13 13 22 22 22 28 28 28 34 34 34 38 38 38 42 42 42 46 46 46"
    And   ppm_pixel(ppm, 75, 0) = (148, 148, 148)
    And   ppm_pixel(ppm, 76, 0) = (148, 148, 148)
    And   ppm_pixel(ppm, 254, 0) = (255, 255, 255)
    And   distinct_values(ppm) = 183
    Given ref ← read_file("reference/chapter-01/ramp.ppm")
    Then  max_channel_difference(ppm, ref) ≤ 1

  Scenario: Clamping changes the color, not only the brightness
    Given c ← clamp_pair()
    Then  c.width = 200
    And   c.height = 100
    And   pixel_at(c, 50, 50) = color(2, 0.5, 0.5)
    And   pixel_at(c, 150, 50) = color(1, 0.25, 0.25)
    When  ppm ← canvas_to_ppm(c)
    Then  ppm_pixel(ppm, 50, 50) = (255, 188, 188)
    And   ppm_pixel(ppm, 150, 50) = (255, 137, 137)
    Given ref ← read_file("reference/chapter-01/clamp-pair.ppm")
    Then  max_channel_difference(ppm, ref) ≤ 1
