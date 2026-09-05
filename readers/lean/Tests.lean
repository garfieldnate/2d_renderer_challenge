/-
  Every scenario in features/*.feature, one named check each.
  Scenario Outlines are expanded to one check per Examples row.
  Run from the project root so that reference/... resolves.
-/
import Suite.Harness
import Suite.Chapter01
import Suite.Chapter02

def main : IO UInt32 := do
  let r : Runner := { passed := ← IO.mkRef 0, failed := ← IO.mkRef 0 }
  let mark ← IO.mkRef (0, 0)

  chapter01 r
  let p1 ← r.passed.get
  let f1 ← r.failed.get
  mark.set (p1, f1)

  chapter02 r
  let p ← r.passed.get
  let f ← r.failed.get
  let (p1, f1) ← mark.get

  IO.println ""
  IO.println s!"chapter 1: {p1 + f1} scenarios, {p1} passed, {f1} failed"
  IO.println s!"chapter 2: {p - p1 + f - f1} scenarios, {p - p1} passed, {f - f1} failed"
  IO.println s!"total:     {p + f} scenarios, {p} passed, {f} failed"
  return (if f == 0 then 0 else 1)
