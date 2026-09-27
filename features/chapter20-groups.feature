Feature: Clips and group opacity
  draw_coverage(l, cov, paint, alpha) paints into a layer: at every pixel
  whose coverage times alpha, k, is above 0, the paint's colour c at the
  pixel center becomes the premultiplied pixel (c·k, k) and goes over what
  is there. union_coverage(a, b) is 1 - (1 - a)(1 - b) at every pixel, the
  alpha of one silhouette over the other. clip_coverage(root, ref, m,
  width, height) is the coverage of the clipPath a url(#id) names: the
  union, starting from nothing, of the fill of every shape child (other
  children are skipped), each built through m times the clipPath's own
  transform times the child's, under the child's clip-rule, computed from
  the clipPath's style, which starts from initial_style(); m is the matrix
  of the element that uses the clip, its own transform included. A clipPath
  with no shapes clips everything away; a reference to nothing, or to
  something that isn't a clipPath, clips nothing. mask_layer(l, cov)
  multiplies every premultiplied channel of every pixel by the coverage
  under it. In the walker, an element whose opacity is below 1, and an svg
  or g with a clip-path, draws into a fresh transparent layer: its children
  (or its own fill and stroke) go in there, then the layer is masked by the
  clip if there is one, then chapter 12's pop_group_with_opacity puts it
  over the layer below. Any other shape with a clip-path multiplies the
  clip into its fill's and stroke's coverage before painting.

  Scenario: Painting into a layer at a coverage and an alpha
    Given cov ← coverage_buffer(2, 1)
    And   set_coverage(cov, 0, 0, 0.5)
    And   set_coverage(cov, 1, 0, 1)
    And   l ← layer(2, 1)
    When  draw_coverage(l, cov, solid(color(1, 0, 0)), 0.5)
    Then  layer_pixel(l, 0, 0) = pixel(0.25, 0, 0, 0.25)
    And   layer_pixel(l, 1, 0) = pixel(0.5, 0, 0, 0.5)
    And   coverage_at(union_coverage(cov, cov), 0, 0) = 0.75
    And   coverage_at(union_coverage(cov, cov), 1, 0) = 1

  Scenario: An element's opacity fades its fill and stroke together
    When  c ← render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' stroke='blue' stroke-width='2' opacity='0.5'/></svg>", 4, 4)
    Then  pixel_at(c, 1, 1) = color(1, 0.5, 0.5)
    And   pixel_at(c, 0, 0) = color(0.5, 0.5, 1)

  Scenario: A group's opacity applies after its children are flattened
    When  g ← render_svg("<svg viewBox='0 0 4 4'><g opacity='0.5'><rect width='4' height='4' fill='red'/><rect width='4' height='4' fill='blue'/></g></svg>", 4, 4)
    And   e ← render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' opacity='0.5'/><rect width='4' height='4' fill='blue' opacity='0.5'/></svg>", 4, 4)
    Then  pixel_at(g, 0, 0) = color(0.5, 0.5, 1)
    And   pixel_at(e, 0, 0) = color(0.5, 0.25, 0.75)

  Scenario: A clip on a shape, and on a group
    When  s ← render_svg("<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='2' height='4'/></clipPath><rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>", 4, 4)
    And   g ← render_svg("<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='2' height='4'/></clipPath><g clip-path='url(#c)' opacity='0.5'><rect width='4' height='4' fill='red'/></g></svg>", 4, 4)
    Then  pixel_at(s, 0, 0) = color(1, 0, 0)
    And   pixel_at(s, 3, 0) = color(1, 1, 1)
    And   pixel_at(g, 0, 0) = color(1, 0.5, 0.5)
    And   pixel_at(g, 3, 0) = color(1, 1, 1)

  Scenario: A clip is the union of its shapes
    When  c ← render_svg("<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='1' height='4'/><rect x='3' width='1' height='4'/></clipPath><rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>", 4, 4)
    And   h ← render_svg("<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='0.5' height='4'/><rect width='0.5' height='4'/></clipPath><rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>", 4, 4)
    Then  pixel_at(c, 0, 0) = color(1, 0, 0)
    And   pixel_at(c, 1, 0) = color(1, 1, 1)
    And   pixel_at(c, 3, 0) = color(1, 0, 0)
    And   pixel_at(h, 0, 0) = color(1, 0.25, 0.25)

  Scenario: Each clip shape has its own clip-rule
    When  e ← render_svg("<svg viewBox='0 0 10 10'><clipPath id='c'><path clip-rule='evenodd' d='M0 0H10V10H0Z M2 2H8V8H2Z'/></clipPath><rect width='10' height='10' fill='red' clip-path='url(#c)'/></svg>", 10, 10)
    And   n ← render_svg("<svg viewBox='0 0 10 10'><clipPath id='c'><path d='M0 0H10V10H0Z M2 2H8V8H2Z'/></clipPath><rect width='10' height='10' fill='red' clip-path='url(#c)'/></svg>", 10, 10)
    Then  pixel_at(e, 0, 0) = color(1, 0, 0)
    And   pixel_at(e, 5, 5) = color(1, 1, 1)
    And   pixel_at(n, 5, 5) = color(1, 0, 0)

  Scenario: A clip lives in the user space of the element that uses it
    When  u ← render_svg("<svg viewBox='0 0 8 4'><clipPath id='c'><rect width='2' height='4'/></clipPath><rect width='4' height='4' fill='red' clip-path='url(#c)' transform='translate(4 0)'/></svg>", 8, 4)
    And   t ← render_svg("<svg viewBox='0 0 4 4'><clipPath id='c' transform='translate(2 0)'><rect width='2' height='4'/></clipPath><rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>", 4, 4)
    And   k ← render_svg("<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='2' height='4' transform='translate(2 0)'/></clipPath><rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>", 4, 4)
    Then  pixel_at(u, 4, 0) = color(1, 0, 0)
    And   pixel_at(u, 6, 0) = color(1, 1, 1)
    And   pixel_at(t, 0, 0) = color(1, 1, 1)
    And   pixel_at(t, 3, 0) = color(1, 0, 0)
    And   pixel_at(k, 0, 0) = color(1, 1, 1)
    And   pixel_at(k, 3, 0) = color(1, 0, 0)

  Scenario: An empty clip hides everything, and a missing one hides nothing
    Then  pixel_at(render_svg("<svg viewBox='0 0 4 4'><clipPath id='c'/><rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>", 4, 4), 0, 0) = color(1, 1, 1)
    And   pixel_at(render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' clip-path='url(#nope)'/></svg>", 4, 4), 0, 0) = color(1, 0, 0)
