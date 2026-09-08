Feature: The image as a paint
  image_paint(img, m, filter, extend) is a paint that samples an image, placed
  on the canvas by matrix m. m maps image space to device space, so a device
  point is taken back through the inverse to find where in the image to look —
  the reason resampling walks destination pixels, not source ones.

  Scenario: The identity transform is bit-exact under every filter
    Given img ← image(2, 2, [opaque(color(1, 0, 0)), opaque(color(0, 1, 0)), opaque(color(0, 0, 1)), opaque(color(1, 1, 1))])
    Then  paint_at(image_paint(img, identity(), "nearest", "clamp"), 0.5, 0.5) = color(1, 0, 0)
    And   paint_at(image_paint(img, identity(), "bilinear", "clamp"), 0.5, 0.5) = color(1, 0, 0)
    And   paint_at(image_paint(img, identity(), "bicubic", "clamp"), 0.5, 0.5) = color(1, 0, 0)
    And   paint_at(image_paint(img, identity(), "bilinear", "clamp"), 1.5, 0.5) = color(0, 1, 0)
    And   paint_at(image_paint(img, identity(), "bilinear", "clamp"), 1.5, 1.5) = color(1, 1, 1)

  Scenario: The transform places the image, and the inverse finds the texel
    Given img ← image(2, 2, [opaque(color(1, 0, 0)), opaque(color(0, 1, 0)), opaque(color(0, 0, 1)), opaque(color(1, 1, 1))])
    When  p ← image_paint(img, translation(10, 0), "nearest", "clamp")
    Then  paint_at(p, 10.5, 0.5) = color(1, 0, 0)
    And   paint_at(p, 11.5, 0.5) = color(0, 1, 0)

  Scenario: A doubled image samples the same texel across two device pixels
    Given img ← image(2, 2, [opaque(color(1, 0, 0)), opaque(color(0, 1, 0)), opaque(color(0, 0, 1)), opaque(color(1, 1, 1))])
    When  p ← image_paint(img, scaling(2, 2), "nearest", "clamp")
    Then  paint_at(p, 0.5, 0.5) = color(1, 0, 0)
    And   paint_at(p, 1.5, 0.5) = color(1, 0, 0)
    And   paint_at(p, 2.5, 0.5) = color(0, 1, 0)
