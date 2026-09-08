Feature: Groups
  A group is an offscreen layer you draw children into, then composite back at
  one opacity. push_group starts it; paint_into draws a child; scale_opacity
  lowers the whole layer's alpha; pop_group_with_opacity flattens the group and
  composites it at an opacity. At opacity 1 a group is identical to drawing its
  children straight onto the canvas — but below 1 it differs, because the group
  is flattened before the opacity is applied, so overlaps inside it are already
  resolved rather than composited twice.

  Scenario: scale_opacity lowers a layer's premultiplied channels together
    Given g ← layer(1, 1)
    When  set_layer_pixel(g, 0, 0, opaque(color(1, 0, 0)))
    And   h ← scale_opacity(g, 0.5)
    Then  layer_pixel(h, 0, 0) = pixel(0.5, 0, 0, 0.5)

  Scenario: A group at opacity 1 is drawing its children directly
    Given a ← polygon(point(2, 2), point(12, 2), point(12, 12), point(2, 12))
    And   b ← polygon(point(6, 6), point(16, 6), point(16, 16), point(6, 16))
    And   ca ← fill_path(a, "nonzero", 20, 20)
    And   cb ← fill_path(b, "nonzero", 20, 20)
    When  direct ← paint_into(paint_into(layer(20, 20), ca, color(1, 0, 0), 1.0), cb, color(0, 0, 1), 1.0)
    And   group ← paint_into(paint_into(push_group(20, 20), ca, color(1, 0, 0), 1.0), cb, color(0, 0, 1), 1.0)
    And   grouped ← pop_group_with_opacity(group, layer(20, 20), 1.0)
    Then  layer_pixel(grouped, 8, 8) = layer_pixel(direct, 8, 8)
    And   layer_pixel(grouped, 3, 3) = layer_pixel(direct, 3, 3)
    And   layer_pixel(grouped, 14, 14) = layer_pixel(direct, 14, 14)

  Scenario: Below opacity 1 a group and per-child opacity part ways at overlaps
    Given a ← polygon(point(2, 2), point(12, 2), point(12, 12), point(2, 12))
    And   b ← polygon(point(6, 6), point(16, 6), point(16, 16), point(6, 16))
    And   ca ← fill_path(a, "nonzero", 20, 20)
    And   cb ← fill_path(b, "nonzero", 20, 20)
    When  perchild ← paint_into(paint_into(layer(20, 20), ca, color(1, 0, 0), 0.5), cb, color(0, 0, 1), 0.5)
    And   group ← paint_into(paint_into(push_group(20, 20), ca, color(1, 0, 0), 1.0), cb, color(0, 0, 1), 1.0)
    And   grouped ← pop_group_with_opacity(group, layer(20, 20), 0.5)
    Then  layer_pixel(grouped, 3, 3) = layer_pixel(perchild, 3, 3)
    And   layer_pixel(grouped, 8, 8) ≠ layer_pixel(perchild, 8, 8)
