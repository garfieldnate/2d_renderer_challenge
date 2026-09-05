// Write the book's pictures to out/. Chapter 1 as P3, chapters 2 and 3 as P6.
import type { Canvas } from "./canvas.ts";
import { canvas_to_p6, canvas_to_ppm } from "./ppm.ts";
import {
  clamp_pair,
  disc_centers,
  disc_coverage,
  fan_bresenham,
  fan_coverage,
  fan_wu,
  gray_match,
  painted_twice,
  plate_01,
  plate_02,
  plate_03,
  quarter_match,
  ramp,
} from "./scenes.ts";

const p3: [string, () => Canvas][] = [
  ["out/gray-match.ppm", gray_match],
  ["out/quarter-match.ppm", quarter_match],
  ["out/ramp.ppm", ramp],
  ["out/clamp-pair.ppm", clamp_pair],
  ["out/plate-01.ppm", plate_01],
];

const p6: [string, () => Canvas][] = [
  ["out/disc-centers.ppm", disc_centers],
  ["out/disc-coverage.ppm", disc_coverage],
  ["out/painted-twice.ppm", painted_twice],
  ["out/plate-02.ppm", plate_02],
  ["out/fan-bresenham.ppm", fan_bresenham],
  ["out/fan-wu.ppm", fan_wu],
  ["out/fan-coverage.ppm", fan_coverage],
  ["out/plate-03.ppm", plate_03],
];

Deno.mkdirSync("out", { recursive: true });
for (const [path, scene] of p3) {
  Deno.writeTextFileSync(path, canvas_to_ppm(scene()));
  console.log("wrote", path);
}
for (const [path, scene] of p6) {
  Deno.writeFileSync(path, canvas_to_p6(scene()));
  console.log("wrote", path);
}
