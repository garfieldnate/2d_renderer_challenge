Feature: Fields compose approximately
  peanut() is two circles, circle_path(60, 80, 40, 96) and
  circle_path(110, 80, 40, 96), overlapping in a waist around x = 85.
  min of their two fields is the field of their union outside it, and it
  isn't inside: at a point deep in the waist, the nearest edge of each
  circle is buried inside the other, and min measures to it anyway. The
  true field of the union is the field of chapter 22's combine of the
  two paths. min_of(a, b) is the smaller number. Shrink both by 20 and
  the difference is a shape.

  Scenario: min is right outside and wrong inside
    Given a ← peanut()[0]
    And   b ← peanut()[1]
    And   u ← combine(a, "nonzero", b, "nonzero", "union")
    Then  min_of(sd_polygon(point(85, 20), a, "nonzero"), sd_polygon(point(85, 20), b, "nonzero")) = 25.000200 ± 0.001
    And   sd_polygon(point(85, 20), u, "nonzero") = 24.998 ± 0.001
    And   min_of(sd_polygon(point(85, 80), a, "nonzero"), sd_polygon(point(85, 80), b, "nonzero")) = -14.992 ± 0.001
    And   sd_polygon(point(85, 80), u, "nonzero") = -31.203 ± 0.001
    And   min_of(sd_polygon(point(60, 80), a, "nonzero"), sd_polygon(point(60, 80), b, "nonzero")) = -39.979 ± 0.001
    And   sd_polygon(point(60, 80), u, "nonzero") = -39.978 ± 0.001
