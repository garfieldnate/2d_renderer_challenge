Feature: The running sum
  resolve(acc, rule) sweeps each row left to right: a cell's winding number is
  the cover of every cell to its left plus its own area, and apply_rule turns
  that number, which may be fractional, into coverage. For "nonzero" that is
  min(1, |w|); for "evenodd" it is the triangle wave that folds |w| into the
  range 0 to 1, so an even winding is empty and an odd one is full.

  Scenario: apply_rule turns a winding number into coverage
    Then  apply_rule(0, "nonzero") = 0
    And   apply_rule(1, "nonzero") = 1
    And   apply_rule(0.25, "nonzero") = 0.25
    And   apply_rule(-0.25, "nonzero") = 0.25
    And   apply_rule(1.5, "nonzero") = 1
    And   apply_rule(2, "nonzero") = 1
    And   apply_rule(0.25, "evenodd") = 0.25
    And   apply_rule(0.75, "evenodd") = 0.75
    And   apply_rule(1.25, "evenodd") = 0.75
    And   apply_rule(1.5, "evenodd") = 0.5
    And   apply_rule(2, "evenodd") = 0
    And   apply_rule(3.25, "evenodd") = 0.75
    And   apply_rule(-1.5, "evenodd") = 0.5

  Scenario: resolve turns one deposited edge into a half-covered column
    Given acc ← accumulator(4, 3)
    When  accumulate(acc, point(1.5, 3), point(1.5, 0))
    And   cov ← resolve(acc, "nonzero")
    Then  coverage_at(cov, 0, 0) = 0
    And   coverage_at(cov, 1, 0) = 0.5
    And   coverage_at(cov, 2, 0) = 1.0
    And   coverage_at(cov, 3, 0) = 1.0
