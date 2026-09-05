/-
  Every scenario in features/chapter02-*.feature, one named check each.
-/
import Suite.Harness
open Renderer

def chapter02 (r : Runner) : IO Unit := do

  ------------------------------------------------------------------ shapes
  IO.println "# features/chapter02-shapes.feature"

  r.run "A point inside a circle" do
    let s := circle 8 8 5
    eqB "inside(s, 8, 8)" (inside s 8 8) true
    eqB "inside(s, 12, 8)" (inside s 12 8) true
    eqB "inside(s, 13, 8)" (inside s 13 8) true
    eqB "inside(s, 13.01, 8)" (inside s 13.01 8) false
    eqB "inside(s, 11.6, 11.6)" (inside s 11.6 11.6) false

  r.run "A point inside a rectangle" do
    let s := rectangle 1.25 2.0 4.75 5.0
    eqB "inside(s, 3, 3)" (inside s 3 3) true
    eqB "inside(s, 1.25, 2.0)" (inside s 1.25 2.0) true
    eqB "inside(s, 4.75, 5.0)" (inside s 4.75 5.0) true
    eqB "inside(s, 1.2, 3)" (inside s 1.2 3) false
    eqB "inside(s, 3, 5.1)" (inside s 3 5.1) false

  r.run "A point inside a half-plane" do
    let s := halfPlane 2.5 0 1 0
    eqB "inside(s, 2.5, 7)" (inside s 2.5 7) true
    eqB "inside(s, 3, -4)" (inside s 3 (-4)) true
    eqB "inside(s, 2.4, 0)" (inside s 2.4 0) false

  r.run "The normal picks the side" do
    let s := halfPlane 2.5 0 (-1) 0
    eqB "inside(s, 2.4, 0)" (inside s 2.4 0) true
    eqB "inside(s, 3, 0)" (inside s 3 0) false

  ---------------------------------------------------------------- binary PPM
  IO.println "# features/chapter02-p6.feature"

  r.run "The header, then the bytes" do
    let c := canvas 2 1
    let c := writePixel c 0 0 (color 1 0 0)
    let c := writePixel c 1 0 (color 0 0.5 0)
    let p6 := canvasToP6 c
    beginsWith "p6" p6 "P6\n2 1\n255\n"
    eqN "length(p6)" p6.size 17
    eqByte "byte 12 of p6" p6 12 255
    eqByte "byte 13 of p6" p6 13 0
    eqByte "byte 16 of p6" p6 16 188

  r.run "The same pixel comes back out of either format" do
    let c := canvas 2 1
    let c := writePixel c 1 0 (color 0 0.5 0)
    let p3 := canvasToPpm c
    let p6 := canvasToP6 c
    eqTri "ppm_pixel(p6, 1, 0)" (ppmPixel p6 1 0) (0, 188, 0)
    eqTri "ppm_pixel(p3, 1, 0)" (ppmPixel p3 1 0) (0, 188, 0)
    eqN "max_channel_difference(p3, p6)" (maxChannelDifference p3 p6) 0
    eqN "distinct_values(p6)" (distinctValues p6) 2

  r.run "Sizes still have to match" do
    let c1 := canvas 2 1
    let c2 := canvas 1 2
    let p6a := canvasToP6 c1
    let p6b := canvasToP6 c2
    eqN "max_channel_difference(p6a, p6b)" (maxChannelDifference p6a p6b) 255

  ----------------------------------------------------------------- magnify
  IO.println "# features/chapter02-magnify.feature"

  r.run "Every pixel becomes a block" do
    let c := canvas 2 1
    let c := writePixel c 0 0 (color 1 0 0)
    let c := writePixel c 1 0 (color 0 0.5 0)
    let m := magnify c 3
    eqN "m.width" m.width 6
    eqN "m.height" m.height 3
    eqC "pixel_at(m, 0, 0)" (pixelAt m 0 0) (color 1 0 0)
    eqC "pixel_at(m, 2, 2)" (pixelAt m 2 2) (color 1 0 0)
    eqC "pixel_at(m, 3, 0)" (pixelAt m 3 0) (color 0 0.5 0)
    eqC "pixel_at(m, 5, 2)" (pixelAt m 5 2) (color 0 0.5 0)
    eqN "exactly 9 pixels of m are color(1, 0, 0)" (m.countPixels (color 1 0 0)) 9

  r.run "Magnifying by one changes nothing" do
    let c := canvas 2 1
    let c := writePixel c 1 0 (color 0 0.5 0)
    let m := magnify c 1
    eqN "max_channel_difference(canvas_to_p6(c), canvas_to_p6(m))"
      (maxChannelDifference (canvasToP6 c) (canvasToP6 m)) 0

  ----------------------------------------------------------------- centers
  IO.println "# features/chapter02-centers.feature"

  r.run "A new coverage buffer is empty" do
    let cov := coverageBuffer 4 3
    eqN "cov.width" cov.width 4
    eqN "cov.height" cov.height 3
    eqF "coverage_at(cov, 2, 1)" (coverageAt cov 2 1) 0
    eqF "ink(cov)" (ink cov) 0

  r.run "Setting coverage" do
    let cov := coverageBuffer 4 3
    let cov := setCoverage cov 2 1 0.75
    eqF "coverage_at(cov, 2, 1)" (coverageAt cov 2 1) 0.75
    eqF "coverage_at(cov, 1, 2)" (coverageAt cov 1 2) 0
    eqF "ink(cov)" (ink cov) 0.75

  r.run "Setting coverage outside the buffer is ignored" do
    let cov := coverageBuffer 4 3
    let cov := setCoverage cov (-1) 1 1
    let cov := setCoverage cov 4 1 1
    let cov := setCoverage cov 1 3 1
    eqF "ink(cov)" (ink cov) 0

  r.run "The center of pixel (x, y) is (x + 0.5, y + 0.5)" do
    let s := halfPlane 2.5 0 1 0
    eqF "center_inside(s, 2, 4)" (centerInside s 2 4) 1
    eqF "center_inside(s, 1, 4)" (centerInside s 1 4) 0
    let t := halfPlane 2.6 0 1 0
    eqF "center_inside(t, 2, 4)" (centerInside t 2 4) 0

  r.run "A disc, by asking each center" do
    let s := circle 8 8 5
    let cov := rasterizeCenters s 16 16
    eqN "cov.width" cov.width 16
    eqN "cov.height" cov.height 16
    eqF "coverage_at(cov, 8, 8)" (coverageAt cov 8 8) 1
    eqF "coverage_at(cov, 3, 8)" (coverageAt cov 3 8) 1
    eqF "coverage_at(cov, 12, 8)" (coverageAt cov 12 8) 1
    eqF "coverage_at(cov, 2, 8)" (coverageAt cov 2 8) 0
    eqF "coverage_at(cov, 13, 8)" (coverageAt cov 13 8) 0
    eqF "coverage_at(cov, 4, 4)" (coverageAt cov 4 4) 1
    eqF "coverage_at(cov, 3, 4)" (coverageAt cov 3 4) 0
    eqF "ink(cov)" (ink cov) 80

  ------------------------------------------------------------------- paint
  IO.println "# features/chapter02-paint.feature"

  r.run "Half coverage is half the paint" do
    let c := canvas 1 1
    let cov := coverageBuffer 1 1
    let cov := setCoverage cov 0 0 0.5
    let c ← paintThrough c cov (color 1 1 1)
    eqC "pixel_at(c, 0, 0)" (pixelAt c 0 0) (color 0.5 0.5 0.5)

  r.run "Paint over something that isn't black" do
    let c := canvas 1 1
    let cov := coverageBuffer 1 1
    let c := fill c (color 0.2 0.2 0.2)
    let cov := setCoverage cov 0 0 0.25
    let c ← paintThrough c cov (color 1 0 0)
    eqC "pixel_at(c, 0, 0)" (pixelAt c 0 0) (color 0.4 0.15 0.15)

  r.run "Zero leaves it alone and one replaces it" do
    let c := canvas 2 1
    let cov := coverageBuffer 2 1
    let c := fill c (color 0.2 0.2 0.2)
    let cov := setCoverage cov 1 0 1
    let c ← paintThrough c cov (color 1 0 0)
    eqC "pixel_at(c, 0, 0)" (pixelAt c 0 0) (color 0.2 0.2 0.2)
    eqC "pixel_at(c, 1, 0)" (pixelAt c 1 0) (color 1 0 0)

  r.run "The arithmetic is on light" do
    let c := canvas 1 1
    let cov := coverageBuffer 1 1
    let cov := setCoverage cov 0 0 0.5
    let c ← paintThrough c cov (color 1 1 1)
    let ppm := canvasToPpm c
    eqTri "ppm_pixel(ppm, 0, 0)" (ppmPixel ppm 0 0) (188, 188, 188)

  r.run "The disc by centers" do
    let c ← discCenters
    let ref ← readFile "reference/chapter-02/disc-centers.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 320
    eqN "c.height" c.height 320
    eqTri "ppm_pixel(p6, 160, 160)" (ppmPixel p6 160 160) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 124, 36)" (ppmPixel p6 124 36) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 132, 36)" (ppmPixel p6 132 36) (243, 196, 89) 1
    eqN "distinct_values(p6)" (distinctValues p6) 5
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1

  ---------------------------------------------------------------- coverage
  IO.println "# features/chapter02-coverage.feature"

  r.run "The sixty-four sample points" do
    let s := halfPlane 2.5 0 1 0
    eqF "coverage(s, 2, 4)" (coverage s 2 4) 0.5
    eqF "coverage(s, 1, 4)" (coverage s 1 4) 0
    eqF "coverage(s, 3, 4)" (coverage s 3 4) 1

  r.run "A rectangle is covered exactly, when its edges land on sample boundaries" do
    let s := rectangle 1.25 2.0 4.75 5.0
    let cov := rasterize s 8 8
    eqF "coverage_at(cov, 0, 2)" (coverageAt cov 0 2) 0
    eqF "coverage_at(cov, 1, 2)" (coverageAt cov 1 2) 0.75
    eqF "coverage_at(cov, 2, 2)" (coverageAt cov 2 2) 1
    eqF "coverage_at(cov, 3, 2)" (coverageAt cov 3 2) 1
    eqF "coverage_at(cov, 4, 2)" (coverageAt cov 4 2) 0.75
    eqF "coverage_at(cov, 5, 2)" (coverageAt cov 5 2) 0
    eqF "coverage_at(cov, 2, 1)" (coverageAt cov 2 1) 0
    eqF "coverage_at(cov, 2, 5)" (coverageAt cov 2 5) 0
    eqF "ink(cov)" (ink cov) 10.5

  r.run "A half-plane through a pixel center covers half of it" do
    let s := halfPlane 2.5 4.5 0.6 0.8
    eqF "coverage(s, 2, 4)" (coverage s 2 4) 0.5

  r.run "Except when the grid conspires" do
    let s := halfPlane 2.5 4.5 1 1
    eqF "coverage(s, 2, 4)" (coverage s 2 4) 0.5625

  r.run "A disc is only ever approximately covered" do
    let s := circle 8 8 5
    let cov := rasterize s 16 16
    eqF "coverage_at(cov, 8, 8)" (coverageAt cov 8 8) 1
    eqF "coverage_at(cov, 3, 8)" (coverageAt cov 3 8) 0.96875
    eqF "coverage_at(cov, 12, 8)" (coverageAt cov 12 8) 0.96875
    eqF "coverage_at(cov, 4, 4)" (coverageAt cov 4 4) 0.5625
    eqF "coverage_at(cov, 3, 4)" (coverageAt cov 3 4) 0
    eqF "ink(cov)" (ink cov) 78.5
    eqF "ink(cov) = 78.5398 ± 0.1" (ink cov) 78.5398 0.1

  r.run "The disc by coverage" do
    let c ← discCoverage
    let ref ← readFile "reference/chapter-02/disc-coverage.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 320
    eqN "c.height" c.height 320
    eqTri "ppm_pixel(p6, 160, 160)" (ppmPixel p6 160 160) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 124, 36)" (ppmPixel p6 124 36) (157, 127, 64) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1

  ------------------------------------------------------- coverage ≠ opacity
  IO.println "# features/chapter02-twice.feature"

  r.run "Half coverage, painted twice, is three quarters" do
    let c := canvas 1 1
    let cov := coverageBuffer 1 1
    let cov := setCoverage cov 0 0 0.5
    let c ← paintThrough c cov (color 1 1 1)
    let c ← paintThrough c cov (color 1 1 1)
    eqC "pixel_at(c, 0, 0)" (pixelAt c 0 0) (color 0.75 0.75 0.75)

  r.run "The disc, once and twice" do
    let c ← paintedTwice
    let ref ← readFile "reference/chapter-02/painted-twice.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 480
    eqN "c.height" c.height 240
    eqTri "ppm_pixel(p6, 120, 120)" (ppmPixel p6 120 120) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 360, 120)" (ppmPixel p6 360 120) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 93, 27)" (ppmPixel p6 93 27) (157, 127, 64) 1
    eqTri "ppm_pixel(p6, 333, 27)" (ppmPixel p6 333 27) (194, 156, 74) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1

  ------------------------------------------------------------------- plate
  IO.println "# features/chapter02-plate.feature"

  r.run "The plate" do
    let c ← plate02
    let ref ← readFile "reference/chapter-02/plate-02.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 480
    eqN "c.height" c.height 240
    eqTri "ppm_pixel(p6, 120, 120)" (ppmPixel p6 120 120) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 360, 120)" (ppmPixel p6 360 120) (243, 196, 89) 1
    eqTri "ppm_pixel(p6, 93, 27)" (ppmPixel p6 93 27) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 333, 27)" (ppmPixel p6 333 27) (157, 127, 64) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1
