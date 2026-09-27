Feature: Stitching, and the four operations
  stitch(kept) links the kept (from, to) pairs into closed contours of
  grid points. Take the unused pair that comes first in the sweep's order
  of from, then of to; walk it, and at the vertex you reach take, among
  the unused pairs leaving it, the one that turns furthest right: the
  first you meet sweeping counterclockwise on screen from the way you
  came back. Exactly: with r the incoming direction reversed, give each
  candidate direction v a half, 0 when cross(r, v) < 0 or when cross(r,
  v) = 0 and dot(r, v) > 0, and 1 otherwise; the lower half wins, and in
  the same half v beats w when cross(v, w) < 0. (cross > 0 is clockwise
  on screen, chapter 4's rule, so this is counterclockwise.) Stop when you're back at the vertex you started from. Then
  drop every vertex whose two neighbours are collinear with it
  (orient = 0), again until none is left; start the contour at its
  topmost vertex, the leftmost of those if there's a tie; and when every
  pair is used, sort the contours by their points in the sweep's order.
  combine(a, rule_a, b, rule_b, op) runs the whole thing: path_segments
  of a as "a" and b as "b", split_segments, keep_edges, stitch, and a path
  with one closed subpath per contour, every coordinate divided by 256.
  The finder doesn't change the answer; use any. simplify(p, rule) is
  combine(p, rule, path(), "nonzero", "union"). point_lists(p) is the
  list of each subpath's points. Every contour winds clockwise on screen
  around what's inside it and counterclockwise around a hole, so the
  result has winding 1 inside and 0 outside and fills the same under
  either rule.

  Scenario: Stitching follows the pairs and drops the straight vertex
    When  c ← stitch([(point(4, 4), point(0, 4)), (point(0, 0), point(2, 0)), (point(0, 4), point(0, 0)), (point(4, 0), point(4, 4)), (point(2, 0), point(4, 0))])
    Then  c = [[point(0, 0), point(4, 0), point(4, 4), point(0, 4)]]

  Scenario: Turning furthest right keeps two squares that touch at a corner apart
    When  c ← stitch([(point(0, 0), point(4, 0)), (point(4, 0), point(4, 4)), (point(4, 4), point(0, 4)), (point(0, 4), point(0, 0)), (point(4, 4), point(8, 4)), (point(8, 4), point(8, 8)), (point(8, 8), point(4, 8)), (point(4, 8), point(4, 4))])
    Then  c = [[point(0, 0), point(4, 0), point(4, 4), point(0, 4)], [point(4, 4), point(8, 4), point(8, 8), point(4, 8)]]

  Scenario: Two squares, four ways
    Given a ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    And   b ← polygon(point(5, 5), point(15, 5), point(15, 15), point(5, 15))
    Then  point_lists(combine(a, "nonzero", b, "nonzero", "union")) = [[point(0, 0), point(10, 0), point(10, 5), point(15, 5), point(15, 15), point(5, 15), point(5, 10), point(0, 10)]]
    And   point_lists(combine(a, "nonzero", b, "nonzero", "intersection")) = [[point(5, 5), point(10, 5), point(10, 10), point(5, 10)]]
    And   point_lists(combine(a, "nonzero", b, "nonzero", "difference")) = [[point(0, 0), point(10, 0), point(10, 5), point(5, 5), point(5, 10), point(0, 10)]]
    And   point_lists(combine(a, "nonzero", b, "nonzero", "xor")) = [[point(0, 0), point(10, 0), point(10, 5), point(5, 5), point(5, 10), point(0, 10)], [point(10, 5), point(15, 5), point(15, 15), point(5, 15), point(5, 10), point(10, 10)]]

  Scenario: The result winds clockwise, whichever way the input wound
    Given ccw ← polygon(point(0, 0), point(0, 10), point(10, 10), point(10, 0))
    Then  polygon_area(ccw) = -100
    And   point_lists(simplify(ccw, "nonzero")) = [[point(0, 0), point(10, 0), point(10, 10), point(0, 10)]]
    And   polygon_area(simplify(ccw, "nonzero")) = 100

  Scenario: A hole winds the other way
    Given outer ← polygon(point(0, 0), point(12, 0), point(12, 12), point(0, 12))
    And   inner ← polygon(point(4, 4), point(8, 4), point(8, 8), point(4, 8))
    When  r ← combine(outer, "nonzero", inner, "nonzero", "difference")
    Then  point_lists(r) = [[point(0, 0), point(12, 0), point(12, 12), point(0, 12)], [point(4, 4), point(4, 8), point(8, 8), point(8, 4)]]
    And   polygon_area(r) = 128

  Scenario: One path's own overlaps are resolved by its fill rule
    Given p ← path()
    When  move_to(p, point(0, 0))
    And   line_to(p, point(10, 0))
    And   line_to(p, point(10, 10))
    And   line_to(p, point(0, 10))
    And   close(p)
    And   move_to(p, point(5, 5))
    And   line_to(p, point(15, 5))
    And   line_to(p, point(15, 15))
    And   line_to(p, point(5, 15))
    And   close(p)
    Then  point_lists(simplify(p, "nonzero")) = [[point(0, 0), point(10, 0), point(10, 5), point(15, 5), point(15, 15), point(5, 15), point(5, 10), point(0, 10)]]
    And   length(point_lists(simplify(p, "evenodd"))) = 2
    And   polygon_area(simplify(p, "evenodd")) = 150

  Scenario: The star's crossings become corners
    Then  point_lists(simplify(star(), "nonzero")) = [[point(80.5, 10.5), point(96.21484375, 58.8671875), point(147.07421875, 58.8671875), point(105.9296875, 88.76171875), point(121.64453125, 137.1328125), point(80.5, 107.23828125), point(39.35546875, 137.1328125), point(55.0703125, 88.76171875), point(13.92578125, 58.8671875), point(64.78515625, 58.8671875)]]
    And   length(point_lists(simplify(star(), "evenodd"))) = 5
    And   polygon_area(simplify(star(), "nonzero")) = 5500.767746 ± 0.000001
    And   polygon_area(simplify(star(), "evenodd")) = 3800.918060 ± 0.000001

  Scenario: A shape with itself
    Given a ← plate_glyph()
    Then  point_lists(combine(a, "nonzero", a, "nonzero", "union")) = point_lists(simplify(a, "nonzero"))
    And   point_lists(combine(a, "nonzero", a, "nonzero", "intersection")) = point_lists(simplify(a, "nonzero"))
    And   point_lists(combine(a, "nonzero", a, "nonzero", "difference")) = []
    And   point_lists(combine(a, "nonzero", a, "nonzero", "xor")) = []

  Scenario: The areas add up
    Given a ← plate_glyph()
    And   b ← plate_star()
    When  union ← polygon_area(combine(a, "nonzero", b, "evenodd", "union"))
    And   both ← polygon_area(combine(a, "nonzero", b, "evenodd", "intersection"))
    And   a_only ← polygon_area(combine(a, "nonzero", b, "evenodd", "difference"))
    And   b_only ← polygon_area(combine(b, "evenodd", a, "nonzero", "difference"))
    And   either ← polygon_area(combine(a, "nonzero", b, "evenodd", "xor"))
    Then  union = either + both ± 0.000001
    And   union = a_only + b_only + both ± 0.000001
    And   union + both = polygon_area(simplify(a, "nonzero")) + polygon_area(simplify(b, "evenodd")) ± 0.05

  Scenario: Either fill rule fills the result the same
    Given r ← combine(plate_glyph(), "nonzero", plate_star(), "evenodd", "xor")
    Then  max_coverage_difference(fill_path(r, "nonzero", 200, 200), fill_path(r, "evenodd", 200, 200)) ≤ 0.000001
