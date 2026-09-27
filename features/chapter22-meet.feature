Feature: Segments, and where two of them meet
  These scenarios work in grid units: every point is already a whole
  number of units. seg(a, b, wa, wb) is a segment between two grid points
  that carries how much it adds to the winding number of path A (wa) and
  of path B (wb). Its ends are stored in the sweep's order, lo before hi
  by lex_less; if a comes after b they are swapped and wa and wb change
  sign, so seg(a, b, 1, 0) and seg(b, a, -1, 0) are the same segment: an
  edge that ran from lo to hi adds +1, one that ran from hi to lo adds -1.
  Two segments are equal when their ends and both windings are.
  path_segments(p, operand) snaps both ends of every one of chapter 5's
  edges(p) and makes each a seg with winding (1, 0) for operand "a" and
  (0, 1) for "b", in the order edges lists them, dropping an edge whose
  ends snap to the same point.

  meet(s, t) says how s and t meet, as a kind and two lists: on_s, the
  points s has to be split at, and on_t, the points t has to be split
  at. Every test is exact, with orient. "none": no common point. "end":
  they share an endpoint and nothing else. "cross": each one's endpoints
  are strictly on opposite sides of the other's line; both are split at
  crossing_point(s, t), except that a segment isn't split at one of its
  own ends. "touch": not collinear, but an endpoint of one lies strictly
  inside the other, which is split there. "overlap": collinear and
  sharing more than one point; each is split at the other's endpoints
  that lie strictly inside it (none, when they're the same segment). A
  point is strictly inside a segment when it's on its line and lex_less
  puts it strictly between lo and hi. Split points are listed in the
  sweep's order.

  crossing_point(s, t) is the exact crossing rounded to the nearest grid
  point, halves up. With a = s.lo, b = s.hi, c = t.lo, d = t.hi, let
  β = cross(b - a, d - c) and α = cross(c - a, d - c), and if β < 0
  change the sign of both. The crossing is a + (b - a) × α / β, and each
  coordinate is (2N + β) div 2β, where N is a.x × β + (b.x - a.x) × α (or
  the same in y) and div is division rounded down, toward -∞. N reaches
  about 2^59, so this is the one place that needs 64-bit integers.

  Scenario: A segment keeps its ends in the sweep's order
    Given s ← seg(point(10, 0), point(0, 0), 1, 0)
    Then  s.lo = point(0, 0)
    And   s.hi = point(10, 0)
    And   s.wa = -1
    And   s.wb = 0
    And   s = seg(point(0, 0), point(10, 0), -1, 0)
    And   seg(point(0, 5), point(10, 5), 0, 1) ≠ seg(point(10, 5), point(0, 5), 0, 1)
    And   seg(point(4, 9), point(6, 2), 0, 1).lo = point(6, 2)

  Scenario: A path's segments are its edges on the grid
    When  segs ← path_segments(polygon(point(1, 1), point(2, 1), point(2, 2), point(1, 2)), "a")
    Then  segs = [seg(point(256, 256), point(512, 256), 1, 0), seg(point(512, 256), point(512, 512), 1, 0), seg(point(256, 512), point(512, 512), -1, 0), seg(point(256, 256), point(256, 512), -1, 0)]
    And   path_segments(polygon(point(1, 1), point(2, 1), point(2.001, 1), point(2, 2)), "b") = [seg(point(256, 256), point(512, 256), 0, 1), seg(point(512, 256), point(512, 512), 0, 1), seg(point(256, 256), point(512, 512), 0, -1)]

  Scenario: Two segments crossing are both split where they cross
    Given m ← meet(seg(point(0, 0), point(10, 10), 1, 0), seg(point(0, 10), point(10, 0), 1, 0))
    Then  m.kind = "cross"
    And   m.on_s = [point(5, 5)]
    And   m.on_t = [point(5, 5)]

  Scenario: A crossing between grid points rounds to one, halves up
    Given s ← seg(point(0, 0), point(3, 1), 1, 0)
    And   t ← seg(point(0, 1), point(3, 0), 0, 1)
    Then  crossing_point(s, t) = point(2, 1)
    And   crossing_point(seg(point(-3, 0), point(0, 1), 1, 0), seg(point(-3, 1), point(0, 0), 0, 1)) = point(-1, 1)
    And   crossing_point(seg(point(2, 0), point(10, 12), 1, 0), seg(point(9, 0), point(6, 7), 1, 0)) = point(6, 6)
    And   crossing_point(seg(point(2, 0), point(10, 12), 1, 0), seg(point(7, 4), point(3, 7), 1, 0)) = point(5, 5)

  Scenario: A crossing that rounds onto an end splits only the other segment
    Given m ← meet(seg(point(0, 0), point(100, 1), 1, 0), seg(point(0, 1), point(1, -1), 1, 0))
    Then  m.kind = "cross"
    And   m.on_s = []
    And   m.on_t = [point(0, 0)]

  Scenario: An end touching the middle of another segment splits it
    Given m ← meet(seg(point(0, 0), point(10, 0), 1, 0), seg(point(5, 0), point(5, 10), 1, 0))
    Then  m.kind = "touch"
    And   m.on_s = [point(5, 0)]
    And   m.on_t = []

  Scenario: Collinear segments that overlap split each other at their ends
    Given m ← meet(seg(point(0, 0), point(10, 0), 1, 0), seg(point(4, 0), point(14, 0), 1, 0))
    And   n ← meet(seg(point(0, 0), point(10, 0), 1, 0), seg(point(2, 0), point(6, 0), 1, 0))
    And   same ← meet(seg(point(0, 0), point(10, 0), 1, 0), seg(point(10, 0), point(0, 0), 1, 0))
    Then  m.kind = "overlap"
    And   m.on_s = [point(4, 0)]
    And   m.on_t = [point(10, 0)]
    And   n.kind = "overlap"
    And   n.on_s = [point(2, 0), point(6, 0)]
    And   n.on_t = []
    And   same.kind = "overlap"
    And   same.on_s = []
    And   same.on_t = []

  Scenario: Segments that share only an end, or nothing, aren't split
    Then  meet(seg(point(0, 0), point(10, 0), 1, 0), seg(point(10, 0), point(10, 10), 1, 0)).kind = "end"
    And   meet(seg(point(0, 0), point(10, 0), 1, 0), seg(point(10, 0), point(20, 0), 1, 0)).kind = "end"
    And   meet(seg(point(0, 0), point(10, 0), 1, 0), seg(point(0, 1), point(10, 1), 1, 0)).kind = "none"
    And   meet(seg(point(0, 0), point(10, 0), 1, 0), seg(point(11, 0), point(20, 0), 1, 0)).kind = "none"
    And   meet(seg(point(0, 0), point(10, 0), 1, 0), seg(point(12, -5), point(12, 5), 1, 0)).kind = "none"
    And   meet(seg(point(0, 0), point(4, 4), 1, 0), seg(point(3, 0), point(9, 2), 1, 0)).kind = "none"
