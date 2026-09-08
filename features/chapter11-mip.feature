Feature: Minification and mip pyramids
  Shrinking an image is a different problem from enlarging it: every
  reconstruction filter drops detail between the pixels it lands on, so a
  minified image sparkles. The standard answer is a mip pyramid: downsample the
  image by half repeatedly, each level the average of the one above, and read
  from the level whose size matches the target. A box downsample preserves the
  average, so a level and its parent agree on the whole image's colour.

  Scenario: Downsample averages each 2x2 block
    Given img ← image(2, 2, [opaque(color(1, 0, 0)), opaque(color(0, 1, 0)), opaque(color(0, 0, 1)), opaque(color(1, 1, 1))])
    When  d ← downsample(img)
    Then  d.width = 1
    And   d.height = 1
    And   pixel_color(image_texel(d, 0, 0)) = color(0.5, 0.5, 0.5)

  Scenario: A mip chain halves down to a single pixel
    Given img ← image(2, 2, [opaque(color(1, 0, 0)), opaque(color(0, 1, 0)), opaque(color(0, 0, 1)), opaque(color(1, 1, 1))])
    When  chain ← mip_chain(img)
    Then  length(chain) = 2
    And   chain[0].width = 2
    And   chain[1].width = 1
    And   pixel_color(image_texel(chain[1], 0, 0)) = color(0.5, 0.5, 0.5)

  Scenario: The mip level follows the minification
    Then  mip_level_for(2.0) = 0
    And   mip_level_for(1.0) = 0
    And   mip_level_for(0.5) = 1
    And   mip_level_for(0.25) = 2
    And   mip_level_for(0.3) = 1
