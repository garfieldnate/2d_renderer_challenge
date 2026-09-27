Feature: Bentley-Ottmann
  find_splits(segs, "bentley-ottmann", st) finds exactly what "brute"
  finds, testing only segments that are next to each other. Events are
  points, handled once each in the sweep's order; to begin with, every
  lo and hi is an event, and a lo remembers the segments that start
  there, U. The status is a list of segments in order left to right
  along the sweep, empty at first. To handle the event P, add 1 to
  st.events, then:
    1. Find the block of the status that passes through P, the segments
       with orient(lo, hi, P) = 0; those with orient < 0 are all before
       it and those with orient > 0 all after, so a binary search finds
       it. L is the block's segments whose hi is P; C is the rest, the
       ones with P strictly inside.
    2. Split each segment of C at P rounded to the nearest grid point,
       halves up, which is P itself when P is a grid point.
    3. Replace the block by U and C together, in the order they leave P
       left to right: s before t when cross(t.hi - t.lo, s.hi - s.lo) >
       0, and when that's 0, the one earlier in segs first.
    4. If nothing was put back, test the two segments now either side of
       the gap. Otherwise test the segment left of what was put back
       against the first of it, and the last of it against the segment
       to its right. Only test pairs that exist. A test adds 1 to
       st.tests, and if the two segments cross as meet's "cross" means
       at a point after P in the sweep's order, that exact point is an
       event, unless it already is one.
  A crossing's exact point is (X / D, Y / D), with D = β and X and Y the
  N of crossing_point. Keep it exact: orient against it is dx × (Y -
  D × lo.y) - dy × (X - D × lo.x), which needs about 80 bits, and
  putting two events in order compares Y1 × D2 with Y2 × D1, about 100.

  Scenario: Three segments through one point are split in one event
    Given st ← sweep_stats()
    When  splits ← find_splits([seg(point(0, 0), point(12, 12), 1, 0), seg(point(12, 0), point(0, 12), 1, 0), seg(point(6, 0), point(6, 12), 1, 0)], "bentley-ottmann", st)
    Then  splits = [[point(6, 6)], [point(6, 6)], [point(6, 6)]]
    And   st.events = 7
    And   st.tests = 2

  Scenario: A crossing between grid points is an exact event, split rounded
    Given st ← sweep_stats()
    When  splits ← find_splits([seg(point(0, 0), point(3, 1), 1, 0), seg(point(0, 1), point(3, 0), 0, 1)], "bentley-ottmann", st)
    Then  splits = [[point(2, 1)], [point(2, 1)]]
    And   st.events = 5
    And   st.tests = 1

  Scenario: A horizontal segment is last among those leaving a point
    Given st ← sweep_stats()
    When  splits ← find_splits([seg(point(0, 5), point(10, 5), 1, 0), seg(point(5, 0), point(5, 10), 1, 0), seg(point(2, 0), point(8, 10), 1, 0)], "bentley-ottmann", st)
    Then  splits = [[point(5, 5)], [point(5, 5)], [point(5, 5)]]
    And   st.events = 7
    And   st.tests = 2

  Scenario: Neighbours that part and meet again find their crossing twice, and it's one event
    Given st ← sweep_stats()
    When  splits ← find_splits([seg(point(0, 0), point(10, 10), 1, 0), seg(point(10, 0), point(0, 10), 1, 0), seg(point(5, 1), point(5, 3), 1, 0)], "bentley-ottmann", st)
    Then  splits = [[point(5, 5)], [point(5, 5)], []]
    And   st.events = 7
    And   st.tests = 4

  Scenario: Bentley-Ottmann finds what every pair finds, testing neighbours only
    Given segs ← struck_segments(1)
    And   st ← sweep_stats()
    When  splits ← find_splits(segs, "bentley-ottmann", st)
    Then  splits = find_splits(segs, "brute", sweep_stats())
    And   st.tests = 1659
    And   st.events = 879

  Scenario: The whole split, three ways, one answer
    Given segs ← struck_segments(2)
    And   brute ← sweep_stats()
    And   sweep ← sweep_stats()
    And   bo ← sweep_stats()
    When  a ← split_segments(segs, "brute", brute)
    And   b ← split_segments(segs, "sweep", sweep)
    And   c ← split_segments(segs, "bentley-ottmann", bo)
    Then  a = b
    And   a = c
    And   length(c) = 1559
    And   brute.tests = 2012677
    And   sweep.tests = 278841
    And   bo.tests = 5224
    And   bo.events = 2823
    And   bo.passes = 2
