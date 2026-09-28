Feature: Selection and undo
  A selection is a coverage mask. marquee(x0, y0, x1, y1, w, h) is
  chapter 12's clip_rect. add_selection(a, b) is 1 - (1 - a)(1 - b),
  subtract_selection(a, b) is a × (1 - b), intersect_selection(a, b) is
  chapter 12's multiply_coverage. feather(m, r) is a box blur of radius r,
  along the rows and then down the columns, each value the mean of the 2r
  + 1 centred on it with those off the buffer counted as 0.
  float_selection(c, sel, backfill) lifts the selection's pixels into a
  chapter 9 layer, each premultiplied by the selection's coverage k, and
  mixes the canvas under them toward backfill by k; move_floating(f, dx,
  dy) moves it; drop_floating(c, f) composites every pixel of it with
  alpha above 0, moved, source-over the canvas, dropping those that land
  off the canvas. A history(c) is a command stack: history_fill(h, x0, y0,
  x1, y1, col) is an edit that first saves the canvas pixels of its
  rectangle (end exclusive, cut to the canvas) and then sets them to col;
  undo(h) puts the saved pixels back, keeps the ones it replaced for redo,
  and answers true (false with nothing to undo); redo(h) does the
  reverse; a new edit throws the redo stack away. stored_pixels(h) is how
  many pixels both stacks hold.

  Scenario: Selections combine like coverage
    Given a ← marquee(2, 2, 6, 6, 8, 8)
    And   b ← marquee(4, 4, 8, 8, 8, 8)
    Then  ink(add_selection(a, b)) = 28
    And   ink(subtract_selection(a, b)) = 12
    And   ink(intersect_selection(a, b)) = 4

  Scenario: Feathering keeps the selection's size and softens its edge
    Given f ← feather(marquee(2, 2, 6, 6, 8, 8), 1)
    Then  coverage_at(f, 3, 3) = 1
    And   coverage_at(f, 2, 2) = 0.444444
    And   coverage_at(f, 1, 1) = 0.111111
    And   ink(f) = 16

  Scenario: Off the buffer counts as unselected
    Given f ← feather(marquee(0, 0, 4, 4, 8, 8), 1)
    Then  coverage_at(f, 0, 0) = 0.444444
    And   coverage_at(f, 1, 1) = 1

  Scenario: A floating selection moves and drops
    Given c ← canvas(8, 8)
    When  fill(c, color(0, 0, 1))
    And   write_pixel(c, 2, 2, color(1, 0, 0))
    And   write_pixel(c, 3, 2, color(1, 0, 0))
    And   write_pixel(c, 2, 3, color(1, 0, 0))
    And   write_pixel(c, 3, 3, color(1, 0, 0))
    And   f ← float_selection(c, marquee(2, 2, 4, 4, 8, 8), color(0, 0, 1))
    And   move_floating(f, 3, 1)
    And   drop_floating(c, f)
    Then  pixel_at(c, 2, 2) = color(0, 0, 1)
    And   pixel_at(c, 5, 3) = color(1, 0, 0)
    And   pixel_at(c, 6, 4) = color(1, 0, 0)
    And   pixel_at(c, 4, 2) = color(0, 0, 1)

  Scenario: Undo, redo, and a new edit ends redo
    Given c ← canvas(8, 8)
    And   h ← history(c)
    When  history_fill(h, 0, 0, 4, 4, color(1, 1, 1))
    And   history_fill(h, 2, 2, 6, 6, color(1, 0, 0))
    Then  pixel_at(c, 3, 3) = color(1, 0, 0)
    And   stored_pixels(h) = 32
    And   undo(h) = true
    And   pixel_at(c, 3, 3) = color(1, 1, 1)
    And   pixel_at(c, 5, 5) = color(0, 0, 0)
    And   redo(h) = true
    And   pixel_at(c, 3, 3) = color(1, 0, 0)
    And   undo(h) = true
    And   undo(h) = true
    And   undo(h) = false
    And   pixel_at(c, 1, 1) = color(0, 0, 0)
    And   redo(h) = true
    And   pixel_at(c, 1, 1) = color(1, 1, 1)

  Scenario: An edit after an undo throws redo away
    Given c ← canvas(8, 8)
    And   h ← history(c)
    When  history_fill(h, 0, 0, 4, 4, color(1, 1, 1))
    And   history_fill(h, 2, 2, 6, 6, color(1, 0, 0))
    And   undo(h)
    And   history_fill(h, 0, 0, 1, 1, color(0, 1, 0))
    Then  redo(h) = false
    And   stored_pixels(h) = 17
    And   pixel_at(c, 0, 0) = color(0, 1, 0)
