Feature: Tiles
  The canvas is cut into tiles 16 pixels square, starting at the top left;
  a tile at the right or bottom edge is cut short by the canvas. Filling a
  path deposits into the cells its edges cross (chapter 7's accumulate
  and add_cell, unchanged, but storing only the cells deposited into).
  classify_tiles(p, rule, width, height) answers classes[ty][tx] for every
  tile: "empty" when the tile lies outside fill_bounds; otherwise
  "partial" when a cell in it got a deposit with a nonzero area or cover;
  otherwise look at the running sum arriving at the tile's left edge in
  each of its rows (the covers of every cell to its left in that row,
  added left to right): if on every row it is within 0.000001 of the same
  whole number n, the tile is "solid" when apply_rule(n, rule) is 1 and
  "empty" when it isn't, and if not, it's "partial". A horizontal edge
  deposits nothing, which is why the rows have to agree. fill_path_tiled(
  p, rule, width, height, st) resolves the cells of the partial tiles only,
  each row of a tile starting from the running sum arriving at its left
  edge, adds the number of cells it resolved to st.cells, and answers the
  tiled coverage: 1 in a solid tile, 0 in an empty one, the resolved value
  in a partial one. tile_count(classes, kind) counts the tiles of a kind.

  Scenario: A square leaves its middle tiles solid
    When  t ← classify_tiles(polygon(point(4, 4), point(60, 4), point(60, 60), point(4, 60)), "nonzero", 64, 64)
    Then  t[0] = ["partial", "partial", "partial", "partial"]
    And   t[1] = ["partial", "solid", "solid", "partial"]
    And   t[3] = ["partial", "partial", "partial", "partial"]
    And   tile_count(t, "solid") = 4

  Scenario: An edge on a tile boundary deposits into the tile on its right
    When  t ← classify_tiles(polygon(point(16, 16), point(48, 16), point(48, 48), point(16, 48)), "nonzero", 64, 64)
    Then  t[0] = ["empty", "empty", "empty", "empty"]
    And   t[1] = ["empty", "partial", "solid", "partial"]
    And   t[2] = ["empty", "partial", "solid", "partial"]
    And   t[3] = ["empty", "empty", "empty", "empty"]

  Scenario: A horizontal edge makes a tile partial, and an edge off the canvas deposits nothing
    When  t ← classify_tiles(polygon(point(0, 0), point(64, 0), point(64, 40), point(0, 40)), "nonzero", 64, 64)
    Then  t[0] = ["partial", "solid", "solid", "solid"]
    And   t[2] = ["partial", "partial", "partial", "partial"]
    And   t[3] = ["empty", "empty", "empty", "empty"]

  Scenario: The fill rule decides what a hole is
    Given ring ← path()
    When  move_to(ring, point(2, 2))
    And   line_to(ring, point(62, 2))
    And   line_to(ring, point(62, 62))
    And   line_to(ring, point(2, 62))
    And   close(ring)
    And   move_to(ring, point(14, 14))
    And   line_to(ring, point(50, 14))
    And   line_to(ring, point(50, 50))
    And   line_to(ring, point(14, 50))
    And   close(ring)
    Then  classify_tiles(ring, "nonzero", 64, 64)[1] = ["partial", "solid", "solid", "partial"]
    And   classify_tiles(ring, "evenodd", 64, 64)[1] = ["partial", "empty", "empty", "partial"]

  Scenario: Only partial tiles are resolved, and the coverage agrees with chapter 7
    Given st ← stats()
    And   sq ← polygon(point(4, 4), point(60, 4), point(60, 60), point(4, 60))
    When  t ← fill_path_tiled(sq, "nonzero", 64, 64, st)
    Then  st.cells = 3072
    And   coverage_in(t, 30, 30) = 1
    And   coverage_in(t, 2, 2) = 0
    And   coverage_in(t, 4, 30) = 1
    And   max_coverage_difference(full_coverage(t, 64, 64), fill_path(sq, "nonzero", 64, 64)) ≤ 0.000001

  Scenario: A tiny shape in a corner of a canvas cut short
    When  t ← classify_tiles(polygon(point(3, 3), point(5, 3), point(5, 5), point(3, 5)), "nonzero", 40, 40)
    Then  length(t) = 3
    And   length(t[0]) = 3
    And   t[0] = ["partial", "empty", "empty"]
    And   tile_count(t, "empty") = 8
