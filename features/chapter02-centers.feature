Feature: The coverage buffer, and the first question
  A coverage buffer is a canvas of numbers instead of colors: for each pixel,
  how much of it the shape covers, from 0 to 1. The first way to fill one is
  to ask whether the pixel's center is inside.

  Scenario: A new coverage buffer is empty
    Given cov ← coverage_buffer(4, 3)
    Then  cov.width = 4
    And   cov.height = 3
    And   coverage_at(cov, 2, 1) = 0
    And   ink(cov) = 0

  Scenario: Setting coverage
    Given cov ← coverage_buffer(4, 3)
    When  set_coverage(cov, 2, 1, 0.75)
    Then  coverage_at(cov, 2, 1) = 0.75
    And   coverage_at(cov, 1, 2) = 0
    And   ink(cov) = 0.75

  Scenario: Setting coverage outside the buffer is ignored
    Given cov ← coverage_buffer(4, 3)
    When  set_coverage(cov, -1, 1, 1)
    And   set_coverage(cov, 4, 1, 1)
    And   set_coverage(cov, 1, 3, 1)
    Then  ink(cov) = 0

  Scenario: The center of pixel (x, y) is (x + 0.5, y + 0.5)
    Given s ← half_plane(2.5, 0, 1, 0)
    And   t ← half_plane(2.6, 0, 1, 0)
    Then  center_inside(s, 2, 4) = 1
    And   center_inside(s, 1, 4) = 0
    And   center_inside(t, 2, 4) = 0

  Scenario: A disc, by asking each center
    Given s ← circle(8, 8, 5)
    When  cov ← rasterize_centers(s, 16, 16)
    Then  cov.width = 16
    And   cov.height = 16
    And   coverage_at(cov, 8, 8) = 1
    And   coverage_at(cov, 3, 8) = 1
    And   coverage_at(cov, 12, 8) = 1
    And   coverage_at(cov, 2, 8) = 0
    And   coverage_at(cov, 13, 8) = 0
    And   coverage_at(cov, 4, 4) = 1
    And   coverage_at(cov, 3, 4) = 0
    And   ink(cov) = 80
