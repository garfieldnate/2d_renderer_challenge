Feature: Stroking is filling
  stroke_to_path(path, width, cap, join, miter_limit) turns a stroked path into
  a fillable outline: one rectangle per segment, one join wedge per interior
  vertex, one cap shape per open end, all as subpaths of one path filled
  nonzero. There is no new rasterizer; a stroke is a path, and a path is filled.

  Scenario: A stroked segment with butt caps is exactly a rectangle
    Given seg ← path()
    When  move_to(seg, point(0, 5))
    And   line_to(seg, point(10, 5))
    And   o ← stroke_to_path(seg, 4, "butt", "miter", 4.0)
    Then  length(subpaths(o)) = 1
    And   subpaths(o)[0].points[0] = point(0, 7)
    And   subpaths(o)[0].points[1] = point(10, 7)
    And   subpaths(o)[0].points[2] = point(10, 3)
    And   subpaths(o)[0].points[3] = point(0, 3)

  Scenario: The stroked segment fills the same pixels as the rectangle
    Given seg ← path()
    When  move_to(seg, point(0, 5))
    And   line_to(seg, point(10, 5))
    And   o ← stroke_to_path(seg, 4, "butt", "miter", 4.0)
    And   rect ← polygon(point(0, 3), point(10, 3), point(10, 7), point(0, 7))
    Then  max_coverage_difference(fill_path(o, "nonzero", 12, 10), fill_path(rect, "nonzero", 12, 10)) = 0

  Scenario Outline: A chevron's join is a different shape for each join style
    Given o ← stroke_to_path(chevron(), 26, "butt", "<join>", 4.0)
    Then  length(subpaths(o)) = 3
    And   length(subpaths(o)[2].points) = <points>

    Examples:
      | join  | points |
      | miter | 4      |
      | bevel | 3      |
      | round | 13     |

  Scenario: The round join is an arc across the outer gap, not around the inside
    Given o ← stroke_to_path(chevron(), 26, "butt", "round", 4.0)
    Then  subpaths(o)[2].points[0] = point(80, 120)
    And   subpaths(o)[2].points[6] = point(78.797, 132.944) ± 0.01
    And   inside_nonzero(o, 80, 131) = true
    And   inside_nonzero(o, 80, 135) = false

  Scenario: The miter reaches its tip at the vertex plus the miter length
    Given o ← stroke_to_path(chevron(), 26, "butt", "miter", 4.0)
    Then  subpaths(o)[2].points[0] = point(80, 120)
    And   subpaths(o)[2].points[2] = point(80, 144.528) ± 0.01

  Scenario: The join sits on the outer side of the turn
    Given o ← stroke_to_path(chevron(), 26, "butt", "bevel", 4.0)
    Then  subpaths(o)[2].points[0] = point(80, 120)
    And   subpaths(o)[2].points[1] = point(68.976, 126.89) ± 0.01
    And   subpaths(o)[2].points[2] = point(91.024, 126.89) ± 0.01

  Scenario: Every piece winds the same way, so overlapping pieces add instead of cancelling
    Given hat ← path()
    When  move_to(hat, point(30, 120))
    And   line_to(hat, point(80, 40))
    And   line_to(hat, point(130, 120))
    And   o ← stroke_to_path(hat, 26, "butt", "bevel", 4.0)
    Then  polygon_area(o) = -4981.625 ± 0.01
    And   polygon_area(stroke_to_path(chevron(), 26, "butt", "bevel", 4.0)) = -4981.625 ± 0.01

  Scenario: A wide stroke around a tight bend overlaps itself and stays solid
    Given o ← stroke_to_path(u_turn(), 40, "butt", "round", 4.0)
    When  cov ← fill_path(o, "nonzero", 100, 100)
    Then  length(subpaths(o)) = 15
    And   coverage_at(cov, 50, 37) = 1
    And   coverage_at(cov, 46, 22) = 1
    And   coverage_at(cov, 53, 22) = 1

  Scenario: A closed subpath strokes to segments and joins, with no caps
    Given tri ← path()
    When  move_to(tri, point(20, 20))
    And   line_to(tri, point(80, 20))
    And   line_to(tri, point(50, 70))
    And   close(tri)
    And   o ← stroke_to_path(tri, 8, "butt", "miter", 4.0)
    Then  length(subpaths(o)) = 6
