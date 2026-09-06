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
  let t2 ← IO.monoMsNow
  let fbo ← fanBothOrders
  let t3 ← IO.monoMsNow
  IO.println s!"fan_both_orders: {t3 - t2}ms"
  saveP6 "fan-both-orders.ppm" fbo
  let t4 ← IO.monoMsNow
  let p4 ← plate04
  let t5 ← IO.monoMsNow
  IO.println s!"plate_04: {t5 - t4}ms"
  saveP6 "plate-04.ppm" p4
  let t6 ← IO.monoMsNow
  let sc ← starCenters
  let t7 ← IO.monoMsNow
  IO.println s!"star_centers: {t7 - t6}ms"
  saveP6 "star-centers.ppm" sc
  let t8 ← IO.monoMsNow
  let scov ← starCoverage
  let t9 ← IO.monoMsNow
  IO.println s!"star_coverage: {t9 - t8}ms"
  saveP6 "star-coverage.ppm" scov
  let t10 ← IO.monoMsNow
  let p5 ← plate05
  let t11 ← IO.monoMsNow
  IO.println s!"plate_05: {t11 - t10}ms"
  saveP6 "plate-05.ppm" p5
  let t12 ← IO.monoMsNow
  let sp ← spiral
  let t13 ← IO.monoMsNow
  IO.println s!"spiral: {t13 - t12}ms"
  saveP6 "spiral.ppm" sp
  let t14 ← IO.monoMsNow
  let p6 ← plate06
  let t15 ← IO.monoMsNow
  IO.println s!"plate_06: {t15 - t14}ms"
  saveP6 "plate-06.ppm" p6
