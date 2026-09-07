Feature: One edge in one row
  accumulate_row(acc, row, x0, x1, height) deposits the piece of an edge that
  lies in a single row, running from x0 to x1 across it and carrying a signed
  height. The height is shared among the cells the piece crosses in proportion
  to the width it has in each, and each cell's area is its share weighted by
  how far to the left of the cell the piece sits.

  Scenario: A piece that stays in one cell
    Given acc ← accumulator(4, 3)
    When  accumulate_row(acc, 0, 1.5, 1.5, 1.0)
    Then  area_at(acc, 1, 0) = 0.5
    And   cover_at(acc, 1, 0) = 1.0

  Scenario: A slanted piece in one cell leans its area toward the left
    Given acc ← accumulator(4, 3)
    When  accumulate_row(acc, 0, 1.0, 1.5, 1.0)
    Then  area_at(acc, 1, 0) = 0.75
    And   cover_at(acc, 1, 0) = 1.0

  Scenario: A piece that spans several cells shares its height by width
    Given acc ← accumulator(4, 3)
    When  accumulate_row(acc, 2, 0.0, 3.0, 1.0)
    Then  area_at(acc, 0, 2) = 0.1667 ± 0.0001
    And   area_at(acc, 1, 2) = 0.1667 ± 0.0001
    And   area_at(acc, 2, 2) = 0.1667 ± 0.0001
    And   cover_at(acc, 0, 2) = 0.3333 ± 0.0001
    And   cover_at(acc, 1, 2) = 0.3333 ± 0.0001
    And   cover_at(acc, 2, 2) = 0.3333 ± 0.0001

  Scenario: A negative height deposits negative numbers
    Given acc ← accumulator(4, 3)
    When  accumulate_row(acc, 0, 1.5, 1.5, -1.0)
    Then  area_at(acc, 1, 0) = -0.5
    And   cover_at(acc, 1, 0) = -1.0
