Feature: An image is a grid of pixels
  read_image(ppm) reads a PPM back into an image, decoding each byte from sRGB
  to linear light and storing opaque premultiplied pixels. image_texel(img,
  ix, iy, extend) is the pixel at an integer texel, with an index outside the
  image folded back in by the extend mode: clamp holds the edge, repeat wraps,
  reflect bounces.

  Scenario: A PPM reads back into the image it was written from
    Given c ← canvas(2, 2)
    When  write_pixel(c, 0, 0, color(1, 0, 0))
    And   write_pixel(c, 1, 0, color(0, 1, 0))
    And   write_pixel(c, 0, 1, color(0, 0, 1))
    And   write_pixel(c, 1, 1, color(1, 1, 1))
    And   img ← read_image(canvas_to_p6(c))
    Then  img.width = 2
    And   img.height = 2
    And   pixel_color(image_texel(img, 0, 0)) = color(1, 0, 0)
    And   pixel_color(image_texel(img, 1, 1)) = color(1, 1, 1)
    And   pixel_alpha(image_texel(img, 0, 0)) = 1

  Scenario: Clamp holds the edge texel
    Given img ← image(2, 2, [opaque(color(1, 0, 0)), opaque(color(0, 1, 0)), opaque(color(0, 0, 1)), opaque(color(1, 1, 1))])
    Then  pixel_color(image_texel(img, -1, 0, "clamp")) = color(1, 0, 0)
    And   pixel_color(image_texel(img, 2, 0, "clamp")) = color(0, 1, 0)

  Scenario: Repeat wraps and reflect bounces
    Given img ← image(2, 2, [opaque(color(1, 0, 0)), opaque(color(0, 1, 0)), opaque(color(0, 0, 1)), opaque(color(1, 1, 1))])
    Then  pixel_color(image_texel(img, 2, 0, "repeat")) = color(1, 0, 0)
    And   pixel_color(image_texel(img, -1, 0, "repeat")) = color(0, 1, 0)
    And   pixel_color(image_texel(img, 2, 0, "reflect")) = color(0, 1, 0)
    And   pixel_color(image_texel(img, -1, 0, "reflect")) = color(1, 0, 0)
