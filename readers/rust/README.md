# The 2D Renderer Challenge — Rust

Chapters 1 (`The Canvas and the Color`) through 8 (`Curves`), stdlib only.

## Build, test, render

```
cargo test --release   # every scenario in features/, chapters 1-8
cargo run --release --bin render_all   # writes all renders (P3 + P6) to out/
```

That's it — `cargo build` alone also works if you just want the library to compile.

## Layout

- `src/lib.rs` — the renderer: colors, canvas, sRGB, P3/P6 PPM, shapes,
  coverage buffers, `magnify`, `paint_through`, Bresenham's and Wu's line
  algorithms, `thick_line`, tuples, matrices and transforms, paths and
  winding numbers, the classical scanline sweep, the analytic
  (accumulator-based) exact fill, Bezier curves and flattening, the SVG
  elliptical arc, and the chapter's named figures/plates.
- `src/bin/render_all.rs` — renders every figure/plate to `out/`.
- `tests/*.rs` — one test file per `features/*.feature` file (Gherkin
  scenarios translated 1:1 into `#[test]` functions; outlines expanded per
  row).
- `reference/chapter-0{1..8}/*.ppm` — the book's reference images,
  compared against with `max_channel_difference`.

`--release` matters here: chapter 2's brute-force `coverage()` samples 64
points per pixel per disc, chapter 3's `thick_line` reuses that same
rasterizer for every ray of the fan (twelve 160×160 rasterizations at 64
samples a pixel), and chapter 5's plate rasterizes the star by coverage
twice — comfortably fast in release, noticeably slower in debug.

## Chapter 3 notes

`Shape` gained one variant, `Intersection`, for `thick_line`: four
half-plane parameters (not four `Shape`s) held in a fixed-size array
rather than a `Vec`. (Chapter 4's `Union(Vec<Shape>)` and chapter 5's
`Filled(Box<Path>, Rule)` mean `Shape` is `Clone` but no longer `Copy` —
existing code that used to rely on `Shape: Copy` now borrows a `&Shape`
instead, which turned out to be less friction than cloning throughout.)

## Chapter 5 notes

`Path` is a `Vec<Subpath>`, each `Subpath` a `Vec<Tuple>` plus a `closed`
flag. `edges(p)` always treats every subpath as closed — the flag only
affects where the *next* `line_to` after a `close` starts. `winding_at`
and `crossings` both use the half-open rule (`a.y <= y < b.y` or the
reverse) so a vertex on the ray counts once. `filled(p, rule)` is a new
`Shape` variant so chapter 2's `rasterize`/`rasterize_centers` machinery
draws any path unchanged.

## Chapter 6 notes

`edge_table(p)` reshapes `edges(p)` into non-horizontal `Edge`s
(`y_top`, `y_bottom`, `x_top`, `slope`, `direction`), sorted by `y_top`
then `x_top`. `fill_path_aliased` sweeps the sorted table with an active
edge list — no full rescan per row — and its output is byte-for-byte the
same coverage buffer as chapter 5's `rasterize_centers(filled(p, rule),
w, h)`, checked directly with `max_coverage_difference`. `transform_path`
gives `Path` the same "transform the points, then ask" treatment chapter
4 gave `Shape`.

## Chapter 7 notes

`Accumulator` holds two `Vec<f64>` (`area`, `cover`), one entry per cell.
`add_cell` folds a deposit left of the buffer onto column 0 as pure cover
and drops one right of it; `accumulate_row` splits a piece across the
cells it spans, weighting each cell's area by the trapezoid midpoint
rule; `accumulate` clips a whole edge to the rows it crosses (clamped to
the buffer) and hands each piece to `accumulate_row`, with a horizontal
edge dropped outright. `resolve` sweeps each row left to right, turning
the running cover sum plus each cell's own area into a winding number,
and `apply_rule` folds that (possibly fractional) number into coverage
for `"nonzero"` (`min(1, |w|)`) or `"evenodd"` (the `|w|` triangle wave).
`fill_path` is `accumulator` + `accumulate` over every edge + `resolve`,
and replaces `fill_path_aliased` as the fill from here on (kept only for
chapter 6's own scenarios and the two direct A/B comparisons this
chapter's scenarios make against it). `polygon_area` is the shoelace
formula, used to check the fill's ink against ground truth rather than
against another rasterizer.

`soft_square()` and `star_exact()` and `spiral_smooth()` are named in
`chapter-07.html`'s prose and scenarios but, unlike `needles()`, `rays()`
and `sunburst()`, ship with no pseudocode or figure source in the
chapter. Their geometry (canvas size, magnification, panel layout, ink
choice) was reverse-engineered from the pinned pixel values and the
reference PPMs themselves — see FEEDBACK.md.

## Chapter 8 notes

`Curve` is a `Vec<Tuple>` of 3 (`quadratic`) or 4 (`cubic`) control
points. `point_at`/`split_at` share one `de_casteljau` construction;
`derivative` evaluates the hodograph (control points scaled by degree,
one degree lower) at `t`, so it's a vector (`w = 0`) automatically
through `Tuple` subtraction. `curve_bounds` finds the derivative's roots
in `(0, 1)` directly by degree (linear for a quadratic's derivative,
the quadratic formula for a cubic's) rather than a generic numeric
solver, since those are the only two degrees the book ever has.
`flatten` recurses via `split_at(c, 0.5)` until `flatness(c) <=
tolerance`; `flatten_into_path` appends to a `Path` with `line_to`,
skipping the curve's own first point when the pen is already there.
`arc`/`arc_point` are a direct port of the SVG spec's endpoint-to-center
construction (`Option<Arc>`, `None` for a degenerate arc), including the
radius-growing correction and the large_arc/sweep angle adjustment.
`derivative`, `curve_bounds`, `polyline_length` and `flatten_length` have
no JS reference source in the chapter either (only prose and scenarios);
their algorithms are standard Bezier math, not lifted from the book.
