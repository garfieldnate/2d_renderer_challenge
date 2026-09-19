Feature: Stroking a curve is one outline
  stroke_curve_to_path(c, width, cap, tolerance) is the stroke of a curve as
  one closed subpath: the offset at +h flattened forward, the end cap's
  points, the offset at -h flattened backward, the start cap's points, with
  consecutive duplicates dropped. Fill it nonzero. flatten_then_stroke(c,
  width, cap, tolerance) is chapter 13's way, the flattened polyline stroked
  with round joins, and point_count(p) counts a path's points. hairpin() is a
  cubic that bends back on itself with a tightest radius of about 8; stroked
  60 wide, its inner offset folds into a loop.

  Scenario: The stroke of a curve is one closed subpath, right offset out and left offset back
    Given o ← stroke_curve_to_path(hairpin(), 60, "butt", 0.25)
    Then  length(subpaths(o)) = 1
    And   subpaths(o)[0].closed = true
    And   length(subpaths(o)[0].points) = 58
    And   subpaths(o)[0].points[0] = offset_point(hairpin(), 0, 30)
    And   subpaths(o)[0].points[57] = offset_point(hairpin(), 0, -30)
    And   subpaths(o)[0].points[0] = point(64.5435, 145.214) ± 0.001

  Scenario: Caps add their points to the same outline
    Then  point_count(stroke_curve_to_path(hairpin(), 60, "round", 0.25)) = 88
    And   point_count(stroke_curve_to_path(hairpin(), 60, "square", 0.25)) = 62

  Scenario: Flattening first gives the same picture from many more pieces
    Given o ← stroke_curve_to_path(hairpin(), 60, "butt", 0.25)
    And   f ← flatten_then_stroke(hairpin(), 60, "butt", 0.25)
    Then  length(subpaths(f)) = 43
    And   point_count(f) = 172
    And   point_count(o) = 58
    And   max_coverage_difference(fill_path(o, "nonzero", 160, 160), fill_path(f, "nonzero", 160, 160)) ≤ 0.6

  Scenario: The inner offset folds into a loop, and nonzero fills it
    Given o ← stroke_curve_to_path(hairpin(), 60, "butt", 0.25)
    Then  length(cusps(hairpin(), 30)) = 2
    And   length(cusps(hairpin(), -30)) = 0
    And   distance_to_curve(hairpin(), point(80.5, 60.5)) = 25.967 ± 0.01
    And   inside_nonzero(o, 80.5, 60.5) = true
    And   inside_evenodd(o, 80.5, 60.5) = false
    And   distance_to_curve(hairpin(), point(80.5, 30.5)) = 14.503 ± 0.01
    And   inside_nonzero(o, 80.5, 30.5) = true
    And   inside_evenodd(o, 80.5, 30.5) = true
    And   distance_to_curve(hairpin(), point(80.5, 85.5)) = 32.626 ± 0.01
    And   inside_nonzero(o, 80.5, 85.5) = false
