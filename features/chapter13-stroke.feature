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
      | round | 24     |

  Scenario: The miter reaches its tip at the vertex plus the miter length
    Given o ← stroke_to_path(chevron(), 26, "butt", "miter", 4.0)
    Then  subpaths(o)[2].points[0] = point(80, 120)
    And   subpaths(o)[2].points[2] = point(80, 144.528) ± 0.01
