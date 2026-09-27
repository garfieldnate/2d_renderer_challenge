Feature: A faster way to find where segments meet
  find_splits(segs, "sweep", st) finds exactly what "brute" finds, testing
  fewer pairs. Sort the segments by lo and then by hi, in the sweep's
  order, and keep an active list, empty at first. For each segment s in
  turn: take out of the active list every segment whose hi isn't after
  s.lo in the sweep's order (it ended above s, or where s starts, and can
  only share that point); call meet on s and each segment still active,
  adding 1 to st.tests for each; then add s to the list. Two segments
  that meet anywhere are active together when the later one arrives, so
  nothing is missed. struck_line(n) is the chapter's benchmark, a pair of
  paths (text, bars): the word Pathfinder n times with a space between,
  set by chapter 18's layout_run with kerning at 120 / n pixels to the em
  from (20, 160), every glyph flattened to 0.1 pixel; and 14n
  parallelograms, bar k with corners (x, 100), (x + 22 / n, 100),
  (x - 40 / n, 200) and (x - 62 / n, 200), where x = -40 + 48k / n.
  struck_segments(n) is merge_segments of path_segments(text, "a") and
  path_segments(bars, "b").

  Scenario: The sweep finds what every pair finds
    Given segs ← struck_segments(1)
    And   brute ← sweep_stats()
    And   sweep ← sweep_stats()
    When  a ← find_splits(segs, "brute", brute)
    And   b ← find_splits(segs, "sweep", sweep)
    Then  length(segs) = 787
    And   a = b
    And   brute.tests = 309291
    And   sweep.tests = 34326

  Scenario: Only pairs whose rows overlap are tested
    Given segs ← [seg(point(0, 0), point(10, 10), 1, 0), seg(point(0, 20), point(10, 30), 1, 0), seg(point(10, 0), point(0, 10), 0, 1), seg(point(5, 10), point(5, 20), 0, 1)]
    And   st ← sweep_stats()
    And   brute ← sweep_stats()
    When  splits ← find_splits(segs, "sweep", st)
    Then  splits = find_splits(segs, "brute", brute)
    And   st.tests = 3
    And   brute.tests = 6
    And   splits[0] = [point(5, 5)]
    And   splits[2] = [point(5, 5)]
    And   splits[3] = []

  Scenario: A segment that ends where another starts is out of the list
    Given st ← sweep_stats()
    When  splits ← find_splits([seg(point(0, 0), point(0, 10), 1, 0), seg(point(0, 10), point(0, 20), 1, 0)], "sweep", st)
    Then  st.tests = 0
