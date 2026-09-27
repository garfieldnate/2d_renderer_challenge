Feature: A grid
  Every coordinate is snapped to a grid of 1/256 of a pixel and held as a
  whole number of grid units: grid(v) is floor(v × 256 + 0.5), which
  rounds halves up, toward +∞, and snap_point(p) is point(grid(p.x),
  grid(p.y)). Coordinates must lie within 1024 pixels of the origin
  either way, 262144 units. orient(a, b, c) is chapter 4's
  cross(b - a, c - a) on grid points: positive when c is clockwise of the
  line from a to b on screen, negative when it's counterclockwise, 0 when
  the three are collinear. On whole numbers of that size every product
  and difference is below 2^53, so orient is exact even in a language
  whose only number is a double. lex_less(p, q) is the sweep's order, top
  to bottom and then left to right: p.y < q.y, or p.y = q.y and p.x < q.x.

  Scenario: A coordinate becomes a whole number of grid units, halves up
    Then  grid(1) = 256
    And   grid(0.5) = 128
    And   grid(3.14159) = 804
    And   grid(0.001953125) = 1
    And   grid(-0.001953125) = 0
    And   grid(0.0019) = 0
    And   grid(-0.003) = -1
    And   snap_point(point(2.5, -0.25)) = point(640, -64)

  Scenario: A square moved a millionth of a pixel snaps back onto itself
    Given a ← polygon(point(10, 10), point(30, 10), point(30, 30), point(10, 30))
    And   b ← polygon(point(10.000001, 10), point(30, 10.000001), point(30.000001, 30), point(10, 30.000001))
    Then  point_lists(combine(a, "nonzero", b, "nonzero", "xor")) = []
    And   point_lists(combine(a, "nonzero", b, "nonzero", "union")) = [[point(10, 10), point(30, 10), point(30, 30), point(10, 30)]]

  Scenario: orient says which way three points turn
    Then  orient(point(0, 0), point(256, 0), point(0, 256)) = 65536
    And   orient(point(0, 0), point(256, 0), point(0, -256)) = -65536
    And   orient(point(0, 0), point(256, 0), point(512, 0)) = 0

  Scenario: orient is exact at the far corners of the grid
    Given a ← point(-262144, -262144)
    And   b ← point(262144, 262143)
    And   c ← point(262143, 262142)
    Then  orient(a, b, c) = -1
    And   orient(a, b, point(0, 0)) = 262144
    And   orient(a, point(262144, 262144), point(0, 0)) = 0

  Scenario: The sweep's order is top to bottom, then left to right
    Then  lex_less(point(5, 1), point(0, 2)) = true
    And   lex_less(point(0, 2), point(5, 1)) = false
    And   lex_less(point(1, 3), point(2, 3)) = true
    And   lex_less(point(2, 3), point(2, 3)) = false
