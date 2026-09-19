Feature: Closed subpaths, and starting over
  Every subpath starts the pattern over from the phase. A closed subpath is
  walked around its closing segment as well, and if its last dash runs all
  the way into its first, the two are joined into one dash that turns the
  starting corner. A dash that covers the whole loop comes back as the loop,
  closed.

  Scenario: Each subpath starts the pattern over
    Given two ← path()
    When  move_to(two, point(0, 0))
    And   line_to(two, point(7, 0))
    And   move_to(two, point(0, 10))
    And   line_to(two, point(20, 10))
    And   d ← dash(two, [6, 4], 0)
    Then  length(subpaths(d)) = 3
    And   subpaths(d)[0].points[1] = point(6, 0)
    And   subpaths(d)[1].points[0] = point(0, 10)
    And   subpaths(d)[1].points[1] = point(6, 10)
    And   subpaths(d)[2].points[0] = point(10, 10)
    And   subpaths(d)[2].points[1] = point(16, 10)

  Scenario: A closed subpath is walked around its closing segment
    Given square ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    When  d ← dash(square, [6, 4], 0)
    Then  length(subpaths(d)) = 4
    And   subpaths(d)[3].points[0] = point(0, 10)
    And   subpaths(d)[3].points[1] = point(0, 4)
    And   subpaths(d)[3].closed = false

  Scenario: A last dash that runs into the first is joined to it
    Given square ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    When  d ← dash(square, [4, 2], 0)
    Then  length(subpaths(d)) = 6
    And   subpaths(d)[0].points[0] = point(6, 0)
    And   subpaths(d)[0].points[1] = point(10, 0)
    And   length(subpaths(d)[5].points) = 3
    And   subpaths(d)[5].points[0] = point(0, 4)
    And   subpaths(d)[5].points[1] = point(0, 0)
    And   subpaths(d)[5].points[2] = point(4, 0)
    And   path_length(d) = 28

  Scenario: A dash that covers the whole loop is the loop, closed
    Given square ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    When  d ← dash(square, [100, 1], 0)
    Then  length(subpaths(d)) = 1
    And   subpaths(d)[0].closed = true
    And   length(subpaths(d)[0].points) = 4
    And   path_length(d) = 40

  Scenario: A pattern that ends on a gap at the start leaves the corner alone
    Given square ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    When  d ← dash(square, [10, 10], 0)
    Then  length(subpaths(d)) = 2
    And   subpaths(d)[0].points[0] = point(0, 0)
    And   subpaths(d)[1].points[1] = point(0, 10)
