/-
  Writes every chapter's pictures into out/.
  Chapter 1's are P3 (text); chapter 2's are P6 (bytes).
-/
import Renderer
open Renderer

def saveP3 (name : String) (c : Canvas) : IO Unit := do
  let path := System.FilePath.mk s!"out/{name}"
  IO.FS.writeFile path (canvasToPpm c)
  IO.println s!"wrote {path} ({c.width}x{c.height}, P3)"

def saveP6 (name : String) (c : Canvas) : IO Unit := do
  let path := System.FilePath.mk s!"out/{name}"
  IO.FS.writeBinFile path (canvasToP6 c)
  IO.println s!"wrote {path} ({c.width}x{c.height}, P6)"

def main : IO Unit := do
  IO.FS.createDirAll "out"
  saveP3 "gray-match.ppm" grayMatch
  saveP3 "quarter-match.ppm" quarterMatch
  saveP3 "ramp.ppm" ramp
  saveP3 "clamp-pair.ppm" clampPair
  saveP3 "plate-01.ppm" (← plate01)
  saveP6 "disc-centers.ppm" (← discCenters)
  saveP6 "disc-coverage.ppm" (← discCoverage)
  saveP6 "painted-twice.ppm" (← paintedTwice)
  saveP6 "plate-02.ppm" (← plate02)
  saveP6 "fan-bresenham.ppm" fanBresenham
  saveP6 "fan-wu.ppm" (← fanWu)
  let t0 ← IO.monoMsNow
  let cov ← fanCoverage
  let t1 ← IO.monoMsNow
  IO.println s!"fan_coverage: {t1 - t0}ms"
  saveP6 "fan-coverage.ppm" cov
  saveP6 "plate-03.ppm" (← plate03)
