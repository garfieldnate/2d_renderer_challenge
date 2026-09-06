Feature: The sweep
  fill_path_aliased(p, rule, w, h) is the scanline fill: it sweeps the rows
  from top to bottom keeping the list of edges that span the current row's
  sample height, sorts their crossings, and fills the spans. Its result is
  a coverage buffer of 0s and 1s, and it is exactly the buffer chapter 5's
  rasterize_centers(filled(p, rule), w, h) produces.
  max_coverage_difference(a, b) is the largest difference between
  corresponding entries of two coverage buffers, and 1 when their sizes
  differ. transform_path(p, m) takes every point of every subpath through m.

  Scenario: Two buffers that differ
    Given a ← coverage_buffer(3, 3)
    And   b ← coverage_buffer(3, 3)
    When  set_coverage(a, 1, 1, 1)
    And   set_coverage(b, 1, 1, 0.25)
    Then  max_coverage_difference(a, b) = 0.75
    And   max_coverage_difference(a, a) = 0

  Scenario: Buffers of different sizes are as different as it gets
    Given a ← coverage_buffer(3, 3)
    And   b ← coverage_buffer(3, 4)
    Then  max_coverage_difference(a, b) = 1

  Scenario: A rectangle
    Given p ← polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6))
    When  cov ← fill_path_aliased(p, "nonzero", 8, 8)
    Then  coverage_at(cov, 2, 2) = 1
    And   coverage_at(cov, 5, 5) = 1
    And   coverage_at(cov, 6, 5) = 0
    And   coverage_at(cov, 5, 6) = 0
    And   coverage_at(cov, 1, 2) = 0
    And   ink(cov) = 16
    And   max_coverage_difference(cov, rasterize_centers(filled(p, "nonzero"), 8, 8)) = 0

  Scenario: A triangle
    Given p ← polygon(point(0, 0), point(10, 0), point(5, 10))
    When  cov ← fill_path_aliased(p, "nonzero", 20, 20)
    Then  coverage_at(cov, 0, 0) = 1
    And   coverage_at(cov, 9, 0) = 1
    And   coverage_at(cov, 10, 0) = 0
    And   coverage_at(cov, 4, 8) = 1
    And   coverage_at(cov, 3, 8) = 0
    And   coverage_at(cov, 5, 9) = 0
    And   ink(cov) = 50
    And   max_coverage_difference(cov, rasterize_centers(filled(p, "nonzero"), 20, 20)) = 0

  Scenario: The same triangle drawn the other way round
    Given a ← polygon(point(0, 0), point(10, 0), point(5, 10))
    And   b ← polygon(point(0, 0), point(5, 10), point(10, 0))
    When  ca ← fill_path_aliased(a, "nonzero", 20, 20)
    And   cb ← fill_path_aliased(b, "nonzero", 20, 20)
    Then  max_coverage_difference(ca, cb) = 0

  Scenario: A polygon circle
    Given p ← circle_path(10.3, 9.7, 7, 12)
    When  cov ← fill_path_aliased(p, "nonzero", 20, 20)
    Then  ink(cov) = 145
    And   max_coverage_difference(cov, rasterize_centers(filled(p, "nonzero"), 20, 20)) = 0

  Scenario: The star, both rules, matches chapter 5 pixel for pixel
    Given p ← star()
    When  nz ← fill_path_aliased(p, "nonzero", 160, 160)
    And   eo ← fill_path_aliased(p, "evenodd", 160, 160)
    Then  ink(nz) = 5480
    And   ink(eo) = 3780
    And   coverage_at(nz, 80, 80) = 1
    And   coverage_at(eo, 80, 80) = 0
    And   max_coverage_difference(nz, rasterize_centers(filled(p, "nonzero"), 160, 160)) = 0
    And   max_coverage_difference(eo, rasterize_centers(filled(p, "evenodd"), 160, 160)) = 0

  Scenario: An edge that starts on a sample height is active there, and one that ends there is not
    Given p ← polygon(point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5))
    When  cov ← fill_path_aliased(p, "nonzero", 8, 8)
    Then  coverage_at(cov, 2, 1) = 0
    And   coverage_at(cov, 2, 2) = 1
    And   coverage_at(cov, 2, 4) = 1
    And   coverage_at(cov, 2, 5) = 0
    And   coverage_at(cov, 1, 3) = 1
    And   coverage_at(cov, 4, 3) = 0
    And   ink(cov) = 9
    And   max_coverage_difference(cov, rasterize_centers(filled(p, "nonzero"), 8, 8)) = 0

  Scenario: A bow tie has four crossings on a row, and they must be sorted
    Given p ← polygon(point(1, 1), point(15, 6), point(15, 1), point(1, 6))
    When  cov ← fill_path_aliased(p, "nonzero", 16, 8)
    Then  spans(p, "nonzero", 2) = [(1, 5.2), (10.8, 15)]
    And   spans(p, "evenodd", 2) = [(1, 5.2), (10.8, 15)]
    And   coverage_at(cov, 4, 2) = 1
    And   coverage_at(cov, 5, 2) = 0
    And   coverage_at(cov, 10, 2) = 0
    And   coverage_at(cov, 11, 2) = 1
    And   ink(cov) = 34
    And   max_coverage_difference(cov, rasterize_centers(filled(p, "nonzero"), 16, 8)) = 0

  Scenario: A polygon larger than the buffer fills it
    Given p ← polygon(point(-5, -5), point(30, -5), point(30, 30), point(-5, 30))
    When  cov ← fill_path_aliased(p, "nonzero", 8, 8)
    Then  ink(cov) = 64

  Scenario: An empty path fills nothing
    Given p ← path()
    When  cov ← fill_path_aliased(p, "nonzero", 8, 8)
    Then  ink(cov) = 0

  Scenario: transform_path takes every point through the matrix and keeps the flags
    Given p ← polygon(point(1.25, 2), point(4.75, 2), point(4.75, 5), point(1.25, 5))
    When  q ← transform_path(p, translation(10, 20))
    Then  length(subpaths(q)) = 1
    And   subpaths(q)[0].closed = true
    And   subpaths(q)[0].points[0] = point(11.25, 22)
    And   subpaths(q)[0].points[2] = point(14.75, 25)
    And   subpaths(p)[0].points[0] = point(1.25, 2)

  Scenario: A transformed star fills where the transform put it
    Given p ← transform_path(star(), translation(10, 10) * scaling(0.11, 0.11) * translation(-80.5, -80.5))
    When  nz ← fill_path_aliased(p, "nonzero", 20, 20)
    And   eo ← fill_path_aliased(p, "evenodd", 20, 20)
    Then  bounds(p) = (2.6769, 2.3, 17.3231, 16.2294)
    And   ink(nz) = 60
    And   ink(eo) = 40
    And   max_coverage_difference(nz, rasterize_centers(filled(p, "nonzero"), 20, 20)) = 0
