Feature: Brushes
  brush(radius, hardness, spacing, flow, opacity) is a round brush.
  dab_coverage(b, d), at distance d from a dab's center, is 1 when d ≤
  hardness × radius, 0 when d ≥ radius, and (radius - d) / (radius -
  hardness × radius) between. stamp_positions(events, b) spaces dabs by
  distance, not by event: the first event is a dab, and then there is one
  every step = spacing × 2 × radius of arc length along the polyline
  through the events, the distance still needed carried from segment to
  segment. stroke_mask(width, height, centers, b) is one stroke's coverage:
  for every center in order, at every pixel of the box floor(x - radius)
  to ceil(x + radius) (and the same in y, cut to the canvas) with k =
  dab_coverage(b, distance from the pixel's center) above 0, m ← 1 - (1 -
  m)(1 - flow × k), so overlapping dabs build up. paint_stroke(c, events,
  b, col, by_distance) makes the mask from stamp_positions when
  by_distance is true and from the events themselves when it's false,
  multiplies it by opacity, and paints it through with chapter 2's
  paint_through; it answers the mask it painted. wobbly_events() is 25
  pointer events, event i at (20 + 360u², 60 + 30 sin(2πu)) with u = i /
  24, bunched at the start where the hand was slow. min_along(m, events,
  n) is the least mask value at the pixels under n evenly spaced points
  (t = k / n, k from 0 to n - 1) of every segment of the events, the
  pixel being floor of each coordinate.

  Scenario: A dab's profile
    Given b ← brush(10, 0.5, 0.25, 0.6, 1)
    Then  dab_coverage(b, 0) = 1
    And   dab_coverage(b, 5) = 1
    And   dab_coverage(b, 7.5) = 0.5
    And   dab_coverage(b, 10) = 0
    And   dab_coverage(b, 12) = 0

  Scenario: Dabs are spaced by distance along the path, carried across events
    Then  stamp_positions([point(0, 0), point(3, 0), point(10, 0)], brush(10, 0.5, 0.25, 0.6, 1)) = [point(0, 0), point(5, 0), point(10, 0)]
    And   stamp_positions([point(0, 0), point(12, 0)], brush(2, 1, 0.5, 1, 1)) = [point(0, 0), point(2, 0), point(4, 0), point(6, 0), point(8, 0), point(10, 0), point(12, 0)]
    And   length(stamp_positions(wobbly_events(), brush(8, 0.5, 0.25, 0.6, 1))) = 99

  Scenario: Flow builds up where dabs overlap
    Given one ← stroke_mask(20, 20, [point(10, 10)], brush(4, 0.5, 1, 0.6, 1))
    And   two ← stroke_mask(20, 20, [point(10, 10), point(10, 10)], brush(4, 0.5, 1, 0.6, 1))
    Then  coverage_at(one, 10, 10) = 0.6
    And   coverage_at(one, 12, 10) = 0.435147
    And   coverage_at(two, 10, 10) = 0.84

  Scenario: One dab per event leaves beads; spacing by distance doesn't
    Given ev ← wobbly_events()
    And   b ← brush(8, 0.5, 0.25, 0.6, 1)
    When  by_distance ← stroke_mask(400, 120, stamp_positions(ev, b), b)
    And   by_event ← stroke_mask(400, 120, ev, b)
    Then  min_along(by_event, ev, 50) = 0
    And   min_along(by_distance, ev, 50) = 0.704456
