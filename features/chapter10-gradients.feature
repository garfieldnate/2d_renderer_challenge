Feature: The three gradients
  Each gradient turns a device point into a parameter, then looks it up in the
  stop table. linear_t projects the point onto the axis. radial_t solves a
  quadratic for the circle the point lies on, between a start circle and an end
  circle; a focal gradient is the start radius set to zero, and points no
  circle reaches come back as none. conic_t is the angle around a center.

  Scenario: A linear gradient's parameter is the distance along its axis
    Given g ← linear_gradient(point(10, 10), point(110, 10), [], "pad")
    Then  linear_t(g, 10, 10) = 0
    And   linear_t(g, 35, 10) = 0.25
    And   linear_t(g, 60, 10) = 0.5
    And   linear_t(g, 110, 10) = 1

  Scenario: Distance across the axis does not change the parameter
    Given g ← linear_gradient(point(10, 10), point(110, 10), [], "pad")
    Then  linear_t(g, 60, 10) = 0.5
    And   linear_t(g, 60, 50) = 0.5

  Scenario: A linear gradient's colour along the axis is the parameter itself
    Given g ← linear_gradient(point(0, 0), point(100, 0), [stop(0, color(0, 0, 0)), stop(1, color(1, 1, 1))], "pad")
    Then  paint_at(g, 25, 0) = color(0.25, 0.25, 0.25)
    And   paint_at(g, 50, 0) = color(0.5, 0.5, 0.5)

  Scenario: A concentric radial gradient's parameter is distance over radius
    Given g ← radial_gradient(point(50, 50), 0, point(50, 50), 40, [], "pad")
    Then  radial_t(g, 50, 50) = 0
    And   radial_t(g, 70, 50) = 0.5
    And   radial_t(g, 90, 50) = 1

  Scenario: A focal gradient runs from the focal point to the end circle
    Given g ← radial_gradient(point(35, 50), 0, point(50, 50), 40, [], "pad")
    Then  radial_t(g, 35, 50) = 0
    And   radial_t(g, 90, 50) = 1

  Scenario: A conic gradient sweeps the angle around its center
    Given g ← conic_gradient(point(50, 50), -π / 2, [], "pad")
    Then  conic_t(g, 50, 10) = 0
    And   conic_t(g, 90, 50) = 0.25
    And   conic_t(g, 50, 90) = 0.5
    And   conic_t(g, 10, 50) = 0.75
