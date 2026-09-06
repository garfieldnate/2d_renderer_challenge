/-
  Every scenario in features/*.feature, one named check each.
  Scenario Outlines are expanded to one check per Examples row.
  Run from the project root so that reference/... resolves.
-/
import Suite.Harness
import Suite.Chapter01
import Suite.Chapter02
import Suite.Chapter03
import Suite.Chapter04
import Suite.Chapter05
import Suite.Chapter06

def main : IO UInt32 := do
  let r : Runner := { passed := ← IO.mkRef 0, failed := ← IO.mkRef 0 }
  let mark1 ← IO.mkRef (0, 0)
  let mark2 ← IO.mkRef (0, 0)
  let mark3 ← IO.mkRef (0, 0)
  let mark4 ← IO.mkRef (0, 0)
  let mark5 ← IO.mkRef (0, 0)

  chapter01 r
  let p1 ← r.passed.get
  let f1 ← r.failed.get
  mark1.set (p1, f1)

  chapter02 r
  let p2 ← r.passed.get
  let f2 ← r.failed.get
  mark2.set (p2, f2)

  chapter03 r
  let p3 ← r.passed.get
  let f3 ← r.failed.get
  mark3.set (p3, f3)

  chapter04 r
  let p4 ← r.passed.get
  let f4 ← r.failed.get
  mark4.set (p4, f4)

  chapter05 r
  let p5 ← r.passed.get
  let f5 ← r.failed.get
  mark5.set (p5, f5)

  chapter06 r
  let p ← r.passed.get
  let f ← r.failed.get
  let (p1, f1) ← mark1.get
  let (p2, f2) ← mark2.get
  let (p3, f3) ← mark3.get
  let (p4, f4) ← mark4.get
  let (p5, f5) ← mark5.get

  IO.println ""
  IO.println s!"chapter 1: {p1 + f1} scenarios, {p1} passed, {f1} failed"
  IO.println s!"chapter 2: {p2 - p1 + f2 - f1} scenarios, {p2 - p1} passed, {f2 - f1} failed"
  IO.println s!"chapter 3: {p3 - p2 + f3 - f2} scenarios, {p3 - p2} passed, {f3 - f2} failed"
  IO.println s!"chapter 4: {p4 - p3 + f4 - f3} scenarios, {p4 - p3} passed, {f4 - f3} failed"
  IO.println s!"chapter 5: {p5 - p4 + f5 - f4} scenarios, {p5 - p4} passed, {f5 - f4} failed"
  IO.println s!"chapter 6: {p - p5 + f - f5} scenarios, {p - p5} passed, {f - f5} failed"
  IO.println s!"total:     {p + f} scenarios, {p} passed, {f} failed"
  return (if f == 0 then 0 else 1)
