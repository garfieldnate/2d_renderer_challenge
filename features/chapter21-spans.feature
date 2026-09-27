Feature: Spans
  draw_tiled(l, t, paint, alpha, st) paints a tiled coverage into a layer
  tile by tile, skipping empty tiles. In a partial tile each pixel whose
  coverage times alpha is above 0 is blended, as draw_coverage does. A
  solid tile is a run of pixels of the same coverage, 1: when the paint is
  a solid colour and alpha is 1, every pixel of it is written as that
  colour at alpha 1, a copy, which is exactly what the blend would have
  produced (c times 1 plus 0 times what was there); otherwise every pixel
  of it is blended at alpha. Each blended pixel adds 1 to st.blends and
  each copied one 1 to st.copies. A solid paint's colour is looked up once
  for the whole tile, not once per pixel.

  Scenario: A solid opaque colour copies its solid tiles and blends its edges
    Given sq ← polygon(point(4, 4), point(60, 4), point(60, 60), point(4, 60))
    And   t ← fill_path_tiled(sq, "nonzero", 64, 64, stats())
    And   st ← stats()
    And   l ← layer(64, 64)
    When  draw_tiled(l, t, solid(color(1, 0, 0)), 1, st)
    Then  st.copies = 1024
    And   st.blends = 2112
    And   layer_pixel(l, 30, 30) = pixel(1, 0, 0, 1)
    And   layer_pixel(l, 2, 2) = pixel(0, 0, 0, 0)

  Scenario: The copies draw exactly what blending would have
    Given sq ← polygon(point(4.5, 4.5), point(59.5, 4.5), point(59.5, 59.5), point(4.5, 59.5))
    And   a ← layer(64, 64)
    And   b ← layer(64, 64)
    When  draw_tiled(a, fill_path_tiled(sq, "nonzero", 64, 64, stats()), solid(color(0.2, 0.6, 0.9)), 1, stats())
    And   draw_coverage(b, fill_path(sq, "nonzero", 64, 64), solid(color(0.2, 0.6, 0.9)), 1)
    Then  layers_equal(a, b) = true

  Scenario: At half alpha nothing is copied
    Given sq ← polygon(point(4, 4), point(60, 4), point(60, 60), point(4, 60))
    And   t ← fill_path_tiled(sq, "nonzero", 64, 64, stats())
    And   st ← stats()
    And   l ← layer(64, 64)
    When  draw_tiled(l, t, solid(color(1, 0, 0)), 0.5, st)
    Then  st.copies = 0
    And   st.blends = 3136
    And   layer_pixel(l, 30, 30) = pixel(0.5, 0, 0, 0.5)
