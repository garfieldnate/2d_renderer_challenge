Feature: The offset curve
  sub_curve(c, t0, t1) is the piece of a curve between two parameters, by
  splitting twice. offset_curve(c, d, tolerance) is the offset as a list of
  cubics in order: the curve is split at its cusps, and each piece is fitted,
  halved and fitted again until offset_error is within tolerance, at most
  sixteen halvings deep. offset_distance_error(c, d, tolerance) is the honest
  check: how far 100 points spread along the result stray from distance |d|
  to the curve. The points are u = i / 99 times the number of pieces for
  i = 0 to 99, each taken on piece floor(u) at parameter u - floor(u), the
  last on the last piece at 1. On the outside of a bend it stays within
  tolerance. On the inside, past the radius, the offset folds back through
  itself and comes much closer than d: that is the fold, and it is not an
  error in the fit.

  Scenario: A piece of a curve between two parameters
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    When  piece ← sub_curve(c, 0.25, 0.75)
    Then  point_at(piece, 0) = point(0.625, 2.25)
    And   point_at(piece, 0.5) = point(2, 3)
    And   point_at(piece, 1) = point(3.375, 2.25)

  Scenario: A gentle offset needs one piece at a loose tolerance and four at a tight one
    Given arc ← cubic(point(100, 0), point(100, 55.2285), point(55.2285, 100), point(0, 100))
    Then  length(offset_curve(arc, 10, 0.1)) = 1
    And   length(offset_curve(arc, 10, 0.01)) = 4
    And   length(offset_curve(arc, -10, 0.01)) = 4

  Scenario: The pieces chain end to end from the first offset point to the last
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    When  pieces ← offset_curve(c, 1, 0.01)
    Then  length(pieces) = 4
    And   pieces[0].points[0] = point(-1, 0)
    And   pieces[1].points[0] = pieces[0].points[3]
    And   pieces[1].points[3] = point(2, 4)
    And   pieces[2].points[0] = point(2, 4)
    And   pieces[3].points[3] = point(5, 0)

  Scenario: On the outside every point of the offset is a distance d from the curve
    Given arc ← cubic(point(100, 0), point(100, 55.2285), point(55.2285, 100), point(0, 100))
    And   q ← quadratic(point(0, 0), point(2, 4), point(4, 0))
    Then  offset_distance_error(arc, 10, 0.01) ≤ 0.01
    And   offset_distance_error(arc, -10, 0.01) ≤ 0.01
    And   offset_distance_error(q, 2, 0.01) ≤ 0.01
    And   offset_distance_error(q, 2, 0.1) ≤ 0.1

  Scenario: On the inside of a tight bend the offset folds and comes closer than d
    Given q ← quadratic(point(0, 0), point(2, 4), point(4, 0))
    When  pieces ← offset_curve(q, -2, 0.01)
    Then  length(pieces) = 6
    And   pieces[1].points[3] = point(2.4502, 0.118898) ± 0.0001
    And   pieces[2].points[3] = point(2, 0)
    And   pieces[3].points[3] = point(1.5498, 0.118898) ± 0.0001
    And   distance_to_curve(q, point(2, 0)) = 1.732051
    And   offset_distance_error(q, -2, 0.01) ≥ 0.7
    And   offset_distance_error(q, -2, 0.01) = 0.707336 ± 0.0001
