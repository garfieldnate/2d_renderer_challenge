Feature: Soft masks
  A soft mask is a clip whose values are between 0 and 1 instead of only 0 or
  1, and it multiplies in exactly the same way. soft_mask is a radial falloff,
  coverage 1 at its center fading to 0 at radius r, so multiplying a shape by
  it fades the shape out toward the edge instead of cutting it hard.

  Scenario: A soft mask fades from its center to its edge
    Given m ← soft_mask(6, 6, 5, 12, 12)
    Then  coverage_at(m, 5, 5) = 0.8586 ± 0.0001
    And   coverage_at(m, 1, 6) = 0.0945 ± 0.0001
    And   coverage_at(m, 0, 0) = 0

  Scenario: A shape multiplied by a soft mask keeps its interior and fades its rim
    Given shape ← fill_path(polygon(point(0, 0), point(12, 0), point(12, 12), point(0, 12)), "nonzero", 12, 12)
    And   m ← soft_mask(6, 6, 5, 12, 12)
    When  masked ← multiply_coverage(shape, m)
    Then  coverage_at(masked, 5, 5) = 0.8586 ± 0.0001
    And   coverage_at(masked, 0, 0) = 0
