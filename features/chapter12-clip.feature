Feature: A clip is a coverage buffer
  Clipping needs no new machinery. A clip is a coverage buffer, and clipping
  one coverage by another is multiply_coverage, cell by cell. clip_rect and
  clip_path build clips as ordinary fills. full_clip is coverage 1 everywhere,
  so clipping to the whole canvas is a no-op; and because multiplication
  commutes, nesting clips in either order gives the same result.

  Scenario: Multiplying two coverage buffers, cell by cell
    Given a ← coverage_buffer(2, 1)
    And   b ← coverage_buffer(2, 1)
    When  set_coverage(a, 0, 0, 0.5)
    And   set_coverage(a, 1, 0, 1.0)
    And   set_coverage(b, 0, 0, 0.5)
    And   set_coverage(b, 1, 0, 0.25)
    When  m ← multiply_coverage(a, b)
    Then  coverage_at(m, 0, 0) = 0.25
    And   coverage_at(m, 1, 0) = 0.25

  Scenario: Clipping to the whole canvas changes nothing
    Given cov ← fill_path(circle_path(6, 6, 4, 32), "nonzero", 12, 12)
    And   full ← full_clip(12, 12)
    Then  max_coverage_difference(multiply_coverage(cov, full), cov) = 0

  Scenario: Nested clips commute
    Given r ← clip_rect(2, 2, 8, 8, 12, 12)
    And   c ← clip_path(circle_path(6, 6, 4, 32), "nonzero", 12, 12)
    Then  max_coverage_difference(multiply_coverage(r, c), multiply_coverage(c, r)) = 0

  Scenario: A clip zeroes the coverage outside it
    Given shape ← fill_path(polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10)), "nonzero", 12, 12)
    And   clip ← clip_rect(2, 2, 6, 6, 12, 12)
    When  clipped ← multiply_coverage(shape, clip)
    Then  coverage_at(clipped, 4, 4) = 1.0
    And   coverage_at(clipped, 8, 8) = 0.0
