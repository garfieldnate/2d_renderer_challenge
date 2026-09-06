Feature: Is this point inside?
  crossings(p, x, y) counts the edges a ray from (x, y) toward +x crosses.
  winding_at(p, x, y) is the winding number: each edge that crosses the
  ray's height counts +1 or -1 by direction. Positive is clockwise on the
  screen. Both use the half-open rule: an edge from a to b is crossed when
  the ray's height y satisfies a.y ≤ y < b.y or b.y ≤ y < a.y, so a vertex
  on the ray counts once, not twice.

  Scenario: Crossings from inside and outside a square
    Given p ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    Then  crossings(p, 5, 5) = 1
    And   crossings(p, 15, 5) = 0
    And   crossings(p, -1, 5) = 2
    And   crossings(p, 0, 5) = 1
    And   crossings(p, 10, 5) = 0

  Scenario: A clockwise square winds once
    Given p ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    Then  winding_at(p, 5, 5) = 1
    And   winding_at(p, 15, 5) = 0
    And   winding_at(p, -1, 5) = 0
    And   winding_at(p, 5, -1) = 0
    And   winding_at(p, 5, 11) = 0

  Scenario: The same square the other way round winds minus once
    Given p ← polygon(point(0, 0), point(0, 10), point(10, 10), point(10, 0))
    Then  winding_at(p, 5, 5) = -1
    And   crossings(p, 5, 5) = 1

  Scenario: A ray through a vertex counts it once
    Given p ← polygon(point(5, 0), point(10, 5), point(5, 10), point(0, 5))
    Then  crossings(p, 2, 5) = 1
    And   winding_at(p, 2, 5) = 1
    And   crossings(p, -1, 5) = 2
    And   winding_at(p, -1, 5) = 0
    And   winding_at(p, 12, 5) = 0
    And   winding_at(p, 5, 5) = 1

  Scenario: The boundary belongs to the top and the left
    Given p ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    Then  winding_at(p, 5, 0) = 1
    And   winding_at(p, 0, 5) = 1
    And   winding_at(p, 0, 0) = 1
    And   winding_at(p, 5, 10) = 0
    And   winding_at(p, 10, 5) = 0
    And   winding_at(p, 10, 10) = 0

  Scenario: Two rectangles that share an edge cover it once
    Given p ← path()
    When  move_to(p, point(0, 0))
    And   line_to(p, point(5, 0))
    And   line_to(p, point(5, 10))
    And   line_to(p, point(0, 10))
    And   close(p)
    And   move_to(p, point(5, 0))
    And   line_to(p, point(10, 0))
    And   line_to(p, point(10, 10))
    And   line_to(p, point(5, 10))
    And   close(p)
    Then  winding_at(p, 2, 5) = 1
    And   winding_at(p, 5, 5) = 1
    And   winding_at(p, 8, 5) = 1

  Scenario: A diamond wound twice has winding number 2
    Given p ← path()
    When  move_to(p, point(5, 0))
    And   line_to(p, point(10, 5))
    And   line_to(p, point(5, 10))
    And   line_to(p, point(0, 5))
    And   line_to(p, point(5, 0))
    And   line_to(p, point(10, 5))
    And   line_to(p, point(5, 10))
    And   line_to(p, point(0, 5))
    And   close(p)
    Then  length(edges(p)) = 8
    And   winding_at(p, 5, 5) = 2
    And   crossings(p, 5, 5) = 2
    And   winding_at(p, 12, 5) = 0

  Scenario: The polygon circle
    Given p ← circle_path(10, 10, 5, 8)
    Then  winding_at(p, 10, 10) = 1
    And   winding_at(p, 14.9, 10) = 1
    And   winding_at(p, 15, 10) = 0
    And   winding_at(p, 10, 5.1) = 1
    And   winding_at(p, 10, 4.9) = 0

  Scenario: The pentagram's center winds twice
    Given p ← star()
    Then  winding_at(p, 80.5, 80.5) = 2
    And   crossings(p, 80.5, 80.5) = 2
    And   winding_at(p, 80.5, 20) = 1
    And   winding_at(p, 30, 60) = 1
    And   crossings(p, 30, 60) = 3
    And   winding_at(p, 80.5, 120) = 0
    And   crossings(p, 80.5, 120) = 2
    And   winding_at(p, 10, 10) = 0
