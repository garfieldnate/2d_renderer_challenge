Feature: Four pixels at a time
  composite_span(l, y, x, ks, c) composites the colour c into row y of a
  layer through a run of coverages, one pixel at a time: pixel x + i, with
  k = ks[i] and t = 1 - k, becomes (c.r·k + t·r, c.g·k + t·g, c.b·k + t·b,
  k + t·a), with no test for k = 0. composite_span4 does the same four
  pixels to a step, each lane doing exactly the scalar arithmetic in the
  same order with no fused multiply-add, and the pixels left over when the
  run's length isn't a multiple of four one at a time. layers_equal(a, b)
  is true when every channel of every pixel is the same number.

  Scenario: A coverage of 0 is an exact no-op, and 1 is an exact copy
    Given l ← layer(4, 1)
    And   set_layer_pixel(l, 0, 0, pixel(0.1, 0.2, 0.3, 0.5))
    And   set_layer_pixel(l, 1, 0, pixel(0.1, 0.2, 0.3, 0.5))
    And   set_layer_pixel(l, 2, 0, pixel(0.1, 0.2, 0.3, 0.5))
    When  composite_span(l, 0, 0, [0, 1, 0.5], color(0.8, 0.4, 0.2))
    Then  layer_pixel(l, 0, 0) = pixel(0.1, 0.2, 0.3, 0.5)
    And   layer_pixel(l, 1, 0) = pixel(0.8, 0.4, 0.2, 1)
    And   layer_pixel(l, 2, 0) = pixel(0.45, 0.3, 0.25, 0.75)
    And   layer_pixel(l, 3, 0) = pixel(0, 0, 0, 0)

  Scenario: Four at a time gives the same numbers, the leftover pixels included
    Given a ← layer(12, 1)
    And   b ← layer(12, 1)
    And   set_layer_pixel(a, 4, 0, pixel(0.1, 0.2, 0.3, 0.5))
    And   set_layer_pixel(b, 4, 0, pixel(0.1, 0.2, 0.3, 0.5))
    And   set_layer_pixel(a, 10, 0, pixel(0.05, 0.1, 0.02, 0.2))
    And   set_layer_pixel(b, 10, 0, pixel(0.05, 0.1, 0.02, 0.2))
    When  composite_span(a, 0, 1, [0, 1, 0.5, 0.25, 0.1, 0.9, 0, 1, 0.3, 0.7, 0.05], color(0.8, 0.4, 0.2))
    And   composite_span4(b, 0, 1, [0, 1, 0.5, 0.25, 0.1, 0.9, 0, 1, 0.3, 0.7, 0.05], color(0.8, 0.4, 0.2))
    Then  layers_equal(a, b) = true
    And   layer_pixel(b, 4, 0) = pixel(0.275, 0.25, 0.275, 0.625)
    And   layer_pixel(b, 11, 0) = pixel(0.04, 0.02, 0.01, 0.05)
    And   layer_pixel(b, 0, 0) = pixel(0, 0, 0, 0)
