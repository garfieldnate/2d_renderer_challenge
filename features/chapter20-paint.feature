Feature: Paint servers
  A fill or stroke of url(#id) names a gradient element somewhere in the
  document. transformed_paint(paint, m) is a chapter 10 paint seen through
  a matrix: its colour at a device point is the inner paint's colour at
  inverse(m) times that point, so a gradient can be written in any
  coordinates and m puts it on the canvas. gradient_stops(el) reads the
  stop children in order (other children are skipped): an offset is a
  number or a percentage (divided by 100), clamped to [0, 1] and raised to
  the offset before it if it's smaller; its colour is the stop's computed
  stop-color (initial black, not inherited, from an attribute or a style
  declaration). paint_server(root, ref, bbox, ctm) builds the paint:
  gradientUnits objectBoundingBox (the default) means the gradient's
  coordinates live in the unit square of bbox, the shape's user-space
  bounds, so the matrix is ctm times translation(x0, y0) times scaling(x1 -
  x0, y1 - y0); userSpaceOnUse means they're in user space and the matrix
  is ctm. Either way gradientTransform is multiplied on last, on the right.
  A linearGradient reads x1, y1, x2, y2 (defaults 0, 0, 1, 0); a
  radialGradient reads cx, cy, r (defaults 0.5) and fx, fy (defaults cx,
  cy) and fr (default 0) and becomes chapter 10's radial_gradient from the
  focal circle (fx, fy, fr) to the circle (cx, cy, r). A coordinate is a
  number or a percentage. spreadMethod pad, reflect or repeat is chapter
  10's extend mode (pad when absent). The answer is none when the id names
  nothing, or something that isn't a gradient, or a gradient with no
  stops, or when an objectBoundingBox gradient meets a box of zero width or
  height; a single stop is a solid paint of its colour, and so are a linear
  gradient whose two points coincide and a radial one whose r is zero,
  painted in the last stop's colour.

  Scenario: A paint seen through a matrix
    Given g ← linear_gradient(point(0, 0), point(1, 0), [stop(0, color(0, 0, 0)), stop(1, color(1, 1, 1))], "pad")
    Then  paint_at(transformed_paint(g, scaling(10, 1)), 5, 0) = color(0.5, 0.5, 0.5)
    And   paint_at(transformed_paint(g, translation(10, 0) * scaling(10, 1)), 12.5, 3) = color(0.25, 0.25, 0.25)

  Scenario: Stops are fractions, never going backwards, and only stop children count
    Given root ← parse_xml("<linearGradient><stop offset='50%' style='stop-color: red'/><stop offset='20%' stop-color='blue'/><circle/><stop offset='1.5' stop-color='lime'/></linearGradient>")
    When  stops ← gradient_stops(root)
    Then  length(stops) = 3
    And   stops[0] = stop(0.5, color(1, 0, 0))
    And   stops[1] = stop(0.5, color(0, 0, 1))
    And   stops[2] = stop(1, color(0, 1, 0))

  Scenario: objectBoundingBox spreads the gradient across the shape's bounds
    Given root ← parse_xml("<svg><linearGradient id='a'><stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/></linearGradient></svg>")
    When  p ← paint_server(root, "url(#a)", (10, 0, 30, 10), identity())
    Then  paint_at(p, 10, 5) = color(0, 0, 0)
    And   paint_at(p, 15, 5) = color(0.25, 0.25, 0.25)
    And   paint_at(p, 20, 5) = color(0.5, 0.5, 0.5)
    And   paint_at(p, 30, 5) = color(1, 1, 1)
    And   paint_at(paint_server(root, "url(#a)", (10, 0, 30, 10), scaling(2, 2)), 40, 10) = color(0.5, 0.5, 0.5)

  Scenario: userSpaceOnUse leaves the coordinates in user space
    Given root ← parse_xml("<svg><linearGradient id='u' gradientUnits='userSpaceOnUse' x1='0' y1='0' x2='100' y2='0'><stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/></linearGradient></svg>")
    Then  paint_at(paint_server(root, "url(#u)", (10, 0, 30, 10), identity()), 50, 5) = color(0.5, 0.5, 0.5)
    And   paint_at(paint_server(root, "url(#u)", (10, 0, 30, 10), scaling(2, 2)), 100, 0) = color(0.5, 0.5, 0.5)

  Scenario: gradientTransform applies inside the bounding box's square
    Given root ← parse_xml("<svg><linearGradient id='t' gradientTransform='rotate(90)'><stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/></linearGradient></svg>")
    When  p ← paint_server(root, "url(#t)", (10, 0, 30, 10), identity())
    Then  paint_at(p, 20, 2.5) = color(0.25, 0.25, 0.25)
    And   paint_at(p, 11, 5) = color(0.5, 0.5, 0.5)

  Scenario: spreadMethod is the extend mode
    Given root ← parse_xml("<svg><linearGradient id='r' x2='0.25' spreadMethod='reflect'><stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/></linearGradient><linearGradient id='p' x2='25%' spreadMethod='repeat'><stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/></linearGradient></svg>")
    When  r ← paint_server(root, "url(#r)", (10, 0, 30, 10), identity())
    And   p ← paint_server(root, "url(#p)", (10, 0, 30, 10), identity())
    Then  paint_at(r, 17.5, 5) = color(0.5, 0.5, 0.5)
    And   paint_at(r, 20, 5) = color(0, 0, 0)
    And   paint_at(r, 22.5, 5) = color(0.5, 0.5, 0.5)
    And   paint_at(p, 19.9, 5) = color(0.98, 0.98, 0.98)
    And   paint_at(p, 20.1, 5) = color(0.02, 0.02, 0.02)

  Scenario: A radial gradient, centred and focal
    Given root ← parse_xml("<svg><radialGradient id='c'><stop offset='0' stop-color='white'/><stop offset='1' stop-color='black'/></radialGradient><radialGradient id='f' fx='0.25'><stop offset='0' stop-color='white'/><stop offset='1' stop-color='black'/></radialGradient></svg>")
    When  c ← paint_server(root, "url(#c)", (10, 0, 30, 10), identity())
    And   f ← paint_server(root, "url(#f)", (10, 0, 30, 10), identity())
    Then  paint_at(c, 20, 5) = color(1, 1, 1)
    And   paint_at(c, 25, 5) = color(0.5, 0.5, 0.5)
    And   paint_at(c, 20, 0) = color(0, 0, 0)
    And   paint_at(f, 15, 5) = color(1, 1, 1)
    And   paint_at(f, 17.5, 5) = color(0.8333, 0.8333, 0.8333)

  Scenario: When there's nothing to paint with, and when there's one colour
    Given root ← parse_xml("<svg><linearGradient id='one'><stop offset='0.3' stop-color='red'/></linearGradient><linearGradient id='empty'/><linearGradient id='same' x2='0'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient><clipPath id='k'/><linearGradient id='a'><stop offset='0'/><stop offset='1' stop-color='white'/></linearGradient></svg>")
    Then  paint_at(paint_server(root, "url(#one)", (10, 0, 30, 10), identity()), 0, 0) = color(1, 0, 0)
    And   paint_at(paint_server(root, "url(#same)", (10, 0, 30, 10), identity()), 15, 5) = color(0, 0, 1)
    And   paint_server(root, "url(#empty)", (10, 0, 30, 10), identity()) = none
    And   paint_server(root, "url(#k)", (10, 0, 30, 10), identity()) = none
    And   paint_server(root, "url(#missing)", (10, 0, 30, 10), identity()) = none
    And   paint_server(root, "url(#a)", (0, 0, 10, 0), identity()) = none
