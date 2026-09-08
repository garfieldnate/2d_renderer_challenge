Feature: Sampling, and the half-pixel offset
  A texel's center is at (tx + 0.5, ty + 0.5), not at (tx, ty). Every sampler
  works in texel-center space, the source coordinate minus 0.5, which is the
  detail that keeps a resampled image from sliding half a pixel. sample_nearest
  takes the texel the point falls in; sample_bilinear blends the four around
  it; sample_bicubic is a Catmull-Rom over sixteen, sharper. All are given a
  2x2 image of red, green, blue, white.

  Scenario: Every sampler returns the texel exactly at its center
    Given img ← image(2, 2, [opaque(color(1, 0, 0)), opaque(color(0, 1, 0)), opaque(color(0, 0, 1)), opaque(color(1, 1, 1))])
    Then  pixel_color(sample_nearest(img, 0.5, 0.5)) = color(1, 0, 0)
    And   pixel_color(sample_bilinear(img, 0.5, 0.5)) = color(1, 0, 0)
    And   pixel_color(sample_bicubic(img, 0.5, 0.5)) = color(1, 0, 0)
    And   pixel_color(sample_bilinear(img, 1.5, 1.5)) = color(1, 1, 1)

  Scenario: Nearest takes the texel the point falls in
    Given img ← image(2, 2, [opaque(color(1, 0, 0)), opaque(color(0, 1, 0)), opaque(color(0, 0, 1)), opaque(color(1, 1, 1))])
    Then  pixel_color(sample_nearest(img, 0.9, 0.1)) = color(1, 0, 0)
    And   pixel_color(sample_nearest(img, 1.1, 0.1)) = color(0, 1, 0)

  Scenario: Bilinear blends toward its neighbours
    Given img ← image(2, 2, [opaque(color(1, 0, 0)), opaque(color(0, 1, 0)), opaque(color(0, 0, 1)), opaque(color(1, 1, 1))])
    Then  pixel_color(sample_bilinear(img, 1.0, 0.5)) = color(0.5, 0.5, 0)
    And   pixel_color(sample_bilinear(img, 1.0, 1.0)) = color(0.5, 0.5, 0.5)

  Scenario: The Catmull-Rom weights sum to one and pass through the samples
    Then  catmull(0) = [0, 1, 0, 0]
    And   catmull(0.5) = [-0.0625, 0.5625, 0.5625, -0.0625]
