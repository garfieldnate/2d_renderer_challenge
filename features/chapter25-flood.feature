Feature: Flood fill
  bytes_at(c, x, y) is the pixel's three file bytes by chapter 1's
  to_byte. A pixel matches the seed at a tolerance when every channel's
  byte is within tolerance of the seed pixel's. flood_mask(c, x, y,
  tolerance, connectivity, fs) is the scanline flood fill, as a coverage
  mask of 1s: a stack of seeds, the first (x, y); pop one, skip it if it's
  in the mask or doesn't match, grow left and right from it along the
  row while the pixels match and aren't in the mask, put the run in the
  mask, and for the rows above and below, over the run's columns (one
  further at each end for connectivity 8), push the first pixel of every
  run of pixels that match and aren't in the mask. Each push adds 1 to
  fs.pushes and fs.deepest is the most seeds the stack ever held.
  select_color(c, x, y, tolerance) is the bucket with Contiguous off:
  every pixel of the canvas that matches. anti_alias_mask(m) is the
  bucket's Anti-alias box: every pixel outside the mask with a 4-neighbour
  in it gets 0.5. bucket(c, x, y, col, tolerance, contiguous, anti_alias,
  connectivity) paints the mask through in col and answers it.
  ring_canvas() is 160 by 160 of pale paper (0.92, 0.9, 0.82), and on it
  chapter 13's stroke_to_path of circle_path(80, 80, 60, 96), 4 wide, butt
  caps, round joins, limit 4, filled by chapter 7 and painted through in
  ink (0.05, 0.05, 0.08). naive_depth(w, h) is how deep the recursive
  four-way fill goes filling an empty w by h canvas from (0, 0), each call
  trying right, left, down, up: the deepest chain of calls in flight.

  Scenario: The ring's pixels
    Given c ← ring_canvas()
    Then  bytes_at(c, 80, 80) = (246, 243, 234)
    And   bytes_at(c, 80, 20) = (63, 63, 80)
    And   bytes_at(c, 142, 80) = (246, 243, 234)

  Scenario: Tolerance decides how much of the antialiased edge the bucket takes
    Given c ← ring_canvas()
    Then  ink(flood_mask(c, 80, 80, 0, 4, fill_stats())) = 10324
    And   ink(flood_mask(c, 80, 80, 32, 4, fill_stats())) = 10484
    And   ink(flood_mask(c, 80, 80, 160, 4, fill_stats())) = 10700
    And   ink(flood_mask(c, 80, 80, 254, 4, fill_stats())) = 25600
    And   ink(anti_alias_mask(flood_mask(c, 80, 80, 32, 4, fill_stats()))) = 10648
    And   ink(select_color(c, 80, 80, 0)) = 23636

  Scenario: Eight-way connectivity leaks through a diagonal
    Given c ← canvas(3, 3)
    When  fill(c, color(1, 1, 1))
    And   write_pixel(c, 1, 0, color(0, 0, 0))
    And   write_pixel(c, 0, 1, color(0, 0, 0))
    Then  ink(flood_mask(c, 0, 0, 0, 4, fill_stats())) = 1
    And   ink(flood_mask(c, 0, 0, 0, 8, fill_stats())) = 7

  Scenario: Recursion goes as deep as the region is big; the scanline stack doesn't
    Given fs ← fill_stats()
    When  m ← flood_mask(canvas(200, 200), 0, 0, 0, 4, fs)
    Then  ink(m) = 40000
    And   fs.pushes = 200
    And   fs.deepest = 1
    And   naive_depth(4, 3) = 12
    And   naive_depth(200, 200) = 40000
