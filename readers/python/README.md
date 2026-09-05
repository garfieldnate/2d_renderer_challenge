# 2D Renderer Challenge: Python Implementation

Python 3 implementation of chapters 1 and 2 of the 2D Renderer Challenge, using only the Python standard library.

## Build

No build step required. The implementation uses only Python 3 stdlib.

## Run Tests

```sh
python3 test_runner.py
```

This runs all Gherkin scenarios from both chapter 1 and chapter 2.

## Produce Renders

```sh
python3 -c "
import renderer
import os
os.makedirs('out', exist_ok=True)
for name, func in [('disc-centers.ppm', renderer.disc_centers), ('disc-coverage.ppm', renderer.disc_coverage), ('painted-twice.ppm', renderer.painted_twice), ('plate-02.ppm', renderer.plate_02)]:
    p6 = renderer.canvas_to_p6(func())
    with open(f'out/{name}', 'wb') as f:
        f.write(p6 if isinstance(p6, bytes) else p6.encode('latin-1'))
"
```

## Files

- `renderer.py` — Core graphics functions and chapter implementations
- `test_runner.py` — Gherkin test harness
- `features/` — Gherkin feature files (test specifications)
- `reference/` — Reference images for validation
- `out/` — Generated output images (after rendering)

## Implementation Notes

- Chapter 1 implements the canvas, colors, and PPM output
- Chapter 2 adds coverage buffers, shape queries, and antialiasing via supersampling
- All geometry calculations use floating-point coordinates
- Antialiasing uses 8×8 supersampling (64 samples per pixel)
- P6 binary PPM files are used for efficiency
