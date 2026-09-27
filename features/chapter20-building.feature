Feature: From commands to a path
  The commands become a chapter 5 path in device space. arc_cubics(x1, y1,
  rx, ry, angle, large, sweep, x2, y2) turns an arc into cubics: chapter
  8's arc gives the center form (the angle in degrees, converted to
  radians), the swept angle is cut into n equal pieces, n = ceil(|delta| /
  (pi / 2) - 0.000001) and at least 1, so that a quarter turn the
  arithmetic lands a hair past is still one piece, and each
  piece from theta to theta + d is the cubic whose inner control points sit
  on the tangents at its ends, 4/3 tan(d/4) of a radius along them, on the
  ellipse's own axes. The first cubic starts exactly at (x1, y1) and the
  last ends exactly at (x2, y2). Coincident endpoints have no arc and give
  no cubics; a zero radius gives one straight cubic, its control points at
  the thirds of the chord, because SVG draws a line there.
  build_path(cmds, m, tolerance) walks the commands keeping a current
  point: M is a move_to and L a line_to, each point taken through m; C and
  Q are cubics and quadratics from the current point, taken through m and
  then flattened into the path (chapter 8's order: transform, then
  flatten); A is its arc_cubics, each done the same way; Z is a close. A
  subpath that is nothing but its moveto is dropped. commands_bounds(cmds)
  is the tight box of the geometry in user space: every M and L point and
  chapter 8's curve_bounds of every curve, (0, 0, 0, 0) when there's none.

  Scenario: A quarter circle is one cubic with handles 0.5523 of a radius long
    When  cs ← arc_cubics(10, 0, 10, 10, 0, 0, 1, 0, 10)
    Then  length(cs) = 1
    And   cs[0].points[0] = point(10, 0)
    And   cs[0].points[1] = point(10, 5.5228)
    And   cs[0].points[2] = point(5.5228, 10)
    And   cs[0].points[3] = point(0, 10)
    And   length(arc_cubics(8.3, 1.1, 3.3, 3.3, 0, 0, 1, 5, 4.4)) = 1

  Scenario: A half turn is two quarters, and the sweep flag says which way round
    When  cs ← arc_cubics(0, 0, 5, 5, 0, 0, 1, 10, 0)
    Then  length(cs) = 2
    And   cs[0].points[3] = point(5, -5)
    And   cs[1].points[1] = point(7.7614, -5)
    And   cs[1].points[3] = point(10, 0)
    And   arc_cubics(0, 0, 5, 5, 0, 0, 0, 10, 0)[0].points[3] = point(5, 5)

  Scenario: Radii too small to reach are grown, as chapter 8 does
    When  cs ← arc_cubics(0, 0, 1, 1, 0, 0, 1, 10, 0)
    Then  length(cs) = 2
    And   cs[0].points[3] = point(5, -5)

  Scenario: The large-arc flag takes the long way round
    Then  length(arc_cubics(0, 0, 10, 10, 0, 1, 0, 0.01, 0)) = 4
    And   length(arc_cubics(0, 0, 10, 10, 0, 0, 0, 0.01, 0)) = 1

  Scenario: No arc between coincident points, and a line when a radius is zero
    Then  length(arc_cubics(3, 3, 5, 5, 0, 0, 1, 3, 3)) = 0
    And   length(arc_cubics(0, 0, 0, 5, 0, 0, 1, 9, 3)) = 1
    And   arc_cubics(0, 0, 0, 5, 0, 0, 1, 9, 3)[0].points[1] = point(3, 1)
    And   arc_cubics(0, 0, 0, 5, 0, 0, 1, 9, 3)[0].points[2] = point(6, 2)

  Scenario: Points go through the matrix, and Z then L starts at the subpath's start
    When  p ← build_path(path_commands("M0 0 L10 0 L10 10 Z L0 10"), scaling(2, 2), 0.1)
    Then  length(subpaths(p)) = 2
    And   subpaths(p)[0].points = [point(0, 0), point(20, 0), point(20, 20)]
    And   subpaths(p)[0].closed = true
    And   subpaths(p)[1].points = [point(0, 0), point(0, 20)]
    And   subpaths(p)[1].closed = false

  Scenario: A moveto on its own is dropped, but a closed point stays
    When  p ← build_path(path_commands("M0 0 L10 0 M20 20 M5 5 L6 6 M7 7"), identity(), 0.1)
    Then  length(subpaths(p)) = 2
    And   subpaths(p)[1].points = [point(5, 5), point(6, 6)]
    And   length(subpaths(build_path(path_commands("M1 1 Z"), identity(), 0.1))) = 1

  Scenario: Curves are flattened after the transform, so a bigger curve gets more points
    Then  length(subpaths(build_path(path_commands("M0 0 Q10 0 10 10"), identity(), 0.1))[0].points) = 13
    And   length(subpaths(build_path(path_commands("M0 0 Q10 0 10 10"), scaling(10, 10), 0.1))[0].points) = 33

  Scenario: An arc in a path ends exactly at its end point
    When  p ← build_path(path_commands("M0 0 A5 5 0 0 1 10 0"), identity(), 0.1)
    Then  length(subpaths(p)[0].points) = 17
    And   subpaths(p)[0].points[16] = point(10, 0)
    And   subpaths(p)[0].points[8] = point(5, -5)

  Scenario: The bounds of the geometry, not of the control points
    Then  commands_bounds(path_commands("M0 0 C0 -10 10 -10 10 0")) = (0, -7.5, 10, 0)
    And   commands_bounds(path_commands("M0 0 Q10 20 20 0")) = (0, 0, 20, 10)
    And   commands_bounds(path_commands("M0 0 A5 5 0 0 1 10 0")) = (0, -5, 10, 0)
    And   commands_bounds(path_commands("M0 0 A5 5 0 0 0 10 0")) = (0, 0, 10, 5)
    And   commands_bounds(path_commands("")) = (0, 0, 0, 0)
