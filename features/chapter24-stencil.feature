Feature: Filling without sorting
  triangle_winding(a, b, c, x, y) is chapter 5's winding_at for the
  closed triangle a, b, c at the point (x, y): +1 inside a triangle that
  runs clockwise on screen, -1 inside one that runs counterclockwise, 0
  outside, with chapter 5's half-open rule on the edges. A stencil is one
  whole number per pixel, all 0 at first, and a count of fragments.
  stencil_triangle(s, a, b, c, ox, oy) visits every pixel of the
  triangle's bounding box on the canvas, from floor(min x - ox) to
  ceil(max x - ox) and the same in y, both ends included, and adds
  triangle_winding at the pixel's sample point (x + ox, y + oy); each
  pixel it changes adds 1 to fragments. fan_anchor(p) is the first point
  of the first subpath that has one, or point(0, 0).
  stencil_buffer(p, width, height, ox, oy) adds, for every edge (a, b) of
  chapter 5's edges(p), the triangle (anchor, a, b); ox and oy are 0.5
  when they're left out. Because the fan's spokes cancel exactly under the
  half-open rule, the stencil at every pixel is winding_at(p, x + ox, y +
  oy). cover(s, rule) is a coverage buffer of 1 where the stencil fills
  under the rule, 0 elsewhere. stencil_at(s, x, y) reads one pixel, and
  winding_mismatches(s, p) counts the pixels where the stencil and
  winding_at at the pixel center disagree.

  Scenario: One triangle, either way round
    Then  triangle_winding(point(0, 0), point(4, 0), point(0, 4), 1, 1) = 1
    And   triangle_winding(point(0, 0), point(0, 4), point(4, 0), 1, 1) = -1
    And   triangle_winding(point(0, 0), point(4, 0), point(0, 4), 3, 3) = 0

  Scenario: A square as four signed triangles
    Given sq ← polygon(point(1, 1), point(5, 1), point(5, 5), point(1, 5))
    When  s ← stencil_buffer(sq, 6, 6)
    Then  fan_anchor(sq) = point(1, 1)
    And   s.values = [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0]
    And   s.fragments = 16

  Scenario: The stencil is chapter 5's winding number at every pixel
    Given s ← stencil_buffer(star(), 160, 160)
    And   g ← stencil_buffer(plate_glyph(), 200, 200)
    Then  winding_mismatches(s, star()) = 0
    And   winding_mismatches(g, plate_glyph()) = 0
    And   stencil_at(s, 80, 80) = 2
    And   stencil_at(s, 80, 30) = 1
    And   stencil_at(s, 5, 5) = 0
    And   s.fragments = 13660
    And   g.fragments = 22639

  Scenario: Cover keeps what the rule fills
    Given s ← stencil_buffer(star(), 160, 160)
    Then  coverage_at(cover(s, "nonzero"), 80, 80) = 1
    And   coverage_at(cover(s, "evenodd"), 80, 80) = 0
    And   coverage_at(cover(s, "evenodd"), 80, 30) = 1
