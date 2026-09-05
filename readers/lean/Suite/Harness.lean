/-
  A very small test harness: one named check per Gherkin scenario.
-/
import Renderer
open Renderer

abbrev T := ReaderT (IO.Ref (Array String)) IO

def note (msg : String) : T Unit := do (← read).modify (·.push msg)

def chk (ok : Bool) (msg : String) : T Unit := unless ok do note msg

/-- `a = b`, with the book's tolerance unless another is given. -/
def eqF (label : String) (a b : Float) (eps : Float := epsilon) : T Unit :=
  chk (approxEq a b eps) s!"{label}: got {a}, expected {b} (±{eps})"

/-- `a ≠ b` -/
def neF (label : String) (a b : Float) (eps : Float := epsilon) : T Unit :=
  chk (!approxEq a b eps) s!"{label}: got {a}, expected not {b} (±{eps})"

def eqC (label : String) (a b : Color) (eps : Float := epsilon) : T Unit :=
  chk (a.approxEq b eps) s!"{label}: got {a}, expected {b} (±{eps})"

def neC (label : String) (a b : Color) (eps : Float := epsilon) : T Unit :=
  chk (!a.approxEq b eps) s!"{label}: got {a}, expected not {b} (±{eps})"

def eqN (label : String) (a b : Nat) : T Unit :=
  chk (a == b) s!"{label}: got {a}, expected {b}"

def leN (label : String) (a b : Nat) : T Unit :=
  chk (a <= b) s!"{label}: got {a}, expected ≤ {b}"

def eqB (label : String) (a b : Bool) : T Unit :=
  chk (a == b) s!"{label}: got {a}, expected {b}"

def triStr (t : Nat × Nat × Nat) : String := s!"({t.1}, {t.2.1}, {t.2.2})"

/-- A triple of whole numbers compares exactly, unless `± 1` says otherwise. -/
def eqTri (label : String) (g e : Nat × Nat × Nat) (tol : Nat := 0) : T Unit :=
  let d (a b : Nat) : Nat := if a > b then a - b else b - a
  chk (d g.1 e.1 <= tol && d g.2.1 e.2.1 <= tol && d g.2.2 e.2.2 <= tol)
    s!"{label}: got {triStr g}, expected {triStr e} (±{tol})"

def eqS (label : String) (a b : String) : T Unit :=
  chk (a == b) s!"{label}: got {repr a}, expected {repr b}"

def pairStr (p : Nat × Nat) : String := s!"({p.1}, {p.2})"

def pixelListStr (a : Array (Nat × Nat)) : String :=
  "[" ++ String.intercalate ", " (a.toList.map pairStr) ++ "]"

/-- "lit_pixels(c) = [(x, y), ...]", or comparing two canvases' `lit_pixels`. -/
def eqPixels (label : String) (a b : Array (Nat × Nat)) : T Unit :=
  chk (a == b) s!"{label}: got {pixelListStr a}, expected {pixelListStr b}"

def textLines (s : String) : Array String := (s.splitOn "\n").toArray

/-- "lines a-b of ppm are" a quoted block. -/
def linesAre (s : String) (a : Nat) (expected : List String) : T Unit := do
  let ls := textLines s
  for (want, i) in expected.zipIdx do
    let n := a + i
    if _h : n - 1 < ls.size then
      eqS s!"line {n}" ls[n-1] want
    else
      note s!"line {n}: missing (file has {ls.size} lines)"

/-! ### Byte-level checks, for P6 -/

/-- "p6 begins with ..." -/
def beginsWith (label : String) (b : ByteArray) (s : String) : T Unit := do
  let p := s.toUTF8
  let ok := Id.run do
    if b.size < p.size then return false
    let mut ok := true
    for i in [0:p.size] do
      if b[i]! != p[i]! then ok := false
    return ok
  chk ok s!"{label}: does not begin with {repr s}"

/-- "byte N of p6 = v". The book counts bytes from 1: for a 2-by-1 canvas the
    11-byte header is bytes 1-11 and the first pixel byte is byte 12. -/
def eqByte (label : String) (b : ByteArray) (n v : Nat) : T Unit :=
  if _h : n - 1 < b.size then
    eqN label b[n-1]!.toNat v
  else
    note s!"{label}: file has only {b.size} bytes"

structure Runner where
  passed : IO.Ref Nat
  failed : IO.Ref Nat

/-- Every scenario that doesn't say otherwise expects linear blending on,
    so the switch is reset before each one. -/
def Runner.run (r : Runner) (name : String) (body : T Unit) : IO Unit := do
  setLinearBlending true
  let errs ← IO.mkRef (#[] : Array String)
  try
    body.run errs
  catch e =>
    errs.modify (·.push s!"exception: {e}")
  let es ← errs.get
  if es.isEmpty then
    r.passed.modify (· + 1)
    IO.println s!"PASS  {name}"
  else
    r.failed.modify (· + 1)
    IO.println s!"FAIL  {name}"
    for e in es do IO.println s!"        {e}"
