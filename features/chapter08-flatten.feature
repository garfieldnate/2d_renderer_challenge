Feature: Flattening
  flatness(c) is how far the curve strays from the straight chord between its
  ends, the greatest distance of an interior control point from that chord.
  flatten(c, tolerance) returns a polyline within tolerance of the curve, as a
  list of points from start to end, by subdividing wherever a piece is not yet
  flat enough. A straight run needs two points; a sharp bend needs many, and
  as the tolerance shrinks the polyline's length climbs toward the true arc
  length. polyline_length and flatten_length measure it.
  flatten_into_path(p, c, tolerance) appends a flattened curve to a path with
  line_to: when the path has no subpath, or its last subpath is closed, it
  starts a new subpath at the curve's first point with move_to; otherwise, if
  the pen already stands exactly on the curve's first point that point is
  skipped, so consecutive curves don't leave a zero-length edge at the join,
  and if it doesn't the first point is joined to the pen with a line.

  Scenario: Flatness is the reach of the control points from the chord
    Given q ← quadratic(point(0, 0), point(2, 4), point(4, 0))
    Then  flatness(q) = 4
    And   flatness(cubic(point(0, 0), point(1, 1), point(2, 2), point(3, 3))) = 0

  Scenario: A straight curve flattens to its two endpoints
    Given c ← cubic(point(0, 0), point(1, 1), point(2, 2), point(3, 3))
    When  pts ← flatten(c, 0.01)
    Then  length(pts) = 2
    And   pts[0] = point(0, 0)
    And   pts[1] = point(3, 3)

  Scenario: Flattening always keeps both ends
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    When  pts ← flatten(c, 2.0)
    Then  pts[0] = point(0, 0)
    And   pts[length(pts) - 1] = point(4, 0)

  Scenario: A tighter tolerance uses more points
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    Then  length(flatten(c, 2.0)) = 3
    And   length(flatten(c, 0.1)) = 9

  Scenario: A curve scaled up needs more points, so flatten after the transform
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    Then  length(flatten(c, 0.1)) = 9
    And   length(flatten(transform_curve(c, scaling(10, 10)), 0.1)) = 33

  Scenario: The flattened length converges to the arc length
    Given c ← cubic(point(0, 0), point(0, 4), point(4, 4), point(4, 0))
    Then  flatten_length(c, 2.0) = 7.2111 ± 0.001
    And   flatten_length(c, 0.1) = 7.9509 ± 0.001
    And   flatten_length(c, 0.001) = 7.9992 ± 0.001

  Scenario: Appending curves to a path joins them without repeating a point
    Given p ← path()
    When  flatten_into_path(p, quadratic(point(0, 0), point(10, 0), point(10, 10)), 0.1)
    And   flatten_into_path(p, quadratic(point(10, 10), point(10, 20), point(0, 20)), 0.1)
    Then  length(subpaths(p)) = 1
    And   length(subpaths(p)[0].points) = 25
    And   subpaths(p)[0].points[12] = point(10, 10)
    And   subpaths(p)[0].points[13] ≠ point(10, 10)

  Scenario: A curve that starts away from the pen is joined with a line, and after a close it starts a new subpath
    Given p ← path()
    When  flatten_into_path(p, quadratic(point(0, 0), point(10, 0), point(10, 10)), 0.1)
    And   flatten_into_path(p, quadratic(point(5, 25), point(0, 30), point(-5, 25)), 0.1)
    And   close(p)
    And   flatten_into_path(p, quadratic(point(50, 0), point(60, 0), point(60, 10)), 0.1)
    Then  length(subpaths(p)) = 2
    And   length(subpaths(p)[0].points) = 22
    And   subpaths(p)[0].points[13] = point(5, 25)
    And   subpaths(p)[1].points[0] = point(50, 0)
    And   length(subpaths(p)[1].points) = 13
