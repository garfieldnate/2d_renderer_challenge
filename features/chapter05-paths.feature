Feature: A path is a list of instructions
  path() is empty. move_to(p, point) starts a new subpath there. line_to(p,
  point) extends the current subpath. close(p) marks it closed. subpaths(p)
  is the list, each with .points and .closed. edges(p) lists every edge of
  every subpath as (a, b) pairs, treating every subpath as closed whether or
  not close was called. bounds(p) is (min x, min y, max x, max y) over every
  point.

  Scenario: An empty path
    Given p ← path()
    Then  length(subpaths(p)) = 0
    And   length(edges(p)) = 0
    And   bounds(p) = (0, 0, 0, 0)

  Scenario: A triangle, closed
    Given p ← path()
    When  move_to(p, point(1, 1))
    And   line_to(p, point(9, 1))
    And   line_to(p, point(5, 8))
    And   close(p)
    Then  length(subpaths(p)) = 1
    And   subpaths(p)[0].closed = true
    And   length(subpaths(p)[0].points) = 3
    And   subpaths(p)[0].points[2] = point(5, 8)
    And   length(edges(p)) = 3
    And   edges(p)[2] = (point(5, 8), point(1, 1))
    And   bounds(p) = (1, 1, 9, 8)

  Scenario: A triangle left open still has three edges
    Given p ← path()
    When  move_to(p, point(1, 1))
    And   line_to(p, point(9, 1))
    And   line_to(p, point(5, 8))
    Then  subpaths(p)[0].closed = false
    And   length(edges(p)) = 3
    And   edges(p)[2] = (point(5, 8), point(1, 1))

  Scenario: move_to starts a second subpath
    Given p ← path()
    When  move_to(p, point(0, 0))
    And   line_to(p, point(10, 0))
    And   line_to(p, point(10, 10))
    And   line_to(p, point(0, 10))
    And   close(p)
    And   move_to(p, point(3, 3))
    And   line_to(p, point(3, 7))
    And   line_to(p, point(7, 7))
    And   line_to(p, point(7, 3))
    And   close(p)
    Then  length(subpaths(p)) = 2
    And   subpaths(p)[1].points[0] = point(3, 3)
    And   length(edges(p)) = 8
    And   bounds(p) = (0, 0, 10, 10)

  Scenario: line_to after a close starts a new subpath where the closed one began
    Given p ← path()
    When  move_to(p, point(1, 1))
    And   line_to(p, point(4, 1))
    And   line_to(p, point(4, 4))
    And   close(p)
    And   line_to(p, point(9, 9))
    Then  length(subpaths(p)) = 2
    And   subpaths(p)[1].closed = false
    And   length(subpaths(p)[1].points) = 2
    And   subpaths(p)[1].points[0] = point(1, 1)
    And   subpaths(p)[1].points[1] = point(9, 9)

  Scenario: line_to with nothing to extend behaves as move_to
    Given p ← path()
    When  line_to(p, point(2, 3))
    Then  length(subpaths(p)) = 1
    And   length(subpaths(p)[0].points) = 1
    And   subpaths(p)[0].points[0] = point(2, 3)

  Scenario: A subpath of one point has no edges, and closing nothing does nothing
    Given p ← path()
    When  close(p)
    And   move_to(p, point(1, 1))
    And   move_to(p, point(2, 2))
    Then  length(subpaths(p)) = 2
    And   length(edges(p)) = 0
    And   bounds(p) = (1, 1, 2, 2)

  Scenario: A subpath of two points has two edges and encloses nothing
    Given p ← path()
    When  move_to(p, point(1, 1))
    And   line_to(p, point(9, 9))
    Then  length(edges(p)) = 2
    And   winding_at(p, 3, 5) = 0

  Scenario: polygon is a closed subpath through its points
    Given p ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    Then  length(subpaths(p)) = 1
    And   subpaths(p)[0].closed = true
    And   length(edges(p)) = 4

  Scenario: circle_path is a polygon standing in for a circle
    Given p ← circle_path(10, 10, 5, 8)
    Then  length(subpaths(p)[0].points) = 8
    And   subpaths(p)[0].points[0] = point(15, 10)
    And   subpaths(p)[0].points[1] = point(13.5355, 13.5355)
    And   subpaths(p)[0].points[2] = point(10, 15)
    And   bounds(p) = (5, 5, 15, 15)
