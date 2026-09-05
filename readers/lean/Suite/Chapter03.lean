/-
  Every scenario in features/chapter03-*.feature, one named check each.
-/
import Suite.Harness
open Renderer

def chapter03 (r : Runner) : IO Unit := do

  --------------------------------------------------------------- bresenham
  IO.println "# features/chapter03-bresenham.feature"

  r.run "lit_pixels reads like a page" do
    let c := canvas 10 10
    let c := writePixel c 5 0 (color 1 1 1)
    let c := writePixel c 0 2 (color 1 1 1)
    let c := writePixel c 2 2 (color 0.5 0 0)
    eqPixels "lit_pixels(c)" (litPixels c) #[(5, 0), (0, 2), (2, 2)]

  r.run "A diagonal" do
    let c := canvas 10 10
    let c := lineBresenham c 0 0 5 5 (color 1 1 1)
    eqPixels "lit_pixels(c)" (litPixels c) #[(0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5)]

  r.run "A horizontal line lights one row and nothing else" do
    let c := canvas 10 10
    let c := lineBresenham c 0 3 7 3 (color 1 1 1)
    eqPixels "lit_pixels(c)" (litPixels c)
      #[(0, 3), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3)]

  r.run "A shallow line steps along x" do
    let c := canvas 10 10
    let c := lineBresenham c 0 0 7 3 (color 1 1 1)
    eqPixels "lit_pixels(c)" (litPixels c)
      #[(0, 0), (1, 0), (2, 1), (3, 1), (4, 2), (5, 2), (6, 3), (7, 3)]

  r.run "A steep line steps along y" do
    let c := canvas 10 10
    let c := lineBresenham c 1 1 3 7 (color 1 1 1)
    eqPixels "lit_pixels(c)" (litPixels c)
      #[(1, 1), (1, 2), (2, 3), (2, 4), (2, 5), (3, 6), (3, 7)]

  r.run "The pixels don't depend on which end you start from" do
    let c1 := canvas 10 10
    let c2 := canvas 10 10
    let c1 := lineBresenham c1 1 1 3 7 (color 1 1 1)
    let c2 := lineBresenham c2 3 7 1 1 (color 1 1 1)
    eqPixels "lit_pixels(c1)" (litPixels c1) (litPixels c2)
    eqN "max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2))"
      (maxChannelDifference (canvasToP6 c1) (canvasToP6 c2)) 0

  r.run "A line going up and to the right" do
    let c := canvas 10 10
    let c := lineBresenham c 0 6 7 3 (color 1 1 1)
    eqPixels "lit_pixels(c)" (litPixels c)
      #[(6, 3), (7, 3), (4, 4), (5, 4), (2, 5), (3, 5), (0, 6), (1, 6)]

  r.run "At an exact half the line stays on its row one step longer" do
    let c := canvas 10 10
    let c := lineBresenham c 0 0 4 2 (color 1 1 1)
    eqPixels "lit_pixels(c)" (litPixels c) #[(0, 0), (1, 0), (2, 1), (3, 1), (4, 2)]

  r.run "A line of one point" do
    let c := canvas 10 10
    let c := lineBresenham c 3 3 3 3 (color 1 1 1)
    eqPixels "lit_pixels(c)" (litPixels c) #[(3, 3)]

  r.run "A line may run off the canvas" do
    let c := canvas 10 10
    let c := lineBresenham c 0 0 12 6 (color 1 1 1)
    eqN "length(lit_pixels(c))" (litPixels c).size 10

  ---------------------------------------------------------------------- wu
  IO.println "# features/chapter03-wu.feature"

  r.run "A half step lights two pixels equally" do
    let c := canvas 10 10
    let c ← lineWu c 0 0 4 2 (color 1 1 1)
    eqC "pixel_at(c, 0, 0)" (pixelAt c 0 0) (color 1 1 1)
    eqC "pixel_at(c, 1, 0)" (pixelAt c 1 0) (color 0.5 0.5 0.5)
    eqC "pixel_at(c, 1, 1)" (pixelAt c 1 1) (color 0.5 0.5 0.5)
    eqC "pixel_at(c, 2, 1)" (pixelAt c 2 1) (color 1 1 1)
    eqC "pixel_at(c, 2, 2)" (pixelAt c 2 2) (color 0 0 0)
    eqC "pixel_at(c, 4, 2)" (pixelAt c 4 2) (color 1 1 1)
    eqF "total_ink(c)" (totalInk c) 5

  r.run "A diagonal has uniform weights" do
    let c := canvas 10 10
    let c ← lineWu c 0 0 5 5 (color 1 1 1)
    eqPixels "lit_pixels(c)" (litPixels c) #[(0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5)]
    eqC "pixel_at(c, 3, 3)" (pixelAt c 3 3) (color 1 1 1)
    eqF "total_ink(c)" (totalInk c) 6

  r.run "A horizontal line has weight 1 on its row and 0 on the neighbors" do
    let c := canvas 10 10
    let c ← lineWu c 0 3 7 3 (color 1 1 1)
    eqPixels "lit_pixels(c)" (litPixels c)
      #[(0, 3), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3)]
    eqC "pixel_at(c, 3, 3)" (pixelAt c 3 3) (color 1 1 1)
    eqC "pixel_at(c, 3, 2)" (pixelAt c 3 2) (color 0 0 0)
    eqC "pixel_at(c, 3, 4)" (pixelAt c 3 4) (color 0 0 0)
    eqF "total_ink(c)" (totalInk c) 8

  r.run "A steep line weights across columns" do
    let c := canvas 10 10
    let c ← lineWu c 1 1 3 7 (color 1 1 1)
    eqC "pixel_at(c, 1, 1)" (pixelAt c 1 1) (color 1 1 1)
    eqC "pixel_at(c, 1, 2)" (pixelAt c 1 2) (color 0.6667 0.6667 0.6667)
    eqC "pixel_at(c, 2, 2)" (pixelAt c 2 2) (color 0.3333 0.3333 0.3333)
    eqC "pixel_at(c, 2, 4)" (pixelAt c 2 4) (color 1 1 1)
    eqC "pixel_at(c, 3, 7)" (pixelAt c 3 7) (color 1 1 1)
    eqF "total_ink(c)" (totalInk c) 7

  r.run "The weights don't depend on which end you start from" do
    let c1 := canvas 10 10
    let c2 := canvas 10 10
    let c1 ← lineWu c1 1 1 3 7 (color 1 1 1)
    let c2 ← lineWu c2 3 7 1 1 (color 1 1 1)
    eqN "max_channel_difference(canvas_to_p6(c1), canvas_to_p6(c2))"
      (maxChannelDifference (canvasToP6 c1) (canvasToP6 c2)) 0

  r.run "A line that starts above the canvas" do
    let c := canvas 10 10
    let c ← lineWu c 0 (-1) 8 3 (color 1 1 1)
    eqC "pixel_at(c, 1, 0)" (pixelAt c 1 0) (color 0.5 0.5 0.5)
    eqC "pixel_at(c, 2, 0)" (pixelAt c 2 0) (color 1 1 1)
    eqF "total_ink(c)" (totalInk c) 7.5

  r.run "A Wu line of one point" do
    let c := canvas 10 10
    let c ← lineWu c 3 3 3 3 (color 1 1 1)
    eqPixels "lit_pixels(c)" (litPixels c) #[(3, 3)]
    eqC "pixel_at(c, 3, 3)" (pixelAt c 3 3) (color 1 1 1)

  r.run "Sevenths" do
    let c := canvas 10 10
    let c ← lineWu c 0 0 7 3 (color 1 1 1)
    eqC "pixel_at(c, 1, 0)" (pixelAt c 1 0) (color 0.5714 0.5714 0.5714)
    eqC "pixel_at(c, 1, 1)" (pixelAt c 1 1) (color 0.4286 0.4286 0.4286)
    eqC "pixel_at(c, 2, 0)" (pixelAt c 2 0) (color 0.1429 0.1429 0.1429)
    eqC "pixel_at(c, 2, 1)" (pixelAt c 2 1) (color 0.8571 0.8571 0.8571)
    eqF "total_ink(c)" (totalInk c) 8

  for (x1, y1, ink) in
    #[((12 : Int), (2 : Int), (11.0 : Float)), (10, 8, 9), (8, 10, 9), (2, 12, 11)] do
    r.run s!"The ink depends on the angle [x1={x1}, y1={y1}, ink={ink}]" do
      let c := canvas 20 20
      let c ← lineWu c 2 2 x1 y1 (color 1 1 1)
      eqF "total_ink(c)" (totalInk c) ink

  ------------------------------------------------------------------- quad
  IO.println "# features/chapter03-quad.feature"

  r.run "Inside a thick line" do
    let s := thickLine 0 0 4 0 1
    eqB "inside(s, 2.5, 0.5)" (inside s 2.5 0.5) true
    eqB "inside(s, 2.5, 1.0)" (inside s 2.5 1.0) true
    eqB "inside(s, 2.5, 1.01)" (inside s 2.5 1.01) false
    eqB "inside(s, 0.5, 0.5)" (inside s 0.5 0.5) true
    eqB "inside(s, 0.4, 0.5)" (inside s 0.4 0.5) false
    eqB "inside(s, 4.5, 0.5)" (inside s 4.5 0.5) true
    eqB "inside(s, 4.6, 0.5)" (inside s 4.6 0.5) false

  r.run "A horizontal thick line covers its row, with half pixels at the ends" do
    let s := thickLine 0 3 7 3 1
    let cov := rasterize s 10 10
    eqF "coverage_at(cov, 0, 3)" (coverageAt cov 0 3) 0.5
    eqF "coverage_at(cov, 1, 3)" (coverageAt cov 1 3) 1
    eqF "coverage_at(cov, 6, 3)" (coverageAt cov 6 3) 1
    eqF "coverage_at(cov, 7, 3)" (coverageAt cov 7 3) 0.5
    eqF "coverage_at(cov, 8, 3)" (coverageAt cov 8 3) 0
    eqF "coverage_at(cov, 3, 2)" (coverageAt cov 3 2) 0
    eqF "coverage_at(cov, 3, 4)" (coverageAt cov 3 4) 0
    eqF "ink(cov)" (ink cov) 7

  r.run "A line of no length is a square" do
    let s := thickLine 3 3 3 3 1
    let cov := rasterize s 8 8
    eqF "coverage_at(cov, 3, 3)" (coverageAt cov 3 3) 1
    eqF "ink(cov)" (ink cov) 1

  r.run "A wider line" do
    let s := thickLine 0 3 7 3 3
    let cov := rasterize s 10 10
    eqF "coverage_at(cov, 3, 2)" (coverageAt cov 3 2) 1
    eqF "coverage_at(cov, 3, 3)" (coverageAt cov 3 3) 1
    eqF "coverage_at(cov, 3, 4)" (coverageAt cov 3 4) 1
    eqF "coverage_at(cov, 3, 1)" (coverageAt cov 3 1) 0
    eqF "coverage_at(cov, 3, 5)" (coverageAt cov 3 5) 0
    eqF "coverage_at(cov, 0, 3)" (coverageAt cov 0 3) 0.5
    eqF "ink(cov)" (ink cov) 21

  r.run "An off-axis line runs through pixel centers, not corners" do
    let s := thickLine 2 2 11 5 1
    let cov := rasterize s 16 10
    eqF "coverage_at(cov, 2, 2)" (coverageAt cov 2 2) 0.484375
    eqF "coverage_at(cov, 11, 5)" (coverageAt cov 11 5) 0.484375
    eqF "coverage_at(cov, 6, 3)" (coverageAt cov 6 3) 0.6875
    eqF "coverage_at(cov, 7, 3)" (coverageAt cov 7 3) 0.359375
    eqF "coverage_at(cov, 2, 1)" (coverageAt cov 2 1) 0
    eqF "ink(cov)" (ink cov) 9.4063

  for (x1, y1) in #[((12 : Int), (2 : Int)), (10, 8), (8, 10), (2, 12)] do
    r.run s!"The ink is the length, whatever the angle [x1={x1}, y1={y1}]" do
      let s := thickLine 2 2 x1 y1 1
      let cov := rasterize s 20 20
      eqF "ink(cov)" (ink cov) 10

  r.run "Except that the grid is blind along the diagonal" do
    let s := thickLine 2 2 9 9 1
    let cov := rasterize s 20 20
    eqF "ink(cov)" (ink cov) 9.71875
    eqF "ink(cov) = 9.8995 ± 0.25" (ink cov) 9.8995 0.25

  ------------------------------------------------------------------- plate
  IO.println "# features/chapter03-plate.feature"

  r.run "The ray endpoints" do
    let expected : Array (Int × Int) :=
      #[(152, 80), (142, 116), (116, 142), (80, 152), (44, 142), (18, 116),
        (8, 80), (18, 44), (44, 18), (80, 8), (116, 18), (142, 44)]
    chk (rayEnds == expected) s!"ray_ends(): got {repr rayEnds}, expected {repr expected}"

  r.run "Bresenham's fan" do
    let c := fanBresenham
    let ref ← readFile "reference/chapter-03/fan-bresenham.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 160
    eqN "c.height" c.height 160
    eqTri "ppm_pixel(p6, 80, 80)" (ppmPixel p6 80 80) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 120, 80)" (ppmPixel p6 120 80) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 10, 10)" (ppmPixel p6 10 10) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 100, 91)" (ppmPixel p6 100 91) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 100, 92)" (ppmPixel p6 100 92) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 103, 120)" (ppmPixel p6 103 120) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 102, 120)" (ppmPixel p6 102 120) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 104, 120)" (ppmPixel p6 104 120) (39, 39, 44) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1

  r.run "Wu's fan" do
    let c ← fanWu
    let ref ← readFile "reference/chapter-03/fan-wu.ppm"
    let p6 := canvasToP6 c
    eqTri "ppm_pixel(p6, 80, 80)" (ppmPixel p6 80 80) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 120, 80)" (ppmPixel p6 120 80) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 100, 91)" (ppmPixel p6 100 91) (163, 163, 161) 1
    eqTri "ppm_pixel(p6, 100, 92)" (ppmPixel p6 100 92) (199, 199, 196) 1
    eqTri "ppm_pixel(p6, 103, 120)" (ppmPixel p6 103 120) (220, 220, 216) 1
    eqTri "ppm_pixel(p6, 104, 120)" (ppmPixel p6 104 120) (130, 130, 129) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1

  r.run "The fan as twelve thin rectangles" do
    let c ← fanCoverage
    let ref ← readFile "reference/chapter-03/fan-coverage.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 320
    eqN "c.height" c.height 320
    eqTri "ppm_pixel(p6, 160, 160)" (ppmPixel p6 160 160) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 10, 10)" (ppmPixel p6 10 10) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 240, 160)" (ppmPixel p6 240 160) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 240, 158)" (ppmPixel p6 240 158) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 200, 183)" (ppmPixel p6 200 183) (177, 177, 174) 1
    eqTri "ppm_pixel(p6, 200, 185)" (ppmPixel p6 200 185) (209, 209, 205) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1

  r.run "Plate 3" do
    let c ← plate03
    let ref ← readFile "reference/chapter-03/plate-03.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 640
    eqN "c.height" c.height 320
    eqTri "ppm_pixel(p6, 160, 160)" (ppmPixel p6 160 160) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 480, 160)" (ppmPixel p6 480 160) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 10, 10)" (ppmPixel p6 10 10) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 200, 183)" (ppmPixel p6 200 183) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 200, 185)" (ppmPixel p6 200 185) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 520, 183)" (ppmPixel p6 520 183) (163, 163, 161) 1
    eqTri "ppm_pixel(p6, 520, 185)" (ppmPixel p6 520 185) (199, 199, 196) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1
