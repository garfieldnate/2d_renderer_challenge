# The 2D Renderer Challenge — Rust

Chapters 1 (`The Canvas and the Color`), 2 (`Coverage`) and 3 (`Lines`),
stdlib only.

## Build, test, render

```
cargo test --release   # every scenario in features/, chapters 1-3
cargo run --release --bin render_all   # writes all renders (P3 + P6) to out/
```

That's it — `cargo build` alone also works if you just want the library to compile.

## Layout

- `src/lib.rs` — the renderer: colors, canvas, sRGB, P3/P6 PPM, shapes,
  coverage buffers, `magnify`, `paint_through`, Bresenham's and Wu's line
  algorithms, `thick_line`, and the chapter's named figures/plates.
- `src/bin/render_all.rs` — renders every figure/plate to `out/`.
- `tests/*.rs` — one test file per `features/*.feature` file (Gherkin
  scenarios translated 1:1 into `#[test]` functions; outlines expanded per
  row).
- `reference/chapter-0{1,2,3}/*.ppm` — the book's reference images,
  compared against with `max_channel_difference`.

`--release` matters here: chapter 2's brute-force `coverage()` samples 64
points per pixel per disc, and chapter 3's `thick_line` reuses that same
rasterizer for every ray of the fan (twelve 160×160 rasterizations at 64
samples a pixel) — comfortably fast in release, noticeably slower in
debug.

## Chapter 3 notes

`Shape` gained one variant, `Intersection`, for `thick_line`: four
half-plane parameters (not four `Shape`s) held in a fixed-size array
rather than a `Vec`, so `Shape` stays `Copy` — existing code (`inside(s:
Shape, ...)`, chapter 2's `plate_02`) already relies on being able to use
a shape value more than once without cloning it.
