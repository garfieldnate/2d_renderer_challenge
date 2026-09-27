Feature: Numbers
  Every attribute the chapter parses is made of numbers, and SVG writes
  them tighter than intuition expects. read_number(s, i) reads the number
  that starts at index i of s and answers the number and the index right
  past it, or none and i when there's no number there. A number is an
  optional sign, digits, an optional point and more digits (at least one
  digit somewhere), and an optional exponent: e or E, an optional sign,
  and at least one digit. An e with no digit after it isn't part of the
  number. A second point ends the number, so ".5.5" is two numbers, and a
  sign ends it too, so "30-40" is two. number_list(s) reads a list: numbers
  separated by whitespace (space, tab, carriage return, newline) and at
  most one comma, with whitespace around the comma allowed, stopping at the
  first thing that isn't a number. read_flag(s, i) reads an arc flag, which
  is the single character 0 or 1 and needs no separator after it. In the
  strings below \t is a tab and \n a newline, as in most languages.

  Scenario: A number is read, and the index moves past it
    Then  read_number("12.5e1,3", 0) = (125, 6)
    And   read_number("M-.5", 1) = (-0.5, 4)
    And   read_number("x", 0) = (none, 0)
    And   read_number("-", 0) = (none, 0)
    And   read_number(".", 0) = (none, 0)

  Scenario: Signs and a second point separate numbers without any space
    Then  number_list("10,20 30-40") = (10, 20, 30, -40)
    And   number_list(".5.5") = (0.5, 0.5)
    And   number_list("0.5.5.5") = (0.5, 0.5, 0.5)
    And   number_list("+3 -0") = (3, 0)

  Scenario: Exponents, and an e that isn't one
    Then  number_list("1e2 1E-1 -.5e+1") = (100, 0.1, -5)
    And   number_list("1e5.5") = (100000, 0.5)
    And   number_list("3.") = (3,)
    And   number_list("1e") = (1,)

  Scenario: One comma between numbers, and the list stops at anything else
    Then  number_list("5 , 6") = (5, 6)
    And   number_list(" 5\t6\n7 ") = (5, 6, 7)
    And   number_list("5,,6") = (5,)
    And   number_list("1 2 x 3") = (1, 2)
    And   number_list("") = ()

  Scenario: A flag is one character and needs no separator
    Then  read_flag("0110", 0) = (0, 1)
    And   read_flag("0110", 1) = (1, 2)
    And   read_flag("2", 0) = (none, 0)
