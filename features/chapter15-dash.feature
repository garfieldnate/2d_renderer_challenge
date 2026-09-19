Feature: The walk
  dash(p, pattern, phase) walks every subpath from its start by arc length,
  on for pattern[0], off for pattern[1], and so on around the pattern, and
  every on-stretch becomes an open subpath of the result. The walk goes
  straight through a subpath's vertices, so a dash that reaches a corner
  turns it. phase is how far into the pattern the walk begins, taken modulo
  the pattern's sum, so a phase of the sum is no phase at all and a negative
  phase is the same as the sum plus it. A dash that would begin exactly at
  the end of a subpath is not emitted.

  Scenario: Dashes on a straight line land at exact multiples
    Given seg ← path()
    When  move_to(seg, point(0, 0))
    And   line_to(seg, point(100, 0))
    And   d ← dash(seg, [10, 5], 0)
    Then  length(subpaths(d)) = 7
    And   subpaths(d)[0].points[0] = point(0, 0)
    And   subpaths(d)[0].points[1] = point(10, 0)
    And   subpaths(d)[1].points[0] = point(15, 0)
    And   subpaths(d)[1].points[1] = point(25, 0)
    And   subpaths(d)[6].points[0] = point(90, 0)
    And   subpaths(d)[6].points[1] = point(100, 0)
    And   subpaths(d)[6].closed = false

  Scenario: The dashes and the gaps add up to the path
    Given seg ← path()
    When  move_to(seg, point(0, 0))
    And   line_to(seg, point(100, 0))
    And   d ← dash(seg, [10, 5], 0)
    Then  path_length(d) = 70
    And   path_length(seg) - path_length(d) = 30

  Scenario: The phase starts the walk partway into the pattern
    Given seg ← path()
    When  move_to(seg, point(0, 0))
    And   line_to(seg, point(100, 0))
    And   d ← dash(seg, [10, 5], 3)
    Then  length(subpaths(d)) = 7
    And   subpaths(d)[0].points[0] = point(0, 0)
    And   subpaths(d)[0].points[1] = point(7, 0)
    And   subpaths(d)[1].points[0] = point(12, 0)
    And   subpaths(d)[6].points[1] = point(97, 0)

  Scenario: A phase into a gap starts with a gap
    Given seg ← path()
    When  move_to(seg, point(0, 0))
    And   line_to(seg, point(100, 0))
    And   d ← dash(seg, [10, 5], 12)
    Then  length(subpaths(d)) = 7
    And   subpaths(d)[0].points[0] = point(3, 0)
    And   subpaths(d)[0].points[1] = point(13, 0)
    And   subpaths(d)[6].points[0] = point(93, 0)
    And   subpaths(d)[6].points[1] = point(100, 0)

  Scenario: A phase of the pattern's sum is no phase, and a negative phase wraps
    Given seg ← path()
    When  move_to(seg, point(0, 0))
    And   line_to(seg, point(100, 0))
    Then  subpaths(dash(seg, [10, 5], 15))[0].points[1] = point(10, 0)
    And   subpaths(dash(seg, [10, 5], 15))[1].points[0] = point(15, 0)
    And   subpaths(dash(seg, [10, 5], -3))[0].points[0] = point(3, 0)
    And   subpaths(dash(seg, [10, 5], -3))[0].points[1] = point(13, 0)

  Scenario: A dash that reaches a corner turns it
    Given bend ← path()
    When  move_to(bend, point(0, 0))
    And   line_to(bend, point(10, 0))
    And   line_to(bend, point(10, 10))
    And   d ← dash(bend, [12, 4], 0)
    Then  length(subpaths(d)) = 2
    And   length(subpaths(d)[0].points) = 3
    And   subpaths(d)[0].points[1] = point(10, 0)
    And   subpaths(d)[0].points[2] = point(10, 2)
    And   subpaths(d)[1].points[0] = point(10, 6)
    And   subpaths(d)[1].points[1] = point(10, 10)

  Scenario: A gap that reaches a corner turns it too
    Given bend ← path()
    When  move_to(bend, point(0, 0))
    And   line_to(bend, point(10, 0))
    And   line_to(bend, point(10, 10))
    And   d ← dash(bend, [8, 4], 0)
    Then  length(subpaths(d)) = 2
    And   subpaths(d)[0].points[1] = point(8, 0)
    And   subpaths(d)[1].points[0] = point(10, 2)

  Scenario: Duplicate points do not stall the walk
    Given seg ← path()
    When  move_to(seg, point(0, 0))
    And   line_to(seg, point(0, 0))
    And   line_to(seg, point(10, 0))
    And   d ← dash(seg, [4, 2], 0)
    Then  length(subpaths(d)) = 2
    And   subpaths(d)[0].points[1] = point(4, 0)
    And   subpaths(d)[1].points[0] = point(6, 0)
