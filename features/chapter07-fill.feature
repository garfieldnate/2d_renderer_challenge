Feature: The fill
  fill_path(p, rule, w, h) deposits every edge of the path into an accumulator
  and resolves it. It is the fill from chapter 7 on. For a simple polygon its
  total ink is the polygon's exact area, because the coverage it computes is
  exact, not sampled. Where a shape's edges land on the sample grid it agrees
  with chapter 2's supersampler to the bit; everywhere else it agrees with the
  truth, which the supersampler only approaches.

  Scenario: A square whose edges sit on pixel centers
    Given p ← polygon(point(1.5, 1.5), point(5.5, 1.5), point(5.5, 5.5), point(1.5, 5.5))
    When  cov ← fill_path(p, "nonzero", 8, 8)
    Then  coverage_at(cov, 1, 1) = 0.25
    And   coverage_at(cov, 3, 1) = 0.5
    And   coverage_at(cov, 1, 3) = 0.5
    And   coverage_at(cov, 3, 3) = 1.0
    And   coverage_at(cov, 0, 0) = 0
    And   ink(cov) = 16.0
    And   ink(cov) = polygon_area(p)

  Scenario: The ink of a filled polygon is its exact area
    Given r ← polygon(point(1.5, 2), point(4.75, 2), point(4.75, 5), point(1.5, 5))
    And   t ← polygon(point(0, 0), point(10, 0), point(5, 10))
    When  cr ← fill_path(r, "nonzero", 8, 8)
    And   ct ← fill_path(t, "nonzero", 20, 20)
    Then  ink(cr) = 9.75
    And   ink(cr) = polygon_area(r)
    And   coverage_at(cr, 1, 3) = 0.5
    And   coverage_at(cr, 2, 3) = 1.0
    And   coverage_at(cr, 4, 3) = 0.75
    And   ink(ct) = 50.0
    And   ink(ct) = polygon_area(t)

  Scenario: A polygon circle's ink is its exact area, where the supersampler misses
    Given p ← circle_path(10.3, 9.7, 7, 12)
    When  cov ← fill_path(p, "nonzero", 20, 20)
    Then  ink(cov) = polygon_area(p)
    And   ink(cov) = 147.0 ± 0.0001

  Scenario: A scaled shape's ink scales with its area
    Given t ← transform_path(polygon(point(0, 0), point(10, 0), point(5, 10)), scaling(2, 3))
    When  cov ← fill_path(t, "nonzero", 40, 40)
    Then  ink(cov) = 300.0
    And   ink(cov) = polygon_area(t)

  Scenario: On a grid-aligned shape the fill and the supersampler agree exactly
    Given r ← polygon(point(1.5, 2), point(4.75, 2), point(4.75, 5), point(1.5, 5))
    And   t ← polygon(point(0, 0), point(10, 0), point(5, 10))
    Then  max_coverage_difference(fill_path(r, "nonzero", 8, 8), rasterize(filled(r, "nonzero"), 8, 8)) = 0
    And   max_coverage_difference(fill_path(t, "nonzero", 20, 20), rasterize(filled(t, "nonzero"), 20, 20)) = 0

  Scenario: The fill replaces chapter 6's, agreeing on solid pixels and improving the edge
    Given r ← polygon(point(1.5, 2), point(4.75, 2), point(4.75, 5), point(1.5, 5))
    When  exact ← fill_path(r, "nonzero", 8, 8)
    And   aliased ← fill_path_aliased(r, "nonzero", 8, 8)
    Then  coverage_at(exact, 2, 3) = 1.0
    And   coverage_at(aliased, 2, 3) = 1.0
    And   coverage_at(exact, 6, 3) = 0
    And   coverage_at(aliased, 6, 3) = 0
    And   coverage_at(exact, 4, 3) = 0.75
    And   coverage_at(aliased, 4, 3) = 1.0

  Scenario: A doubled square is solid under nonzero and a hole under even-odd
    Given p ← path()
    When  move_to(p, point(1.5, 1.5))
    And   line_to(p, point(5.5, 1.5))
    And   line_to(p, point(5.5, 5.5))
    And   line_to(p, point(1.5, 5.5))
    And   close(p)
    And   move_to(p, point(1.5, 1.5))
    And   line_to(p, point(5.5, 1.5))
    And   line_to(p, point(5.5, 5.5))
    And   line_to(p, point(1.5, 5.5))
    And   close(p)
    And   nz ← fill_path(p, "nonzero", 8, 8)
    And   eo ← fill_path(p, "evenodd", 8, 8)
    Then  coverage_at(nz, 3, 3) = 1.0
    And   coverage_at(eo, 3, 3) = 0

  Scenario: The star, both rules, filled exactly
    Given p ← star()
    When  nz ← fill_path(p, "nonzero", 160, 160)
    And   eo ← fill_path(p, "evenodd", 160, 160)
    Then  coverage_at(nz, 80, 80) = 1.0
    And   coverage_at(eo, 80, 80) = 0
    And   ink(nz) = 5500.7654 ± 0.01
    And   ink(eo) = 3801.1615 ± 0.01
    And   coverage_at(nz, 44, 80) = 0.9456 ± 0.001
    And   coverage_at(nz, 43, 80) = 0.3556 ± 0.001

  Scenario: A polygon larger than the buffer fills it solid
    Given p ← polygon(point(-5, -5), point(30, -5), point(30, 30), point(-5, 30))
    When  cov ← fill_path(p, "nonzero", 8, 8)
    Then  ink(cov) = 64.0

  Scenario: An empty path fills nothing
    Given p ← path()
    When  cov ← fill_path(p, "nonzero", 8, 8)
    Then  ink(cov) = 0
