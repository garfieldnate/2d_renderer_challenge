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

  Scenario: A closed subpath that ends where it began has no zero-length closing segment
    Given sq ← path()
    When  move_to(sq, point(0, 0))
    And   line_to(sq, point(10, 0))
    And   line_to(sq, point(10, 10))
    And   line_to(sq, point(0, 10))
    And   line_to(sq, point(0, 0))
    And   close(sq)
    And   o ← stroke_to_path(sq, 2, "butt", "miter", 4.0)
    Then  length(subpaths(o)) = 8
    And   polygon_area(o) = -84 ± 0.0001

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

  Scenario: A square cap extends a half-width past the end
    Given seg ← path()
    When  move_to(seg, point(45, 40))
    And   line_to(seg, point(115, 40))
    And   o ← stroke_to_path(seg, 30, "square", "miter", 4.0)
    Then  length(subpaths(o)) = 3
    And   subpaths(o)[2].points[1] = point(130, 55)
    And   subpaths(o)[2].points[2] = point(130, 25)

  Scenario: A single point with a square cap is a square
    Given p ← path()
    When  move_to(p, point(20, 20))
    And   o ← stroke_to_path(p, 10, "square", "miter", 4.0)
    Then  length(subpaths(o)) = 1
    And   bounds(o) = (15, 15, 25, 25)
