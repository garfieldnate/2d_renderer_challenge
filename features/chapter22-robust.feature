Feature: The hard cases
  Every case here is one where boolean operations written in floating
  point produce slivers, gaps or nonsense, and where the grid gives an
  exact answer. float_crossing(a, b, c, d) is the trap: the crossing of
  the line through a and b with the line through c and d, in pixels, in
  floating point, a + (b - a) × t with t = cross(c - a, d - c) /
  cross(b - a, d - c). The comparisons with it are written ± 0, exact.

  Scenario: A crossing computed in floating point is on neither segment
    Given a ← point(2.6, 2.3)
    And   b ← point(10, 4.7)
    And   c ← point(8.4, 4.8)
    And   d ← point(6.4, 1.5)
    When  p ← float_crossing(a, b, c, d)
    Then  cross(b - a, p - a) ≠ 0 ± 0
    And   cross(d - c, p - c) ≠ 0 ± 0

  Scenario: Squares sharing an edge unite into one rectangle
    Given a ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    And   b ← polygon(point(10, 0), point(20, 0), point(20, 10), point(10, 10))
    Then  point_lists(combine(a, "nonzero", b, "nonzero", "union")) = [[point(0, 0), point(20, 0), point(20, 10), point(0, 10)]]
    And   point_lists(combine(a, "nonzero", b, "nonzero", "intersection")) = []

  Scenario: Squares sharing part of an edge
    Given a ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    And   b ← polygon(point(10, 4), point(20, 4), point(20, 14), point(10, 14))
    Then  point_lists(combine(a, "nonzero", b, "nonzero", "union")) = [[point(0, 0), point(10, 0), point(10, 4), point(20, 4), point(20, 14), point(10, 14), point(10, 10), point(0, 10)]]

  Scenario: Squares touching at a corner share a point and nothing else
    Given a ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    And   b ← polygon(point(10, 10), point(20, 10), point(20, 20), point(10, 20))
    Then  length(point_lists(combine(a, "nonzero", b, "nonzero", "union"))) = 2
    And   point_lists(combine(a, "nonzero", b, "nonzero", "intersection")) = []

  Scenario: Two triangles that share only their top point stay two contours
    Given a ← polygon(point(5, 0), point(10, 8), point(7, 8))
    And   b ← polygon(point(5, 0), point(3, 8), point(0, 8))
    Then  point_lists(combine(a, "nonzero", b, "nonzero", "union")) = [[point(5, 0), point(3, 8), point(0, 8)], [point(5, 0), point(10, 8), point(7, 8)]]

  Scenario: A corner resting on an edge
    Given a ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    And   b ← polygon(point(5, 10), point(8, 15), point(2, 15))
    Then  point_lists(combine(a, "nonzero", b, "nonzero", "union")) = [[point(0, 0), point(10, 0), point(10, 10), point(0, 10)], [point(5, 10), point(8, 15), point(2, 15)]]

  Scenario: A spike that goes out and comes back adds nothing
    Then  point_lists(simplify(polygon(point(0, 0), point(10, 0), point(10, 5), point(18, 5), point(10, 5), point(10, 10), point(0, 10)), "nonzero")) = [[point(0, 0), point(10, 0), point(10, 10), point(0, 10)]]

  Scenario: A sliver thinner than the grid is gone, and one a grid unit thick stays
    Then  point_lists(simplify(polygon(point(0, 0), point(10, 0), point(10, 0.001), point(0, 0.001)), "nonzero")) = []
    And   point_lists(simplify(polygon(point(0, 0), point(10, 0), point(10, 0.003), point(0, 0.003)), "nonzero")) = [[point(0, 0), point(10, 0), point(10, 0.00390625), point(0, 0.00390625)]]
