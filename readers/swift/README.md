# The 2D Renderer Challenge — Swift

Chapters 1–3. Plain `swiftc`, no SwiftPM, no dependencies, no network.
Run everything from this directory.

```sh
./build.sh          # swiftc -O -o run Sources/*.swift
./run               # runs all 131 scenarios, per-chapter counts, exits non-zero on failure
./run render        # writes out/ — chapter 1 as P3, chapters 2-3 as P6
```

`Sources/Renderer.swift` is the renderer (sections numbered as in the book),
`Sources/Tests.swift` is one `scenario` per Gherkin scenario in `features/`,
`Sources/main.swift` is the entry point.

Chapter 2 writes `out/disc-centers.ppm`, `out/disc-coverage.ppm`,
`out/painted-twice.ppm` and `out/plate-02.ppm`; chapter 3 adds
`out/fan-bresenham.ppm`, `out/fan-wu.ppm`, `out/fan-coverage.ppm` and
`out/plate-03.ppm`. All eight are byte-identical to `reference/`.

Build with `-O`. Unoptimized the suite takes 3.9 s instead of 0.49 s.

`fan_coverage()` — twelve 160x160 rasterizations at 64 samples/pixel — took
0.020s standalone with `-O` on this machine (`./run render` prints the timing
each time). `paint_through` always mixes in linear light, regardless of the
`linearBlending` switch (see § 2.5); it does not call the switchable `mix()`.
