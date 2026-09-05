// Write the chapter's five pictures to out/.
import { canvas_to_ppm } from "./ppm.ts";
import { clamp_pair, gray_match, plate_01, quarter_match, ramp } from "./scenes.ts";

const jobs: [string, () => ReturnType<typeof ramp>][] = [
  ["out/gray-match.ppm", gray_match],
  ["out/quarter-match.ppm", quarter_match],
  ["out/ramp.ppm", ramp],
  ["out/clamp-pair.ppm", clamp_pair],
  ["out/plate-01.ppm", plate_01],
];

Deno.mkdirSync("out", { recursive: true });
for (const [path, scene] of jobs) {
  Deno.writeTextFileSync(path, canvas_to_ppm(scene()));
  console.log("wrote", path);
}
