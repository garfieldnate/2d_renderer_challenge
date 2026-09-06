/-
  Every scenario in features/chapter05-*.feature, one named check each.
-/
import Suite.Harness
open Renderer

def chapter05 (r : Runner) : IO Unit := do

  ------------------------------------------------------------------- paths
  IO.println "# features/chapter05-paths.feature"

  r.run "An empty path" do
    let p := path
    eqN "length(subpaths(p))" (subpaths p).size 0
    eqN "length(edges(p))" (edges p).size 0
    eqBounds "bounds(p)" (bounds p) (0, 0, 0, 0)

  r.run "A triangle, closed" do
    let p := path
    let p := moveTo p (point 1 1)
    let p := lineTo p (point 9 1)
    let p := lineTo p (point 5 8)
    let p := close p
    eqN "length(subpaths(p))" (subpaths p).size 1
    eqB "subpaths(p)[0].closed" (subpaths p)[0]!.closed true
    eqN "length(subpaths(p)[0].points)" (subpaths p)[0]!.points.size 3
    eqT "subpaths(p)[0].points[2]" (subpaths p)[0]!.points[2]! (point 5 8)
    eqN "length(edges(p))" (edges p).size 3
    eqEdge "edges(p)[2]" (edges p)[2]! (point 5 8, point 1 1)
    eqBounds "bounds(p)" (bounds p) (1, 1, 9, 8)

  r.run "A triangle left open still has three edges" do
    let p := path
    let p := moveTo p (point 1 1)
    let p := lineTo p (point 9 1)
    let p := lineTo p (point 5 8)
    eqB "subpaths(p)[0].closed" (subpaths p)[0]!.closed false
    eqN "length(edges(p))" (edges p).size 3
    eqEdge "edges(p)[2]" (edges p)[2]! (point 5 8, point 1 1)

  r.run "move_to starts a second subpath" do
    let p := path
    let p := moveTo p (point 0 0)
    let p := lineTo p (point 10 0)
    let p := lineTo p (point 10 10)
    let p := lineTo p (point 0 10)
    let p := close p
    let p := moveTo p (point 3 3)
    let p := lineTo p (point 3 7)
    let p := lineTo p (point 7 7)
    let p := lineTo p (point 7 3)
    let p := close p
    eqN "length(subpaths(p))" (subpaths p).size 2
    eqT "subpaths(p)[1].points[0]" (subpaths p)[1]!.points[0]! (point 3 3)
    eqN "length(edges(p))" (edges p).size 8
    eqBounds "bounds(p)" (bounds p) (0, 0, 10, 10)

  r.run "line_to after a close starts a new subpath where the closed one began" do
    let p := path
    let p := moveTo p (point 1 1)
    let p := lineTo p (point 4 1)
    let p := lineTo p (point 4 4)
    let p := close p
    let p := lineTo p (point 9 9)
    eqN "length(subpaths(p))" (subpaths p).size 2
    eqB "subpaths(p)[1].closed" (subpaths p)[1]!.closed false
    eqN "length(subpaths(p)[1].points)" (subpaths p)[1]!.points.size 2
    eqT "subpaths(p)[1].points[0]" (subpaths p)[1]!.points[0]! (point 1 1)
    eqT "subpaths(p)[1].points[1]" (subpaths p)[1]!.points[1]! (point 9 9)

  r.run "line_to with nothing to extend behaves as move_to" do
    let p := path
    let p := lineTo p (point 2 3)
    eqN "length(subpaths(p))" (subpaths p).size 1
    eqN "length(subpaths(p)[0].points)" (subpaths p)[0]!.points.size 1
    eqT "subpaths(p)[0].points[0]" (subpaths p)[0]!.points[0]! (point 2 3)

  r.run "A subpath of one point has no edges, and closing nothing does nothing" do
    let p := path
    let p := close p
    let p := moveTo p (point 1 1)
    let p := moveTo p (point 2 2)
    eqN "length(subpaths(p))" (subpaths p).size 2
    eqN "length(edges(p))" (edges p).size 0
    eqBounds "bounds(p)" (bounds p) (1, 1, 2, 2)

  r.run "A subpath of two points has two edges and encloses nothing" do
    let p := path
    let p := moveTo p (point 1 1)
    let p := lineTo p (point 9 9)
    eqN "length(edges(p))" (edges p).size 2
    eqI "winding_at(p, 3, 5)" (windingAt p 3 5) 0

  r.run "polygon is a closed subpath through its points" do
    let p := polygon #[point 0 0, point 10 0, point 10 10, point 0 10]
    eqN "length(subpaths(p))" (subpaths p).size 1
    eqB "subpaths(p)[0].closed" (subpaths p)[0]!.closed true
    eqN "length(edges(p))" (edges p).size 4

  r.run "circle_path is a polygon standing in for a circle" do
    let p := circlePath 10 10 5 8
    eqN "length(subpaths(p)[0].points)" (subpaths p)[0]!.points.size 8
    eqT "subpaths(p)[0].points[0]" (subpaths p)[0]!.points[0]! (point 15 10)
    eqT "subpaths(p)[0].points[1]" (subpaths p)[0]!.points[1]! (point 13.5355 13.5355)
    eqT "subpaths(p)[0].points[2]" (subpaths p)[0]!.points[2]! (point 10 15)
    eqBounds "bounds(p)" (bounds p) (5, 5, 15, 15)

  ------------------------------------------------------------------ winding
  IO.println "# features/chapter05-winding.feature"

  r.run "Crossings from inside and outside a square" do
    let p := polygon #[point 0 0, point 10 0, point 10 10, point 0 10]
    eqN "crossings(p, 5, 5)" (crossings p 5 5) 1
    eqN "crossings(p, 15, 5)" (crossings p 15 5) 0
    eqN "crossings(p, -1, 5)" (crossings p (-1) 5) 2

  r.run "A clockwise square winds once" do
    let p := polygon #[point 0 0, point 10 0, point 10 10, point 0 10]
    eqI "winding_at(p, 5, 5)" (windingAt p 5 5) 1
    eqI "winding_at(p, 15, 5)" (windingAt p 15 5) 0
    eqI "winding_at(p, -1, 5)" (windingAt p (-1) 5) 0
    eqI "winding_at(p, 5, -1)" (windingAt p 5 (-1)) 0
    eqI "winding_at(p, 5, 11)" (windingAt p 5 11) 0

  r.run "The same square the other way round winds minus once" do
    let p := polygon #[point 0 0, point 0 10, point 10 10, point 10 0]
    eqI "winding_at(p, 5, 5)" (windingAt p 5 5) (-1)
    eqN "crossings(p, 5, 5)" (crossings p 5 5) 1

  r.run "A ray through a vertex counts it once" do
    let p := polygon #[point 5 0, point 10 5, point 5 10, point 0 5]
    eqN "crossings(p, 2, 5)" (crossings p 2 5) 1
    eqI "winding_at(p, 2, 5)" (windingAt p 2 5) 1
    eqN "crossings(p, -1, 5)" (crossings p (-1) 5) 2
    eqI "winding_at(p, -1, 5)" (windingAt p (-1) 5) 0
    eqI "winding_at(p, 12, 5)" (windingAt p 12 5) 0
    eqI "winding_at(p, 5, 5)" (windingAt p 5 5) 1

  r.run "The boundary belongs to the top and the left" do
    let p := polygon #[point 0 0, point 10 0, point 10 10, point 0 10]
    eqI "winding_at(p, 5, 0)" (windingAt p 5 0) 1
    eqI "winding_at(p, 0, 5)" (windingAt p 0 5) 1
    eqI "winding_at(p, 0, 0)" (windingAt p 0 0) 1
    eqI "winding_at(p, 5, 10)" (windingAt p 5 10) 0
    eqI "winding_at(p, 10, 5)" (windingAt p 10 5) 0
    eqI "winding_at(p, 10, 10)" (windingAt p 10 10) 0

  r.run "Two rectangles that share an edge cover it once" do
    let p := path
    let p := moveTo p (point 0 0)
    let p := lineTo p (point 5 0)
    let p := lineTo p (point 5 10)
    let p := lineTo p (point 0 10)
    let p := close p
    let p := moveTo p (point 5 0)
    let p := lineTo p (point 10 0)
    let p := lineTo p (point 10 10)
    let p := lineTo p (point 5 10)
    let p := close p
    eqI "winding_at(p, 2, 5)" (windingAt p 2 5) 1
    eqI "winding_at(p, 5, 5)" (windingAt p 5 5) 1
    eqI "winding_at(p, 8, 5)" (windingAt p 8 5) 1

  r.run "A diamond wound twice has winding number 2" do
    let p := path
    let p := moveTo p (point 5 0)
    let p := lineTo p (point 10 5)
    let p := lineTo p (point 5 10)
    let p := lineTo p (point 0 5)
    let p := lineTo p (point 5 0)
    let p := lineTo p (point 10 5)
    let p := lineTo p (point 5 10)
    let p := lineTo p (point 0 5)
    let p := close p
    eqN "length(edges(p))" (edges p).size 8
    eqI "winding_at(p, 5, 5)" (windingAt p 5 5) 2
    eqN "crossings(p, 5, 5)" (crossings p 5 5) 2
    eqI "winding_at(p, 12, 5)" (windingAt p 12 5) 0

  r.run "The polygon circle" do
    let p := circlePath 10 10 5 8
    eqI "winding_at(p, 10, 10)" (windingAt p 10 10) 1
    eqI "winding_at(p, 14.9, 10)" (windingAt p 14.9 10) 1
    eqI "winding_at(p, 15, 10)" (windingAt p 15 10) 0
    eqI "winding_at(p, 10, 5.1)" (windingAt p 10 5.1) 1
    eqI "winding_at(p, 10, 4.9)" (windingAt p 10 4.9) 0

  r.run "The pentagram's center winds twice" do
    let p := star
    eqI "winding_at(p, 80.5, 80.5)" (windingAt p 80.5 80.5) 2
    eqN "crossings(p, 80.5, 80.5)" (crossings p 80.5 80.5) 2
    eqI "winding_at(p, 80.5, 20)" (windingAt p 80.5 20) 1
    eqI "winding_at(p, 30, 60)" (windingAt p 30 60) 1
    eqN "crossings(p, 30, 60)" (crossings p 30 60) 3
    eqI "winding_at(p, 80.5, 120)" (windingAt p 80.5 120) 0
    eqN "crossings(p, 80.5, 120)" (crossings p 80.5 120) 2
    eqI "winding_at(p, 10, 10)" (windingAt p 10 10) 0

  --------------------------------------------------------------------- rules
  IO.println "# features/chapter05-rules.feature"

  r.run "A single loop is inside under both rules" do
    let p := polygon #[point 0 0, point 10 0, point 10 10, point 0 10]
    eqB "inside_nonzero(p, 5, 5)" (insideNonzero p 5 5) true
    eqB "inside_evenodd(p, 5, 5)" (insideEvenOdd p 5 5) true
    eqB "inside_nonzero(p, 15, 5)" (insideNonzero p 15 5) false
    eqB "inside_evenodd(p, 15, 5)" (insideEvenOdd p 15 5) false

  r.run "An inner loop the other way round is a hole under both rules" do
    let p := path
    let p := moveTo p (point 0 0)
    let p := lineTo p (point 10 0)
    let p := lineTo p (point 10 10)
    let p := lineTo p (point 0 10)
    let p := close p
    let p := moveTo p (point 3 3)
    let p := lineTo p (point 3 7)
    let p := lineTo p (point 7 7)
    let p := lineTo p (point 7 3)
    let p := close p
    eqI "winding_at(p, 5, 5)" (windingAt p 5 5) 0
    eqI "winding_at(p, 1, 1)" (windingAt p 1 1) 1
    eqB "inside_nonzero(p, 5, 5)" (insideNonzero p 5 5) false
    eqB "inside_evenodd(p, 5, 5)" (insideEvenOdd p 5 5) false
    eqB "inside_nonzero(p, 1, 1)" (insideNonzero p 1 1) true

  r.run "An inner loop the same way round is a hole only under even-odd" do
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
    eqI "winding_at(p, 5, 5)" (windingAt p 5 5) 2
    eqB "inside_nonzero(p, 5, 5)" (insideNonzero p 5 5) true
    eqB "inside_evenodd(p, 5, 5)" (insideEvenOdd p 5 5) false

  r.run "A loop wound twice vanishes under even-odd" do
    let p := path
    let p := moveTo p (point 5 0)
    let p := lineTo p (point 10 5)
    let p := lineTo p (point 5 10)
    let p := lineTo p (point 0 5)
    let p := lineTo p (point 5 0)
    let p := lineTo p (point 10 5)
    let p := lineTo p (point 5 10)
    let p := lineTo p (point 0 5)
    let p := close p
    eqB "inside_nonzero(p, 5, 5)" (insideNonzero p 5 5) true
    eqB "inside_evenodd(p, 5, 5)" (insideEvenOdd p 5 5) false

  r.run "The pentagram's center is inside under nonzero and outside under even-odd" do
    let p := star
    eqB "inside_nonzero(p, 80.5, 80.5)" (insideNonzero p 80.5 80.5) true
    eqB "inside_evenodd(p, 80.5, 80.5)" (insideEvenOdd p 80.5 80.5) false
    eqB "inside_nonzero(p, 80.5, 20)" (insideNonzero p 80.5 20) true
    eqB "inside_evenodd(p, 80.5, 20)" (insideEvenOdd p 80.5 20) true
    eqB "inside_nonzero(p, 80.5, 120)" (insideNonzero p 80.5 120) false
    eqB "inside_evenodd(p, 80.5, 120)" (insideEvenOdd p 80.5 120) false

  r.run "A filled path is a shape" do
    let s := filled (polygon #[point 2 2, point 6 2, point 6 6, point 2 6]) "nonzero"
    let cov := rasterize s 8 8
    eqB "inside(s, 3, 3)" (inside s 3 3) true
    eqB "inside(s, 7, 3)" (inside s 7 3) false
    eqF "coverage_at(cov, 3, 3)" (coverageAt cov 3 3) 1
    eqF "coverage_at(cov, 1, 3)" (coverageAt cov 1 3) 0
    eqF "coverage_at(cov, 6, 3)" (coverageAt cov 6 3) 0
    eqF "ink(cov)" (ink cov) 16

  r.run "A filled path takes the rule seriously" do
    let p := star
    let a := filled p "nonzero"
    let b := filled p "evenodd"
    let ca := rasterize a 160 160
    let cb := rasterize b 160 160
    eqF "coverage_at(ca, 80, 80)" (coverageAt ca 80 80) 1
    eqF "coverage_at(cb, 80, 80)" (coverageAt cb 80 80) 0
    eqF "coverage_at(ca, 80, 20)" (coverageAt ca 80 20) 1
    eqF "coverage_at(cb, 80, 20)" (coverageAt cb 80 20) 1
    eqF "coverage_at(ca, 80, 10)" (coverageAt ca 80 10) 0.0625
    eqF "coverage_at(cb, 80, 10)" (coverageAt cb 80 10) 0.0625
    eqF "ink(ca)" (ink ca) 5499.9375
    eqF "ink(cb)" (ink cb) 3800.375

  r.run "Rasterizing within the bounds gives the same coverage" do
    let p := star
    let s := filled p "evenodd"
    let full := rasterize s 160 160
    let within := rasterizeWithin s (bounds p) 160 160
    eqF "ink(within)" (ink within) (ink full)
    eqF "coverage_at(within, 80, 20)" (coverageAt within 80 20) (coverageAt full 80 20)
    eqF "coverage_at(within, 13, 58)" (coverageAt within 13 58) (coverageAt full 13 58)
    eqF "coverage_at(within, 10, 10)" (coverageAt within 10 10) 0

  r.run "The box is inclusive of the pixels it touches, and clipped to the buffer" do
    let s := filled (polygon #[point 1.5 1.5, point 6.5 1.5, point 6.5 6.5, point 1.5 6.5])
      "nonzero"
    let cov := rasterizeWithin s (1.5, 1.5, 6.5, 6.5) 8 8
    let big := rasterizeWithin s (-5, -5, 20, 20) 8 8
    eqF "coverage_at(cov, 1, 1)" (coverageAt cov 1 1) 0.25
    eqF "coverage_at(cov, 6, 6)" (coverageAt cov 6 6) 0.25
    eqF "coverage_at(cov, 3, 3)" (coverageAt cov 3 3) 1
    eqF "ink(cov)" (ink cov) 25
    eqF "ink(big)" (ink big) 25

  --------------------------------------------------------------------- plate
  IO.println "# features/chapter05-plate.feature"

  r.run "The pentagram" do
    let p := star
    eqN "length(subpaths(p))" (subpaths p).size 1
    eqN "length(edges(p))" (edges p).size 5
    eqT "subpaths(p)[0].points[0]" (subpaths p)[0]!.points[0]! (point 80.5 10.5)
    eqT "subpaths(p)[0].points[1]" (subpaths p)[0]!.points[1]! (point 121.645 137.1312)
    eqT "subpaths(p)[0].points[2]" (subpaths p)[0]!.points[2]! (point 13.926 58.8688)
    eqT "subpaths(p)[0].points[3]" (subpaths p)[0]!.points[3]! (point 147.074 58.8688)
    eqT "subpaths(p)[0].points[4]" (subpaths p)[0]!.points[4]! (point 39.355 137.1312)
    eqBounds "bounds(p)" (bounds p) (13.926, 10.5, 147.074, 137.1312)

  r.run "The star by the center question" do
    let c ← starCenters
    let ref ← readFile "reference/chapter-05/star-centers.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 320
    eqN "c.height" c.height 160
    eqTri "ppm_pixel(p6, 80, 80)" (ppmPixel p6 80 80) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 240, 80)" (ppmPixel p6 240 80) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 80, 20)" (ppmPixel p6 80 20) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 240, 20)" (ppmPixel p6 240 20) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 30, 60)" (ppmPixel p6 30 60) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 190, 60)" (ppmPixel p6 190 60) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 80, 120)" (ppmPixel p6 80 120) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 80, 10)" (ppmPixel p6 80 10) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 10, 10)" (ppmPixel p6 10 10) (39, 39, 44) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1

  r.run "The star by coverage" do
    let c ← starCoverage
    let ref ← readFile "reference/chapter-05/star-coverage.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 320
    eqN "c.height" c.height 160
    eqTri "ppm_pixel(p6, 80, 80)" (ppmPixel p6 80 80) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 240, 80)" (ppmPixel p6 240 80) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 80, 20)" (ppmPixel p6 80 20) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 240, 20)" (ppmPixel p6 240 20) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 80, 120)" (ppmPixel p6 80 120) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 80, 10)" (ppmPixel p6 80 10) (77, 65, 48) 1
    eqTri "ppm_pixel(p6, 240, 10)" (ppmPixel p6 240 10) (77, 65, 48) 1
    eqTri "ppm_pixel(p6, 80, 11)" (ppmPixel p6 80 11) (199, 160, 76) 1
    eqTri "ppm_pixel(p6, 14, 58)" (ppmPixel p6 14 58) (101, 83, 52) 1
    eqTri "ppm_pixel(p6, 174, 58)" (ppmPixel p6 174 58) (101, 83, 52) 1
    eqTri "ppm_pixel(p6, 10, 10)" (ppmPixel p6 10 10) (39, 39, 44) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1

  r.run "Plate 5" do
    let c ← plate05
    let ref ← readFile "reference/chapter-05/plate-05.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 640
    eqN "c.height" c.height 640
    eqTri "ppm_pixel(p6, 160, 160)" (ppmPixel p6 160 160) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 480, 160)" (ppmPixel p6 480 160) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 160, 480)" (ppmPixel p6 160 480) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 480, 480)" (ppmPixel p6 480 480) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 160, 40)" (ppmPixel p6 160 40) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 480, 360)" (ppmPixel p6 480 360) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 160, 20)" (ppmPixel p6 160 20) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 160, 341)" (ppmPixel p6 160 341) (77, 65, 48) 1
    eqTri "ppm_pixel(p6, 480, 341)" (ppmPixel p6 480 341) (77, 65, 48) 1
    eqTri "ppm_pixel(p6, 348, 437)" (ppmPixel p6 348 437) (101, 83, 52) 1
    eqTri "ppm_pixel(p6, 20, 20)" (ppmPixel p6 20 20) (39, 39, 44) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1
