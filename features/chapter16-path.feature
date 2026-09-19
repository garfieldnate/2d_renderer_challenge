Feature: The flip, in one place, and the path
  Fonts are y up with the origin on the baseline; the canvas is y down with
  the origin at the corner. text_matrix(font, size, x, y) is the one place
  that difference lives: scale by size / units_per_em, turn y over, and put
  the glyph's origin at (x, y). glyph_path(font, name, m, tolerance) takes
  every quadratic of the outline through m, flattens it in device space,
  and closes each contour; contour_path(font, name, i, m, tolerance) does
  one contour. Fill the path nonzero. The counter of an o is a hole for
  exactly the reason the pentagram's center was: it winds the other way.

  Scenario: The text matrix scales and turns y over
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    When  m ← text_matrix(font, 2048, 100, 500)
    Then  m * point(0, 0) = point(100, 500)
    And   m * point(2048, 2048) = point(2148, -1548)
    And   m * point(0, 1900) = point(100, -1400)
    And   text_matrix(font, 16, 10, 20) * point(1024, 1024) = point(18, 12)

  Scenario: A glyph path has one closed subpath per contour
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   m ← text_matrix(font, 200, 20, 160)
    Then  length(subpaths(glyph_path(font, "o", m, 0.05))) = 2
    And   subpaths(glyph_path(font, "o", m, 0.05))[0].closed = true
    And   subpaths(glyph_path(font, "o", m, 0.05))[1].closed = true
    And   length(subpaths(glyph_path(font, "eacute", m, 0.05))) = 3
    And   length(subpaths(glyph_path(font, "i", m, 0.05))) = 2

  Scenario: The two contours of an o wind opposite ways, and the flip turns both over
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   m ← text_matrix(font, 200, 20, 160)
    Then  polygon_area(contour_path(font, "o", 0, m, 0.05)) = 8509.81 ± 0.01
    And   polygon_area(contour_path(font, "o", 1, m, 0.05)) = -3894.40 ± 0.01
    And   polygon_area(contour_path(font, "o", 0, identity(), 1)) ≤ 0
    And   polygon_area(contour_path(font, "o", 1, identity(), 1)) ≥ 0

  Scenario: The counter is a hole: the ink is the outer area minus the inner
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   m ← text_matrix(font, 200, 20, 160)
    When  cov ← fill_path(glyph_path(font, "o", m, 0.05), "nonzero", 200, 200)
    Then  ink(cov) = 4615.41 ± 0.01
    And   coverage_at(cov, 35, 110) = 1
    And   coverage_at(cov, 72, 100) = 0
    And   coverage_at(cov, 5, 5) = 0
