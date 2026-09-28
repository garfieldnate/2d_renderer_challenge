Feature: Sampling instead of area
  sample_pattern(n) is n sample points inside the unit pixel: for 1,
  (0.5, 0.5); for 4, the rotated grid (0.375, 0.125), (0.875, 0.375),
  (0.125, 0.625), (0.625, 0.875); for 16, sample k from 0 to 15 at ((k +
  0.5) / 16, (((5k + 3) mod 16) + 0.5) / 16), sixteen rooks with no two
  on a row or a column; for 64, chapter 2's 8 by 8 grid, ((i + 0.5) / 8,
  (j + 0.5) / 8), j the outer loop. msaa_coverage(p, rule, width,
  height, n) is, at every pixel, the number of samples whose stencil
  (stencil_buffer with that sample's ox, oy) fills under the rule,
  divided by n. sliver() is polygon(point(2, 10.3), point(78, 12.2),
  point(78, 30), point(2, 30)), whose top edge climbs one pixel in forty.

  Scenario: The patterns
    Then  length(sample_pattern(16)) = 16
    And   sample_pattern(16)[0] = point(0.03125, 0.21875)
    And   sample_pattern(16)[1] = point(0.09375, 0.53125)
    And   sample_pattern(4)[2] = point(0.125, 0.625)
    And   length(sample_pattern(64)) = 64

  Scenario: More samples come closer to chapter 7, and how they're placed matters as much as how many
    Given exact ← fill_path(sliver(), "nonzero", 80, 40)
    Then  max_coverage_difference(msaa_coverage(sliver(), "nonzero", 80, 40, 1), exact) = 0.4875
    And   max_coverage_difference(msaa_coverage(sliver(), "nonzero", 80, 40, 4), exact) = 0.1125
    And   max_coverage_difference(msaa_coverage(sliver(), "nonzero", 80, 40, 16), exact) = 0.0375
    And   max_coverage_difference(msaa_coverage(sliver(), "nonzero", 80, 40, 64), exact) = 0.0375
