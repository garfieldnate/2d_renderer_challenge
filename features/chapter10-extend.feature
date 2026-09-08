Feature: Extend modes
  extend(t, mode) folds a parameter that fell outside [0, 1] back in. "pad"
  clamps it to the ends, "repeat" wraps it around, and "reflect" bounces it
  back and forth so the gradient mirrors every unit.

  Scenario Outline: The three modes fold a parameter back in
    Then  extend(<t>, "pad") = <pad>
    And   extend(<t>, "repeat") = <repeat>
    And   extend(<t>, "reflect") = <reflect>

    Examples:
      | t     | pad | repeat | reflect |
      | 0.3   | 0.3 | 0.3    | 0.3     |
      | -0.25 | 0   | 0.75   | 0.25    |
      | 1     | 1   | 0      | 1       |
      | 1.25  | 1   | 0.25   | 0.75    |
      | 1.75  | 1   | 0.75   | 0.25    |
      | 2.25  | 1   | 0.25   | 0.25    |
