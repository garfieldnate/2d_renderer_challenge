Feature: The SVG elliptical arc
  arc(x1, y1, rx, ry, phi, large_arc, sweep, x2, y2) turns SVG's endpoint form
  of an elliptical arc into a center form you can walk: a center, radii, the
  x-axis rotation phi in radians, a start angle and a swept angle.
  arc_point(a, t) is the point at t from 0 to 1 along it. The two flag bits
  pick which of four arcs joins the endpoints. Radii too small to reach are
  grown until they do, and corrected is set. Coincident endpoints or a
  zero radius describe no arc at all.

  Scenario: The two flags choose among four arcs between the same endpoints
    Given a ← arc(0, 0, 5, 5, 0, 0, 0, 6, 0)
    Then  arc_point(a, 0.5) = point(3, 1)
    And   arc_point(arc(0, 0, 5, 5, 0, 0, 1, 6, 0), 0.5) = point(3, -1)
    And   arc_point(arc(0, 0, 5, 5, 0, 1, 0, 6, 0), 0.5) = point(3, 9)
    And   arc_point(arc(0, 0, 5, 5, 0, 1, 1, 6, 0), 0.5) = point(3, -9)

  Scenario: Every one of the four still meets both endpoints
    Given a ← arc(0, 0, 5, 5, 0, 1, 0, 6, 0)
    Then  arc_point(a, 0) = point(0, 0)
    And   arc_point(a, 1) = point(6, 0)

  Scenario: Radii too small to reach are grown until they do
    Given a ← arc(0, 0, 0.5, 0.5, 0, 0, 1, 2, 0)
    Then  a.corrected = true
    And   a.rx = 1.0
    And   a.ry = 1.0
    And   arc_point(a, 0) = point(0, 0)
    And   arc_point(a, 1) = point(2, 0)
    And   arc_point(a, 0.5) = point(1, -1)

  Scenario: A half circle is the boundary the acos clamp guards
    Given a ← arc(0, 0, 2.5, 2.5, 0, 0, 0, 3, 4)
    Then  arc_point(a, 0) = point(0, 0)
    And   arc_point(a, 1) = point(3, 4)
    And   arc_point(a, 0.5) = point(-0.5, 3.5)
    And   arc_point(arc(0, 0, 2.5, 2.5, 0, 0, 1, 3, 4), 0.5) = point(3.5, 0.5)

  Scenario: A rotated ellipse still lands on its endpoints
    Given a ← arc(1, 1, 4, 2, π / 6, 0, 1, 7, 4)
    Then  a.corrected = false
    And   arc_point(a, 0) = point(1, 1)
    And   arc_point(a, 1) = point(7, 4)
    And   arc_point(a, 0.5) = point(4.268029, 1.595108)

  Scenario: A degenerate arc is no arc
    Then  arc(0, 0, 1, 1, 0, 0, 1, 0, 0) = none
    And   arc(0, 0, 0, 1, 0, 0, 1, 2, 0) = none
