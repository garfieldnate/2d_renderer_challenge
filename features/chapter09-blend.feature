Feature: Blend modes
  blend(mode, src, dst) is source-over with the overlap first passed through a
  blend function. With mode "normal" the blend function returns the source, so
  blend is exactly over. The twelve separable modes act on each channel on its
  own; with an opaque source over an opaque destination the result is the blend
  function itself. blend_color(mode, backdrop, source) is that function.

  Scenario: Normal is source-over
    Given src ← from_color(color(1, 0, 0), 0.6)
    And   dst ← from_color(color(0, 0, 1), 0.4)
    Then  blend("normal", src, dst) = over(src, dst)

  Scenario Outline: The separable modes, opaque source 0.8 over opaque backdrop 0.3
    Given src ← opaque(color(0.8, 0.8, 0.8))
    And   dst ← opaque(color(0.3, 0.3, 0.3))
    Then  blend("<mode>", src, dst).r = <value> ± 0.0001

    Examples:
      | mode        | value    |
      | normal      | 0.8      |
      | multiply    | 0.24     |
      | screen      | 0.86     |
      | overlay     | 0.48     |
      | darken      | 0.3      |
      | lighten     | 0.8      |
      | color-dodge | 1.0      |
      | color-burn  | 0.125    |
      | hard-light  | 0.72     |
      | soft-light  | 0.448634 |
      | difference  | 0.5      |
      | exclusion   | 0.62     |

  Scenario: A blended pixel over an opaque backdrop stays opaque
    Given src ← opaque(color(0.8, 0.8, 0.8))
    And   dst ← opaque(color(0.3, 0.3, 0.3))
    Then  blend("multiply", src, dst).a = 1
    And   blend("screen", src, dst).a = 1

  Scenario: The four non-separable modes mix a saturated red with a blue
    Given src ← opaque(color(0.9, 0.2, 0.2))
    And   dst ← opaque(color(0.2, 0.4, 0.8))
    Then  pixel_color(blend("hue", src, dst)) = color(0.804, 0.204, 0.204) ± 0.0001
    And   pixel_color(blend("saturation", src, dst)) = color(0.169333, 0.402667, 0.869333) ± 0.0001
    And   pixel_color(blend("color", src, dst)) = color(0.874, 0.174, 0.174) ± 0.0001
    And   pixel_color(blend("luminosity", src, dst)) = color(0.226, 0.426, 0.826) ± 0.0001

  Scenario: A non-separable blend that overflows is clipped back into range
    Given src ← opaque(color(0.95, 0.95, 0.95))
    And   dst ← opaque(color(0.2, 0.45, 0.95))
    Then  pixel_color(blend("luminosity", src, dst)) = color(0.927885, 0.951923, 1.0) ± 0.0001

  Scenario: blend_color is the blend function on two straight colours
    Then  blend_color("multiply", color(0.8, 0.8, 0.8), color(0.5, 0.5, 0.5)) = color(0.4, 0.4, 0.4)
    And   blend_color("color", color(0.2, 0.4, 0.8), color(0.9, 0.2, 0.2)) = color(0.874, 0.174, 0.174) ± 0.0001
