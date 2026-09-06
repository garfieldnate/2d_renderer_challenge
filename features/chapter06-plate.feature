Feature: Plate 6
  Twenty-four stars along a spiral, each the chapter 5 star shrunk to
  radius 1 about the origin and then scaled, turned and moved by one
  matrix, filled nonzero by the sweep. unit_star() is that star of radius
  1. spiral() is the 320 by 320 picture and plate_06() is it magnified by 2.

  Scenario: The unit star
    Given p ← unit_star()
    Then  length(edges(p)) = 5
    And   subpaths(p)[0].points[0] = point(0, -1)
    And   subpaths(p)[0].points[1] = point(0.5878, 0.809)
    And   subpaths(p)[0].points[2] = point(-0.9511, -0.309)
    And   bounds(p) = (-0.9511, -1, 0.9511, 0.809)

  Scenario: The spiral
    Given c ← spiral()
    And   ref ← read_file("reference/chapter-06/spiral.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 320
    And   ppm_pixel(p6, 180, 160) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 183, 171) = (124, 196, 237) ± 1
    And   ppm_pixel(p6, 179, 183) = (237, 137, 149) ± 1
    And   ppm_pixel(p6, 104, 139) = (237, 137, 149) ± 1
    And   ppm_pixel(p6, 230, 111) = (124, 196, 237) ± 1
    And   ppm_pixel(p6, 32, 137) = (124, 196, 237) ± 1
    And   ppm_pixel(p6, 34, 104) = (237, 137, 149) ± 1
    And   ppm_pixel(p6, 160, 160) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 5, 5) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 300, 20) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 6
    Given c ← plate_06()
    And   ref ← read_file("reference/chapter-06/plate-06.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 640
    And   c.height = 640
    And   ppm_pixel(p6, 360, 320) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 68, 208) = (237, 137, 149) ± 1
    And   ppm_pixel(p6, 320, 320) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
