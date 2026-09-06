Feature: How big is a transform
  approx_scale(m) is one number for how much m stretches lengths: the
  square root of the absolute value of the determinant of its upper-left
  2 by 2, which is ad - bc for the block [[a, b], [c, d]]. Exact for
  uniform scales and rotations, a compromise otherwise, and the chapter
  says which.

  Scenario: The identity, a translation and a rotation don't stretch
    Then  approx_scale(identity()) = 1
    And   approx_scale(translation(7, 9)) = 1
    And   approx_scale(rotation(1.1)) = 1

  Scenario: A uniform scale is reported exactly
    Then  approx_scale(scaling(2, 2)) = 2
    And   approx_scale(scaling(0.5, 0.5)) = 0.5
    And   approx_scale(scaling(3, 3) * rotation(0.7)) = 3
    And   approx_scale(translation(5, 5) * scaling(3, 3)) = 3

  Scenario: A reflection is not a negative scale
    Then  approx_scale(scaling(-2, 2)) = 2

  Scenario: A non-uniform scale is reported as the geometric mean
    Then  approx_scale(scaling(4, 1)) = 2
    And   approx_scale(scaling(4, 1) * rotation(0.4)) = 2
    And   approx_scale(scaling(9, 1)) = 3

  Scenario: A shear that preserves area reports 1
    Then  approx_scale(shearing(1, 0)) = 1
    And   approx_scale(shearing(0.5, 0.5)) = 0.8660

  Scenario: A collapsed transform reports 0
    Then  approx_scale(scaling(0, 1)) = 0
    And   approx_scale(matrix3(1, 2, 0, 2, 4, 0, 0, 0, 1)) = 0
