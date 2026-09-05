/-
  Every scenario in features/*.feature, one named check each.
  Scenario Outlines are expanded to one check per Examples row.
  Run from the project root so that reference/... resolves.
-/
import Suite.Harness
import Suite.Chapter01
import Suite.Chapter02
import Suite.Chapter03

def main : IO UInt32 := do
  let r : Runner := { passed := ← IO.mkRef 0, failed := ← IO.mkRef 0 }
  let mark1 ← IO.mkRef (0, 0)
  let mark2 ← IO.mkRef (0, 0)

  chapter01 r
  let p1 ← r.passed.get
  let f1 ← r.failed.get
  mark1.set (p1, f1)

  chapter02 r
  let p2 ← r.passed.get
  let f2 ← r.failed.get
  mark2.set (p2, f2)

  chapter03 r
  let p ← r.passed.get
  let f ← r.failed.get
  let (p1, f1) ← mark1.get
  let (p2, f2) ← mark2.get

  IO.println ""
  IO.println s!"chapter 1: {p1 + f1} scenarios, {p1} passed, {f1} failed"
  IO.println s!"chapter 2: {p2 - p1 + f2 - f1} scenarios, {p2 - p1} passed, {f2 - f1} failed"
  IO.println s!"chapter 3: {p - p2 + f - f2} scenarios, {p - p2} passed, {f - f2} failed"
  IO.println s!"total:     {p + f} scenarios, {p} passed, {f} failed"
  return (if f == 0 then 0 else 1)
