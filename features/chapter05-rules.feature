Feature: Two rules
  inside_nonzero(p, x, y) is true when the winding number isn't zero.
  inside_evenodd(p, x, y) is true when it's odd. filled(p, rule) is the
  shape a path encloses under a rule, "nonzero" or "evenodd", so that
  chapter 2's rasterizer can draw it. rasterize_within(shape, box, w, h) is
  chapter 2's rasterize restricted to the pixels the box touches.

  Scenario: A single loop is inside under both rules
    Given p ← polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10))
    Then  inside_nonzero(p, 5, 5) = true
    And   inside_evenodd(p, 5, 5) = true
    And   inside_nonzero(p, 15, 5) = false
    And   inside_evenodd(p, 15, 5) = false

  Scenario: An inner loop the other way round is a hole under both rules
    Given p ← path()
    When  move_to(p, point(0, 0))
    And   line_to(p, point(10, 0))
    And   line_to(p, point(10, 10))
    And   line_to(p, point(0, 10))
    And   close(p)
    And   move_to(p, point(3, 3))
    And   line_to(p, point(3, 7))
    And   line_to(p, point(7, 7))
    And   line_to(p, point(7, 3))
    And   close(p)
    Then  winding_at(p, 5, 5) = 0
    And   winding_at(p, 1, 1) = 1
    And   inside_nonzero(p, 5, 5) = false
    And   inside_evenodd(p, 5, 5) = false
    And   inside_nonzero(p, 1, 1) = true

  Scenario: An inner loop the same way round is a hole only under even-odd
    Given p ← path()
    When  move_to(p, point(0, 0))
    And   line_to(p, point(10, 0))
    And   line_to(p, point(10, 10))
    And   line_to(p, point(0, 10))
    And   close(p)
    And   move_to(p, point(3, 3))
    And   line_to(p, point(7, 3))
    And   line_to(p, point(7, 7))
    And   line_to(p, point(3, 7))
    And   close(p)
    Then  winding_at(p, 5, 5) = 2
    And   inside_nonzero(p, 5, 5) = true
    And   inside_evenodd(p, 5, 5) = false

  Scenario: A loop wound twice vanishes under even-odd
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
    Then  inside_nonzero(p, 5, 5) = true
    And   inside_evenodd(p, 5, 5) = false

  Scenario: Even-odd counts negative windings too
    Given p ← polygon(point(0, 0), point(0, 10), point(10, 10), point(10, 0))
    And   q ← path()
    When  move_to(q, point(5, 0))
    And   line_to(q, point(0, 5))
    And   line_to(q, point(5, 10))
    And   line_to(q, point(10, 5))
    And   line_to(q, point(5, 0))
    And   line_to(q, point(0, 5))
    And   line_to(q, point(5, 10))
    And   line_to(q, point(10, 5))
    And   line_to(q, point(5, 0))
    And   line_to(q, point(0, 5))
    And   line_to(q, point(5, 10))
    And   line_to(q, point(10, 5))
    And   close(q)
    Then  winding_at(p, 5, 5) = -1
    And   inside_evenodd(p, 5, 5) = true
    And   winding_at(q, 5, 5) = -3
    And   inside_evenodd(q, 5, 5) = true
    And   inside_nonzero(q, 5, 5) = true

  Scenario: The pentagram's center is inside under nonzero and outside under even-odd
    Given p ← star()
    Then  inside_nonzero(p, 80.5, 80.5) = true
    And   inside_evenodd(p, 80.5, 80.5) = false
    And   inside_nonzero(p, 80.5, 20) = true
    And   inside_evenodd(p, 80.5, 20) = true
    And   inside_nonzero(p, 80.5, 120) = false
    And   inside_evenodd(p, 80.5, 120) = false

  Scenario: A filled path is a shape
    Given s ← filled(polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6)), "nonzero")
    When  cov ← rasterize(s, 8, 8)
    Then  inside(s, 3, 3) = true
    And   inside(s, 7, 3) = false
    And   coverage_at(cov, 3, 3) = 1
    And   coverage_at(cov, 1, 3) = 0
    And   coverage_at(cov, 6, 3) = 0
    And   ink(cov) = 16

  Scenario: A filled path takes the rule seriously
    Given p ← star()
    And   a ← filled(p, "nonzero")
    And   b ← filled(p, "evenodd")
    When  ca ← rasterize(a, 160, 160)
    And   cb ← rasterize(b, 160, 160)
    Then  coverage_at(ca, 80, 80) = 1
    And   coverage_at(cb, 80, 80) = 0
    And   coverage_at(ca, 80, 20) = 1
    And   coverage_at(cb, 80, 20) = 1
    And   coverage_at(ca, 80, 10) = 0.0625
    And   coverage_at(cb, 80, 10) = 0.0625
    And   ink(ca) = 5499.9375
    And   ink(cb) = 3800.375

  Scenario: Rasterizing within the bounds gives the same coverage
    Given p ← star()
    And   s ← filled(p, "evenodd")
    When  full ← rasterize(s, 160, 160)
    And   within ← rasterize_within(s, bounds(p), 160, 160)
    Then  ink(within) = ink(full)
    And   coverage_at(within, 80, 20) = coverage_at(full, 80, 20)
    And   coverage_at(within, 13, 58) = coverage_at(full, 13, 58)
    And   coverage_at(within, 10, 10) = 0

  Scenario: The box is inclusive of the pixels it touches, and clipped to the buffer
    Given s ← filled(polygon(point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)), "nonzero")
    When  cov ← rasterize_within(s, (1.5, 1.5, 6.5, 6.5), 8, 8)
    And   big ← rasterize_within(s, (-5, -5, 20, 20), 8, 8)
    Then  coverage_at(cov, 1, 1) = 0.25
    And   coverage_at(cov, 6, 6) = 0.25
    And   coverage_at(cov, 3, 3) = 1
    And   ink(cov) = 25
    And   ink(big) = 25
