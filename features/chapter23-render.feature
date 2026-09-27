Feature: Rendering a field
  A field is a width, a height and one number per pixel, row by row.
  field(width, height, fn) samples fn at every pixel center, point(x +
  0.5, y + 0.5); field_of(width, height, values) makes one from a list;
  field_at(f, x, y) reads one, and field_range(f) is (least, greatest).
  field_coverage(f) is chapter 2's coverage buffer with clamp(0.5 - d,
  0, 1) at each pixel: a pixel whose center is on the edge is half
  covered, and the coverage ramps to 0 and 1 over one pixel either side.
  polygon_field(p, rule, width, height) is the field of sd_polygon.
  coverage_error(cov, exact) is a coverage buffer of |cov - exact| at
  each pixel. simplify is chapter 22's.

  Scenario: A field is sampled at pixel centers
    Given f ← circle_field(8, 8, 3, 16, 16)
    Then  field_at(f, 8, 8) = -2.292893
    And   field_at(f, 11, 8) = 0.535534
    And   coverage_at(field_coverage(f), 8, 8) = 1
    And   coverage_at(field_coverage(f), 11, 8) = 0

  Scenario: Along an edge that runs with the pixels, the field is exact
    Given box ← polygon(point(10.3, 12.7), point(50.6, 12.7), point(50.6, 40.2), point(10.3, 40.2))
    When  cov ← field_coverage(polygon_field(box, "nonzero", 64, 64))
    And   exact ← fill_path(box, "nonzero", 64, 64)
    Then  coverage_at(cov, 10, 25) = 0.7
    And   coverage_at(exact, 10, 25) = 0.7
    And   coverage_at(cov, 10, 12) = 0.3
    And   coverage_at(exact, 10, 12) = 0.21
    And   max_coverage_difference(cov, exact) = 0.12

  Scenario: Along a slanted edge it's a little off
    Given d ← polygon(point(74.37, 40.21), point(40.37, 74.21), point(6.37, 40.21), point(40.37, 6.21))
    When  cov ← field_coverage(polygon_field(d, "nonzero", 80, 80))
    And   exact ← fill_path(d, "nonzero", 80, 80)
    Then  coverage_at(cov, 71, 43) = 0.203015
    And   coverage_at(exact, 71, 43) = 0.1682

  Scenario: At the star's points it's a long way off, and inside it's wrong until the path is simplified
    Given exact ← fill_path(star(), "nonzero", 160, 160)
    When  raw ← coverage_error(field_coverage(polygon_field(star(), "nonzero", 160, 160)), exact)
    And   clean ← coverage_error(field_coverage(polygon_field(simplify(star(), "nonzero"), "nonzero", 160, 160)), exact)
    Then  max_coverage_difference(field_coverage(polygon_field(star(), "nonzero", 160, 160)), exact) = 0.491037
    And   ink(raw) = 44.800368
    And   ink(clean) = 9.808571
    And   coverage_at(raw, 80, 80) = 0
    And   coverage_at(raw, 80, 58) = 0.131190
    And   coverage_at(clean, 80, 58) = 0
