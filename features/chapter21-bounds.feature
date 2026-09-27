Feature: Bounds
  A path can only touch the pixels under its bounds. fill_bounds(p, width,
  height) is that window of the canvas in whole pixels: x0 and y0 the
  floors of the path's least x and y, x1 and y1 one more than the floors of
  its greatest (an edge on x = 20 deposits into column 20, so column 20 is
  in), each cut to the canvas; (0, 0, 0, 0) for an empty path or a window
  with nothing left in it. fill_path_bounded(p, rule, width, height, st)
  moves the path by (-x0, -y0), fills it with chapter 7 into an
  accumulator the window's size, and answers a window: the coverage buffer
  and its (x0, y0). It adds the window's width times height to st.cells.
  coverage_in(c, x, y) reads a window at a canvas pixel, 0 outside it, and
  also reads a plain coverage buffer and the tiled coverage of the next
  section; full_coverage(c, width, height) turns any of them into a
  canvas-sized buffer. draw_window(l, win, paint, alpha, st) is
  draw_coverage over the window's pixels only. Moving the path changes a
  few sums in the last bit, so the coverage agrees with chapter 7's to
  within 0.000001, not exactly; the bytes of a render don't change.

  Scenario: The window under a path, in whole pixels
    Then  fill_bounds(polygon(point(2.5, 3.25), point(20, 3.25), point(20, 17.75), point(2.5, 17.75)), 64, 64) = (2, 3, 21, 18)
    And   fill_bounds(polygon(point(2, 3), point(20, 3), point(20, 18), point(2, 18)), 64, 64) = (2, 3, 21, 19)
    And   fill_bounds(polygon(point(-5, -5), point(10.5, -5), point(10.5, 70), point(-5, 70)), 64, 64) = (0, 0, 11, 64)
    And   fill_bounds(polygon(point(70, 5), point(80, 5), point(80, 10), point(70, 10)), 64, 64) = (0, 0, 0, 0)
    And   fill_bounds(path(), 64, 64) = (0, 0, 0, 0)

  Scenario: A bounded fill resolves only its window, and agrees with chapter 7
    Given st ← stats()
    And   tri ← polygon(point(3.3, 2.7), point(40.1, 9.9), point(12.6, 33.3))
    When  win ← fill_path_bounded(tri, "nonzero", 64, 64, st)
    Then  win.x0 = 3
    And   win.y0 = 2
    And   win.cov.width = 38
    And   win.cov.height = 32
    And   st.cells = 1216
    And   coverage_in(win, 1, 1) = 0
    And   coverage_in(win, 60, 60) = 0
    And   max_coverage_difference(full_coverage(win, 64, 64), fill_path(tri, "nonzero", 64, 64)) ≤ 0.000001

  Scenario: The tiger, bounded
    Given st ← stats()
    When  c ← render_svg_with(read_file("reference/chapter-20/tiger.svg"), 450, 450, "bounded", st)
    Then  st.cells = 1395287
    And   st.copies = 0
    And   max_channel_difference(canvas_to_p6(c), read_file("reference/chapter-20/tiger.ppm")) ≤ 1
