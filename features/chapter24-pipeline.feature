Feature: The compute pipeline
  encode_svg(text, width, height) is chapter 20's walker drawing nothing:
  it answers the scene as a flat list, in document order, of Fill(path,
  rule, paint, alpha, clip), Push(opacity, clip) and Pop. A shape's fill
  and then its stroke outline are Fills of device paths built exactly as
  chapter 20 builds them; an element chapter 20 draws into a fresh layer
  (opacity below 1, or a group with a clip) is a Push before its contents
  and a Pop after; a clip is the list of (device path, clip rule) of the
  clipPath's shapes, on the Push of a grouped element and on the Fill of
  a shape that isn't grouped. Scene(commands, width, height) numbers every
  path, clip parts included, as a draw. Tiles are chapter 21's, 16
  pixels, cut short at the right and bottom. The four stages each read one
  thing and write another:
    flatten_stage(scene): every draw's edges(p) as segments (draw, a, b).
    bin_stage(scene, segments): every segment's chapter 21 sparse
      deposits, one per call of the accumulator's add that isn't
      dropped, filed in segment order under the tile of the deposit's
      cell: bins[(tx, ty)] is a list of (draw, x, row, area, cover).
    coarse_stage(scene, bins): for every tile, its command list. For a
      draw in a tile: the cells are its deposits summed per cell in
      segment order; the arriving sum on each of the tile's rows is the
      covers of that draw's cells to the tile's left in that row, added
      left to right from 0; and the tile is classed as chapter 21's
      classify_tiles classes it. A Fill becomes ("fill", tile draw, rule,
      paint, alpha, clip) unless its tile draw is empty; a clip becomes the
      list of (tile draw, clip rule) of its parts, empty ones included.
      Push and Pop are copied to every tile, and then cull_groups drops
      each push whose pop has no fill between them in that tile,
      innermost first.
    fine_tile(scene, commands, tx, ty, fs): one tile, reading only its
      list, into its own block of transparent pixels, with a stack of
      blocks for groups. A fill's coverage is chapter 21's resolve: each
      row from its arriving sum, apply_rule(running + area) and then
      running + cover along the row; 1 in a solid tile. A clip's values
      start at 0 and take 1 - (1 - v)(1 - c) for each part in order. When
      the tile is solid, the paint is a solid colour, alpha is 1 and there
      is no clip, each pixel is the colour at alpha 1; otherwise k =
      (coverage × clip) × alpha, and where k > 0 the paint at the pixel
      center at k goes over the top block. push starts a new transparent
      block; pop takes it off, scales it by its clip's values if it has
      one, and composites it over the block below at its opacity, chapter
      20's composite_group. Answers the bottom block; fs.tiles counts
      tiles run.
  run_pipeline(scene, seed, fs) runs all four and the fine stage over
  every tile, in raster order when seed is none and in lcg_shuffle(tile
  count, seed) order otherwise, and answers the canvas, every tile's block
  flattened over white. render_svg_gpu(text, width, height, seed) is
  run_pipeline(Scene(encode_svg(text, width, height), width, height),
  seed, a fresh FineStats). deposit_count(bins) and command_count(lists)
  total the stage outputs. lcg_shuffle(n, seed) is Fisher-Yates from the
  end, the same in every language: x starts at seed, and for i from n - 1
  down to 1, x ← (1103515245 x + 12345) mod 2³¹, j = x mod (i + 1), swap
  entries i and j. The product needs 62 bits: a double rounds it.

  Scenario: The same shuffle everywhere
    Then  lcg_shuffle(10, 1) = [1, 2, 8, 9, 5, 6, 7, 4, 3, 0]
    And   lcg_shuffle(5, 7) = [0, 2, 3, 4, 1]

  Scenario: An empty group costs a tile nothing
    Then  cull_groups([("push", 1, none), ("pop",), ("fill", 1), ("push", 0.5, none), ("push", 1, none), ("pop",), ("fill", 2), ("pop",)]) = [("fill", 1), ("push", 0.5, none), ("fill", 2), ("pop",)]

  Scenario: The tiger's scene, stage by stage
    Given sc ← Scene(encode_svg(read_file("reference/chapter-20/tiger.svg"), 450, 450), 450, 450)
    When  segs ← flatten_stage(sc)
    And   bins ← bin_stage(sc, segs)
    And   lists ← coarse_stage(sc, bins)
    Then  length(sc.commands) = 305
    And   length(sc.draws) = 305
    And   length(segs) = 37051
    And   deposit_count(bins) = 119876
    And   command_count(lists) = 4004

  Scenario Outline: Every document, drawn tile by tile in any order, is chapter 20's
    Given text ← read_file(<svg>)
    When  in_order ← canvas_to_p6(render_svg_gpu(text, <w>, <h>, none))
    And   shuffled ← canvas_to_p6(render_svg_gpu(text, <w>, <h>, 99))
    Then  max_channel_difference(in_order, read_file(<ppm>)) = 0
    And   in_order = shuffled

    Examples:
      | svg                                  | ppm                                  | w   | h   |
      | "reference/chapter-20/tiger.svg"     | "reference/chapter-20/tiger.ppm"     | 450 | 450 |
      | "reference/chapter-20/harbor.svg"    | "reference/chapter-20/harbor.ppm"    | 480 | 320 |
      | "reference/chapter-20/rose.svg"      | "reference/chapter-20/rose.ppm"      | 400 | 400 |

  Scenario: A clip on a shape that isn't grouped
    Given svg ← "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><clipPath id='c'><circle cx='32' cy='32' r='20'/></clipPath><rect x='4' y='4' width='56' height='40' fill='#c83' clip-path='url(#c)'/></svg>"
    Then  max_channel_difference(canvas_to_p6(render_svg_gpu(svg, 64, 64, 3)), canvas_to_p6(render_svg(svg, 64, 64))) = 0
