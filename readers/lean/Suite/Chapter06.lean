/-
  Every scenario in features/chapter06-*.feature, one named check each.
-/
import Suite.Harness
open Renderer

def chapter06 (r : Runner) : IO Unit := do

  --------------------------------------------------------------------- edges
  IO.println "# features/chapter06-edges.feature"

  r.run "A rectangle has two edges in its table" do
    let p := polygon #[point 2 2, point 6 2, point 6 6, point 2 6]
    let t := edgeTable p
    eqN "length(t)" t.size 2
    eqF "t[0].y_top" t[0]!.yTop 2
    eqF "t[0].y_bottom" t[0]!.yBottom 6
    eqF "t[0].x_top" t[0]!.xTop 2
    eqF "t[0].slope" t[0]!.slope 0
    eqI "t[0].direction" t[0]!.direction (-1)
    eqF "t[1].x_top" t[1]!.xTop 6
    eqI "t[1].direction" t[1]!.direction 1

  r.run "A triangle's edges carry their slopes" do
    let p := polygon #[point 0 0, point 10 0, point 5 10]
    let t := edgeTable p
    eqN "length(t)" t.size 2
    eqF "t[0].x_top" t[0]!.xTop 0
    eqF "t[0].slope" t[0]!.slope 0.5
    eqI "t[0].direction" t[0]!.direction (-1)
    eqF "t[1].x_top" t[1]!.xTop 10
    eqF "t[1].slope" t[1]!.slope (-0.5)
    eqI "t[1].direction" t[1]!.direction 1

  r.run "The table is sorted by top, then by x at the top" do
    let p := path
    let p := moveTo p (point 2 2)
    let p := lineTo p (point 4 1)
    let p := lineTo p (point 6 3)
    let p := lineTo p (point 8 1)
    let p := lineTo p (point 9 6)
    let p := lineTo p (point 1 6)
    let p := close p
    let t := edgeTable p
    eqN "length(t)" t.size 5
    eqF "t[0].y_top" t[0]!.yTop 1
    eqF "t[0].x_top" t[0]!.xTop 4
    eqF "t[1].y_top" t[1]!.yTop 1
    eqF "t[1].x_top" t[1]!.xTop 4
    eqF "t[2].y_top" t[2]!.yTop 1
    eqF "t[2].x_top" t[2]!.xTop 8
    eqF "t[3].y_top" t[3]!.yTop 1
    eqF "t[3].x_top" t[3]!.xTop 8
    eqF "t[4].y_top" t[4]!.yTop 2
    eqF "t[4].x_top" t[4]!.xTop 2

  r.run "A horizontal edge is dropped, not clamped" do
    let p := polygon #[point 0 0, point 10 0, point 10 5, point 0 5]
    let t := edgeTable p
    eqN "length(t)" t.size 2
    eqF "t[0].x_top" t[0]!.xTop 0
    eqF "t[1].x_top" t[1]!.xTop 10

  r.run "An edge knows where it crosses a height" do
    let p := polygon #[point 0 0, point 10 0, point 5 10]
    let t := edgeTable p
    eqF "x_at(t[0], 4)" (xAt t[0]! 4) 2
    eqF "x_at(t[1], 4)" (xAt t[1]! 4) 8
    eqF "x_at(t[0], 0.5)" (xAt t[0]! 0.5) 0.25

  r.run "The edge table is the same whichever way the path was drawn" do
    let a := polygon #[point 0 0, point 10 0, point 5 10]
    let b := polygon #[point 0 0, point 5 10, point 10 0]
    let ta := edgeTable a
    let tb := edgeTable b
    eqF "ta[0].x_top" ta[0]!.xTop tb[0]!.xTop
    eqF "ta[0].slope" ta[0]!.slope tb[0]!.slope
    eqI "ta[0].direction" ta[0]!.direction (-1)
    eqI "tb[0].direction" tb[0]!.direction 1

  --------------------------------------------------------------------- spans
  IO.println "# features/chapter06-spans.feature"

  r.run "Crossings on a row, sorted by x" do
    let p := polygon #[point 2 2, point 6 2, point 6 6, point 2 6]
    let t := edgeTable p
    eqCrossings "xs" (crossingsOnRow t 3.5) #[(2, -1), (6, 1)]
    eqCrossings "crossings_on_row(edge_table(p), 1.5)" (crossingsOnRow t 1.5) #[]
    eqCrossings "crossings_on_row(edge_table(p), 6)" (crossingsOnRow t 6) #[]
    eqN "length(crossings_on_row(edge_table(p), 2))" (crossingsOnRow t 2).size 2

  r.run "The star's crossings through its middle" do
    let t := edgeTable star
    let xs := crossingsOnRow t 80.5
    eqN "length(xs)" xs.size 4
    eqCrossings "xs" xs #[(43.6988, -1), (57.7556, -1), (103.2444, 1), (117.3012, 1)]

  r.run "Spans from crossings under each rule" do
    let xs : Array (Float × Int) := #[(1, 1), (3, 1), (5, -1), (7, -1)]
    eqSpans "spans_from_crossings(xs, \"nonzero\")" (spansFromCrossings xs "nonzero") #[(1, 7)]
    eqSpans "spans_from_crossings(xs, \"evenodd\")" (spansFromCrossings xs "evenodd")
      #[(1, 3), (5, 7)]
    eqSpans "spans_from_crossings([], \"nonzero\")" (spansFromCrossings #[] "nonzero") #[]

  r.run "The spans of an axis-aligned rectangle are exact" do
    let p := polygon #[point 1.25 2, point 4.75 2, point 4.75 5, point 1.25 5]
    eqSpans "spans(p, \"nonzero\", 1)" (spans p "nonzero" 1) #[]
    eqSpans "spans(p, \"nonzero\", 2)" (spans p "nonzero" 2) #[(1.25, 4.75)]
    eqSpans "spans(p, \"nonzero\", 4)" (spans p "nonzero" 4) #[(1.25, 4.75)]
    eqSpans "spans(p, \"nonzero\", 5)" (spans p "nonzero" 5) #[]

  r.run "A rectangle whose edges sit on sample heights" do
    let p := polygon #[point 1.5 2.5, point 4.5 2.5, point 4.5 5.5, point 1.5 5.5]
    eqSpans "spans(p, \"nonzero\", 1)" (spans p "nonzero" 1) #[]
    eqSpans "spans(p, \"nonzero\", 2)" (spans p "nonzero" 2) #[(1.5, 4.5)]
    eqSpans "spans(p, \"nonzero\", 4)" (spans p "nonzero" 4) #[(1.5, 4.5)]
    eqSpans "spans(p, \"nonzero\", 5)" (spans p "nonzero" 5) #[]

  for (row, x0, x1) in
    #[((0 : Nat), (0.25 : Float), (9.75 : Float)), (1, 0.75, 9.25), (4, 2.25, 7.75), (9, 4.75, 5.25)] do
    r.run s!"A triangle's spans narrow by one per row [row={row}, x0={x0}, x1={x1}]" do
      let p := polygon #[point 0 0, point 10 0, point 5 10]
      eqSpans s!"spans(p, \"nonzero\", {row})" (spans p "nonzero" row) #[(x0, x1)]

  r.run "The row past the triangle's apex has no span" do
    let p := polygon #[point 0 0, point 10 0, point 5 10]
    eqSpans "spans(p, \"nonzero\", 10)" (spans p "nonzero" 10) #[]

  r.run "A flat top is not a span of its own" do
    let p := polygon #[point 0 0, point 10 0, point 10 5, point 0 5]
    eqN "length(edge_table(p))" (edgeTable p).size 2
    eqSpans "spans(p, \"nonzero\", 0)" (spans p "nonzero" 0) #[(0, 10)]
    eqSpans "spans(p, \"nonzero\", 4)" (spans p "nonzero" 4) #[(0, 10)]
    eqSpans "spans(p, \"nonzero\", 5)" (spans p "nonzero" 5) #[]

  r.run "A ring is two spans under even-odd and one under nonzero" do
    let p := path
    let p := moveTo p (point 0 0)
    let p := lineTo p (point 10 0)
    let p := lineTo p (point 10 10)
    let p := lineTo p (point 0 10)
    let p := close p
    let p := moveTo p (point 3 3)
    let p := lineTo p (point 7 3)
    let p := lineTo p (point 7 7)
    let p := lineTo p (point 3 7)
    let p := close p
    eqSpans "spans(p, \"nonzero\", 5)" (spans p "nonzero" 5) #[(0, 10)]
    eqSpans "spans(p, \"evenodd\", 5)" (spans p "evenodd" 5) #[(0, 3), (7, 10)]

  r.run "The star's spans through its middle" do
    let p := star
    eqSpans "spans(p, \"nonzero\", 80)" (spans p "nonzero" 80) #[(43.6988, 117.3012)]
    eqSpans "spans(p, \"evenodd\", 80)" (spans p "evenodd" 80) #[(43.6988, 57.7556), (103.2444, 117.3012)]

  r.run "fill_span fills the pixels whose centers are in the span" do
    let cov := coverageBuffer 8 3
    let cov := fillSpan cov 1 1.25 4.75
    eqF "coverage_at(cov, 0, 1)" (coverageAt cov 0 1) 0
    eqF "coverage_at(cov, 1, 1)" (coverageAt cov 1 1) 1
    eqF "coverage_at(cov, 4, 1)" (coverageAt cov 4 1) 1
    eqF "coverage_at(cov, 5, 1)" (coverageAt cov 5 1) 0
    eqF "coverage_at(cov, 2, 0)" (coverageAt cov 2 0) 0
    eqF "ink(cov)" (ink cov) 4

  r.run "The span is half-open at its right end" do
    let cov := coverageBuffer 8 3
    let cov := fillSpan cov 1 1.5 4.5
    eqF "coverage_at(cov, 1, 1)" (coverageAt cov 1 1) 1
    eqF "coverage_at(cov, 3, 1)" (coverageAt cov 3 1) 1
    eqF "coverage_at(cov, 4, 1)" (coverageAt cov 4 1) 0
    eqF "ink(cov)" (ink cov) 3

  r.run "A span may run off either side of the buffer" do
    let a := coverageBuffer 8 3
    let b := coverageBuffer 8 3
    let c := coverageBuffer 8 3
    let a := fillSpan a 1 (-3) 2.5
    let b := fillSpan b 1 6.5 20
    let c := fillSpan c 1 2.5 2.5
    eqF "ink(a)" (ink a) 2
    eqF "coverage_at(a, 1, 1)" (coverageAt a 1 1) 1
    eqF "ink(b)" (ink b) 2
    eqF "coverage_at(b, 6, 1)" (coverageAt b 6 1) 1
    eqF "ink(c)" (ink c) 0

  -------------------------------------------------------------------- sweep
  IO.println "# features/chapter06-sweep.feature"

  r.run "Two buffers that differ" do
    let a := coverageBuffer 3 3
    let b := coverageBuffer 3 3
    let a := setCoverage a 1 1 1
    let b := setCoverage b 1 1 0.25
    eqF "max_coverage_difference(a, b)" (maxCoverageDifference a b) 0.75
    eqF "max_coverage_difference(a, a)" (maxCoverageDifference a a) 0

  r.run "Buffers of different sizes are as different as it gets" do
    let a := coverageBuffer 3 3
    let b := coverageBuffer 3 4
    eqF "max_coverage_difference(a, b)" (maxCoverageDifference a b) 1

  r.run "A rectangle" do
    let p := polygon #[point 2 2, point 6 2, point 6 6, point 2 6]
    let cov := fillPathAliased p "nonzero" 8 8
    eqF "coverage_at(cov, 2, 2)" (coverageAt cov 2 2) 1
    eqF "coverage_at(cov, 5, 5)" (coverageAt cov 5 5) 1
    eqF "coverage_at(cov, 6, 5)" (coverageAt cov 6 5) 0
    eqF "coverage_at(cov, 5, 6)" (coverageAt cov 5 6) 0
    eqF "coverage_at(cov, 1, 2)" (coverageAt cov 1 2) 0
    eqF "ink(cov)" (ink cov) 16
    eqF "max_coverage_difference(cov, rasterize_centers(filled(p, \"nonzero\"), 8, 8))"
      (maxCoverageDifference cov (rasterizeCenters (filled p "nonzero") 8 8)) 0

  r.run "A triangle" do
    let p := polygon #[point 0 0, point 10 0, point 5 10]
    let cov := fillPathAliased p "nonzero" 20 20
    eqF "coverage_at(cov, 0, 0)" (coverageAt cov 0 0) 1
    eqF "coverage_at(cov, 9, 0)" (coverageAt cov 9 0) 1
    eqF "coverage_at(cov, 10, 0)" (coverageAt cov 10 0) 0
    eqF "coverage_at(cov, 4, 8)" (coverageAt cov 4 8) 1
    eqF "coverage_at(cov, 3, 8)" (coverageAt cov 3 8) 0
    eqF "coverage_at(cov, 5, 9)" (coverageAt cov 5 9) 0
    eqF "ink(cov)" (ink cov) 50
    eqF "max_coverage_difference(cov, rasterize_centers(filled(p, \"nonzero\"), 20, 20))"
      (maxCoverageDifference cov (rasterizeCenters (filled p "nonzero") 20 20)) 0

  r.run "The same triangle drawn the other way round" do
    let a := polygon #[point 0 0, point 10 0, point 5 10]
    let b := polygon #[point 0 0, point 5 10, point 10 0]
    let ca := fillPathAliased a "nonzero" 20 20
    let cb := fillPathAliased b "nonzero" 20 20
    eqF "max_coverage_difference(ca, cb)" (maxCoverageDifference ca cb) 0

  r.run "A polygon circle" do
    let p := circlePath 10.3 9.7 7 12
    let cov := fillPathAliased p "nonzero" 20 20
    eqF "ink(cov)" (ink cov) 145
    eqF "max_coverage_difference(cov, rasterize_centers(filled(p, \"nonzero\"), 20, 20))"
      (maxCoverageDifference cov (rasterizeCenters (filled p "nonzero") 20 20)) 0

  r.run "The star, both rules, matches chapter 5 pixel for pixel" do
    let p := star
    let nz := fillPathAliased p "nonzero" 160 160
    let eo := fillPathAliased p "evenodd" 160 160
    eqF "ink(nz)" (ink nz) 5480
    eqF "ink(eo)" (ink eo) 3780
    eqF "coverage_at(nz, 80, 80)" (coverageAt nz 80 80) 1
    eqF "coverage_at(eo, 80, 80)" (coverageAt eo 80 80) 0
    eqF "max_coverage_difference(nz, rasterize_centers(filled(p, \"nonzero\"), 160, 160))"
      (maxCoverageDifference nz (rasterizeCenters (filled p "nonzero") 160 160)) 0
    eqF "max_coverage_difference(eo, rasterize_centers(filled(p, \"evenodd\"), 160, 160))"
      (maxCoverageDifference eo (rasterizeCenters (filled p "evenodd") 160 160)) 0

  r.run "An edge that starts on a sample height is active there, and one that ends there is not" do
    let p := polygon #[point 1.5 2.5, point 4.5 2.5, point 4.5 5.5, point 1.5 5.5]
    let cov := fillPathAliased p "nonzero" 8 8
    eqF "coverage_at(cov, 2, 1)" (coverageAt cov 2 1) 0
    eqF "coverage_at(cov, 2, 2)" (coverageAt cov 2 2) 1
    eqF "coverage_at(cov, 2, 4)" (coverageAt cov 2 4) 1
    eqF "coverage_at(cov, 2, 5)" (coverageAt cov 2 5) 0
    eqF "coverage_at(cov, 1, 3)" (coverageAt cov 1 3) 1
    eqF "coverage_at(cov, 4, 3)" (coverageAt cov 4 3) 0
    eqF "ink(cov)" (ink cov) 9
    eqF "max_coverage_difference(cov, rasterize_centers(filled(p, \"nonzero\"), 8, 8))"
      (maxCoverageDifference cov (rasterizeCenters (filled p "nonzero") 8 8)) 0

  r.run "A polygon larger than the buffer fills it" do
    let p := polygon #[point (-5) (-5), point 30 (-5), point 30 30, point (-5) 30]
    let cov := fillPathAliased p "nonzero" 8 8
    eqF "ink(cov)" (ink cov) 64

  r.run "An empty path fills nothing" do
    let p := path
    let cov := fillPathAliased p "nonzero" 8 8
    eqF "ink(cov)" (ink cov) 0

  r.run "transform_path takes every point through the matrix and keeps the flags" do
    let p := polygon #[point 1.25 2, point 4.75 2, point 4.75 5, point 1.25 5]
    let q := transformPath p (translation 10 20)
    eqN "length(subpaths(q))" (subpaths q).size 1
    eqB "subpaths(q)[0].closed" (subpaths q)[0]!.closed true
    eqT "subpaths(q)[0].points[0]" (subpaths q)[0]!.points[0]! (point 11.25 22)
    eqT "subpaths(q)[0].points[2]" (subpaths q)[0]!.points[2]! (point 14.75 25)
    eqT "subpaths(p)[0].points[0]" (subpaths p)[0]!.points[0]! (point 1.25 2)

  r.run "A transformed star fills where the transform put it" do
    let p := transformPath star
      (translation 10 10 * scaling 0.11 0.11 * translation (-80.5) (-80.5))
    let nz := fillPathAliased p "nonzero" 20 20
    let eo := fillPathAliased p "evenodd" 20 20
    eqBounds "bounds(p)" (bounds p) (2.6769, 2.3, 17.3231, 16.2294)
    eqF "ink(nz)" (ink nz) 60
    eqF "ink(eo)" (ink eo) 40
    eqF "max_coverage_difference(nz, rasterize_centers(filled(p, \"nonzero\"), 20, 20))"
      (maxCoverageDifference nz (rasterizeCenters (filled p "nonzero") 20 20)) 0

  --------------------------------------------------------------------- plate
  IO.println "# features/chapter06-plate.feature"

  r.run "The unit star" do
    let p := unitStar
    eqN "length(edges(p))" (edges p).size 5
    eqT "subpaths(p)[0].points[0]" (subpaths p)[0]!.points[0]! (point 0 (-1))
    eqT "subpaths(p)[0].points[1]" (subpaths p)[0]!.points[1]! (point 0.5878 0.809)
    eqT "subpaths(p)[0].points[2]" (subpaths p)[0]!.points[2]! (point (-0.9511) (-0.309))
    eqBounds "bounds(p)" (bounds p) (-0.9511, -1, 0.9511, 0.809)

  r.run "The spiral" do
    let c ← spiral
    let ref ← readFile "reference/chapter-06/spiral.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 320
    eqN "c.height" c.height 320
    eqTri "ppm_pixel(p6, 180, 160)" (ppmPixel p6 180 160) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 183, 171)" (ppmPixel p6 183 171) (124, 196, 237) 1
    eqTri "ppm_pixel(p6, 179, 183)" (ppmPixel p6 179 183) (237, 137, 149) 1
    eqTri "ppm_pixel(p6, 104, 139)" (ppmPixel p6 104 139) (237, 137, 149) 1
    eqTri "ppm_pixel(p6, 230, 111)" (ppmPixel p6 230 111) (124, 196, 237) 1
    eqTri "ppm_pixel(p6, 32, 137)" (ppmPixel p6 32 137) (124, 196, 237) 1
    eqTri "ppm_pixel(p6, 34, 104)" (ppmPixel p6 34 104) (237, 137, 149) 1
    eqTri "ppm_pixel(p6, 160, 160)" (ppmPixel p6 160 160) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 5, 5)" (ppmPixel p6 5 5) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 300, 20)" (ppmPixel p6 300 20) (39, 39, 44) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1

  r.run "Plate 6" do
    let c ← plate06
    let ref ← readFile "reference/chapter-06/plate-06.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 640
    eqN "c.height" c.height 640
    eqTri "ppm_pixel(p6, 360, 320)" (ppmPixel p6 360 320) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 68, 208)" (ppmPixel p6 68 208) (237, 137, 149) 1
    eqTri "ppm_pixel(p6, 320, 320)" (ppmPixel p6 320 320) (39, 39, 44) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1
