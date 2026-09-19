Feature: Length along a path, and along a curve
  path_length(p) sums the segments of every subpath; a closed subpath
  includes the segment from its last point back to its first. For a curve,
  arc_length_table(c, n) is n + 1 running lengths of the polyline through
  point_at(c, i / n), arc_length(c, n) is its last entry, and t_at_length(
  table, s) finds the parameter where the running length reaches s by
  linear interpolation inside the segment that spans it, 0 before the start
  and 1 past the end. point_at_length and split_at_length go through it.

  Scenario: The length of a path sums its segments, and a closed subpath includes the closing one
    Given open ← path()
    When  move_to(open, point(0, 0))
    And   line_to(open, point(3, 4))
    And   line_to(open, point(3, 0))
    Then  path_length(open) = 9
    And   path_length(polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))) = 40

  Scenario: The arc-length table is the running length of chords
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    When  table ← arc_length_table(c, 4)
    Then  length(table) = 5
    And   table[0] = 0
    And   table[1] = 2.335193
    And   table[2] = 3.901438
    And   table[4] = 7.802876

  Scenario: More chords creep up on the true length
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    And   line ← cubic(point(0, 0), point(1, 1), point(2, 2), point(3, 3))
    Then  arc_length(c, 4) = 7.802876
    And   arc_length(c, 16) = 7.987725
    And   arc_length(c, 256) = 7.999952
    And   arc_length(line, 256) = 4.242641

  Scenario: The parameter at a length, by interpolation
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    When  table ← arc_length_table(c, 256)
    And   total ← arc_length(c, 256)
    Then  t_at_length(table, 0) = 0
    And   t_at_length(table, total / 2) = 0.5
    And   t_at_length(table, total / 4) = 0.201966
    And   t_at_length(table, total + 1) = 1
    And   t_at_length(table, -1) = 0

  Scenario: A point and a split at a given length
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    When  total ← arc_length(c, 256)
    And   left ← split_at_length(c, 2, 256)[0]
    And   right ← split_at_length(c, 2, 256)[1]
    Then  point_at_length(c, total / 2, 256) = point(2, 3)
    And   point_at_length(c, total / 4, 256) = point(0.423579, 1.93411) ± 0.0001
    And   arc_length(left, 256) = 2 ± 0.001
    And   arc_length(right, 256) = 6 ± 0.001
    And   point_at(left, 1) = point_at(right, 0)

  Scenario: The parameter is not the length
    Given c ← lopsided()
    When  total ← arc_length(c, 256)
    Then  total = 225.8293 ± 0.001
    And   point_at(c, 0.5) = point(88.75, 37.5)
    And   point_at_length(c, total / 2, 256) = point(94.8542, 37.4727) ± 0.001
    And   t_at_length(arc_length_table(c, 256), total / 2) = 0.527003 ± 0.0001
