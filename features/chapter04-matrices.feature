Feature: Matrices
  A 3 by 3 matrix of real numbers, written row by row. M[r, c] is the
  entry in row r and column c, counting from 0. Matrices compare
  component-wise with the usual tolerance. matrix3 takes nine numbers, row
  by row, for the times a table is too much ceremony.

  Scenario: Constructing and inspecting a matrix
    Given the following matrix M:
      | 1 | 2 | 3 |
      | 4 | 5 | 6 |
      | 7 | 8 | 9 |
    Then  M[0, 0] = 1
    And   M[0, 2] = 3
    And   M[1, 0] = 4
    And   M[1, 1] = 5
    And   M[2, 0] = 7
    And   M[2, 2] = 9
    And   M = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)

  Scenario: Matrix equality with identical matrices
    Given A ← matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
    And   B ← matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
    Then  A = B

  Scenario: Matrix equality with different matrices
    Given A ← matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
    And   B ← matrix3(1, 2, 3, 4, 5, 6, 7, 8, 8)
    Then  A ≠ B

  Scenario: Multiplying two matrices
    Given the following matrix A:
      | 1 | 2 | 3 |
      | 4 | 5 | 6 |
      | 7 | 8 | 9 |
    And   the following matrix B:
      | 2 | -1 | 0 |
      | 1 |  3 | 1 |
      | 0 |  1 | 2 |
    Then  A * B is the following matrix:
      |  4 |  8 |  8 |
      | 13 | 17 | 17 |
      | 22 | 26 | 26 |

  Scenario: Matrix multiplication is not commutative
    Given A ← matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
    And   B ← matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2)
    Then  A * B ≠ B * A

  Scenario: A matrix multiplied by a point
    Given the following matrix A:
      | 1 | 2 | 3 |
      | 4 | 5 | 6 |
      | 0 | 0 | 1 |
    And   p ← point(1, 2)
    Then  A * p = point(8, 20)

  Scenario: A matrix multiplied by a vector ignores the last column
    Given the following matrix A:
      | 1 | 2 | 3 |
      | 4 | 5 | 6 |
      | 0 | 0 | 1 |
    And   v ← vector(1, 2)
    Then  A * v = vector(5, 14)

  Scenario: Multiplying by the identity matrix changes nothing
    Given A ← matrix3(0, 1, 2, 1, 2, 4, 2, 4, 8)
    And   p ← point(1, 2)
    Then  A * identity() = A
    And   identity() * A = A
    And   identity() * p = p

  Scenario: Transposing a matrix
    Given the following matrix A:
      | 0 | 9 | 3 |
      | 9 | 8 | 0 |
      | 1 | 8 | 5 |
    Then  transpose(A) is the following matrix:
      | 0 | 9 | 1 |
      | 9 | 8 | 8 |
      | 3 | 0 | 5 |

  Scenario: Transposing the identity matrix
    Then  transpose(identity()) = identity()

  Scenario: The determinant of a 3 by 3 matrix
    Given the following matrix A:
      |  1 | 2 |  6 |
      | -5 | 8 | -4 |
      |  2 | 6 |  4 |
    Then  determinant(A) = -196

  Scenario: The determinant of a transform is the area factor
    Then  determinant(identity()) = 1
    And   determinant(scaling(2, 3)) = 6
    And   determinant(rotation(0.7)) = 1
    And   determinant(translation(4, 9)) = 1
    And   determinant(scaling(-1, 1)) = -1

  Scenario: Testing an invertible matrix for invertibility
    Given the following matrix A:
      | 3 | 0 |  2 |
      | 2 | 0 | -2 |
      | 0 | 1 |  1 |
    Then  determinant(A) = 10
    And   is_invertible(A) = true

  Scenario: Testing a non-invertible matrix for invertibility
    Given the following matrix A:
      | 1 | 2 | 3 |
      | 2 | 4 | 6 |
      | 0 | 0 | 1 |
    Then  determinant(A) = 0
    And   is_invertible(A) = false

  Scenario: Invertibility is an exact test against zero
    Then  is_invertible(scaling(0.0001, 1)) = true
    And   determinant(scaling(0.0001, 1)) = 0.0001
    And   inverse(scaling(0.0001, 1)) * point(0.0001, 3) = point(1, 3)

  Scenario: Calculating the inverse of a matrix
    Given the following matrix A:
      | 3 | 0 |  2 |
      | 2 | 0 | -2 |
      | 0 | 1 |  1 |
    And   B ← inverse(A)
    Then  B[0, 0] = 0.2
    And   B[1, 2] = 1
    And   B[2, 1] = -0.3
    And   B is the following matrix:
      |  0.2 |  0.2 | 0 |
      | -0.2 |  0.3 | 1 |
      |  0.2 | -0.3 | 0 |
    And   A * B = identity()

  Scenario: Multiplying a product by its inverse
    Given A ← matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9)
    And   B ← matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2)
    And   C ← A * B
    Then  C * inverse(B) = A

  Scenario: The inverse of a transform is a transform
    Given A ← translation(5, -3) * rotation(π / 6) * scaling(2, 3)
    And   B ← inverse(A)
    Then  B[2, 0] = 0
    And   B[2, 1] = 0
    And   B[2, 2] = 1
    And   B[0, 0] = 0.4330
    And   B[0, 2] = -1.4151
    And   B[1, 2] = 1.6994
    And   B * A = identity()
