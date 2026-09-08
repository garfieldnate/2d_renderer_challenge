Feature: The stop table
  A gradient is a table of colour stops, each an offset in [0, 1] and a colour.
  sample_stops(stops, t) is the colour at parameter t: the first colour below
  the first stop, the last colour above the last stop, and a straight blend in
  linear light between the two stops that bracket t, found by binary search.

  Scenario: A stop offset returns its own colour
    Given s ← [stop(0, color(0, 0, 0)), stop(0.5, color(1, 0, 0)), stop(1, color(1, 1, 1))]
    Then  sample_stops(s, 0) = color(0, 0, 0)
    And   sample_stops(s, 0.5) = color(1, 0, 0)
    And   sample_stops(s, 1) = color(1, 1, 1)

  Scenario: Between two stops is a straight blend
    Given s ← [stop(0, color(0, 0, 0)), stop(0.5, color(1, 0, 0)), stop(1, color(1, 1, 1))]
    Then  sample_stops(s, 0.25) = color(0.5, 0, 0)
    And   sample_stops(s, 0.75) = color(1, 0.5, 0.5)

  Scenario: Outside the ends clamps to the end colours
    Given s ← [stop(0, color(0, 0, 0)), stop(0.5, color(1, 0, 0)), stop(1, color(1, 1, 1))]
    Then  sample_stops(s, -0.3) = color(0, 0, 0)
    And   sample_stops(s, 1.5) = color(1, 1, 1)

  Scenario: Uneven stops still blend by their own spacing
    Given s ← [stop(0, color(0, 0, 0)), stop(0.8, color(1, 0, 0)), stop(1, color(0, 0, 1))]
    Then  sample_stops(s, 0.4) = color(0.5, 0, 0)
    And   sample_stops(s, 0.9) = color(0.5, 0, 0.5)
