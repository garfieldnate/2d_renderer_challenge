Feature: Something paths can't do
  smooth_min(a, b, k) is min(a, b) when k is 0 or less. Otherwise, with
  h = max(k - |a - b|, 0) / k, it's min(a, b) - h² k / 4: the same as
  min where a and b are more than k apart, and up to k / 4 less where
  they're close, which rounds the crease where two shapes meet into a
  fillet. field_smooth_union(a, b, k) applies it at every pixel.
  fillet_field(k) is a 160 by 160 field of smooth_min(sd_circle(p,
  point(60, 70), 36), sd_rounded_box(p, point(105, 95), 40, 25, 4), k).

  Scenario: Far apart it's min; close together it's less
    Then  smooth_min(1, 5, 2) = 1
    And   smooth_min(3, 3, 4) = 2
    And   smooth_min(2, 3, 4) = 1.4375
    And   smooth_min(2, 3, 0) = 2

  Scenario: The fillet fills the crease
    Given sharp ← fillet_field(0)
    And   filleted ← fillet_field(32)
    Then  field_at(sharp, 98, 63) = 3.044846
    And   field_at(filleted, 98, 63) = -3.320843
    And   field_at(sharp, 60, 70) = field_at(filleted, 60, 70)
    And   field_smooth_union(fillet_field(0), fillet_field(0), 0).values = fillet_field(0).values
