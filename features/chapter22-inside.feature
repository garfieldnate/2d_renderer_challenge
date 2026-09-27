Feature: Which side is inside
  Once no two segments cross, a segment has the same two winding numbers
  all along each of its sides, so it's enough to ask at its midpoint m.
  winding_beside(segs, i) is chapter 5's winding_at at m, for path A and
  path B together, with two changes. The half-open rule compares in the
  sweep's order: segment f spans m when f.lo is before m or equal to it
  and m is before f.hi, by lex_less, not by y alone. And the two cases of
  chapter 5 are one: f counts when it spans m and orient(f.lo, f.hi, m)
  is positive, and it adds its own windings, f.wa to A and f.wb to B. The
  answer is two pairs: first (A, B) summed over every segment but i,
  which is the side of segment i where it doesn't count; then that plus
  i's own windings, the side where it does, which is its left, or below
  it when it's horizontal. No other segment passes through m, because
  nothing crosses and no endpoint is inside another segment; compute m
  doubled, as lo + hi, to stay in whole numbers.

  inside_rule(w, rule) is w ≠ 0 for "nonzero" and w odd for "evenodd".
  op_inside(op, in_a, in_b) is in_a or in_b for "union", in_a and in_b
  for "intersection", in_a and not in_b for "difference", and in_a ≠ in_b
  for "xor". keep_edges(segs, rule_a, rule_b, op) keeps segment i, in
  order, when op_inside differs between its two sides, as the pair (from,
  to): (lo, hi) when the inside is on the side where it counts, (hi, lo)
  when it isn't. Either way the inside ends up on the right as you travel
  from to to, which is clockwise on screen around what's inside.

  Scenario: The two sides of a square's edges
    Given sq ← merge_segments([seg(point(0, 0), point(4, 0), 1, 0), seg(point(4, 0), point(4, 4), 1, 0), seg(point(4, 4), point(0, 4), 1, 0), seg(point(0, 4), point(0, 0), 1, 0)])
    Then  sq[0] = seg(point(0, 0), point(4, 0), 1, 0)
    And   winding_beside(sq, 0) = ((0, 0), (1, 0))
    And   sq[1] = seg(point(0, 0), point(0, 4), -1, 0)
    And   winding_beside(sq, 1) = ((1, 0), (0, 0))
    And   winding_beside(sq, 2) = ((0, 0), (1, 0))
    And   winding_beside(sq, 3) = ((1, 0), (0, 0))

  Scenario: Where two squares overlap, both paths wind around the middle
    Given a ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    And   b ← polygon(point(5, 5), point(15, 5), point(15, 15), point(5, 15))
    When  segs ← split_segments(path_segments(a, "a") + path_segments(b, "b"), "brute", sweep_stats())
    Then  segs[3] = seg(point(1280, 1280), point(2560, 1280), 0, 1)
    And   winding_beside(segs, 3) = ((1, 0), (1, 1))
    And   segs[6] = seg(point(2560, 1280), point(2560, 2560), 1, 0)
    And   winding_beside(segs, 6) = ((0, 1), (1, 1))

  Scenario: The ray breaks a tie in y by x, as the sweep does
    Given segs ← [seg(point(0, 0), point(0, 10), 1, 0), seg(point(4, 0), point(4, 5), 0, 1), seg(point(4, 5), point(4, 20), 0, -1)]
    And   flat ← [seg(point(0, 0), point(10, 0), 1, 0), seg(point(12, -5), point(12, 0), 0, 1), seg(point(12, 0), point(12, 5), 0, -1)]
    Then  winding_beside(segs, 0) = ((0, 1), (1, 1))
    And   winding_beside(flat, 0) = ((0, 1), (1, 1))

  Scenario Outline: What each operation calls inside
    Then  op_inside(<op>, true, true) = <both>
    And   op_inside(<op>, true, false) = <a_only>
    And   op_inside(<op>, false, true) = <b_only>
    And   op_inside(<op>, false, false) = false

    Examples:
      | op             | both  | a_only | b_only |
      | "union"        | true  | true   | true   |
      | "intersection" | true  | false  | false  |
      | "difference"   | false | true   | false  |
      | "xor"          | false | true   | true   |

  Scenario: A winding of 2 is inside under nonzero and outside under even-odd
    Then  inside_rule(2, "nonzero") = true
    And   inside_rule(2, "evenodd") = false
    And   inside_rule(-1, "evenodd") = true
    And   inside_rule(-2, "nonzero") = true
    And   inside_rule(0, "nonzero") = false

  Scenario: The kept edges run with the inside on their right
    Given a ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    And   b ← polygon(point(5, 5), point(15, 5), point(15, 15), point(5, 15))
    When  segs ← split_segments(path_segments(a, "a") + path_segments(b, "b"), "brute", sweep_stats())
    Then  keep_edges(segs, "nonzero", "nonzero", "intersection") = [(point(1280, 1280), point(2560, 1280)), (point(1280, 2560), point(1280, 1280)), (point(2560, 1280), point(2560, 2560)), (point(2560, 2560), point(1280, 2560))]
    And   keep_edges(segs, "nonzero", "nonzero", "difference") = [(point(0, 0), point(2560, 0)), (point(0, 2560), point(0, 0)), (point(2560, 0), point(2560, 1280)), (point(2560, 1280), point(1280, 1280)), (point(1280, 1280), point(1280, 2560)), (point(1280, 2560), point(0, 2560))]
    And   length(keep_edges(segs, "nonzero", "nonzero", "union")) = 8
    And   length(keep_edges(segs, "nonzero", "nonzero", "xor")) = 12
