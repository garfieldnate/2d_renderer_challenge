Feature: Magnify
  magnify(canvas, k) returns a canvas k times wider and taller, every pixel
  repeated into a k by k block. No smoothing, no averaging.

  Scenario: Every pixel becomes a block
    Given c ← canvas(2, 1)
    When  write_pixel(c, 0, 0, color(1, 0, 0))
    And   write_pixel(c, 1, 0, color(0, 0.5, 0))
    And   m ← magnify(c, 3)
    Then  m.width = 6
    And   m.height = 3
    And   pixel_at(m, 0, 0) = color(1, 0, 0)
    And   pixel_at(m, 2, 2) = color(1, 0, 0)
    And   pixel_at(m, 3, 0) = color(0, 0.5, 0)
    And   pixel_at(m, 5, 2) = color(0, 0.5, 0)
    And   exactly 9 pixels of m are color(1, 0, 0)

  Scenario: Magnifying by one changes nothing
    Given c ← canvas(2, 1)
    When  write_pixel(c, 1, 0, color(0, 0.5, 0))
    And   m ← magnify(c, 1)
    Then  max_channel_difference(canvas_to_p6(c), canvas_to_p6(m)) = 0
