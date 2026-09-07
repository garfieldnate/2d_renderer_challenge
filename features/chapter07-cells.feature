Feature: Two numbers per cell
  The accumulator holds two numbers per cell, not one. accumulator(w, h) is a
  grid of them, all zero. area_at(acc, x, y) is what the cell itself has
  collected; cover_at(acc, x, y) is what it carries to every cell on its
  right. add_cell(acc, x, row, area, cover) deposits into one cell. A deposit
  left of the buffer folds onto column 0, where it becomes all cover; a
  deposit right of the buffer is dropped, because nothing is to its right.

  Scenario: A fresh accumulator is all zeros
    Given acc ← accumulator(4, 3)
    Then  acc.width = 4
    And   acc.height = 3
    And   area_at(acc, 1, 0) = 0
    And   cover_at(acc, 3, 2) = 0

  Scenario: add_cell deposits an area and a cover
    Given acc ← accumulator(4, 3)
    When  add_cell(acc, 1, 0, 0.3, 0.7)
    Then  area_at(acc, 1, 0) = 0.3
    And   cover_at(acc, 1, 0) = 0.7
    And   area_at(acc, 0, 0) = 0
    And   cover_at(acc, 2, 0) = 0

  Scenario: add_cell accumulates rather than overwrites
    Given acc ← accumulator(4, 3)
    When  add_cell(acc, 2, 1, 0.25, 0.5)
    And   add_cell(acc, 2, 1, 0.25, 0.5)
    Then  area_at(acc, 2, 1) = 0.5
    And   cover_at(acc, 2, 1) = 1.0

  Scenario: A deposit left of the buffer folds onto column 0 as cover
    Given acc ← accumulator(4, 3)
    When  add_cell(acc, -2, 0, 0.3, 0.7)
    Then  area_at(acc, 0, 0) = 0.7
    And   cover_at(acc, 0, 0) = 0.7

  Scenario: A deposit right of the buffer is dropped
    Given acc ← accumulator(4, 3)
    When  add_cell(acc, 9, 0, 0.3, 0.7)
    Then  area_at(acc, 3, 0) = 0
    And   cover_at(acc, 3, 0) = 0
