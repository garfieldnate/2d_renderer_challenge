Feature: The edge table
  edge_table(p) prepares every non-horizontal edge of a path for the sweep:
  its y_top and y_bottom, x_top (where it crosses its top), its slope in x
  per unit of y, and its direction, +1 when the path heads down the canvas
  along it (increasing y) and -1 when it heads up. Sorted by y_top, then by
  x_top. Horizontal edges are dropped.

  Scenario: A rectangle has two edges in its table
    Given p ← polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6))
    When  t ← edge_table(p)
    Then  length(t) = 2
    And   t[0].y_top = 2
    And   t[0].y_bottom = 6
    And   t[0].x_top = 2
    And   t[0].slope = 0
    And   t[0].direction = -1
    And   t[1].x_top = 6
    And   t[1].direction = 1

  Scenario: A triangle's edges carry their slopes
    Given p ← polygon(point(0, 0), point(10, 0), point(5, 10))
    When  t ← edge_table(p)
    Then  length(t) = 2
    And   t[0].x_top = 0
    And   t[0].slope = 0.5
    And   t[0].direction = -1
    And   t[1].x_top = 10
    And   t[1].slope = -0.5
    And   t[1].direction = 1

  Scenario: The table is sorted by top, then by x at the top
    Given p ← path()
    When  move_to(p, point(2, 2))
    And   line_to(p, point(4, 1))
    And   line_to(p, point(6, 3))
    And   line_to(p, point(8, 1))
    And   line_to(p, point(9, 6))
    And   line_to(p, point(1, 6))
    And   close(p)
    And   t ← edge_table(p)
    Then  length(t) = 5
    And   t[0].y_top = 1
    And   t[0].x_top = 4
    And   t[1].y_top = 1
    And   t[1].x_top = 4
    And   t[2].y_top = 1
    And   t[2].x_top = 8
    And   t[3].y_top = 1
    And   t[3].x_top = 8
    And   t[4].y_top = 2
    And   t[4].x_top = 2

  Scenario: A horizontal edge is dropped, not clamped
    Given p ← polygon(point(0, 0), point(10, 0), point(10, 5), point(0, 5))
    When  t ← edge_table(p)
    Then  length(t) = 2
    And   t[0].x_top = 0
    And   t[1].x_top = 10

  Scenario: An edge knows where it crosses a height
    Given p ← polygon(point(0, 0), point(10, 0), point(5, 10))
    When  t ← edge_table(p)
    Then  x_at(t[0], 4) = 2
    And   x_at(t[1], 4) = 8
    And   x_at(t[0], 0.5) = 0.25

  Scenario: The edge table is the same whichever way the path was drawn
    Given a ← polygon(point(0, 0), point(10, 0), point(5, 10))
    And   b ← polygon(point(0, 0), point(5, 10), point(10, 0))
    When  ta ← edge_table(a)
    And   tb ← edge_table(b)
    Then  ta[0].x_top = tb[0].x_top
    And   ta[0].slope = tb[0].slope
    And   ta[0].direction = -1
    And   tb[0].direction = 1
