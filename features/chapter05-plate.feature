Feature: Plate 5
  One pentagram, filled four ways: under each rule, by the center question
  and by coverage. star() is the path: five points on a circle of radius 70
  about (80.5, 80.5), the first straight up, visited every second one.

  Scenario: The pentagram
    Given p ← star()
    Then  length(subpaths(p)) = 1
    And   length(edges(p)) = 5
    And   subpaths(p)[0].points[0] = point(80.5, 10.5)
    And   subpaths(p)[0].points[1] = point(121.645, 137.1312)
    And   subpaths(p)[0].points[2] = point(13.926, 58.8688)
    And   subpaths(p)[0].points[3] = point(147.074, 58.8688)
    And   subpaths(p)[0].points[4] = point(39.355, 137.1312)
    And   bounds(p) = (13.926, 10.5, 147.074, 137.1312)

  Scenario: The star by the center question
    Given c ← star_centers()
    And   ref ← read_file("reference/chapter-05/star-centers.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 160
    And   ppm_pixel(p6, 80, 80) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 240, 80) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 80, 20) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 240, 20) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 30, 60) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 190, 60) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 80, 120) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 80, 10) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 10, 10) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The star by coverage
    Given c ← star_coverage()
    And   ref ← read_file("reference/chapter-05/star-coverage.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 160
    And   ppm_pixel(p6, 80, 80) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 240, 80) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 80, 20) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 240, 20) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 80, 120) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 80, 10) = (77, 65, 48) ± 1
    And   ppm_pixel(p6, 240, 10) = (77, 65, 48) ± 1
    And   ppm_pixel(p6, 80, 11) = (199, 160, 76) ± 1
    And   ppm_pixel(p6, 14, 58) = (101, 83, 52) ± 1
    And   ppm_pixel(p6, 174, 58) = (101, 83, 52) ± 1
    And   ppm_pixel(p6, 10, 10) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 5
    Given c ← plate_05()
    And   ref ← read_file("reference/chapter-05/plate-05.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 640
    And   c.height = 640
    And   ppm_pixel(p6, 160, 160) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 480, 160) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 160, 480) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 480, 480) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 160, 40) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 480, 360) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 160, 20) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 160, 341) = (77, 65, 48) ± 1
    And   ppm_pixel(p6, 480, 341) = (77, 65, 48) ± 1
    And   ppm_pixel(p6, 348, 437) = (101, 83, 52) ± 1
    And   ppm_pixel(p6, 20, 20) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
