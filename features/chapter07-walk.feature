Feature: Walking an edge down the rows
  accumulate(acc, a, b) deposits a whole edge: it clips the edge to each row it
  crosses and hands each piece to accumulate_row. Heading up the canvas
  (decreasing y) carries a positive height, heading down a negative one, so the
  running sum in the next section is chapter 5's winding number. A horizontal
  edge deposits nothing. An edge above or below the buffer contributes only the
  rows it actually crosses; an edge left of the buffer covers everything to its
  right; an edge right of it deposits nothing.

  Scenario: An edge going up the canvas carries a positive height
    Given acc ← accumulator(4, 3)
    When  accumulate(acc, point(1.5, 3), point(1.5, 0))
    Then  area_at(acc, 1, 0) = 0.5
    And   cover_at(acc, 1, 0) = 1.0
    And   area_at(acc, 1, 1) = 0.5
    And   cover_at(acc, 1, 2) = 1.0

  Scenario: The same edge going down carries a negative height
    Given acc ← accumulator(4, 3)
    When  accumulate(acc, point(1.5, 0), point(1.5, 3))
    Then  area_at(acc, 1, 0) = -0.5
    And   cover_at(acc, 1, 1) = -1.0

  Scenario: A partial-height edge deposits only its height
    Given acc ← accumulator(4, 3)
    When  accumulate(acc, point(1.5, 0.75), point(1.5, 0.25))
    Then  area_at(acc, 1, 0) = 0.25
    And   cover_at(acc, 1, 0) = 0.5
    And   cover_at(acc, 1, 1) = 0

  Scenario: An edge that crosses several rows is clipped to each
    Given acc ← accumulator(4, 3)
    When  accumulate(acc, point(1.5, 2.5), point(1.5, 0.5))
    Then  cover_at(acc, 1, 0) = 0.5
    And   cover_at(acc, 1, 1) = 1.0
    And   cover_at(acc, 1, 2) = 0.5

  Scenario: An edge reaching above and below the buffer fills every row it can
    Given acc ← accumulator(4, 3)
    When  accumulate(acc, point(1.5, 5), point(1.5, -2))
    Then  cover_at(acc, 1, 0) = 1.0
    And   cover_at(acc, 1, 1) = 1.0
    And   cover_at(acc, 1, 2) = 1.0

  Scenario: A horizontal edge deposits nothing
    Given acc ← accumulator(4, 3)
    When  accumulate(acc, point(0, 1), point(3, 1))
    Then  area_at(acc, 1, 1) = 0
    And   cover_at(acc, 1, 1) = 0

  Scenario: An edge entirely left of the buffer covers every cell to its right
    Given acc ← accumulator(4, 3)
    When  accumulate(acc, point(-3, 3), point(-3, 0))
    Then  area_at(acc, 0, 0) = 1.0
    And   cover_at(acc, 0, 0) = 1.0
    And   area_at(acc, 1, 0) = 0

  Scenario: An edge entirely right of the buffer deposits nothing
    Given acc ← accumulator(4, 3)
    When  accumulate(acc, point(10, 3), point(10, 0))
    Then  area_at(acc, 3, 0) = 0
    And   cover_at(acc, 3, 0) = 0
