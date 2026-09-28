Feature: Quantization
  median_cut(colors, n) makes a palette of at most n byte colours from a
  list of (r, g, b) bytes. Count every distinct colour and put them all,
  sorted, in one box. While there are fewer than n boxes: of the boxes
  with at least two colours, take the one whose widest channel (greatest
  max - min) is widest, the earliest on a tie; sort its colours stably by
  that channel (red before green before blue when widths tie); cut it
  after the first colour at which the running count of pixels reaches
  half the box's pixels (2 × running ≥ total), but never after its last
  colour; stop when no box has two colours. Each box's palette entry is
  its colours' mean weighted by count, each channel rounded halves up.
  canvas_bytes(c) is bytes_at of every pixel, row by row.
  nearest_index(palette, col) is the entry with the least squared
  distance in bytes, the lowest index on a tie; remap(c, palette) is that
  for every pixel. The dithers work in linear light: an entry's light is
  chapter 1's decode of each byte / 255. threshold(c, palette) is the
  nearest entry in light, by squared distance. ordered_dither(c, palette),
  for a two-entry palette, takes the second entry where the pixel's green
  light is above lo + (hi - lo) × chapter 10's dither_threshold(x, y),
  lo and hi the entries' green light, and the first otherwise.
  error_diffuse(c, palette) is Floyd and Steinberg in light: rows top to
  bottom, each left to right; the pixel's light plus the error handed to
  it goes to the nearest entry in light, and the difference goes 7/16 to
  the right, 3/16 below left, 5/16 below and 1/16 below right, what falls
  off the canvas dropped. indexed_canvas(indices, palette, w, h) is the
  canvas of each index's light. ramp_canvas(w, h) has light x / (w - 1)
  in every channel. mean_light(c) is the mean green light.
  canvas_to_bmp8(indices, palette, w, h) writes an 8-bit indexed BMP,
  every number little-endian: "BM", the file size, two 16-bit zeros and
  the offset of the pixels (1078); then a 40-byte header: 40, the width,
  the height (positive: rows bottom to top), 1 plane, 8 bits, 0 for no
  compression, the pixel bytes' size, 2835 and 2835 pixels a metre, the
  palette's length and 0; then 256 entries of blue, green, red, 0, black
  past the palette's end; then the rows from the bottom one up, each
  padded with zeros to a multiple of 4 bytes. read_bmp8(data) answers
  (width, height, palette, indices), the palette as long as the file's
  count says.

  Scenario: Median cut
    Given cols ← [(10, 10, 10), (10, 10, 10), (10, 10, 10), (200, 0, 0), (250, 0, 0), (0, 0, 90), (0, 0, 100), (0, 0, 110)]
    Then  median_cut(cols, 1) = [(60, 4, 41)]
    And   median_cut(cols, 2) = [(5, 5, 55), (225, 0, 0)]
    And   median_cut(cols, 4) = [(10, 10, 10), (0, 0, 100), (200, 0, 0), (250, 0, 0)]
    And   median_cut(cols, 20) = [(10, 10, 10), (0, 0, 90), (0, 0, 100), (0, 0, 110), (200, 0, 0), (250, 0, 0)]
    And   median_cut(canvas_bytes(ring_canvas()), 4) = [(63, 63, 80), (128, 127, 130), (226, 223, 215), (246, 243, 234)]

  Scenario: The nearest entry
    Given pal ← [(0, 0, 0), (255, 255, 255), (255, 0, 0)]
    Then  nearest_index(pal, (120, 120, 120)) = 0
    And   nearest_index(pal, (128, 128, 128)) = 1
    And   nearest_index(pal, (200, 40, 30)) = 2
    And   nearest_index([(0, 0, 0), (0, 0, 0)], (1, 1, 1)) = 0

  Scenario: Two inks three ways: error diffusion keeps the light
    Given r ← ramp_canvas(256, 32)
    And   bw ← [(0, 0, 0), (255, 255, 255)]
    Then  error_diffuse(ramp_canvas(4, 1), bw) = [0, 0, 1, 1]
    And   mean_light(r) = 0.5
    And   mean_light(indexed_canvas(threshold(r, bw), bw, 256, 32)) = 0.5
    And   mean_light(indexed_canvas(ordered_dither(r, bw), bw, 256, 32)) = 0.530273
    And   mean_light(indexed_canvas(error_diffuse(r, bw), bw, 256, 32)) = 0.500732

  Scenario: An 8-bit BMP, byte by byte
    Given bm ← canvas_to_bmp8([0, 1, 2, 1, 0, 2, 1, 1, 1, 0], [(10, 20, 30), (200, 100, 50), (0, 0, 255)], 5, 2)
    Then  length(bm) = 1094
    And   bytes_of(bm, 0, 14) = [66, 77, 70, 4, 0, 0, 0, 0, 0, 0, 54, 4, 0, 0]
    And   bytes_of(bm, 14, 54) = [40, 0, 0, 0, 5, 0, 0, 0, 2, 0, 0, 0, 1, 0, 8, 0, 0, 0, 0, 0, 16, 0, 0, 0, 19, 11, 0, 0, 19, 11, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0]
    And   bytes_of(bm, 54, 66) = [30, 20, 10, 0, 50, 100, 200, 0, 255, 0, 0, 0]
    And   bytes_of(bm, 1078, 1094) = [2, 1, 1, 1, 0, 0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0]
    And   read_bmp8(bm) = (5, 2, [(10, 20, 30), (200, 100, 50), (0, 0, 255)], [0, 1, 2, 1, 0, 2, 1, 1, 1, 0])
