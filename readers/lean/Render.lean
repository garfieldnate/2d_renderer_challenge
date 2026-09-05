/-
  Writes the chapter's five pictures into out/.
-/
import Renderer
open Renderer

def save (name : String) (c : Canvas) : IO Unit := do
  let path := System.FilePath.mk s!"out/{name}"
  IO.FS.writeFile path (canvasToPpm c)
  IO.println s!"wrote {path} ({c.width}x{c.height})"

def main : IO Unit := do
  IO.FS.createDirAll "out"
  save "gray-match.ppm" grayMatch
  save "quarter-match.ppm" quarterMatch
  save "ramp.ppm" ramp
  save "clamp-pair.ppm" clampPair
  save "plate-01.ppm" (← plate01)
