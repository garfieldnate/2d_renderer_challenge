# The 2D Renderer Challenge — Rust

Chapters 1 (`The Canvas and the Color`) and 2 (`Coverage`), stdlib only.

## Build, test, render

```
cargo test --release   # every scenario in features/, chapter 1 and chapter 2
cargo run --release --bin render_all   # writes all renders (P3 + P6) to out/
```

That's it — `cargo build` alone also works if you just want the library to compile.

## Layout

- `src/lib.rs` — the renderer: colors, canvas, sRGB, P3/P6 PPM, shapes,
  coverage buffers, `magnify`, `paint_through`, and the chapter's named
  figures/plates.
- `src/bin/render_all.rs` — renders every figure/plate to `out/`.
- `tests/*.rs` — one test file per `features/*.feature` file (Gherkin
  scenarios translated 1:1 into `#[test]` functions; outlines expanded per
  row).
- `reference/chapter-0{1,2}/*.ppm` — the book's reference images, compared
  against with `max_channel_difference`.

`--release` matters here: chapter 2's brute-force `coverage()` samples 64
points per pixel per disc, and the reference renders are 320×320 and
480×240 — comfortably fast in release, noticeably slower in debug.
