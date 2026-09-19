Feature: Plate 15
  even_marks() draws lopsided() twice with eleven marks: at equal steps of
  the parameter on the left, at equal steps of arc length on the right.
  dash_strip() strokes one wave four ways: solid, 12 on 6 off, the same at
  phase 9, and dots (0 on 9 off with round caps). golden_spiral() is seven
  quarter circles, each phi times the radius of the last, flattened into one
  open subpath; spiral_dashes() dashes it 16 on 10 off and strokes every
  dash 7 wide with round caps; plate_15() is it magnified. dash_count(p,
  pattern, phase) is the number of subpaths dash returns.

  Scenario: Marks by parameter and by length
    Given c ← even_marks()
    And   ref ← read_file("reference/chapter-15/even-marks.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 400
    And   c.height = 120
    And   ppm_pixel(p6, 71, 58) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 298, 52) = (124, 196, 237) ± 1
    And   ppm_pixel(p6, 100, 100) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The strip
    Given c ← dash_strip()
    And   ref ← read_file("reference/chapter-15/dash-strip.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 160
    And   ppm_pixel(p6, 160, 20) = (206, 206, 212) ± 1
    And   ppm_pixel(p6, 20, 140) = (237, 137, 149) ± 1
    And   ppm_pixel(p6, 24, 140) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The spiral is one subpath, and it dashes into seventeen
    Given sp ← golden_spiral()
    Then  length(subpaths(sp)) = 1
    And   path_length(sp) = 427.493 ± 0.01
    And   dash_count(sp, [16, 10], 0) = 17
    And   subpaths(dash(sp, [16, 10], 0))[0].points[0] = point(142, 130)
    And   path_length(dash(sp, [16, 10], 0)) = 267.493 ± 0.01

  Scenario: The spiral, dashed
    Given c ← spiral_dashes()
    And   ref ← read_file("reference/chapter-15/spiral-dashes.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 340
    And   c.height = 340
    And   ppm_pixel(p6, 142, 130) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 157, 138) = (124, 196, 237) ± 1
    And   ppm_pixel(p6, 20, 20) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 15
    Given c ← plate_15()
    And   ref ← read_file("reference/chapter-15/plate-15.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 680
    And   c.height = 680
    And   max_channel_difference(p6, ref) ≤ 1
