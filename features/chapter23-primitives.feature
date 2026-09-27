Feature: Exact fields for primitives
  A signed distance is negative inside a shape and positive outside, and
  its size is the distance to the nearest point of the shape's edge.
  sd_circle(p, c, r) is magnitude(p - c) - r. distance_to_segment(p, a,
  b) has no sign, because a segment has no inside: the distance from p to
  a + t (b - a), with t = dot(p - a, b - a) / dot(b - a, b - a) clamped
  to [0, 1], or to a when a = b. sd_box(p, c, hw, hh) is a box centered
  on c, hw and hh from the center to its sides: with qx = |p.x - c.x| - hw
  and qy = |p.y - c.y| - hh, it's the length of (max(qx, 0), max(qy, 0))
  plus min(max(qx, qy), 0). sd_rounded_box(p, c, hw, hh, r) is
  sd_box(p, c, hw - r, hh - r) - r. sd_polygon(p, path, rule) is the least
  distance_to_segment over chapter 5's edges(path), made negative when
  chapter 5's winding_at says p is inside under the rule.

  Scenario: A circle
    Then  sd_circle(point(3, 4), point(0, 0), 2) = 3
    And   sd_circle(point(1, 0), point(0, 0), 2) = -1
    And   sd_circle(point(2, 0), point(0, 0), 2) = 0

  Scenario: A segment, beside it and beyond its ends
    Then  distance_to_segment(point(5, 3), point(0, 0), point(10, 0)) = 3
    And   distance_to_segment(point(-3, 4), point(0, 0), point(10, 0)) = 5
    And   distance_to_segment(point(13, -4), point(0, 0), point(10, 0)) = 5
    And   distance_to_segment(point(3, 4), point(0, 0), point(0, 0)) = 5

  Scenario: A box, beside a side, off a corner, and inside
    Then  sd_box(point(13, 0), point(0, 0), 10, 5) = 3
    And   sd_box(point(13, 9), point(0, 0), 10, 5) = 5
    And   sd_box(point(2, 1), point(0, 0), 10, 5) = -4
    And   sd_box(point(-2, -4), point(0, 0), 10, 5) = -1

  Scenario: Rounding a box rounds its corners and nothing else
    Then  sd_rounded_box(point(13, 9), point(0, 0), 10, 5, 2) = 5.810250
    And   sd_rounded_box(point(13, 0), point(0, 0), 10, 5, 2) = 3
    And   sd_rounded_box(point(0, 0), point(0, 0), 10, 5, 2) = -5

  Scenario: A polygon's sign comes from chapter 5's winding number
    Given sq ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    Then  sd_polygon(point(5, 3), sq, "nonzero") = -3
    And   sd_polygon(point(13, 14), sq, "nonzero") = 5
    And   sd_polygon(point(80.5, 80.5), star(), "nonzero") = -21.631190
    And   sd_polygon(point(80.5, 80.5), star(), "evenodd") = 21.631190
