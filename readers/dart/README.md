# The 2D Renderer Challenge — Dart reader implementation

Chapters 1 through 6, implemented from scratch in Dart (SDK 2.18, no pub
packages). Everything is plain `dart` files with relative imports; there is
no `pubspec.yaml` because nothing here imports a `package:` URI.

## Layout

- `lib/renderer.dart` — the renderer itself: color, canvas, sRGB, PPM/P6,
  shapes, coverage buffers, lines (Bresenham, Wu, thick line), tuples,
  matrices, transforms, paths, winding numbers, the scanline sweep, and
  every named render (`gray_match`, `plate_04`, `spiral`, ...).
- `test/harness.dart` — a minimal hand-rolled test runner (no packages):
  `test(name, body)` registers and runs a case, `expect*` helpers assert,
  `summarize()` prints a pass/fail count and sets a non-zero exit code on
  failure.
- `test/chapterNN_test.dart` — every scenario from
  `features/chapterNN-*.feature`, translated one-for-one, in the same
  order as the feature files.
- `test/run_tests.dart` — runs all six chapters' tests and summarizes.
- `tool/render.dart` — writes every chapter's renders to `out/` under the
  reference filenames and prints `max_channel_difference` against
  `reference/chapter-0N/` for each.

## Running the tests

From this directory (`ch6-dart/`), with no build step:

```
dart test/run_tests.dart
```

This runs all 280 translated scenarios across chapters 1-6 and prints a
pass/fail count, plus a list of failures (if any) with actual vs. expected
values. Exits non-zero if anything failed.

## Writing the renders

```
dart tool/render.dart
```

This writes every chapter's renders (P3 for chapter 1, binary P6 from
chapter 2 on, matching the book) to `out/chapter-0N/<name>.ppm`, and prints
the elapsed time and `max_channel_difference` against
`reference/chapter-0N/<name>.ppm` for each. All twenty renders currently
diff at 0 against the reference images and together take well under four
seconds.

## Notes for whoever picks this up next

- `dart analyze .` is clean.
- The library represents both P3 and P6 file content as a single `Ppm`
  class wrapping raw bytes (`List<int>`), per the chapter 2 hint that a P3
  file is "text that happens to be stored in bytes." `ppm_pixel`,
  `distinct_values`, and `max_channel_difference` parse either format from
  the same bytes.
- `Matrix3`'s `operator *` is `dynamic`-typed so it can dispatch on
  `Matrix3 * Matrix3` vs. `Matrix3 * Tup` in a single expression (as the
  scenarios write it, e.g. `A * B`, `A * p`). For a *chain* of three or
  more matrix multiplications, use `mm(a, b)` or `mmAll([a, b, c])`
  instead of `X * Y as Matrix3 * Z as Matrix3` — Dart's operator
  precedence puts `as` below `*`, so an inline chain like that parses in a
  way that is easy to get wrong. `mm`/`mmAll` sidestep the question
  entirely.
