Feature: The better question
  How much of this pixel is inside the shape? Answered by brute force: an
  8 by 8 grid of sample points, one at the center of each cell of the pixel,
  and count.

  Scenario: The sixty-four sample points
    Given s ← half_plane(2.5, 0, 1, 0)
    Then  coverage(s, 2, 4) = 0.5
    And   coverage(s, 1, 4) = 0
    And   coverage(s, 3, 4) = 1

  Scenario: A rectangle is covered exactly, when its edges land on sample boundaries
    Given s ← rectangle(1.25, 2.0, 4.75, 5.0)
    When  cov ← rasterize(s, 8, 8)
    Then  coverage_at(cov, 0, 2) = 0
    And   coverage_at(cov, 1, 2) = 0.75
    And   coverage_at(cov, 2, 2) = 1
    And   coverage_at(cov, 3, 2) = 1
    And   coverage_at(cov, 4, 2) = 0.75
    And   coverage_at(cov, 5, 2) = 0
    And   coverage_at(cov, 2, 1) = 0
    And   coverage_at(cov, 2, 5) = 0
    And   ink(cov) = 10.5

  Scenario: A half-plane through a pixel center covers half of it
    Given s ← half_plane(2.5, 4.5, 0.6, 0.8)
    Then  coverage(s, 2, 4) = 0.5

  Scenario: Except when the grid conspires
    Given s ← half_plane(2.5, 4.5, 1, 1)
    Then  coverage(s, 2, 4) = 0.5625

  Scenario: A disc is only ever approximately covered
    Given s ← circle(8, 8, 5)
    When  cov ← rasterize(s, 16, 16)
    Then  coverage_at(cov, 8, 8) = 1
    And   coverage_at(cov, 3, 8) = 0.96875
    And   coverage_at(cov, 12, 8) = 0.96875
    And   coverage_at(cov, 4, 4) = 0.5625
    And   coverage_at(cov, 3, 4) = 0
    And   ink(cov) = 78.5
    And   ink(cov) = 78.5398 ± 0.1

  Scenario: The disc by coverage
    Given c ← disc_coverage()
    And   ref ← read_file("reference/chapter-02/disc-coverage.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 320
    And   ppm_pixel(p6, 160, 160) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 124, 36) = (157, 127, 64) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
