Feature: Plate 12
  opacity_plate() draws three overlapping circles two ways: on the left each
  circle is painted at half opacity in turn, so the overlaps composite twice
  and darken; on the right the three are drawn opaque into a group and the whole
  group is composited at half opacity, so the overlaps match the rest.
  plate_12() is it magnified. clip_demo() clips a star to a circle and to a soft
  radial mask.

  Scenario: A single circle looks the same either way, but the overlap does not
    Given c ← opacity_plate()
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 300
    And   c.height = 150
    And   ppm_pixel(p6, 40, 62) = (185, 145, 71) ± 1
    And   ppm_pixel(p6, 190, 62) = (185, 145, 71) ± 1
    And   ppm_pixel(p6, 75, 72) = (203, 156, 165) ± 1
    And   ppm_pixel(p6, 225, 72) = (176, 103, 112) ± 1
    And   ppm_pixel(p6, 5, 5) = (39, 39, 44) ± 1

  Scenario: The opacity plate
    Given c ← opacity_plate()
    And   ref ← read_file("reference/chapter-12/opacity.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 12
    Given c ← plate_12()
    And   ref ← read_file("reference/chapter-12/plate-12.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 600
    And   c.height = 300
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The clip demo, hard against soft
    Given c ← clip_demo()
    And   ref ← read_file("reference/chapter-12/clip-demo.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 300
    And   c.height = 150
    And   ppm_pixel(p6, 225, 45) = (197, 155, 74) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
