Feature: A line is a thin rectangle
  thick_line(x0, y0, x1, y1, width) is a shape: the rectangle of that width
  centered on the segment from the center of pixel (x0, y0) to the center of
  pixel (x1, y1), with square ends. Four half-planes, and chapter 2's
  rasterizer does the rest.

  Scenario: Inside a thick line
    Given s ← thick_line(0, 0, 4, 0, 1)
    Then  inside(s, 2.5, 0.5) = true
    And   inside(s, 2.5, 1.0) = true
    And   inside(s, 2.5, 1.01) = false
    And   inside(s, 0.5, 0.5) = true
    And   inside(s, 0.4, 0.5) = false
    And   inside(s, 4.5, 0.5) = true
    And   inside(s, 4.6, 0.5) = false

  Scenario: A horizontal thick line covers its row, with half pixels at the ends
    Given s ← thick_line(0, 3, 7, 3, 1)
    When  cov ← rasterize(s, 10, 10)
    Then  coverage_at(cov, 0, 3) = 0.5
    And   coverage_at(cov, 1, 3) = 1
    And   coverage_at(cov, 6, 3) = 1
    And   coverage_at(cov, 7, 3) = 0.5
    And   coverage_at(cov, 8, 3) = 0
    And   coverage_at(cov, 3, 2) = 0
    And   coverage_at(cov, 3, 4) = 0
    And   ink(cov) = 7

  Scenario: An off-axis line runs through pixel centers, not corners
    Given s ← thick_line(2, 2, 11, 5, 1)
    When  cov ← rasterize(s, 16, 10)
    Then  coverage_at(cov, 2, 2) = 0.484375
    And   coverage_at(cov, 11, 5) = 0.484375
    And   coverage_at(cov, 6, 3) = 0.6875
    And   coverage_at(cov, 7, 3) = 0.359375
    And   coverage_at(cov, 2, 1) = 0
    And   ink(cov) = 9.4063

  Scenario Outline: The ink is the length, whatever the angle
    Given s ← thick_line(2, 2, <x1>, <y1>, 1)
    When  cov ← rasterize(s, 20, 20)
    Then  ink(cov) = 10

    Examples:
      | x1 | y1 |
      | 12 | 2  |
      | 10 | 8  |
      | 8  | 10 |
      | 2  | 12 |

  Scenario: Except that the grid is blind along the diagonal
    Given s ← thick_line(2, 2, 9, 9, 1)
    When  cov ← rasterize(s, 20, 20)
    # what the sampler says, exactly
    Then  ink(cov) = 9.7188
    # and how far that is from the true length, 7 * sqrt(2)
    And   ink(cov) = 9.8995 ± 0.25
