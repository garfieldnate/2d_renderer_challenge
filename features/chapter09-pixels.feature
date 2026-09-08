Feature: Premultiplied pixels
  A pixel carries a colour and an alpha, and stores the colour already
  multiplied by the alpha: pixel(r, g, b, a) with r, g, b in [0, a].
  from_color(c, a) premultiplies a straight colour; opaque(c) is that at
  alpha 1; pixel_color un-premultiplies and pixel_alpha reads the alpha; CLEAR
  is fully transparent. lerp_pixel blends two pixels straight down the
  premultiplied channels, which is the whole reason for premultiplying:
  half of opaque red and half of nothing is red at half alpha, not a muddy grey.

  Scenario: A colour and an alpha premultiply into a pixel
    Given p ← from_color(color(1, 0, 0), 0.5)
    Then  p = pixel(0.5, 0, 0, 0.5)
    And   pixel_alpha(p) = 0.5
    And   pixel_color(p) = color(1, 0, 0)

  Scenario: Opaque is alpha 1 and leaves the colour alone
    Given p ← opaque(color(0.2, 0.4, 0.8))
    Then  p = pixel(0.2, 0.4, 0.8, 1)
    And   pixel_color(p) = color(0.2, 0.4, 0.8)

  Scenario: A transparent pixel has no colour
    Then  CLEAR = pixel(0, 0, 0, 0)
    And   pixel_color(CLEAR) = color(0, 0, 0)

  Scenario: Averaging premultiplied pixels stays clean
    Given red ← opaque(color(1, 0, 0))
    When  half ← lerp_pixel(red, CLEAR, 0.5)
    Then  half = pixel(0.5, 0, 0, 0.5)
    And   pixel_color(half) = color(1, 0, 0)

  Scenario: A pixel halfway between opaque red and opaque blue
    Given m ← lerp_pixel(opaque(color(1, 0, 0)), opaque(color(0, 0, 1)), 0.5)
    Then  m = pixel(0.5, 0, 0.5, 1)
