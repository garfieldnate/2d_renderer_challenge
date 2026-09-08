Feature: The degenerate cases
  Real paths carry things that divide by zero in a naive stroker: a subpath of
  one point, two identical points in a row, a doubling back. The stroker drops
  duplicate points, and a single-point subpath is not an error — with a round
  cap it is a dot, a legitimate and specified construct; with a butt cap it is
  nothing at all.

  Scenario: Duplicate consecutive points are dropped
    Given seg ← path()
    When  move_to(seg, point(0, 5))
    And   line_to(seg, point(0, 5))
    And   line_to(seg, point(10, 5))
    And   o ← stroke_to_path(seg, 4, "butt", "miter", 4.0)
    Then  length(subpaths(o)) = 1
    And   subpaths(o)[0].points[0] = point(0, 7)

  Scenario: A single point with a round cap is a dot
    Given p ← path()
    When  move_to(p, point(20, 20))
    And   o ← stroke_to_path(p, 10, "round", "miter", 4.0)
    Then  length(subpaths(o)) = 1
    And   bounds(o) = (15, 15, 25, 25)

  Scenario: A single point with a butt cap draws nothing
    Given p ← path()
    When  move_to(p, point(20, 20))
    And   o ← stroke_to_path(p, 10, "butt", "miter", 4.0)
    Then  length(subpaths(o)) = 0

  Scenario: A single point with a square cap is a square
    Given p ← path()
    When  move_to(p, point(20, 20))
    And   o ← stroke_to_path(p, 10, "square", "miter", 4.0)
    Then  length(subpaths(o)) = 1
    And   bounds(o) = (15, 15, 25, 25)
