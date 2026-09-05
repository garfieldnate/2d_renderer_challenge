# The 2D Renderer Challenge — TypeScript / Deno

Chapters 1 and 2, one test file per feature file. Run both from this directory.

```sh
deno test --allow-read            # every scenario in features/
deno run --allow-write --allow-read src/render.ts   # writes the pictures to out/
```

`src/` holds the renderer; `tests/` holds one file per `features/*.feature`;
`out/` gets chapter 1's pictures as P3 text and chapter 2's as binary P6.
