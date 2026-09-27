Feature: Glyph atlases
  bake_box(font, name, size, spread) is chapter 17's bitmap box at the
  quarter 0 grown by spread texels on every side: with s = size /
  units_per_em and glyph_bounds (x0, y0, x1, y1), left = floor(x0 s) -
  spread, right = ceil(x1 s) + spread, top = floor(-y1 s) - spread,
  bottom = ceil(-y0 s) + spread, and the answer is (left, top, right -
  left, bottom - top) and the matrix text_matrix(font, size, -left,
  -top), which puts the box's corner at the origin. bake_sdf(font, name,
  size, spread) is a baked glyph: one field over the box, the glyph's
  signed distance at every texel center (the least distance_to_quadratic
  to its quadratics through the matrix, negative where glyph_path through
  the matrix at 0.01 winds nonzero), clamped to ±spread; and its left and
  top. sample_field(f, sx, sy) is chapter 11's bilinear sample in
  texel-center space: gx = sx - 0.5, gy = sy - 0.5, the four texels
  round (floor(gx), floor(gy)) clamped to the field, blended by the
  fractions. median3(a, b, c) is max(min(a, b), min(max(a, b), c)).
  draw_baked(c, baked, scale, x, y, col) draws a baked glyph with its
  origin at (x, y), each texel scale pixels wide: for every pixel of the
  canvas from floor(x + left × scale), floor(y + top × scale) to ceil(x +
  (left + width) × scale), ceil(y + (top + height) × scale), exclusive,
  u = (px + 0.5 - x) / scale - left and v likewise; sample every channel
  at (u, v); the distance in texels is the one channel or the median of
  three; and the pixel mixes toward col in linear light by clamp(0.5 -
  scale × distance, 0, 1) when that's above 0.

  A multi-channel field colours the edges. The channels are the bits RED
  1, GREEN 2 and BLUE 4; an edge is CYAN (6), MAGENTA (5), YELLOW (3) or
  WHITE (7). is_corner(a, b), for unit directions, is dot(a, b) ≤ 0 or
  |cross(a, b)| > sin(3). color_edges(contour) takes one closed contour's
  curves and answers (curves, masks): the corners are the curves whose
  start direction (derivative at 0, or the chord where that's zero,
  normalized) makes a corner with the end direction of the curve before.
  No corners: every mask WHITE. Otherwise the curves are rotated to start
  at the first corner. One corner: while there are fewer than 3 curves,
  split every curve at 0.5; then curve j of m is CYAN, WHITE or MAGENTA
  as floor(3j / m) is 0, 1 or 2. More corners: each corner starts a run,
  runs alternate CYAN and MAGENTA from the first, and when the number of
  runs is odd the last is YELLOW. Neighbouring runs share exactly one
  channel. pseudo_distance(p, c, t, d), for the nearest t of curve c and
  its distance d: at t = 0 with dot(p - start, start direction) < 0, or
  at t = 1 with dot(p - end, end direction) > 0, it's |cross(direction, p
  - that end)|, the distance to the end's tangent line; otherwise d. It's
  negative when cross(direction at t, p - point_at(c, t)) > 0, the
  curve's right, which is inside for the clockwise contours chapter 16's
  flip makes. bake_msdf(font, name, size, spread) has three channels over
  the box; at each texel center p, for each channel, of the coloured
  edges that carry it, the one with the least distance wins, and when
  two are within 10⁻¹² of each other at an end, the one whose end
  direction is more nearly at right angles to p - that end, by the least
  |dot(direction, unit(p - end))|; the channel is that edge's
  pseudo_distance, clamped to ±spread. bake_mtsdf adds bake_sdf's field
  as a fourth channel. line_curve(a, b) is a straight edge as chapter 16
  makes one, quadratic(a, (a + b) / 2, b); circle_curves(cx, cy, r) is
  eight quadratics, ends on the circle at angles 2πi / 8 and controls at
  radius r / cos(π / 8) halfway between.

  Scenario: The box a glyph is baked into
    Given f ← roboto()
    When  b ← bake_sdf(f, glyph_name(f, 69), 16, 3)
    Then  b.left = -2
    And   b.top = -15
    And   b.width = 14
    And   b.height = 18
    And   field_at(b.channels[0], 0, 0) = 3
    And   field_at(b.channels[0], 4, 9) = -0.401566

  Scenario: What a corner is
    Then  is_corner(vector(1, 0), vector(0, 1)) = true
    And   is_corner(vector(1, 0), vector(-1, 0)) = true
    And   is_corner(vector(1, 0), vector(0.995004165, 0.099833417)) = false
    And   is_corner(vector(1, 0), vector(0.980066578, 0.198669331)) = true

  Scenario: Colouring edges
    Given sq ← [line_curve(point(0, 0), point(10, 0)), line_curve(point(10, 0), point(10, 10)), line_curve(point(10, 10), point(0, 10)), line_curve(point(0, 10), point(0, 0))]
    And   tri ← [line_curve(point(0, 0), point(10, 0)), line_curve(point(10, 0), point(5, 8)), line_curve(point(5, 8), point(0, 0))]
    And   house ← [line_curve(point(0, 0), point(10, 0)), line_curve(point(10, 0), point(10, 10)), line_curve(point(10, 10), point(5, 15)), line_curve(point(5, 15), point(0, 10)), line_curve(point(0, 10), point(0, 0))]
    And   drop ← [quadratic(point(0, 0), point(20, -20), point(30, 0)), quadratic(point(30, 0), point(40, 20), point(20, 20)), quadratic(point(20, 20), point(0, 20), point(0, 0))]
    Then  color_edges(sq)[1] = [6, 5, 6, 5]
    And   color_edges(tri)[1] = [6, 5, 3]
    And   color_edges(house)[1] = [6, 5, 6, 5, 3]
    And   color_edges(drop)[1] = [6, 7, 5]
    And   color_edges(circle_curves(50, 50, 40))[1] = [7, 7, 7, 7, 7, 7, 7, 7]

  Scenario: Pseudo-distance runs straight on past an end
    Given e ← line_curve(point(0, 0), point(10, 0))
    Then  pseudo_distance(point(5, 3), e, 0.5, 3) = -3
    And   pseudo_distance(point(5, -3), e, 0.5, 3) = 3
    And   pseudo_distance(point(14, 3), e, 1, 5) = -3
    And   pseudo_distance(point(-4, -3), e, 0, 5) = 3

  Scenario: A texel's own value is at its center
    Given f ← field_of(3, 2, [0, 4, 8, 2, 6, 10])
    Then  sample_field(f, 1.5, 0.5) = 4
    And   sample_field(f, 1, 0.5) = 2
    And   sample_field(f, 1.5, 1) = 5
    And   sample_field(f, 0, 0) = 0
    And   sample_field(f, 9, 9) = 10

  Scenario: The median
    Then  median3(1, 5, 3) = 3
    And   median3(-2, 4, -1) = -1
    And   median3(7, 7, 2) = 7

  Scenario: Three channels at one texel
    Given f ← roboto()
    When  m ← bake_msdf(f, glyph_name(f, 69), 16, 3)
    Then  field_at(m.channels[0], 4, 9) = -0.320313
    And   field_at(m.channels[1], 4, 9) = -0.242188
    And   field_at(m.channels[2], 4, 9) = -0.320313
