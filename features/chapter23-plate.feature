Feature: Plate 23, and the chapter's renders
  Every render is on chapter 16's paper with its inks: orange (0.9, 0.55,
  0.1), cyan (0.2, 0.75, 0.9), magenta (0.85, 0.2, 0.55), dim (0.3, 0.3,
  0.34), pale (0.92, 0.9, 0.82) and black. paint_field(c, f, col) is
  chapter 2's paint_through(c, field_coverage(f), col). Panels sit side
  by side left to right, and a second row goes under the first.
  band_color(d) is the tint, orange when d > 0 and cyan when it isn't,
  mixed into paper in linear light by 0.12 when floor(|d| / 6) is even
  and 0.3 when it's odd; then, where |d| < 1, mixed toward pale by 1 -
  |d|. band_canvas(f) is a canvas of band_color at every pixel.

    primitive_fields  band_canvas of four 160 by 160 fields: sd_circle
                      about (80, 80) radius 50; sd_box about (80, 80),
                      55 by 35; sd_rounded_box, the same with r = 20; and
                      polygon_field(star(), "evenodd")
    error_map         160 by 160 panels: polygon_field(star(),
                      "nonzero") painted orange; then that field's
                      coverage_error against chapter 7's fill of the star,
                      and the error of the field of simplify(star(),
                      "nonzero"), each pixel paper mixed toward magenta by
                      min(1, 4 × error)
    fields_vs_paths   200 by 200 panels, top row by path: chapter 13's
                      stroke_to_path of the star moved by (19.5, 19.5),
                      10 wide, round caps and joins, miter limit 4; chapter
                      14's stroke_curve_to_path(s_curve(), 20, "round",
                      0.05); chapter 22's xor of plate_glyph() nonzero and
                      plate_star() even-odd; each filled nonzero, painted
                      orange. Bottom row by field: field_stroke of the
                      moved star's polygon_field by 10, field_stroke of
                      cubic_field(s_curve()) by 20, and field_xor of
                      plate_glyph_field() and polygon_field(plate_star(),
                      "evenodd"), each painted orange
    fillets           four 160 by 160 panels, fillet_field(k) for k = 0,
                      8, 16, 32, painted orange, then its field_stroke
                      by 1.5 painted pale
    transform_demo    three 64 by 64 panels, magnified 3 times by chapter
                      2's magnify: transform_bitmap() painted orange;
                      band_canvas of its field_from_coverage; and that
                      field offset by 6, 3 and 0, each stroked 1.5 wide,
                      painted magenta, cyan and orange in that order
    atlas_corners     four 300 by 400 panels, each drawing one baked glyph
                      in orange with draw_baked at (10 - left × scale,
                      10 - top × scale), so the box's corner is at (10,
                      10): E (bake_sdf at 16, spread 3, scale 20); E
                      (bake_msdf at 16, spread 3, scale 20); k (bake_msdf
                      at 16, spread 3, scale 20); k (bake_msdf at 32,
                      spread 3, scale 10)
    trap_shrink       two 170 by 160 panels of the peanut: the fields'
                      union by min, then the field of combine's union;
                      each offset by -20 painted orange, then stroked 1.5
                      wide unshrunk, painted dim
    plate_23          plate_field(), Roboto's ampersand at 170 pixels to
                      the em from (38, 164) in a 200 by 200 field, four
                      ways: band_canvas; painted orange; field_stroke by
                      4 painted cyan; and glowing, every pixel with d > 0
                      paper mixed toward magenta by 0.8 exp(-d / 10), then
                      painted orange
    title             900 by 220: the placements of chapter 18's
                      layout_run(Roboto, "DISTANCE", 160, 78, 172, true),
                      each glyph bake_mtsdf at 32 with spread 4, drawn at
                      scale 5 by draw_effect four times over the run in
                      order: moved by (8, 8), black, the true channel,
                      0.6 clamp((10 - d) / 20); magenta, the true channel,
                      0.8 (1 - clamp(d / 20))²; orange, the median,
                      clamp(0.5 - d); pale, the median, clamp(0.5 - (|d|
                      - 1.5)); every clamp to [0, 1]

  draw_effect(c, baked, scale, x, y, col, true, k_of) is draw_baked with
  the distance in pixels, scale × the fourth channel's sample when true
  is set and scale × the median of the first three when it isn't, turned
  into a mix by k_of instead of clamp(0.5 - d, 0, 1).

  Scenario Outline: Each render matches its reference
    Given c ← <render>()
    And   ref ← read_file(<file>)
    When  p6 ← canvas_to_p6(c)
    Then  c.width = <w>
    And   c.height = <h>
    And   max_channel_difference(p6, ref) ≤ 1

    Examples:
      | render           | file                                            | w    | h   |
      | primitive_fields | "reference/chapter-23/primitive-fields.ppm"     | 640  | 160 |
      | error_map        | "reference/chapter-23/error-map.ppm"            | 480  | 160 |
      | fields_vs_paths  | "reference/chapter-23/fields-vs-paths.ppm"      | 600  | 400 |
      | fillets          | "reference/chapter-23/fillets.ppm"              | 640  | 160 |
      | transform_demo   | "reference/chapter-23/transform-demo.ppm"       | 576  | 192 |
      | atlas_corners    | "reference/chapter-23/atlas-corners.ppm"        | 1200 | 400 |
      | trap_shrink      | "reference/chapter-23/trap-shrink.ppm"          | 340  | 160 |
      | title            | "reference/chapter-23/title.ppm"                | 900  | 220 |

  Scenario: What the renders show
    Given bands ← canvas_to_p6(primitive_fields())
    And   errors ← canvas_to_p6(error_map())
    And   both ← canvas_to_p6(fields_vs_paths())
    And   fil ← canvas_to_p6(fillets())
    And   atlas ← canvas_to_p6(atlas_corners())
    And   shrunk ← canvas_to_p6(trap_shrink())
    Then  ppm_pixel(bands, 80, 80) = (57, 92, 101) ± 1
    And   ppm_pixel(bands, 80, 30) = (185, 188, 184) ± 1
    And   ppm_pixel(bands, 560, 80) = (145, 117, 62) ± 1
    And   ppm_pixel(errors, 80, 80) = (243, 196, 89) ± 1
    And   ppm_pixel(errors, 240, 58) = (180, 95, 149) ± 1
    And   ppm_pixel(errors, 400, 58) = (39, 39, 44) ± 1
    And   ppm_pixel(both, 529, 114) = (243, 196, 89) ± 1
    And   ppm_pixel(both, 529, 314) = (243, 196, 89) ± 1
    And   ppm_pixel(both, 529, 75) = (39, 39, 44) ± 1
    And   ppm_pixel(fil, 98, 63) = (39, 39, 44) ± 1
    And   ppm_pixel(fil, 578, 63) = (243, 196, 89) ± 1
    And   ppm_pixel(atlas, 78, 83) = (39, 39, 44) ± 1
    And   ppm_pixel(atlas, 378, 83) = (243, 196, 89) ± 1
    And   ppm_pixel(shrunk, 85, 80) = (39, 39, 44) ± 1
    And   ppm_pixel(shrunk, 255, 80) = (243, 196, 89) ± 1

  Scenario: Plate 23
    Given c ← plate_23()
    And   ref ← read_file("reference/chapter-23/plate-23.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 800
    And   c.height = 200
    And   ppm_pixel(p6, 3, 3) = (99, 82, 52) ± 1
    And   ppm_pixel(p6, 206, 3) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 283, 45) = (243, 196, 89) ± 1
    And   ppm_pixel(p6, 606, 100) = (45, 40, 48) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
