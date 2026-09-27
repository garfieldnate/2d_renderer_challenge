Feature: Splitting until nothing crosses
  sweep_stats() is a record of work: tests, the pairs of segments handed
  to meet or to a crossing test; events, which Bentley-Ottmann counts in
  its own section; and passes, all three starting at 0.
  find_splits(segs, "brute", st) calls meet on every pair i < j of the
  list, adding 1 to st.tests for each, and answers one list per segment:
  the points it has to be split at, without duplicates and without its
  own ends, in order along it from lo to hi, by dot(q - lo, hi - lo)
  (then by lex_less, for two points with the same dot).
  merge_segments(segs) makes segments with the same lo and hi into one,
  adding up their windings, drops any segment whose windings are both 0,
  and sorts what's left by lo and then by hi, in the sweep's order.
  split_segments(segs, method, st) merges; then, as a pass, adds 1 to
  st.passes and finds the splits with the method; if no segment has one
  it answers the segments; otherwise it cuts every segment into pieces
  at its split points, in order (each piece keeps its parent's windings
  as they were from lo to hi, which seg re-signs if the piece ends up
  running the other way), merges, and makes another pass. The pass that
  finds nothing is counted.

  Scenario: Split points come in order along the segment
    Given st ← sweep_stats()
    When  splits ← find_splits([seg(point(10, 0), point(0, 5), 1, 0), seg(point(2, -1), point(3, 9), 1, 0), seg(point(7, -1), point(8, 9), 1, 0)], "brute", st)
    Then  splits[0] = [point(7, 1), point(2, 4)]
    And   splits[1] = [point(2, 4)]
    And   splits[2] = [point(7, 1)]
    And   st.tests = 3

  Scenario: Rounded points go in order along the segment, not in the sweep's order
    Given segs ← [seg(point(6, 0), point(5, 100), 1, 0), seg(point(15, 42), point(-5, 59), 0, 1), seg(point(12, 43), point(-3, 59), 0, 1)]
    When  splits ← find_splits(segs, "brute", sweep_stats())
    Then  splits[0] = [point(6, 50), point(5, 50)]
    And   lex_less(point(5, 50), point(6, 50)) = true

  Scenario: Merging adds windings, and a segment that adds nothing goes
    When  m ← merge_segments([seg(point(0, 0), point(4, 0), 1, 0), seg(point(4, 0), point(0, 0), 1, 0), seg(point(1, 1), point(2, 2), 1, 0), seg(point(0, 0), point(0, 4), 0, 1), seg(point(0, 4), point(0, 0), 0, -1)])
    Then  m = [seg(point(0, 0), point(0, 4), 0, 2), seg(point(1, 1), point(2, 2), 1, 0)]

  Scenario: Two overlapping squares split into twelve segments in two passes
    Given a ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    And   b ← polygon(point(5, 5), point(15, 5), point(15, 15), point(5, 15))
    And   st ← sweep_stats()
    When  segs ← split_segments(path_segments(a, "a") + path_segments(b, "b"), "brute", st)
    Then  length(segs) = 12
    And   segs[2] = seg(point(2560, 0), point(2560, 1280), 1, 0)
    And   segs[3] = seg(point(1280, 1280), point(2560, 1280), 0, 1)
    And   segs[4] = seg(point(1280, 1280), point(1280, 2560), 0, -1)
    And   st.passes = 2
    And   st.tests = 94

  Scenario: Rounding a crossing can make a new meeting, so the loop goes round again
    Given segs ← [seg(point(2, 0), point(10, 12), 1, 0), seg(point(9, 0), point(6, 7), 1, 0), seg(point(7, 4), point(3, 7), 1, 0)]
    And   st ← sweep_stats()
    When  first ← find_splits(merge_segments(segs), "brute", sweep_stats())
    And   out ← split_segments(segs, "brute", st)
    Then  first[0] = [point(5, 5), point(6, 6)]
    And   first[1] = [point(6, 6)]
    And   first[2] = [point(5, 5)]
    And   st.passes = 3
    And   out = [seg(point(2, 0), point(5, 5), 1, 0), seg(point(9, 0), point(7, 4), 1, 0), seg(point(7, 4), point(5, 5), 1, 0), seg(point(7, 4), point(6, 6), 1, 0), seg(point(5, 5), point(6, 6), 1, 0), seg(point(5, 5), point(3, 7), 1, 0), seg(point(6, 6), point(6, 7), 1, 0), seg(point(6, 6), point(10, 12), 1, 0)]
