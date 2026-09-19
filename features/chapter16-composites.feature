Feature: Composite glyphs
  A composite glyph has no contours of its own: it is other glyphs, each
  placed through a transform [a, b, c, d, dx, dy] that TrueType applies as
  x' = a x + c y + dx, y' = b x + d y + dy. component_matrix(t) is that as a
  matrix3. glyph_outline(font, name) is every contour of a glyph as
  quadratics in font units, components included, each through its matrix,
  recursively. glyph_bounds(font, name) is the tight box of the outline
  from chapter 8's curve_bounds; an empty glyph's is (0, 0, 0, 0).

  Scenario: A component transform is a matrix
    Then  component_matrix([1, 0, 0, 1, 340, 0]) * point(5, 5) = point(345, 5)
    And   component_matrix([2, 0, 0, 1, 10, 0]) * point(3, 4) = point(16, 4)
    And   component_matrix([1, 0.5, 0, 1, 0, 0]) * point(2, 4) = point(2, 5)
    And   component_matrix([1, 0, 0.5, 1, 0, 0]) * point(2, 4) = point(4, 4)
    And   component_matrix([1, 0, 0, 1, 0, 0]) = identity()

  Scenario: eacute is an e and an acute moved right
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  g ← font.glyphs["eacute"]
    Then  length(g.contours) = 0
    And   length(g.components) = 2
    And   g.components[0][0] = "e"
    And   g.components[1][0] = "acute"
    And   g.components[1][1] = [1, 0, 0, 1, 340, 0]
    And   length(glyph_outline(font, "eacute")) = 3
    And   length(glyph_outline(font, "e")) = 2
    And   length(glyph_outline(font, "acute")) = 1

  Scenario: A composite's bounds are the union of its transformed components
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  glyph_bounds(font, "e") = (93, -20, 1011, 1102)
    And   glyph_bounds(font, "acute") = (123, 1240, 540, 1534)
    And   glyph_bounds(font, "eacute") = (93, -20, 1011, 1534)
    And   glyph_bounds(font, "aring") = (109, -20, 1002, 1627)
    And   glyph_bounds(font, "space") = (0, 0, 0, 0)

  Scenario: Bounds are tight, not the control box
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    Then  glyph_bounds(font, "o") = (91, -20, 1076, 1102)
    And   glyph_bounds(font, "H") = (169, 0, 1288, 1456)

  Scenario: A font can be written by hand, and a bump's bounds stop where the curve does
    Given tiny ← load_font('{"units_per_em": 1000, "ascender": 800, "descender": -200, "line_gap": 0, "cmap": {"98": "bump"}, "glyphs": {"bump": {"advance": 300, "contours": [[[0, 0, true], [100, 200, false], [200, 0, true]]], "components": []}, "twice": {"advance": 600, "contours": [], "components": [{"glyph": "bump", "transform": [1, 0, 0, 1, 0, 0]}, {"glyph": "bump", "transform": [1, 0, 0.5, 2, 300, 0]}]}}}')
    Then  glyph_count(tiny) = 2
    And   glyph_name(tiny, 98) = "bump"
    And   length(glyph_outline(tiny, "bump")) = 1
    And   length(glyph_outline(tiny, "bump")[0]) = 2
    And   glyph_bounds(tiny, "bump") = (0, 0, 200, 100)
    And   glyph_bounds(tiny, "twice") = (0, 0, 500, 200)
