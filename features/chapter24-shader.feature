Feature: Paint as a shader
  A shader is a pure function of position: it reads no neighbouring
  pixel, keeps no state, and gives the same colour at a point whatever it
  was asked before. Chapter 10's paint_at already is one. shade_tile(paint,
  tx, ty, seed) evaluates paint_at at the center of every pixel of the 16
  by 16 tile (tx, ty), visiting them in raster order when seed is none and
  in lcg_shuffle(256, seed) order otherwise, and answers the colours in
  raster order.

  Scenario: A gradient asked in any order is the same gradient
    Given g ← radial_gradient(point(20, 20), 0, point(40, 30), 50, [stop(0, color(1, 0, 0)), stop(1, color(0, 0, 1))], "pad")
    When  a ← shade_tile(g, 1, 2, none)
    And   b ← shade_tile(g, 1, 2, 5)
    Then  a = b
    And   a[0] = color(0.735942, 0, 0.264058)
    And   a[255] = color(0.539754, 0, 0.460246)
