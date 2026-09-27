Feature: Counting the work
  Wall-clock time depends on the machine, the language and what else is
  running; a scenario can't pin it. So the chapter counts work instead, in
  a stats record: cells, the accumulator cells a running sum resolved;
  blends, the pixels composited one at a time (a paint sample and a
  source-over); and copies, the pixels written without a blend. stats() is
  a record with all three at 0. fill_path_counted(p, rule, width, height,
  st) is chapter 7's fill_path, adding width times height to st.cells,
  because chapter 7 resolves every cell of the canvas whatever the path.
  draw_coverage_counted(l, cov, paint, alpha, st) is chapter 20's
  draw_coverage, adding 1 to st.blends for every pixel it composites, the
  ones whose coverage times alpha is above 0. render_svg_with(text, width,
  height, mode, st) is chapter 20's render_svg with every fill and stroke
  done one of three ways, counting into st; mode "whole" is chapter 20 as
  written, through these two functions.

  Scenario: Chapter 7 resolves the whole canvas for a small square
    Given st ← stats()
    When  cov ← fill_path_counted(polygon(point(4, 4), point(20, 4), point(20, 20), point(4, 20)), "nonzero", 64, 64, st)
    Then  st.cells = 4096
    And   st.blends = 0
    And   st.copies = 0
    And   max_coverage_difference(cov, fill_path(polygon(point(4, 4), point(20, 4), point(20, 20), point(4, 20)), "nonzero", 64, 64)) = 0

  Scenario: Only the pixels with coverage are blended
    Given st ← stats()
    And   l ← layer(64, 64)
    And   cov ← fill_path(polygon(point(4, 4), point(20, 4), point(20, 20), point(4, 20)), "nonzero", 64, 64)
    When  draw_coverage_counted(l, cov, solid(color(1, 0, 0)), 1, st)
    Then  st.blends = 256
    And   layer_pixel(l, 10, 10) = pixel(1, 0, 0, 1)
    And   layer_pixel(l, 30, 30) = pixel(0, 0, 0, 0)

  Scenario: The tiger, as chapter 20 draws it
    Given st ← stats()
    When  c ← render_svg_with(read_file("reference/chapter-20/tiger.svg"), 450, 450, "whole", st)
    Then  st.cells = 61762500
    And   st.copies = 0
    And   max_channel_difference(canvas_to_p6(c), read_file("reference/chapter-20/tiger.ppm")) ≤ 1
