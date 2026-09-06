Feature: Crossings on a row, and spans
  crossings_on_row(table, y) lists (x, direction) for every edge of the
  table that spans height y under the half-open rule y_top ≤ y < y_bottom,
  sorted by x. spans_from_crossings(xs, rule) walks them left to right,
  accumulating the winding number, and returns the maximal intervals where
  the rule says inside. spans(p, rule, row) does both for pixel row `row`,
  sampled at height row + 0.5. fill_span(cov, row, x0, x1) sets every pixel
  of the row whose center lies in [x0, x1) to 1.

  Scenario: Crossings on a row, sorted by x
    Given p ← polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6))
    When  xs ← crossings_on_row(edge_table(p), 3.5)
    Then  xs = [(2, -1), (6, 1)]
    And   crossings_on_row(edge_table(p), 1.5) = []
    And   crossings_on_row(edge_table(p), 6) = []
    And   length(crossings_on_row(edge_table(p), 2)) = 2

  Scenario: The star's crossings through its middle
    Given p ← star()
    When  xs ← crossings_on_row(edge_table(p), 80.5)
    Then  length(xs) = 4
    And   xs[0] = (43.6988, -1)
    And   xs[1] = (57.7556, -1)
    And   xs[2] = (103.2444, 1)
    And   xs[3] = (117.3012, 1)

  Scenario: Spans from crossings under each rule
    Given xs ← [(1, 1), (3, 1), (5, -1), (7, -1)]
    Then  spans_from_crossings(xs, "nonzero") = [(1, 7)]
    And   spans_from_crossings(xs, "evenodd") = [(1, 3), (5, 7)]
    And   spans_from_crossings([], "nonzero") = []

  Scenario: The spans of an axis-aligned rectangle are exact
    Given p ← polygon(point(1.25, 2), point(4.75, 2), point(4.75, 5), point(1.25, 5))
    Then  spans(p, "nonzero", 1) = []
    And   spans(p, "nonzero", 2) = [(1.25, 4.75)]
    And   spans(p, "nonzero", 4) = [(1.25, 4.75)]
    And   spans(p, "nonzero", 5) = []

  Scenario: A rectangle whose edges sit on sample heights
    Given p ← polygon(point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5))
    Then  spans(p, "nonzero", 1) = []
    And   spans(p, "nonzero", 2) = [(1.5, 4.5)]
    And   spans(p, "nonzero", 4) = [(1.5, 4.5)]
    And   spans(p, "nonzero", 5) = []

  Scenario Outline: A triangle's spans narrow by one per row
    Given p ← polygon(point(0, 0), point(10, 0), point(5, 10))
    Then  spans(p, "nonzero", <row>) = [(<x0>, <x1>)]

    Examples:
      | row | x0   | x1   |
      | 0   | 0.25 | 9.75 |
      | 1   | 0.75 | 9.25 |
      | 4   | 2.25 | 7.75 |
      | 9   | 4.75 | 5.25 |

  Scenario: The row past the triangle's apex has no span
    Given p ← polygon(point(0, 0), point(10, 0), point(5, 10))
    Then  spans(p, "nonzero", 10) = []

  Scenario: A flat top is not a span of its own
    Given p ← polygon(point(0, 0), point(10, 0), point(10, 5), point(0, 5))
    Then  length(edge_table(p)) = 2
    And   spans(p, "nonzero", 0) = [(0, 10)]
    And   spans(p, "nonzero", 4) = [(0, 10)]
    And   spans(p, "nonzero", 5) = []

  Scenario: A ring is two spans under even-odd and one under nonzero
    Given p ← path()
    When  move_to(p, point(0, 0))
    And   line_to(p, point(10, 0))
    And   line_to(p, point(10, 10))
    And   line_to(p, point(0, 10))
    And   close(p)
    And   move_to(p, point(3, 3))
    And   line_to(p, point(7, 3))
    And   line_to(p, point(7, 7))
    And   line_to(p, point(3, 7))
    And   close(p)
    Then  spans(p, "nonzero", 5) = [(0, 10)]
    And   spans(p, "evenodd", 5) = [(0, 3), (7, 10)]

  Scenario: The star's spans through its middle
    Given p ← star()
    Then  spans(p, "nonzero", 80) = [(43.6988, 117.3012)]
    And   spans(p, "evenodd", 80) = [(43.6988, 57.7556), (103.2444, 117.3012)]

  Scenario: fill_span fills the pixels whose centers are in the span
    Given cov ← coverage_buffer(8, 3)
    When  fill_span(cov, 1, 1.25, 4.75)
    Then  coverage_at(cov, 0, 1) = 0
    And   coverage_at(cov, 1, 1) = 1
    And   coverage_at(cov, 4, 1) = 1
    And   coverage_at(cov, 5, 1) = 0
    And   coverage_at(cov, 2, 0) = 0
    And   ink(cov) = 4

  Scenario: The span is half-open at its right end
    Given cov ← coverage_buffer(8, 3)
    When  fill_span(cov, 1, 1.5, 4.5)
    Then  coverage_at(cov, 1, 1) = 1
    And   coverage_at(cov, 3, 1) = 1
    And   coverage_at(cov, 4, 1) = 0
    And   ink(cov) = 3

  Scenario: A span may run off either side of the buffer
    Given a ← coverage_buffer(8, 3)
    And   b ← coverage_buffer(8, 3)
    And   c ← coverage_buffer(8, 3)
    When  fill_span(a, 1, -3, 2.5)
    And   fill_span(b, 1, 6.5, 20)
    And   fill_span(c, 1, 2.5, 2.5)
    Then  ink(a) = 2
    And   coverage_at(a, 1, 1) = 1
    And   ink(b) = 2
    And   coverage_at(b, 6, 1) = 1
    And   ink(c) = 0
