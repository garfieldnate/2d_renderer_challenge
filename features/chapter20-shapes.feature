Feature: Basic shapes
  shape_commands(el) is the list of commands a shape element stands for,
  the equivalent paths the SVG specification gives, built so that
  everything after this point only ever sees path commands. A missing
  number attribute is 0. path is path_commands of its d. rect is M at (x,
  y) and L round the corners clockwise on screen, then Z; with rounded
  corners (rx or ry given and not negative; one given means the other
  equals it; each at most half the width or height) it starts at (x + rx,
  y) and puts an A with sweep 1 between each pair of straight sides. circle
  and ellipse are M at (cx + rx, cy), then four quarter arcs with sweep 1
  through the bottom, left and top, then Z. line is M and L. polyline is M
  at its first pair of points and L at the rest, and polygon is the same
  followed by Z; a number without a partner at the end is dropped. A shape
  that doesn't render, a rect or radius of zero or negative size or an
  empty points list, has no commands, and so does an element that isn't a
  shape.

  Scenario: A rectangle is four corners, clockwise on screen, closed
    When  cmds ← shape_commands(parse_xml("<rect x='1' y='2' width='10' height='5'/>"))
    Then  length(cmds) = 5
    And   cmds[0].args = (1, 2)
    And   cmds[1].args = (11, 2)
    And   cmds[2].args = (11, 7)
    And   cmds[3].args = (1, 7)
    And   cmds[4].op = "Z"

  Scenario: Rounded corners are quarter arcs between the sides
    When  cmds ← shape_commands(parse_xml("<rect width='10' height='6' rx='2'/>"))
    Then  length(cmds) = 10
    And   cmds[0].args = (2, 0)
    And   cmds[1].args = (8, 0)
    And   cmds[2].op = "A"
    And   cmds[2].args = (2, 2, 0, 0, 1, 10, 2)
    And   cmds[8].args = (2, 2, 0, 0, 1, 2, 0)

  Scenario: A corner radius is at most half a side, and one radius stands for both
    When  cmds ← shape_commands(parse_xml("<rect width='10' height='6' rx='20' ry='1'/>"))
    Then  cmds[0].args = (5, 0)
    And   cmds[2].args = (5, 1, 0, 0, 1, 10, 1)
    And   shape_commands(parse_xml("<rect width='10' height='6' ry='3'/>"))[2].args = (3, 3, 0, 0, 1, 10, 3)
    And   length(shape_commands(parse_xml("<rect width='10' height='6' ry='-3'/>"))) = 5

  Scenario: A circle and an ellipse are four quarter arcs from the right-hand point
    When  cmds ← shape_commands(parse_xml("<ellipse cx='5' cy='5' rx='4' ry='2'/>"))
    Then  length(cmds) = 6
    And   cmds[0].args = (9, 5)
    And   cmds[1].args = (4, 2, 0, 0, 1, 5, 7)
    And   cmds[2].args = (4, 2, 0, 0, 1, 1, 5)
    And   cmds[3].args = (4, 2, 0, 0, 1, 5, 3)
    And   cmds[4].args = (4, 2, 0, 0, 1, 9, 5)
    And   cmds[5].op = "Z"
    And   commands_bounds(shape_commands(parse_xml("<circle cx='5' cy='5' r='4'/>"))) = (1, 1, 9, 9)

  Scenario: Lines, polylines and polygons
    Then  length(shape_commands(parse_xml("<line x1='1' y1='2' x2='3' y2='4'/>"))) = 2
    And   shape_commands(parse_xml("<line x1='1' y1='2' x2='3' y2='4'/>"))[1].args = (3, 4)
    And   length(shape_commands(parse_xml("<polyline points='0,0 10,0 10,10 5'/>"))) = 3
    And   length(shape_commands(parse_xml("<polygon points='0 0 10 0 10 10'/>"))) = 4
    And   shape_commands(parse_xml("<polygon points='0 0 10 0 10 10'/>"))[3].op = "Z"

  Scenario: Shapes that don't render have no commands
    Then  length(shape_commands(parse_xml("<rect width='0' height='6'/>"))) = 0
    And   length(shape_commands(parse_xml("<circle r='0'/>"))) = 0
    And   length(shape_commands(parse_xml("<ellipse rx='3'/>"))) = 0
    And   length(shape_commands(parse_xml("<polygon points=''/>"))) = 0
    And   length(shape_commands(parse_xml("<text/>"))) = 0
