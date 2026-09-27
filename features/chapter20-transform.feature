Feature: The transform attribute
  parse_transform(s) turns a transform list into one chapter 4 matrix. The
  list is functions separated by whitespace or a comma, each a name,
  optional whitespace, and its numbers in parentheses (a number_list).
  matrix(a b c d e f) is matrix3(a, c, e, b, d, f, 0, 0, 1), because SVG
  lists the six numbers column by column. translate(tx) means ty = 0 and
  scale(s) means sy = s. rotate(a) is chapter 4's rotation by a degrees,
  and rotate(a cx cy) rotates about (cx, cy): translation(cx, cy) times the
  rotation times translation(-cx, -cy). skewX(a) is shearing(tan a, 0) and
  skewY(a) is shearing(0, tan a), a in degrees. The functions multiply in
  the order written, left to right, so the rightmost one is the first to
  touch a point. An empty or missing attribute is the identity, and so is
  one that doesn't parse: an unknown name, the wrong number of numbers, a
  missing parenthesis.

  Scenario: matrix lists its six numbers column by column
    When  m ← parse_transform("matrix(1 2 3 4 5 6)")
    Then  m is the following matrix:
      | 1 | 3 | 5 |
      | 2 | 4 | 6 |
      | 0 | 0 | 1 |

  Scenario: translate, scale and their one-number forms
    Then  parse_transform("translate(10 20)") * point(1, 1) = point(11, 21)
    And   parse_transform("translate(10)") * point(1, 1) = point(11, 1)
    And   parse_transform("scale(2)") * point(1, 1) = point(2, 2)
    And   parse_transform("scale(2,3)") * point(1, 1) = point(2, 3)
    And   parse_transform("translate(1e1 -2e0)") * point(1, 1) = point(11, -1)

  Scenario: rotate is in degrees, clockwise on screen, and can turn about a point
    Then  parse_transform("rotate(90)") * point(1, 1) = point(-1, 1)
    And   parse_transform("rotate(90 10 10)") * point(1, 1) = point(19, 1)
    And   parse_transform("rotate(90 10 10)") * point(10, 10) = point(10, 10)

  Scenario: skewX leans x with y, skewY leans y with x
    Then  parse_transform("skewX(45)") * point(1, 1) = point(2, 1)
    And   parse_transform("skewY(45)") * point(1, 1) = point(1, 2)
    And   parse_transform("skewX(45)") * point(1, 0) = point(1, 0)

  Scenario: A list applies right to left
    Then  parse_transform("translate(10,20) scale(2)") * point(1, 1) = point(12, 22)
    And   parse_transform("scale(2) translate(10,20)") * point(1, 1) = point(22, 42)
    And   parse_transform("translate(10 20),scale(2)") = parse_transform("translate(10 20) scale(2)")
    And   parse_transform("translate(10 20)rotate(90)") * point(1, 1) = point(9, 21)
    And   parse_transform("translate (5 5)") * point(1, 1) = point(6, 6)

  Scenario: Nothing, or anything broken, is the identity
    Then  parse_transform("") = identity()
    And   parse_transform(none) = identity()
    And   parse_transform("rotate(30 1)") = identity()
    And   parse_transform("translate(1 2) bogus(3)") = identity()
    And   parse_transform("scale(2") = identity()
