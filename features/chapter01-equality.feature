Feature: Comparing numbers
  Floating point arithmetic is approximate, so the book never asks two numbers
  to be identical. When a scenario says a = b it means |a - b| ≤ 0.0001. When a
  scenario needs a different tolerance it writes it in the open, as a = b ± ε.

  Scenario: Two numbers that differ by less than the tolerance are equal
    Then  1.0 = 1.0000001 ± 0.00001

  Scenario: Two numbers that differ by more than the tolerance are not
    Then  1.0 ≠ 1.001 ± 0.00001

  Scenario: The default tolerance is 0.0001
    Then  0.1 + 0.2 = 0.3
    And   1.0 = 1.00009
    And   1.0 ≠ 1.0002
