/-
  Every scenario in features/chapter01-*.feature, one named check each.
-/
import Suite.Harness
open Renderer

def chapter01 (r : Runner) : IO Unit := do
  ---------------------------------------------------------------- equality
  IO.println "# features/chapter01-equality.feature"

  r.run "Two numbers that differ by less than the tolerance are equal" do
    eqF "1.0 = 1.0000001 ± 0.00001" 1.0 1.0000001 0.00001

  r.run "Two numbers that differ by more than the tolerance are not" do
    neF "1.0 ≠ 1.001 ± 0.00001" 1.0 1.001 0.00001

  r.run "The default tolerance is 0.0001" do
    eqF "0.1 + 0.2 = 0.3" (0.1 + 0.2) 0.3
    eqF "1.0 = 1.00009" 1.0 1.00009
    neF "1.0 ≠ 1.0002" 1.0 1.0002

  ------------------------------------------------------------------ colors
  IO.println "# features/chapter01-colors.feature"

  r.run "A color is a red, green, blue tuple" do
    let c := color (-0.5) 0.4 1.7
    eqF "c.red" c.red (-0.5)
    eqF "c.green" c.green 0.4
    eqF "c.blue" c.blue 1.7

  r.run "Adding colors" do
    let c1 := color 0.9 0.6 0.75
    let c2 := color 0.7 0.1 0.25
    eqC "c1 + c2" (c1 + c2) (color 1.6 0.7 1.0)

  r.run "Subtracting colors" do
    let c1 := color 0.9 0.6 0.75
    let c2 := color 0.7 0.1 0.25
    eqC "c1 - c2" (c1 - c2) (color 0.2 0.5 0.5)

  r.run "Scaling a color by a number" do
    let c := color 0.2 0.3 0.4
    eqC "c * 2" (c * (2.0 : Float)) (color 0.4 0.6 0.8)
    eqC "c * 0.5" (c * (0.5 : Float)) (color 0.1 0.15 0.2)

  r.run "Multiplying two colors filters one through the other" do
    let c1 := color 1 0.2 0.4
    let c2 := color 0.9 1 0.1
    eqC "c1 * c2" (c1 * c2) (color 0.9 0.2 0.04)

  r.run "Colors compare component by component, with the usual tolerance" do
    let c1 := color 0.1 0.5 1
    let c2 := color 0.2 0 0
    eqC "c1 + c2 = color(0.3, 0.5, 1)" (c1 + c2) (color 0.3 0.5 1)
    neC "c1 + c2 ≠ color(0.3, 0.5, 1.001)" (c1 + c2) (color 0.3 0.5 1.001)

  ------------------------------------------------------------------ canvas
  IO.println "# features/chapter01-canvas.feature"

  r.run "A new canvas is black" do
    let c := canvas 10 20
    eqN "c.width" c.width 10
    eqN "c.height" c.height 20
    chk (c.everyPixelIs (color 0 0 0)) "every pixel of c is color(0, 0, 0)"

  r.run "Writing a pixel" do
    let c := canvas 10 20
    let red := color 1 0 0
    let c := writePixel c 2 3 red
    eqC "pixel_at(c, 2, 3)" (pixelAt c 2 3) red

  r.run "x is the column and y is the row" do
    let c := canvas 10 20
    let c := writePixel c 2 3 (color 1 0 0)
    eqC "pixel_at(c, 3, 2)" (pixelAt c 3 2) (color 0 0 0)
    eqC "pixel_at(c, 2, 3)" (pixelAt c 2 3) (color 1 0 0)

  r.run "Writing outside the canvas is ignored" do
    let c := canvas 10 20
    let c := writePixel c (-1) 5 (color 1 0 0)
    let c := writePixel c 10 5 (color 1 0 0)
    let c := writePixel c 5 (-1) (color 1 0 0)
    let c := writePixel c 5 20 (color 1 0 0)
    chk (c.everyPixelIs (color 0 0 0)) "every pixel of c is color(0, 0, 0)"

  r.run "A pixel can be written more than once" do
    let c := canvas 10 20
    let c := writePixel c 2 3 (color 1 0 0)
    let c := writePixel c 2 3 (color 0 1 0)
    eqC "pixel_at(c, 2, 3)" (pixelAt c 2 3) (color 0 1 0)

  r.run "Filling a canvas" do
    let c := canvas 10 20
    let c := fill c (color 0.1 0.2 0.3)
    chk (c.everyPixelIs (color 0.1 0.2 0.3)) "every pixel of c is color(0.1, 0.2, 0.3)"

  -------------------------------------------------------------------- sRGB
  IO.println "# features/chapter01-srgb.feature"

  let encodeRows : List (Float × Float) :=
    [ (0.0, 0.0), (0.0025, 0.0323), (0.01, 0.0999), (0.1, 0.3492), (0.216, 0.5021),
      (0.25, 0.5371), (0.5, 0.7354), (0.75, 0.8808), (1.0, 1.0) ]
  for (l, v) in encodeRows do
    r.run s!"Encoding light into a file value [light={l}, value={v}]" do
      eqF s!"encode({l})" (encode l) v

  let decodeRows : List (Float × Float) :=
    [ (0.0, 0.0), (0.04, 0.0031), (0.05, 0.0039), (0.1, 0.0100),
      (0.5, 0.2140), (0.75, 0.5225), (1.0, 1.0) ]
  for (v, l) in decodeRows do
    r.run s!"Decoding a file value into light [value={v}, light={l}]" do
      eqF s!"decode({v})" (decode v) l

  r.run "Decode undoes encode" do
    eqF "decode(encode(0.2))" (decode (encode 0.2)) 0.2 0.000000001

  r.run "Encode undoes decode" do
    eqF "encode(decode(0.7))" (encode (decode 0.7)) 0.7 0.000000001

  r.run "The half gray that isn't 128" do
    eqN "round(encode(0.5) * 255)" (roundNat (encode 0.5 * 255.0)) 188

  r.run "What 128 actually is" do
    eqF "decode(128 / 255)" (decode (128.0 / 255.0)) 0.2159

  --------------------------------------------------------------------- PPM
  IO.println "# features/chapter01-ppm.feature"

  r.run "The PPM header" do
    let ppm := canvasToPpm (canvas 5 3)
    linesAre ppm 1 ["P3", "5 3", "255"]

  r.run "Pixel values are encoded, not scaled" do
    let c := canvas 3 1
    let c := writePixel c 0 0 (color 1 0 0)
    let c := writePixel c 1 0 (color 0 0.5 0)
    let c := writePixel c 2 0 (color 0 0 0.216)
    let ppm := canvasToPpm c
    linesAre ppm 4 ["255 0 0 0 188 0 0 0 128"]

  r.run "Colors out of range are clamped, not wrapped" do
    let c := canvas 2 1
    let c := writePixel c 0 0 (color 1.5 0 (-0.5))
    let ppm := canvasToPpm c
    linesAre ppm 4 ["255 0 0 0 0 0"]

  r.run "Every row starts a new line, and no line exceeds 70 characters" do
    let c := fill (canvas 10 2) (color 1 0.8 0.6)
    let ppm := canvasToPpm c
    linesAre ppm 4
      [ "255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231",
        "203 255 231 203 255 231 203 255 231 203 255 231 203",
        "255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231",
        "203 255 231 203 255 231 203 255 231 203 255 231 203" ]
    for (l, i) in (textLines ppm).zipIdx do
      chk (l.length <= 70) s!"line {i+1} is {l.length} characters, expected at most 70"

  r.run "A line of exactly 70 characters is allowed" do
    let c := fill (canvas 8 1) (color 1 0.1 0)
    let c := writePixel c 7 0 (color 1 1 1)
    let ppm := canvasToPpm c
    linesAre ppm 4
      [ "255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 255",
        "255" ]

  r.run "The file ends with a newline" do
    let ppm := canvasToPpm (canvas 5 3)
    chk (ppm.endsWith "\n") "ppm does not end with a newline character"

  r.run "Reading a pixel back out of the text" do
    let c := canvas 3 2
    let c := writePixel c 2 1 (color 0 0.5 1)
    let ppm := canvasToPpm c
    eqTri "ppm_pixel(ppm, 2, 1)" (ppmPixel ppm 2 1) (0, 188, 255)
    eqTri "ppm_pixel(ppm, 1, 1)" (ppmPixel ppm 1 1) (0, 0, 0)

  r.run "Counting the distinct values in a file" do
    let c := canvas 3 1
    let c := writePixel c 0 0 (color 1 0 0)
    let c := writePixel c 1 0 (color 0 0.5 0)
    let c := writePixel c 2 0 (color 0 0 0.216)
    let ppm := canvasToPpm c
    eqN "distinct_values(ppm)" (distinctValues ppm) 4

  r.run "Comparing two files" do
    let c1 := canvas 2 1
    let c2 := writePixel (canvas 2 1) 0 0 (color 0.5 0 0)
    let ppm1 := canvasToPpm c1
    let ppm2 := canvasToPpm c2
    eqN "max_channel_difference(ppm1, ppm1)" (maxChannelDifference ppm1 ppm1) 0
    eqN "max_channel_difference(ppm1, ppm2)" (maxChannelDifference ppm1 ppm2) 188

  r.run "Files of different sizes are as different as it gets" do
    let ppm1 := canvasToPpm (canvas 5 3)
    let ppm2 := canvasToPpm (canvas 3 5)
    eqN "max_channel_difference(ppm1, ppm2)" (maxChannelDifference ppm1 ppm2) 255

  r.run "The same width with a different height is still a different size" do
    let ppm1 := canvasToPpm (canvas 5 3)
    let ppm2 := canvasToPpm (canvas 5 4)
    eqN "max_channel_difference(ppm1, ppm2)" (maxChannelDifference ppm1 ppm2) 255

  -------------------------------------------------------------- gray match
  IO.println "# features/chapter01-gray-match.feature"

  r.run "The gray match" do
    let c := grayMatch
    eqN "c.width" c.width 300
    eqN "c.height" c.height 100
    eqC "pixel_at(c, 0, 0)" (pixelAt c 0 0) (color 1 1 1)
    eqC "pixel_at(c, 1, 0)" (pixelAt c 1 0) (color 0 0 0)
    eqC "pixel_at(c, 0, 1)" (pixelAt c 0 1) (color 0 0 0)
    eqC "pixel_at(c, 1, 1)" (pixelAt c 1 1) (color 1 1 1)
    eqC "pixel_at(c, 150, 50)" (pixelAt c 150 50) (color 0.2159 0.2159 0.2159)
    eqC "pixel_at(c, 250, 50)" (pixelAt c 250 50) (color 0.5 0.5 0.5)
    eqN "exactly N pixels of c are color(1, 1, 1)" (c.countPixels (color 1 1 1)) 5000

  r.run "The gray match, as a file" do
    let c := grayMatch
    let ref ← readFile "reference/chapter-01/gray-match.ppm"
    let ppm := canvasToPpm c
    eqTri "ppm_pixel(ppm, 0, 0)" (ppmPixel ppm 0 0) (255, 255, 255) 1
    eqTri "ppm_pixel(ppm, 1, 0)" (ppmPixel ppm 1 0) (0, 0, 0) 1
    eqTri "ppm_pixel(ppm, 150, 50)" (ppmPixel ppm 150 50) (128, 128, 128) 1
    eqTri "ppm_pixel(ppm, 250, 50)" (ppmPixel ppm 250 50) (188, 188, 188) 1
    leN "max_channel_difference(ppm, ref)" (maxChannelDifference ppm ref) 1

  r.run "One pixel in four" do
    let c := quarterMatch
    let ref ← readFile "reference/chapter-01/quarter-match.ppm"
    let ppm := canvasToPpm c
    eqN "c.width" c.width 200
    eqN "c.height" c.height 100
    eqC "pixel_at(c, 0, 0)" (pixelAt c 0 0) (color 1 1 1)
    eqC "pixel_at(c, 1, 0)" (pixelAt c 1 0) (color 0 0 0)
    eqC "pixel_at(c, 2, 2)" (pixelAt c 2 2) (color 1 1 1)
    eqC "pixel_at(c, 3, 1)" (pixelAt c 3 1) (color 1 1 1)
    eqC "pixel_at(c, 150, 50)" (pixelAt c 150 50) (color 0.25 0.25 0.25)
    eqN "exactly N pixels of c are color(1, 1, 1)" (c.countPixels (color 1 1 1)) 2500
    eqTri "ppm_pixel(ppm, 150, 50)" (ppmPixel ppm 150 50) (137, 137, 137) 1
    leN "max_channel_difference(ppm, ref)" (maxChannelDifference ppm ref) 1

  --------------------------------------------------------------------- mix
  IO.println "# features/chapter01-mix.feature"

  r.run "Halfway between black and white" do
    let a := color 0 0 0
    let b := color 1 1 1
    eqC "mix(a, b, 0.5)" (← mix a b 0.5) (color 0.5 0.5 0.5)

  r.run "The ends of a mix are its inputs" do
    let a := color 0.7 0 0
    let b := color 0 0.3 0.02
    eqC "mix(a, b, 0)" (← mix a b 0) a
    eqC "mix(a, b, 1)" (← mix a b 1) b

  r.run "Red to green, in light" do
    let a := color 0.7 0 0
    let b := color 0 0.3 0.02
    eqC "mix(a, b, 0.5)" (← mix a b 0.5) (color 0.35 0.15 0.01)
    eqC "mix(a, b, 0.25)" (← mix a b 0.25) (color 0.525 0.075 0.005)

  r.run "Halfway between black and white, the way browsers do it" do
    setLinearBlending false
    let a := color 0 0 0
    let b := color 1 1 1
    eqC "mix(a, b, 0.5)" (← mix a b 0.5) (color 0.2140 0.2140 0.2140)

  r.run "Red to green, the way browsers do it" do
    setLinearBlending false
    let a := color 0.7 0 0
    let b := color 0 0.3 0.02
    eqC "mix(a, b, 0.5)" (← mix a b 0.5) (color 0.1527 0.0693 0.0067)

  r.run "The light's way never clamps" do
    let a := color 1.5 0.5 (-0.2)
    let b := color 0 0 0
    eqC "mix(a, b, 0)" (← mix a b 0) (color 1.5 0.5 (-0.2))
    eqC "mix(a, b, 0.5)" (← mix a b 0.5) (color 0.75 0.25 (-0.1))

  r.run "The switch can be passed instead of set" do
    let a := color 0 0 0
    let b := color 1 1 1
    eqC "mix(a, b, 0.5, true)" (← mix a b 0.5 true) (color 0.5 0.5 0.5)
    eqC "mix(a, b, 0.5, false)" (← mix a b 0.5 false) (color 0.2140 0.2140 0.2140)
    eqB "linear blending is on" (← linearBlendingIsOn) true

  r.run "The browser's way clamps each end before encoding it" do
    setLinearBlending false
    let a := color 1.5 0.5 (-0.2)
    let b := color 0 0 0
    eqC "mix(a, b, 0)" (← mix a b 0) (color 1 0.5 0)
    eqC "mix(a, b, 0.5)" (← mix a b 0.5) (color 0.2140 0.1113 0.0000)

  r.run "The ends of a mix are its inputs either way, when they're in range" do
    setLinearBlending false
    let a := color 0.7 0 0
    let b := color 0 0.3 0.02
    eqC "mix(a, b, 0)" (← mix a b 0) a
    eqC "mix(a, b, 1)" (← mix a b 1) b

  ------------------------------------------------------------------ limits
  IO.println "# features/chapter01-limits.feature"

  r.run "A 256-step ramp" do
    let c := ramp
    eqN "c.width" c.width 256
    eqN "c.height" c.height 32
    eqC "pixel_at(c, 0, 0)" (pixelAt c 0 0) (color 0 0 0)
    eqC "pixel_at(c, 128, 0)" (pixelAt c 128 0) (color 0.5020 0.5020 0.5020)
    eqC "pixel_at(c, 255, 31)" (pixelAt c 255 31) (color 1 1 1)

  r.run "Encoding stretches the dark end and squeezes the bright end" do
    let c := ramp
    let ref ← readFile "reference/chapter-01/ramp.ppm"
    let ppm := canvasToPpm c
    linesAre ppm 4
      ["0 0 0 13 13 13 22 22 22 28 28 28 34 34 34 38 38 38 42 42 42 46 46 46"]
    eqTri "ppm_pixel(ppm, 75, 0)" (ppmPixel ppm 75 0) (148, 148, 148) 1
    eqTri "ppm_pixel(ppm, 76, 0)" (ppmPixel ppm 76 0) (148, 148, 148) 1
    eqTri "ppm_pixel(ppm, 254, 0)" (ppmPixel ppm 254 0) (255, 255, 255) 1
    eqN "distinct_values(ppm)" (distinctValues ppm) 183
    leN "max_channel_difference(ppm, ref)" (maxChannelDifference ppm ref) 1

  r.run "Clamping changes the color, not only the brightness" do
    let c := clampPair
    let ref ← readFile "reference/chapter-01/clamp-pair.ppm"
    let ppm := canvasToPpm c
    eqN "c.width" c.width 200
    eqN "c.height" c.height 100
    eqC "pixel_at(c, 50, 50)" (pixelAt c 50 50) (color 2 0.5 0.5)
    eqC "pixel_at(c, 150, 50)" (pixelAt c 150 50) (color 1 0.25 0.25)
    eqTri "ppm_pixel(ppm, 50, 50)" (ppmPixel ppm 50 50) (255, 188, 188) 1
    eqTri "ppm_pixel(ppm, 150, 50)" (ppmPixel ppm 150 50) (255, 137, 137) 1
    leN "max_channel_difference(ppm, ref)" (maxChannelDifference ppm ref) 1

  ------------------------------------------------------------------- plate
  IO.println "# features/chapter01-plate.feature"

  r.run "The plate" do
    let c ← plate01
    let ref ← readFile "reference/chapter-01/plate-01.ppm"
    let ppm := canvasToPpm c
    eqN "c.width" c.width 400
    eqN "c.height" c.height 180
    eqTri "ppm_pixel(ppm, 0, 20)" (ppmPixel ppm 0 20) (0, 0, 0) 1
    eqTri "ppm_pixel(ppm, 399, 20)" (ppmPixel ppm 399 20) (255, 255, 255) 1
    eqTri "ppm_pixel(ppm, 200, 20)" (ppmPixel ppm 200 20) (128, 128, 128) 1
    eqTri "ppm_pixel(ppm, 200, 65)" (ppmPixel ppm 200 65) (188, 188, 188) 1
    eqTri "ppm_pixel(ppm, 200, 42)" (ppmPixel ppm 200 42) (0, 0, 0) 1
    eqTri "ppm_pixel(ppm, 0, 110)" (ppmPixel ppm 0 110) (218, 0, 0) 1
    eqTri "ppm_pixel(ppm, 399, 110)" (ppmPixel ppm 399 110) (0, 149, 39) 1
    eqTri "ppm_pixel(ppm, 200, 110)" (ppmPixel ppm 200 110) (109, 75, 19) 1
    eqTri "ppm_pixel(ppm, 200, 155)" (ppmPixel ppm 200 155) (160, 108, 26) 1
    eqTri "ppm_pixel(ppm, 200, 87)" (ppmPixel ppm 200 87) (0, 0, 0) 1
    eqTri "ppm_pixel(ppm, 200, 132)" (ppmPixel ppm 200 132) (0, 0, 0) 1
    eqTri "ppm_pixel(ppm, 200, 177)" (ppmPixel ppm 200 177) (0, 0, 0) 1
    leN "max_channel_difference(ppm, ref)" (maxChannelDifference ppm ref) 1
