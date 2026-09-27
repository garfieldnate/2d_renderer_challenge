Feature: The walker
  render_svg(text, width, height) draws a document onto a width by height
  canvas. It starts with a transparent chapter 9 layer, walks the tree from
  the root with initial_style() as the root's parent style and the root's
  view_box_matrix as the starting matrix, and flattens the layer over white
  paper at the end. Walking an element: if it's not svg, g or a shape, it
  and everything inside it are skipped (defs, gradients, clipPath, title,
  text and anything unknown). Otherwise its style is computed_style against
  the parent's, its matrix is the parent's times parse_transform of its
  own transform attribute, and then an svg or g walks its children in
  document order while a shape draws itself. A shape with no commands, or
  whose matrix has no inverse, draws nothing. Drawing is the fill first,
  then the stroke, each through draw_coverage (paint through coverage into
  the layer, source-over, at the pixel centers). The fill, unless it's
  none: build_path of the commands through the matrix at tolerance 0.1,
  filled with chapter 7's fill_path under fill-rule, painted at alpha
  fill-opacity with the solid colour or the paint_server of the reference
  (with the commands' commands_bounds); a reference to nothing paints
  nothing. The stroke, unless it's none or its width is 0: the same device
  path taken back through the inverse of the matrix into user space; dashed
  there with chapter 15's dash when there's a dash array, phase
  stroke-dashoffset; turned into an outline there by chapter 13's
  stroke_to_path with stroke-width, stroke-linecap, stroke-linejoin and
  stroke-miterlimit; the outline taken through the matrix; filled nonzero;
  painted at alpha stroke-opacity. Stroking in user space is what makes a
  squashed transform squash the pen, as SVG requires.

  Scenario: Later elements paint over earlier ones, and paper shows through
    When  c ← render_svg("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 4 4'><rect width='4' height='4' fill='red'/><rect x='2' width='2' height='4' fill='blue'/></svg>", 4, 4)
    Then  pixel_at(c, 0, 0) = color(1, 0, 0)
    And   pixel_at(c, 3, 0) = color(0, 0, 1)
    And   pixel_at(render_svg("<svg><rect width='2' height='2'/></svg>", 4, 4), 0, 0) = color(0, 0, 0)
    And   pixel_at(render_svg("<svg><rect width='2' height='2'/></svg>", 4, 4), 3, 3) = color(1, 1, 1)

  Scenario: The stroke is drawn over the fill, centred on the outline
    When  c ← render_svg("<svg viewBox='0 0 10 10'><rect x='2' y='2' width='6' height='6' fill='red' stroke='blue' stroke-width='2'/></svg>", 10, 10)
    Then  pixel_at(c, 1, 1) = color(0, 0, 1)
    And   pixel_at(c, 2, 5) = color(0, 0, 1)
    And   pixel_at(c, 5, 5) = color(1, 0, 0)
    And   pixel_at(c, 0, 0) = color(1, 1, 1)

  Scenario: A squashed transform squashes the pen
    When  c ← render_svg("<svg viewBox='0 0 20 10'><rect x='2' y='2' width='6' height='6' fill='none' stroke='black' stroke-width='2' transform='scale(2 1)'/></svg>", 20, 10)
    Then  pixel_at(c, 2, 5) = color(0, 0, 0)
    And   pixel_at(c, 5, 5) = color(0, 0, 0)
    And   pixel_at(c, 10, 1) = color(0, 0, 0)
    And   pixel_at(c, 10, 3) = color(1, 1, 1)

  Scenario: Dashes are measured in user space too
    When  c ← render_svg("<svg viewBox='0 0 20 2'><line x1='0' y1='1' x2='10' y2='1' stroke='black' stroke-width='2' stroke-dasharray='2 3' transform='scale(2 1)'/></svg>", 20, 2)
    Then  pixel_at(c, 0, 1) = color(0, 0, 0)
    And   pixel_at(c, 3, 1) = color(0, 0, 0)
    And   pixel_at(c, 4, 1) = color(1, 1, 1)
    And   pixel_at(c, 9, 1) = color(1, 1, 1)
    And   pixel_at(c, 10, 1) = color(0, 0, 0)

  Scenario: The dash offset moves the pattern along the path
    When  c ← render_svg("<svg viewBox='0 0 10 2'><line x1='0' y1='1' x2='10' y2='1' stroke='black' stroke-width='2' stroke-dasharray='2 3' stroke-dashoffset='1'/></svg>", 10, 2)
    Then  pixel_at(c, 0, 1) = color(0, 0, 0)
    And   pixel_at(c, 1, 1) = color(1, 1, 1)
    And   pixel_at(c, 3, 1) = color(1, 1, 1)
    And   pixel_at(c, 4, 1) = color(0, 0, 0)
    And   pixel_at(c, 5, 1) = color(0, 0, 0)
    And   pixel_at(c, 6, 1) = color(1, 1, 1)

  Scenario: Caps and fill rules reach the fill and the stroker
    When  c ← render_svg("<svg viewBox='0 0 10 4'><line x1='2' y1='2' x2='8' y2='2' stroke='black' stroke-width='2' stroke-linecap='square'/></svg>", 10, 4)
    And   e ← render_svg("<svg viewBox='0 0 10 10'><path fill-rule='evenodd' d='M0 0H10V10H0Z M2 2H8V8H2Z'/></svg>", 10, 10)
    Then  pixel_at(c, 1, 2) = color(0, 0, 0)
    And   pixel_at(c, 8, 2) = color(0, 0, 0)
    And   pixel_at(c, 0, 2) = color(1, 1, 1)
    And   pixel_at(e, 0, 0) = color(0, 0, 0)
    And   pixel_at(e, 5, 5) = color(1, 1, 1)

  Scenario: fill-opacity and stroke-opacity fade one paint each
    When  c ← render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' fill-opacity='0.5' stroke='blue' stroke-width='2' stroke-opacity='0.25'/></svg>", 4, 4)
    Then  pixel_at(c, 1, 1) = color(1, 0.5, 0.5)
    And   pixel_at(c, 0, 0) = color(0.75, 0.375, 0.625)

  Scenario: A gradient fill spans the shape's own bounds
    When  c ← render_svg("<svg viewBox='0 0 8 4'><linearGradient id='g'><stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/></linearGradient><rect x='4' width='4' height='4' fill='url(#g)'/></svg>", 8, 4)
    Then  pixel_at(c, 4, 0) = color(0.125, 0.125, 0.125)
    And   pixel_at(c, 5, 0) = color(0.375, 0.375, 0.375)
    And   pixel_at(c, 7, 0) = color(0.875, 0.875, 0.875)

  Scenario: What isn't drawn
    Then  pixel_at(render_svg("<svg viewBox='0 0 4 4'><defs><rect width='4' height='4' fill='red'/></defs><clipPath id='c'><rect width='4' height='4'/></clipPath><text>hi</text><title>t</title><foo><rect width='4' height='4'/></foo></svg>", 4, 4), 0, 0) = color(1, 1, 1)
    And   pixel_at(render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' stroke='blue' transform='scale(0)'/></svg>", 4, 4), 0, 0) = color(1, 1, 1)
    And   pixel_at(render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='url(#nope)' stroke='blue' stroke-width='2'/></svg>", 4, 4), 1, 1) = color(1, 1, 1)
    And   pixel_at(render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='url(#nope)' stroke='blue' stroke-width='2'/></svg>", 4, 4), 0, 0) = color(0, 0, 1)
