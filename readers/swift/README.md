# The 2D Renderer Challenge — Swift

Chapters 1–2. Plain `swiftc`, no SwiftPM, no dependencies, no network.
Run everything from this directory.

```sh
./build.sh          # swiftc -O -o run Sources/*.swift
./run               # runs all 87 scenarios, per-chapter counts, exits non-zero on failure
./run render        # writes out/ — chapter 1 as P3, chapter 2 as P6
```

`Sources/Renderer.swift` is the renderer (sections numbered as in the book),
`Sources/Tests.swift` is one `scenario` per Gherkin scenario in `features/`,
`Sources/main.swift` is the entry point.

Chapter 2 writes `out/disc-centers.ppm`, `out/disc-coverage.ppm`,
`out/painted-twice.ppm` and `out/plate-02.ppm`; all four are byte-identical to
`reference/chapter-02/`.

Build with `-O`. Unoptimized the suite takes 3.9 s instead of 0.49 s.
