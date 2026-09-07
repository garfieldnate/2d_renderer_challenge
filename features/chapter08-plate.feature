Feature: Plate 8
  The renders of chapter 8. drops() fills the same teardrop twice, flattened
  coarse on the left and fine on the right, so the facets show. flower() sets
  three flowers of curved petals at three sizes, every petal flattened in
  device space at one tolerance so the big flower is as smooth as the small
  one, with a disc punched out of each center. plate_08() is the flowers,
  magnified.

  Scenario: The teardrop, coarse against fine
    Given c ← drops()
    And   ref ← read_file("reference/chapter-08/drops.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 480
    And   c.height = 240
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The flowers
    Given c ← flower()
    And   ref ← read_file("reference/chapter-08/flower.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 360
    And   c.height = 360
    And   ppm_pixel(p6, 200, 105) = (124, 196, 237) ± 1
    And   ppm_pixel(p6, 200, 145) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 108, 212) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 108, 250) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 286, 214) = (237, 137, 149) ± 1
    And   ppm_pixel(p6, 10, 10) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 8
    Given c ← plate_08()
    And   ref ← read_file("reference/chapter-08/plate-08.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 720
    And   c.height = 720
    And   ppm_pixel(p6, 400, 210) = (124, 196, 237) ± 1
    And   ppm_pixel(p6, 216, 424) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 572, 428) = (237, 137, 149) ± 1
    And   ppm_pixel(p6, 20, 20) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
