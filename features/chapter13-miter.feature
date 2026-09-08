Feature: The miter, and its limit
  Where two segments meet, a miter join extends their outer edges until they
  cross, at a distance from the vertex of miter_length = h / sin(theta / 2),
  the half-width over the sine of half the turn. On a sharp angle that distance
  runs away to infinity, so a miter_limit caps the ratio miter_length / h, and
  past the limit the join falls back to a bevel.

  Scenario: The miter length matches the closed form
    Then  miter_length(vector(1, 0), vector(0, 1), 2) = 2.828427 ± 0.0001
    And   miter_length(vector(1, 0), vector(0.5, 0.866025), 2) = 2.309401 ± 0.0001

  Scenario: The miter limit switches the join to a bevel past its threshold
    Given sharp ← stroke_to_path(chevron(), 26, "butt", "miter", 2.0)
    And   flat ← stroke_to_path(chevron(), 26, "butt", "miter", 1.5)
    Then  length(subpaths(sharp)[2].points) = 4
    And   length(subpaths(flat)[2].points) = 3
