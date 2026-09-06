/-
  The 2D Renderer Challenge -- chapter 1.
  Colors, canvas, sRGB transfer functions, PPM output, mixing, and the
  chapter's five renders.
-/

namespace Renderer

/-! ## § 1.1  Comparing numbers -/

/-- The book's default tolerance: `a = b` means `|a - b| <= 0.0001`. -/
def epsilon : Float := 0.0001

def approxEq (a b : Float) (eps : Float := epsilon) : Bool :=
  (a - b).abs <= eps

/-- `round(x)` -- nearest whole number. Only ever called on non-negative
    values here (the PPM writer clamps first), so half-up is enough. -/
def roundNat (x : Float) : Nat :=
  (Float.floor (x + 0.5)).toUInt64.toNat

/-- Core Lean has no `Int → Float` coercion. -/
def intToFloat (i : Int) : Float :=
  if i < 0 then -(i.natAbs.toFloat) else i.natAbs.toFloat

/-! ## § 1.2  A color is three numbers -/

structure Color where
  red : Float
  green : Float
  blue : Float
deriving Repr, Inhabited

def color (r g b : Float) : Color := ⟨r, g, b⟩

namespace Color

def add (a b : Color) : Color := ⟨a.red + b.red, a.green + b.green, a.blue + b.blue⟩
def sub (a b : Color) : Color := ⟨a.red - b.red, a.green - b.green, a.blue - b.blue⟩
/-- A color times a number. -/
def scale (a : Color) (s : Float) : Color := ⟨a.red * s, a.green * s, a.blue * s⟩
/-- The Hadamard product: a color times a color, component by component. -/
def multiply (a b : Color) : Color := ⟨a.red * b.red, a.green * b.green, a.blue * b.blue⟩

def map (f : Float → Float) (a : Color) : Color := ⟨f a.red, f a.green, f a.blue⟩

def approxEq (a b : Color) (eps : Float := epsilon) : Bool :=
  Renderer.approxEq a.red b.red eps
    && Renderer.approxEq a.green b.green eps
    && Renderer.approxEq a.blue b.blue eps

def toString (c : Color) : String :=
  s!"color({c.red}, {c.green}, {c.blue})"

end Color

instance : ToString Color := ⟨Color.toString⟩
instance : Add Color := ⟨Color.add⟩
instance : Sub Color := ⟨Color.sub⟩
/-- `c1 * c2` is the Hadamard product. -/
instance : Mul Color := ⟨Color.multiply⟩
/-- `c * 2` is scaling. -/
instance : HMul Color Float Color := ⟨Color.scale⟩
instance : HMul Float Color Color := ⟨fun s c => Color.scale c s⟩

/-! ## § 1.4  The numbers are not the light -/

/-- file value → light -/
def decode (v : Float) : Float :=
  if v <= 0.04045 then v / 12.92 else Float.pow ((v + 0.055) / 1.055) 2.4

/-- light → file value -/
def encode (l : Float) : Float :=
  if l <= 0.0031308 then l * 12.92 else 1.055 * Float.pow l (1.0 / 2.4) - 0.055

def decodeColor (c : Color) : Color := c.map decode
def encodeColor (c : Color) : Color := c.map encode

def clamp01 (x : Float) : Float := if x < 0.0 then 0.0 else if x > 1.0 then 1.0 else x
def clampColor (c : Color) : Color := c.map clamp01

/-! ## § 1.3  The canvas

Lean has no mutable objects, so a canvas is a value and `writePixel` returns a
new one. Because `Array.set!` updates in place when the array is uniquely
referenced, the imperative pseudo-code in the book transliterates directly into
a `let mut c := ...` loop with the same cost. -/

structure Canvas where
  width : Nat
  height : Nat
  pixels : Array Color
deriving Inhabited

def canvas (w h : Nat) : Canvas :=
  { width := w, height := h, pixels := Array.replicate (w * h) (color 0 0 0) }

namespace Canvas

/-- Writes outside the canvas are silently dropped. `x` and `y` are signed. -/
def writePixel (c : Canvas) (x y : Int) (col : Color) : Canvas :=
  if x < 0 || y < 0 || x >= (c.width : Int) || y >= (c.height : Int) then c
  else { c with pixels := c.pixels.set! (y.toNat * c.width + x.toNat) col }

def pixelAt (c : Canvas) (x y : Int) : Color :=
  c.pixels[y.toNat * c.width + x.toNat]!

def fill (c : Canvas) (col : Color) : Canvas :=
  { c with pixels := Array.replicate (c.width * c.height) col }

/-- "every pixel of c is ..." -/
def everyPixelIs (c : Canvas) (col : Color) : Bool :=
  c.pixels.all (fun p => p.approxEq col)

/-- "exactly N pixels of c are ..." -/
def countPixels (c : Canvas) (col : Color) : Nat :=
  c.pixels.foldl (fun n p => if p.approxEq col then n + 1 else n) 0

end Canvas

export Canvas (writePixel pixelAt fill)

/-! ## § 1.5  PPM output -/

/-- Clamp, encode, scale, round -- in that order. -/
def channelToByte (v : Float) : Nat := roundNat (encode (clamp01 v) * 255.0)

def canvasToPpm (c : Canvas) : String := Id.run do
  let mut out := s!"P3\n{c.width} {c.height}\n255\n"
  for y in [0:c.height] do
    let mut line := ""
    for x in [0:c.width] do
      let p := c.pixels[y * c.width + x]!
      for v in [channelToByte p.red, channelToByte p.green, channelToByte p.blue] do
        let s := Nat.repr v
        if line.isEmpty then
          line := s
        else if line.length + 1 + s.length > 70 then
          out := out ++ line ++ "\n"
          line := s
        else
          line := line ++ " " ++ s
    out := out ++ line ++ "\n"
  return out

/-! ### Reading a PPM back (test helpers, not renderer functions)

From chapter 2 on a PPM may be P3 (text) or P6 (bytes), so the readers work on
bytes and accept either: the `PpmBytes` class lets a `String` and a `ByteArray`
be passed to the same function. -/

class PpmBytes (α : Type) where
  ppmBytes : α → ByteArray

instance : PpmBytes ByteArray := ⟨id⟩
instance : PpmBytes String := ⟨String.toUTF8⟩

def ppmTokens (s : String) : Array String :=
  let flat := ((s.replace "\r" " ").replace "\n" " ").replace "\t" " "
  ((flat.splitOn " ").filter (· != "")).toArray

structure PpmInfo where
  width : Nat
  height : Nat
  data : Array Nat
deriving Inhabited

private def isSpaceByte (b : UInt8) : Bool :=
  b == 32 || b == 9 || b == 10 || b == 11 || b == 12 || b == 13

/-- Skips whitespace, then reads one ASCII whole number.
    Returns the number and the index just past its last digit. -/
private def readHeaderNat (b : ByteArray) (i0 : Nat) : Nat × Nat := Id.run do
  let mut i := i0
  while i < b.size && isSpaceByte b[i]! do
    i := i + 1
  let mut v := 0
  while i < b.size && b[i]! >= 48 && b[i]! <= 57 do
    v := v * 10 + (b[i]!.toNat - 48)
    i := i + 1
  return (v, i)

def parsePpmBytes (b : ByteArray) : PpmInfo :=
  if b.size >= 2 && b[0]! == 80 && b[1]! == 54 then
    -- "P6": three header numbers, exactly one whitespace byte, then raw bytes.
    let (w, i) := readHeaderNat b 2
    let (h, i) := readHeaderNat b i
    let (_maxval, i) := readHeaderNat b i
    let start := i + 1
    let n := min (3 * w * h) (b.size - start)
    { width := w, height := h,
      data := Id.run do
        let mut d := Array.emptyWithCapacity n
        for k in [0:n] do
          d := d.push b[start + k]!.toNat
        return d }
  else
    -- "P3": whitespace-separated decimal text.
    let toks := ppmTokens (String.fromUTF8! b)
    { width := (toks[1]!).toNat!, height := (toks[2]!).toNat!,
      data := (toks.extract 4 toks.size).map (·.toNat!) }

def parsePpm [PpmBytes α] (s : α) : PpmInfo := parsePpmBytes (PpmBytes.ppmBytes s)

/-- The three whole numbers at pixel (x, y) of a PPM. -/
def ppmPixel [PpmBytes α] (s : α) (x y : Nat) : Nat × Nat × Nat :=
  let p := parsePpm s
  let i := (y * p.width + x) * 3
  (p.data[i]!, p.data[i+1]!, p.data[i+2]!)

/-- How many different numbers appear in the pixel data.
    Counted with a bucket per value: `Array.qsort` is quadratic on the long
    runs of equal bytes a P6 image is mostly made of. -/
def distinctValues [PpmBytes α] (s : α) : Nat := Id.run do
  let d := (parsePpm s).data
  let mut seen := Array.replicate (d.foldl max 0 + 1) false
  let mut n := 0
  for v in d do
    if !seen[v]! then
      seen := seen.set! v true
      n := n + 1
  return n

/-- Largest absolute difference between corresponding pixel numbers.
    Files of different sizes are as different as it gets. -/
def maxChannelDifference [PpmBytes α] [PpmBytes β] (a : α) (b : β) : Nat :=
  let pa := parsePpm a
  let pb := parsePpm b
  if pa.width != pb.width || pa.height != pb.height then 255
  else Id.run do
    let n := min pa.data.size pb.data.size
    let mut m := 0
    for i in [0:n] do
      let x := pa.data[i]!
      let y := pb.data[i]!
      let d := if x > y then x - y else y - x
      if d > m then m := d
    return m

/-- Reference images are bytes from chapter 2 on; a P3 file is just text that
    happens to be stored in bytes. -/
def readFile (path : String) : IO ByteArray := IO.FS.readBinFile path

/-! ## § 1.7  Two ways to mix

The book asks for one global boolean. Lean is pure, so the switch lives in an
`IO.Ref` created at module initialisation; `mix` therefore returns `IO Color`.
`mixWith` is the pure core, for anyone who would rather pass the flag. -/

initialize linearBlendingRef : IO.Ref Bool ← IO.mkRef true

def setLinearBlending (on : Bool) : IO Unit := linearBlendingRef.set on
def linearBlendingIsOn : IO Bool := linearBlendingRef.get

/-- The way light actually works. -/
def mixLinear (a b : Color) (t : Float) : Color := a + (b - a) * t

/-- The way that feels obvious and is wrong: interpolate the file values. -/
def mixEncoded (a b : Color) (t : Float) : Color :=
  let a' := encodeColor (clampColor a)
  let b' := encodeColor (clampColor b)
  decodeColor (a' + (b' - a') * t)

def mixWith (linear : Bool) (a b : Color) (t : Float) : Color :=
  if linear then mixLinear a b t else mixEncoded a b t

/-- The switch can be passed instead of set; passing it does not touch the
    global one. -/
def mix (a b : Color) (t : Float) (linear : Option Bool := none) : IO Color := do
  match linear with
  | some l => return mixWith l a b t
  | none   => return mixWith (← linearBlendingIsOn) a b t

/-! ## § 1.6, 1.8, 1.9  The renders -/

def grayMatch : Canvas := Id.run do
  let mut c := canvas 300 100
  for y in [0:100] do
    for x in [0:100] do
      c := writePixel c x y (if (x + y) % 2 == 0 then color 1 1 1 else color 0 0 0)
  let g := decode (128.0 / 255.0)
  for y in [0:100] do
    for x in [100:200] do
      c := writePixel c x y (color g g g)
  for y in [0:100] do
    for x in [200:300] do
      c := writePixel c x y (color 0.5 0.5 0.5)
  return c

def quarterMatch : Canvas := Id.run do
  let mut c := canvas 200 100
  for y in [0:100] do
    for x in [0:100] do
      c := writePixel c x y (if (x + y) % 4 == 0 then color 1 1 1 else color 0 0 0)
  for y in [0:100] do
    for x in [100:200] do
      c := writePixel c x y (color 0.25 0.25 0.25)
  return c

def ramp : Canvas := Id.run do
  let mut c := canvas 256 32
  for x in [0:256] do
    let g := x.toFloat / 255.0
    for y in [0:32] do
      c := writePixel c x y (color g g g)
  return c

def clampPair : Canvas := Id.run do
  let mut c := canvas 200 100
  for y in [0:100] do
    for x in [0:100] do
      c := writePixel c x y (color 2 0.5 0.5)
    for x in [100:200] do
      c := writePixel c x y (color 1 0.25 0.25)
  return c

def rampPair (c0 : Canvas) (top : Nat) (a b : Color) : IO Canvas := do
  let mut c := c0
  for x in [0:400] do
    let t := x.toFloat / 399.0
    setLinearBlending false
    let naive ← mix a b t
    setLinearBlending true
    let light ← mix a b t
    for y in [top : top + 40] do
      c := writePixel c x y naive
    for y in [top + 45 : top + 85] do
      c := writePixel c x y light
  return c

def plate01 : IO Canvas := do
  let mut c := canvas 400 180
  c ← rampPair c 0 (color 0 0 0) (color 1 1 1)
  c ← rampPair c 90 (color 0.7 0 0) (color 0 0.3 0.02)
  setLinearBlending true   -- leave it as you found it
  return c

/-! # Chapter 2 -- Coverage -/

/-! ## § 2.1  Shapes are questions

A shape is a function from a point to yes or no. In Lean that is one structure
with one function field: any `Shape` is built by handing `Shape.mk` a
predicate, so "the interface" costs nothing and new shapes need no new type. -/

structure Shape where
  isInside : Float → Float → Bool

/-- Is this point inside you? -/
def inside (s : Shape) (x y : Float) : Bool := s.isInside x y

/-- Inside means within the radius, boundary included. -/
def circle (cx cy r : Float) : Shape :=
  ⟨fun x y => (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r⟩

/-- left, top, right, bottom. Boundary included. -/
def rectangle (x0 y0 x1 y1 : Float) : Shape :=
  ⟨fun x y => x0 <= x && x <= x1 && y0 <= y && y <= y1⟩

/-- A point on the line and a normal pointing into the half you want.
    Inside when the dot product is non-negative; the normal needn't be unit. -/
def halfPlane (px py nx ny : Float) : Shape :=
  ⟨fun x y => (x - px) * nx + (y - py) * ny >= 0.0⟩

/-! ## § 2.2  A faster file

Same numbers as the P3 writer, written as bytes. -/

def canvasToP6 (c : Canvas) : ByteArray := Id.run do
  let header := s!"P6\n{c.width} {c.height}\n255\n".toUTF8
  let mut out := ByteArray.emptyWithCapacity (header.size + 3 * c.width * c.height)
  out := out ++ header
  for p in c.pixels do
    out := out.push (channelToByte p.red).toUInt8
    out := out.push (channelToByte p.green).toUInt8
    out := out.push (channelToByte p.blue).toUInt8
  return out

/-! ## § 2.3  A loupe -/

/-- `k` times wider and taller, every pixel repeated into a k-by-k block. -/
def magnify (c : Canvas) (k : Nat) : Canvas := Id.run do
  let mut m := canvas (c.width * k) (c.height * k)
  for y in [0:c.height] do
    for x in [0:c.width] do
      let col := c.pixels[y * c.width + x]!
      for j in [0:k] do
        for i in [0:k] do
          m := writePixel m (x * k + i) (y * k + j) col
  return m

/-! ## § 2.4  The coverage buffer, and the first question

A canvas of numbers instead of colors. Like `Canvas` it is a value: every
write returns a new buffer. -/

structure Coverage where
  width : Nat
  height : Nat
  values : Array Float
deriving Inhabited

def coverageBuffer (w h : Nat) : Coverage :=
  { width := w, height := h, values := Array.replicate (w * h) 0.0 }

namespace Coverage

def coverageAt (cov : Coverage) (x y : Int) : Float :=
  if x < 0 || y < 0 || x >= (cov.width : Int) || y >= (cov.height : Int) then 0.0
  else cov.values[y.toNat * cov.width + x.toNat]!

/-- Writes outside the buffer are dropped, as with the canvas. -/
def setCoverage (cov : Coverage) (x y : Int) (v : Float) : Coverage :=
  if x < 0 || y < 0 || x >= (cov.width : Int) || y >= (cov.height : Int) then cov
  else { cov with values := cov.values.set! (y.toNat * cov.width + x.toNat) v }

/-- The sum of every value: the shape's area in pixels, as the buffer sees it. -/
def ink (cov : Coverage) : Float := cov.values.foldl (· + ·) 0.0

end Coverage

export Coverage (coverageAt setCoverage ink)

/-- Pixel (x, y) is the square from (x, y) to (x+1, y+1), so its center is
    (x + 0.5, y + 0.5). 1 if that point is inside, 0 if not. -/
def centerInside (s : Shape) (x y : Nat) : Float :=
  if inside s (x.toFloat + 0.5) (y.toFloat + 0.5) then 1.0 else 0.0

def rasterizeCenters (s : Shape) (w h : Nat) : Coverage := Id.run do
  let mut cov := coverageBuffer w h
  for y in [0:h] do
    for x in [0:w] do
      cov := setCoverage cov x y (centerInside s x y)
  return cov

/-! ## § 2.5  Paint through it -/

/-- Moves every pixel of the canvas toward `col` by that pixel's coverage,
    with the linear-blending switch forced to the light's way regardless of
    what it is set to: `mix(pixel, color, coverage, true)`. The one place
    the renderer touches the canvas. -/
def paintThrough (c : Canvas) (cov : Coverage) (col : Color) : IO Canvas := do
  let mut out := c
  for y in [0:c.height] do
    for x in [0:c.width] do
      out := writePixel out x y (← mix (pixelAt out x y) col (coverageAt cov x y) (some true))
  return out

/-! ## § 2.6  The better question

Sixty-four sample points, one at the center of each cell of an 8-by-8 grid. -/

def coverage (s : Shape) (x y : Nat) : Float := Id.run do
  let mut n := 0
  for j in [0:8] do
    for i in [0:8] do
      if inside s (x.toFloat + (i.toFloat + 0.5) / 8.0)
                  (y.toFloat + (j.toFloat + 0.5) / 8.0) then
        n := n + 1
  return n.toFloat / 64.0

def rasterize (s : Shape) (w h : Nat) : Coverage := Id.run do
  let mut cov := coverageBuffer w h
  for y in [0:h] do
    for x in [0:w] do
      cov := setCoverage cov x y (coverage s x y)
  return cov

/-! ## § 2.5, 2.6, 2.7, 2.8  The renders -/

private def paper : Color := color 0.02 0.02 0.025
private def orange : Color := color 0.9 0.55 0.1

def discCenters : IO Canvas := do
  let mut c := canvas 40 40
  c := fill c paper
  let cov := rasterizeCenters (circle 20 20 16) 40 40
  c ← paintThrough c cov orange
  return magnify c 8

/-- `discCenters` with `rasterize` in place of `rasterizeCenters`, and nothing
    else changed. -/
def discCoverage : IO Canvas := do
  let mut c := canvas 40 40
  c := fill c paper
  let cov := rasterize (circle 20 20 16) 40 40
  c ← paintThrough c cov orange
  return magnify c 8

def paintedTwice : IO Canvas := do
  let mut c := canvas 80 40
  c := fill c paper
  let cov := rasterize (circle 20 20 16) 40 40
  let mut once := coverageBuffer 80 40          -- the disc in both halves
  for y in [0:40] do
    for x in [0:40] do
      once := setCoverage once x y (coverageAt cov x y)
      once := setCoverage once (x + 40) y (coverageAt cov x y)
  c ← paintThrough c once orange
  let mut twice := coverageBuffer 80 40         -- the disc in the right half only
  for y in [0:40] do
    for x in [0:40] do
      twice := setCoverage twice (x + 40) y (coverageAt cov x y)
  c ← paintThrough c twice orange
  return magnify c 6

def plate02 : IO Canvas := do
  let mut c := canvas 80 40
  c := fill c paper
  let shape := circle 20 20 16
  let left := rasterizeCenters shape 40 40
  let right := rasterize shape 40 40
  let mut both := coverageBuffer 80 40
  for y in [0:40] do
    for x in [0:40] do
      both := setCoverage both x y (coverageAt left x y)
      both := setCoverage both (x + 40) y (coverageAt right x y)
  c ← paintThrough c both orange
  return magnify c 6

/-! # Chapter 3 -- Lines -/

/-! ## § 3.1  Bresenham

Integer-only, both endpoints included. Threaded through `Id.run do` with
`let mut`: the pseudo-code is already an imperative loop over a mutable
canvas, and that's the most direct translation of it. -/

/-- Every pixel of the canvas that isn't black, in reading order: top row
    first, left to right. A test helper, not a renderer function. -/
def litPixels (c : Canvas) : Array (Nat × Nat) := Id.run do
  let mut out := #[]
  for y in [0:c.height] do
    for x in [0:c.width] do
      let p := c.pixels[y * c.width + x]!
      if !(p.approxEq (color 0 0 0)) then
        out := out.push (x, y)
  return out

/-- The sum of every pixel's red channel: for a white line on black, exactly
    how much paint went down. -/
def totalInk (c : Canvas) : Float := c.pixels.foldl (fun acc p => acc + p.red) 0.0

def lineBresenham (c0 : Canvas) (x0 y0 x1 y1 : Int) (col : Color) : Canvas := Id.run do
  let steep := (y1 - y0).natAbs > (x1 - x0).natAbs
  let mut x0 := x0
  let mut y0 := y0
  let mut x1 := x1
  let mut y1 := y1
  if steep then
    let t0 := x0; x0 := y0; y0 := t0
    let t1 := x1; x1 := y1; y1 := t1
  if x0 > x1 then
    let tx := x0; x0 := x1; x1 := tx
    let ty := y0; y0 := y1; y1 := ty
  let dx : Int := x1 - x0
  let dy : Int := (y1 - y0).natAbs
  let ystep : Int := if y0 < y1 then 1 else -1
  let mut err : Int := dx / 2
  let mut y := y0
  let mut c := c0
  for i in [0:dx.toNat + 1] do
    let x := x0 + (i : Int)
    if steep then
      c := writePixel c y x col
    else
      c := writePixel c x y col
    err := err - dy
    if err < 0 then
      y := y + ystep
      err := err + dx
  return c

/-! ## § 3.2  Wu

`plot` is `paint_through` for one pixel: it drops writes off the canvas, and
as a shortcut (not a rule) skips a weight of zero, so the endpoints of a
line that starts off-canvas never touch a pixel outside it. Like
`paintThrough`, it mixes in light regardless of what the linear-blending
switch is set to: `mix(pixel, color, weight, true)`. -/

def plot (c : Canvas) (x y : Int) (col : Color) (weight : Float) : IO Canvas := do
  if weight == 0.0 then
    return c
  else if x < 0 || y < 0 || x >= (c.width : Int) || y >= (c.height : Int) then
    return c
  else
    return writePixel c x y (← mix (pixelAt c x y) col weight (some true))

/-- Floor, not truncation: they agree on positive numbers and part company
    below zero, and a line that starts above the canvas has a negative `y`
    for a few columns. -/
def floorInt (x : Float) : Int := (Float.floor x).toInt64.toInt

def lineWu (c0 : Canvas) (x0 y0 x1 y1 : Int) (col : Color) : IO Canvas := do
  let steep := (y1 - y0).natAbs > (x1 - x0).natAbs
  let mut x0 := x0
  let mut y0 := y0
  let mut x1 := x1
  let mut y1 := y1
  if steep then
    let t0 := x0; x0 := y0; y0 := t0
    let t1 := x1; x1 := y1; y1 := t1
  if x0 > x1 then
    let tx := x0; x0 := x1; x1 := tx
    let ty := y0; y0 := y1; y1 := ty
  let dx : Int := x1 - x0
  let slope : Float := if dx == 0 then 0.0 else intToFloat (y1 - y0) / intToFloat dx
  let mut c := c0
  for i in [0:dx.toNat + 1] do
    let x := x0 + (i : Int)
    let y := intToFloat y0 + intToFloat (x - x0) * slope
    let yi := floorInt y
    let f := y - intToFloat yi
    if steep then
      c ← plot c yi x col (1.0 - f)
      c ← plot c (yi + 1) x col f
    else
      c ← plot c x yi col (1.0 - f)
      c ← plot c x (yi + 1) col f
  return c

/-! ## § 3.3  The reveal

A line is a rectangle one pixel wide: four half-planes, and chapter 2's
rasterizer already knows what to do with it. `thick_line` itself is defined
in chapter 4, § 4.5, as a one-liner over `segment`, once points exist to
build it from. -/

/-! # Chapter 4 -- Points, Vectors, Transforms

Brought forward from where it's introduced below: chapter 4, § 4.5, redefines
`thick_line` as a one-liner over `segment`, so `Tuple`, `Matrix3` and
`segment` all need to exist before chapter 3's `thick_line` (used by
`fan_coverage`, right after this) can be written in terms of them. Everything
chapter 4 actually adds starts at § 4.1 below; the renders it asks for are in
§ 4.6, after chapter 3's. -/

/-! ## § 4.1  Points and vectors

A point is a place, a vector is a displacement, and the only thing that
tells them apart is `w`: 1 for a point, 0 for a vector. Adding two
components, `w` included, is what makes point - point come out a vector
and point + vector come out a point without a separate rule for each. -/

structure Tuple where
  x : Float
  y : Float
  w : Float
deriving Inhabited

def point (x y : Float) : Tuple := ⟨x, y, 1⟩
def vector (x y : Float) : Tuple := ⟨x, y, 0⟩

namespace Tuple

def add (a b : Tuple) : Tuple := ⟨a.x + b.x, a.y + b.y, a.w + b.w⟩
def sub (a b : Tuple) : Tuple := ⟨a.x - b.x, a.y - b.y, a.w - b.w⟩
def neg (a : Tuple) : Tuple := ⟨-a.x, -a.y, -a.w⟩
def scale (a : Tuple) (s : Float) : Tuple := ⟨a.x * s, a.y * s, a.w * s⟩

def approxEq (a b : Tuple) (eps : Float := epsilon) : Bool :=
  Renderer.approxEq a.x b.x eps
    && Renderer.approxEq a.y b.y eps
    && Renderer.approxEq a.w b.w eps

def toString (t : Tuple) : String := s!"tuple({t.x}, {t.y}, {t.w})"

end Tuple

instance : Add Tuple := ⟨Tuple.add⟩
instance : Sub Tuple := ⟨Tuple.sub⟩
instance : Neg Tuple := ⟨Tuple.neg⟩
instance : HMul Tuple Float Tuple := ⟨Tuple.scale⟩
instance : HDiv Tuple Float Tuple := ⟨fun a s => Tuple.scale a (1.0 / s)⟩
instance : ToString Tuple := ⟨Tuple.toString⟩

/-- Looks at `x` and `y` only: a point's `w` of 1 would otherwise leak in. -/
def magnitude (v : Tuple) : Float := Float.sqrt (v.x * v.x + v.y * v.y)

def normalize (v : Tuple) : Tuple := v * (1.0 / magnitude v)

/-- Looks at `x` and `y` only, same reason as `magnitude`. -/
def dot (a b : Tuple) : Float := a.x * b.x + a.y * b.y

/-- The 2D cross product: a single number, the area (signed) of the
    parallelogram the two vectors span. Positive is the side the y axis
    points to; on a canvas, y points down, so positive reads clockwise. -/
def cross (a b : Tuple) : Float := a.x * b.y - a.y * b.x

/-! ## § 4.2  Matrices

Nine numbers, row by row. `entries[r * 3 + c]` is `M[r, c]`. -/

structure Matrix3 where
  entries : Array Float
deriving Inhabited

def matrix3 (a b c d e f g h i : Float) : Matrix3 := { entries := #[a, b, c, d, e, f, g, h, i] }

namespace Matrix3

/-- `M[r, c]`, both counted from 0. (named `get`, not `at`, because `at` is a reserved token in Lean 4's tactic syntax) -/
def get (m : Matrix3) (r c : Nat) : Float := m.entries[r * 3 + c]!

def approxEq (a b : Matrix3) (eps : Float := epsilon) : Bool := Id.run do
  for i in [0:9] do
    if !Renderer.approxEq a.entries[i]! b.entries[i]! eps then
      return false
  return true

def toString (m : Matrix3) : String :=
  s!"matrix3({m.entries[0]!}, {m.entries[1]!}, {m.entries[2]!}, {m.entries[3]!}, \
{m.entries[4]!}, {m.entries[5]!}, {m.entries[6]!}, {m.entries[7]!}, {m.entries[8]!})"

end Matrix3

instance : ToString Matrix3 := ⟨Matrix3.toString⟩

/-- The identity matrix: multiplying by it changes nothing. -/
def identity : Matrix3 := matrix3 1 0 0 0 1 0 0 0 1

def transpose (m : Matrix3) : Matrix3 := Id.run do
  let mut entries := Array.replicate 9 (0.0 : Float)
  for r in [0:3] do
    for c in [0:3] do
      entries := entries.set! (r * 3 + c) (m.get c r)
  return { entries := entries }

/-- `(A * B)[r, c]` is the dot product of row `r` of `A` with column `c` of `B`. -/
def matMul (a b : Matrix3) : Matrix3 := Id.run do
  let mut entries := Array.replicate 9 (0.0 : Float)
  for r in [0:3] do
    for c in [0:3] do
      entries := entries.set! (r * 3 + c)
        (a.get r 0 * b.get 0 c + a.get r 1 * b.get 1 c + a.get r 2 * b.get 2 c)
  return { entries := entries }

instance : Mul Matrix3 := ⟨matMul⟩

/-- A matrix times a tuple, treating `(x, y, w)` as a column. -/
def matMulTuple (m : Matrix3) (t : Tuple) : Tuple :=
  ⟨ m.get 0 0 * t.x + m.get 0 1 * t.y + m.get 0 2 * t.w,
    m.get 1 0 * t.x + m.get 1 1 * t.y + m.get 1 2 * t.w,
    m.get 2 0 * t.x + m.get 2 1 * t.y + m.get 2 2 * t.w ⟩

instance : HMul Matrix3 Tuple Tuple := ⟨matMulTuple⟩

/-- The 2x2 determinant left when row `r` and column `c` are deleted. -/
def minor (m : Matrix3) (r c : Nat) : Float :=
  let rows := (List.range 3).filter (· != r)
  let cols := (List.range 3).filter (· != c)
  let r0 := rows[0]!
  let r1 := rows[1]!
  let c0 := cols[0]!
  let c1 := cols[1]!
  m.get r0 c0 * m.get r1 c1 - m.get r0 c1 * m.get r1 c0

def cofactor (m : Matrix3) (r c : Nat) : Float :=
  if (r + c) % 2 == 1 then -(minor m r c) else minor m r c

/-- A cofactor expansion along the first row. -/
def determinant (m : Matrix3) : Float :=
  m.get 0 0 * cofactor m 0 0 + m.get 0 1 * cofactor m 0 1 + m.get 0 2 * cofactor m 0 2

/-- An exact test against zero, not the book's usual tolerance: a
    determinant of 0.0001 is not zero, and its inverse is enormous but real. -/
def isInvertible (m : Matrix3) : Bool := determinant m != 0.0

/-- The matrix of cofactors, transposed, divided by the determinant. The
    transpose happens by writing straight into `[c, r]`. -/
def inverse (m : Matrix3) : Matrix3 := Id.run do
  let d := determinant m
  let mut entries := Array.replicate 9 (0.0 : Float)
  for r in [0:3] do
    for c in [0:3] do
      entries := entries.set! (c * 3 + r) (cofactor m r c / d)
  return { entries := entries }

/-! ## § 4.3  The transforms -/

def translation (tx ty : Float) : Matrix3 := matrix3 1 0 tx 0 1 ty 0 0 1
def scaling (sx sy : Float) : Matrix3 := matrix3 sx 0 0 0 sy 0 0 0 1
def rotation (r : Float) : Matrix3 :=
  matrix3 (Float.cos r) (-(Float.sin r)) 0 (Float.sin r) (Float.cos r) 0 0 0 1
def shearing (xy yx : Float) : Matrix3 := matrix3 1 xy 0 yx 1 0 0 0 1

/-! ## § 4.4  How big is a transform?

The square root of the absolute value of the determinant of the upper-left
2-by-2: exact for uniform scales and rotations, the geometric mean of the
two axis scales otherwise. -/
def approxScale (m : Matrix3) : Float :=
  Float.sqrt (Float.abs (m.get 0 0 * m.get 1 1 - m.get 0 1 * m.get 1 0))

/-! ## § 4.5  Transforming what you draw -/

/-- `thick_line` with real endpoints instead of pixel indices: the
    rectangle of `width` centered on the segment from `a` to `b`, square
    ends. A segment of no length has no direction, so it gets `(1, 0)` and
    its two ends are pushed apart by half the width each. -/
def segment (a b : Tuple) (width : Float) : Shape :=
  let ax0 := a.x
  let ay0 := a.y
  let bx0 := b.x
  let by0 := b.y
  let h := width / 2.0
  let len := Float.sqrt ((bx0 - ax0) * (bx0 - ax0) + (by0 - ay0) * (by0 - ay0))
  let (ax, bx, dx, dy) :=
    if len == 0.0 then (ax0 - h, bx0 + h, 1.0, 0.0)
    else (ax0, bx0, (bx0 - ax0) / len, (by0 - ay0) / len)
  let ay := ay0
  let byy := by0
  let nx := -dy
  let ny := dx
  let ahead := halfPlane ax ay dx dy
  let behind := halfPlane bx byy (-dx) (-dy)
  let left := halfPlane (ax + nx * h) (ay + ny * h) (-nx) (-ny)
  let right := halfPlane (ax - nx * h) (ay - ny * h) nx ny
  ⟨fun x y => inside ahead x y && inside behind x y && inside left x y && inside right x y⟩

/-- `thick_line`, now a one-liner over `segment`. -/
def thickLine (x0 y0 x1 y1 : Int) (width : Float) : Shape :=
  segment (point (intToFloat x0 + 0.5) (intToFloat y0 + 0.5))
          (point (intToFloat x1 + 0.5) (intToFloat y1 + 0.5)) width

/-- Inside when any of its parts is. -/
def union (shapes : Array Shape) : Shape :=
  ⟨fun x y => shapes.any (fun s => inside s x y)⟩

/-- The shape seen through `m`: to ask whether a device point is inside,
    send it backwards through the inverse and ask the original shape. A
    shape seen through a matrix with no inverse is empty. -/
def transformed (s : Shape) (m : Matrix3) : Shape :=
  if isInvertible m then
    let inv := inverse m
    ⟨fun x y => let p := inv * point x y; inside s p.x p.y⟩
  else
    ⟨fun _ _ => false⟩

def transformPoints (pts : Array Tuple) (m : Matrix3) : Array Tuple := pts.map (fun p => m * p)

/-- The points, taken through `m`, joined edge to edge and closed from the
    last point back to the first, each edge a `segment` of `width` in
    device space. One shape, so a corner shared by two edges is painted
    once, not twice. -/
def outline (pts : Array Tuple) (m : Matrix3) (width : Float) : Shape := Id.run do
  let tpts := transformPoints pts m
  let n := tpts.size
  let mut segs : Array Shape := #[]
  for i in [0:n] do
    segs := segs.push (segment tpts[i]! tpts[(i + 1) % n]! width)
  return union segs

/-! ## § 3.1, 3.2, 3.3, 3.4  The renders -/

private def fanPaper : Color := color 0.02 0.02 0.025
private def fanInk : Color := color 0.92 0.92 0.88
/-- Needed by chapter 3's fan and chapter 4's rotations both; not private,
    since the scenarios for rotation(π / 6) need it too. -/
def pi : Float := 3.14159265358979323846

/-- Twelve points 72 pixels out from (80, 80), one every 30 degrees, rounded
    to integers. -/
def rayEnds : Array (Int × Int) := Id.run do
  let mut out := #[]
  for k in [0:12] do
    let a := k.toFloat * 30.0 * (pi / 180.0)
    let x := roundNat (80.0 + 72.0 * Float.cos a)
    let y := roundNat (80.0 + 72.0 * Float.sin a)
    out := out.push ((x : Int), (y : Int))
  return out

def fanBresenham : Canvas := Id.run do
  let mut c := canvas 160 160
  c := fill c fanPaper
  for (x, y) in rayEnds do
    c := lineBresenham c 80 80 x y fanInk
  return c

/-- `fanBresenham` with `lineWu` in place of `lineBresenham`, and nothing
    else changed. -/
def fanWu : IO Canvas := do
  let mut c := canvas 160 160
  c := fill c fanPaper
  for (x, y) in rayEnds do
    c ← lineWu c 80 80 x y fanInk
  return c

/-- Each ray a `thickLine` of width 1, rasterized and painted through in
    turn, then magnified by 2. -/
def fanCoverage : IO Canvas := do
  let mut c := canvas 160 160
  c := fill c fanPaper
  for (x, y) in rayEnds do
    let cov := rasterize (thickLine 80 80 x y 1.0) 160 160
    c ← paintThrough c cov fanInk
  return magnify c 2

def plate03 : IO Canvas := do
  let a := fanBresenham
  let b ← fanWu
  let mut both := canvas 320 160
  for y in [0:160] do
    for x in [0:160] do
      both := writePixel both x y (pixelAt a x y)
      both := writePixel both (x + 160) y (pixelAt b x y)
  return magnify both 2

/-! # Chapter 4 -- Points, Vectors, Transforms, continued

§§ 4.1-4.5 (Tuple, Matrix3, the transforms, segment/union/transformed/outline)
live up in chapter 3, right before "The renders", because § 4.5 rewrites
chapter 3's own thick_line in terms of them. This is the rest: the F, the
fan as points, and the two plates that need both. -/

/-! ## § 4.6  Putting it together -/

private def dimF : Color := color 0.16 0.16 0.17

/-- The center, then twelve points 36 out from it, one every 30 degrees. -/
def fanPoints : Array Tuple := Id.run do
  let mut pts := #[point 0 0]
  for k in [0:12] do
    let a := k.toFloat * 30.0 * (pi / 180.0)
    pts := pts.push (point (36.0 * Float.cos a) (36.0 * Float.sin a))
  return pts

/-- Ten corners, clockwise from the top left, in a box 40 wide and 60 tall
    centered on the origin. No symmetry at all: a rotation shows up. -/
def letterF : Array Tuple :=
  #[ point (-20) (-30), point 20 (-30), point 20 (-20), point (-10) (-20),
     point (-10) (-5),  point 12 (-5),  point 12 5,     point (-10) 5,
     point (-10) 30,    point (-20) 30 ]

def sideBySide (a b : Canvas) : Canvas := Id.run do
  let mut c := canvas (a.width + b.width) a.height
  for y in [0:a.height] do
    for x in [0:a.width] do
      c := writePixel c x y (pixelAt a x y)
  for y in [0:b.height] do
    for x in [0:b.width] do
      c := writePixel c (a.width + x) y (pixelAt b x y)
  return c

/-- The fan, described as points around the origin this time, run through
    `m` and drawn as one union of segments. -/
def fanTransformed (m : Matrix3) : IO Canvas := do
  let mut c := canvas 160 160
  c := fill c fanPaper
  let pts := transformPoints fanPoints m
  let mut segs : Array Shape := #[]
  for k in [1:pts.size] do
    segs := segs.push (segment pts[0]! pts[k]! 1.0)
  c ← paintThrough c (rasterize (union segs) 160 160) fanInk
  return c

def fanBothOrders : IO Canvas := do
  let turn := rotation (pi / 6.0)
  let move := translation 104.5 76.5
  let a ← fanTransformed (move * turn)
  let b ← fanTransformed (turn * move)
  return sideBySide a b

/-- A dim copy of the letter at home, for reference, with the two orders
    of `move * turn` painted on top of their own copy of it. -/
def fBothOrders : IO Canvas := do
  let turn := rotation (pi / 6.0)
  let move := translation 104.5 76.5
  let home := translation 44.5 44.5
  let mut ghost := canvas 160 160
  ghost := fill ghost fanPaper
  ghost ← paintThrough ghost (rasterize (outline letterF home 1.0) 160 160) dimF
  let mut a := ghost
  a ← paintThrough a (rasterize (outline letterF (move * turn) 1.0) 160 160) fanInk
  let mut b := ghost
  b ← paintThrough b (rasterize (outline letterF (turn * move) 1.0) 160 160) fanInk
  return sideBySide a b

def plate04 : IO Canvas := do
  let c ← fBothOrders
  return magnify c 2

/-! # Chapter 5 -- Paths and Insideness -/

/-! ## § 5.1  A path is a list of instructions

A path is a list of subpaths, one for each time the pen went down; a
subpath is a list of points and a flag for whether it was closed. -/

structure Subpath where
  points : Array Tuple
  closed : Bool
deriving Inhabited

structure Path where
  subpaths : Array Subpath
deriving Inhabited

def path : Path := { subpaths := #[] }

/-- Lifts the pen and puts it down somewhere new. -/
def moveTo (p : Path) (pt : Tuple) : Path :=
  { p with subpaths := p.subpaths.push { points := #[pt], closed := false } }

/-- Draws a line from wherever the pen is to `pt`. With nothing to extend
    it behaves as `move_to`; after a `close` it starts a new, open subpath
    at the point the closed one began, because that's where `close` left
    the pen. -/
def lineTo (p : Path) (pt : Tuple) : Path :=
  if p.subpaths.size == 0 then
    moveTo p pt
  else
    let last := p.subpaths.back!
    if last.closed then
      { p with subpaths := p.subpaths.push { points := #[last.points[0]!, pt], closed := false } }
    else
      { p with subpaths :=
          p.subpaths.set! (p.subpaths.size - 1) { last with points := last.points.push pt } }

/-- Draws a line back to where the pen was last put down and marks the
    subpath closed. Nothing to close does nothing; closing twice is the
    same as closing once. -/
def close (p : Path) : Path :=
  if p.subpaths.size == 0 then p
  else
    let i := p.subpaths.size - 1
    { p with subpaths := p.subpaths.set! i { p.subpaths[i]! with closed := true } }

def subpaths (p : Path) : Array Subpath := p.subpaths

/-- Every edge of every subpath, as `(a, b)` pairs, treating every subpath
    as closed whether or not `close` was called: the edge from the last
    point back to the first is always included. A subpath of one point
    contributes no edges. -/
def edges (p : Path) : Array (Tuple × Tuple) := Id.run do
  let mut es : Array (Tuple × Tuple) := #[]
  for sp in p.subpaths do
    let n := sp.points.size
    if n >= 2 then
      for i in [0:n] do
        es := es.push (sp.points[i]!, sp.points[(i + 1) % n]!)
  return es

/-- The smallest axis-aligned box around every point of every subpath, as
    `(min x, min y, max x, max y)`. An empty path is `(0, 0, 0, 0)`. -/
def bounds (p : Path) : Float × Float × Float × Float := Id.run do
  let mut minX := 0.0
  let mut minY := 0.0
  let mut maxX := 0.0
  let mut maxY := 0.0
  let mut first := true
  for sp in p.subpaths do
    for pt in sp.points do
      if first then
        minX := pt.x
        maxX := pt.x
        minY := pt.y
        maxY := pt.y
        first := false
      else
        minX := min minX pt.x
        maxX := max maxX pt.x
        minY := min minY pt.y
        maxY := max maxY pt.y
  return (minX, minY, maxX, maxY)

/-- A closed subpath through the given points. -/
def polygon (pts : Array Tuple) : Path := { subpaths := #[{ points := pts, closed := true }] }

/-- A regular `n`-gon standing in for a circle: first point at angle 0, on
    the right, going clockwise on the screen (increasing angle, since y
    points down). -/
def circlePath (cx cy r : Float) (n : Nat) : Path := Id.run do
  let mut pts : Array Tuple := #[]
  for k in [0:n] do
    let a := k.toFloat * (2.0 * pi / n.toFloat)
    pts := pts.push (point (cx + r * Float.cos a) (cy + r * Float.sin a))
  return polygon pts

/-! ## § 5.2  Is this point inside?

Both `crossings` and `winding_at` use the half-open rule: an edge from `a`
to `b` is crossed when the ray's height `y` satisfies `a.y ≤ y < b.y` or
`b.y ≤ y < a.y`. The lower endpoint is in, the higher one is out, so a
vertex on the ray counts once, not twice, and a horizontal edge (`a.y =
b.y`) is never crossed. -/

/-- How many edges a ray from `(x, y)` toward `+x` crosses. -/
def crossings (p : Path) (x y : Float) : Nat := Id.run do
  let mut n := 0
  for (a, b) in edges p do
    if (a.y <= y && y < b.y) || (b.y <= y && y < a.y) then
      let t := (y - a.y) / (b.y - a.y)
      let xc := a.x + t * (b.x - a.x)
      if xc > x then
        n := n + 1
  return n

/-- The winding number: each edge that crosses the ray's height counts +1
    heading down the canvas, -1 heading up, found from the sign of
    `cross(b - a, q - a)` rather than `x` directly. Positive is clockwise
    on the screen. -/
def windingAt (p : Path) (x y : Float) : Int := Id.run do
  let q := point x y
  let mut w : Int := 0
  for (a, b) in edges p do
    if a.y <= y then
      if b.y > y && cross (b - a) (q - a) > 0.0 then
        w := w + 1
    else
      if b.y <= y && cross (b - a) (q - a) < 0.0 then
        w := w - 1
  return w

/-! ## § 5.3  Two rules -/

def insideNonzero (p : Path) (x y : Float) : Bool := windingAt p x y != 0

/-- Odd, by the winding number's parity: `natAbs` first, since a negative
    winding number is odd exactly when its magnitude is. -/
def insideEvenOdd (p : Path) (x y : Float) : Bool := (windingAt p x y).natAbs % 2 == 1

/-- The shape a path encloses under `rule`, `"nonzero"` or `"evenodd"`, so
    chapter 2's rasterizer can draw any path, either rule, correct
    coverage, slowly. -/
def filled (p : Path) (rule : String) : Shape :=
  if rule == "nonzero" then ⟨fun x y => insideNonzero p x y⟩
  else ⟨fun x y => insideEvenOdd p x y⟩

/-- The ceiling of a `Float`, as an `Int`: the floor of the negation,
    negated, so it needs no library function beyond `floorInt`. -/
def ceilInt (x : Float) : Int := -(floorInt (-x))

/-- `rasterize`, restricted to the pixels `box` touches: columns from
    `floor(min x)` up to but not including `ceil(max x)`, rows likewise,
    both clipped to the buffer. Same coverage as `rasterize`, less work. -/
def rasterizeWithin (s : Shape) (box : Float × Float × Float × Float) (w h : Nat) : Coverage :=
  Id.run do
    let (minX, minY, maxX, maxY) := box
    let mut cov := coverageBuffer w h
    let x0 := (max 0 (floorInt minX)).toNat
    let x1 := (max 0 (min (w : Int) (ceilInt maxX))).toNat
    let y0 := (max 0 (floorInt minY)).toNat
    let y1 := (max 0 (min (h : Int) (ceilInt maxY))).toNat
    for y in [y0:y1] do
      for x in [x0:x1] do
        cov := setCoverage cov x y (coverage s x y)
    return cov

/-! ## § 5.4  Putting it together -/

/-- Five points on a circle of radius 70 about (80.5, 80.5), the first
    straight up, visited every second one so the pen crosses itself. -/
def star : Path := Id.run do
  let mut p := path
  for k in [0:5] do
    let a := (-90.0 + 144.0 * k.toFloat) * (pi / 180.0)
    let q := point (80.5 + 70.0 * Float.cos a) (80.5 + 70.0 * Float.sin a)
    p := if k == 0 then moveTo p q else lineTo p q
  return close p

def starPanel (rule method : String) : IO Canvas := do
  let mut c := canvas 160 160
  c := fill c (color 0.02 0.02 0.025)
  let s := filled star rule
  let cov := if method == "centers" then rasterizeCenters s 160 160
             else rasterizeWithin s (bounds star) 160 160
  c ← paintThrough c cov (color 0.9 0.55 0.1)
  return c

def starCenters : IO Canvas := do
  let a ← starPanel "nonzero" "centers"
  let b ← starPanel "evenodd" "centers"
  return sideBySide a b

def starCoverage : IO Canvas := do
  let a ← starPanel "nonzero" "coverage"
  let b ← starPanel "evenodd" "coverage"
  return sideBySide a b

def plate05 : IO Canvas := do
  let top ← starCenters
  let bottom ← starCoverage
  let mut both := canvas 320 320
  for y in [0:160] do
    for x in [0:320] do
      both := writePixel both x y (pixelAt top x y)
      both := writePixel both x (y + 160) (pixelAt bottom x y)
  return magnify both 2

/-! # Chapter 6 -- Filling a Polygon -/

/-! ## § 6.1  The edge table

Each non-horizontal edge of a path, ready for the sweep: which end is
higher on the canvas, where it crosses its own top, how far it moves in
`x` per unit of `y`, and which way the path went along it. -/

structure Edge where
  yTop : Float
  yBottom : Float
  xTop : Float
  slope : Float
  direction : Int
deriving Inhabited

/-- `x_top + (y - y_top) * slope`, the one computation an edge knows how
    to do. -/
def xAt (e : Edge) (y : Float) : Float := e.xTop + (y - e.yTop) * e.slope

/-- Every non-horizontal edge of `p`, sorted by `y_top` then `x_top`.
    Horizontal edges (`a.y = b.y` exactly) are dropped: their slope would
    be a division by zero, and chapter 5's half-open rule already says
    they never cross a sample height. -/
def edgeTable (p : Path) : Array Edge := Id.run do
  let mut es : Array Edge := #[]
  for (a, b) in edges p do
    if a.y != b.y then
      let slope := (b.x - a.x) / (b.y - a.y)
      let (yTop, yBottom, xTop, dir) :=
        if a.y < b.y then (a.y, b.y, a.x, (1 : Int)) else (b.y, a.y, b.x, (-1 : Int))
      es := es.push { yTop := yTop, yBottom := yBottom, xTop := xTop, slope := slope, direction := dir }
  return es.qsort (fun e1 e2 => e1.yTop < e2.yTop || (e1.yTop == e2.yTop && e1.xTop < e2.xTop))

/-! ## § 6.2  Crossings on a row, and spans -/

/-- `(x, direction)` for every edge of `table` that spans height `y`, under
    the half-open rule `y_top ≤ y < y_bottom`, sorted by `x`. The slow
    version: every edge, every row. -/
def crossingsOnRow (table : Array Edge) (y : Float) : Array (Float × Int) := Id.run do
  let mut xs : Array (Float × Int) := #[]
  for e in table do
    if e.yTop <= y && y < e.yBottom then
      xs := xs.push (xAt e y, e.direction)
  return xs.qsort (fun a b => a.1 < b.1)

/-- A walk left to right, accumulating the winding number and asking the
    rule whether it's inside; the maximal stretches where it is. -/
def spansFromCrossings (xs : Array (Float × Int)) (rule : String) : Array (Float × Float) :=
  Id.run do
    let mut out : Array (Float × Float) := #[]
    let mut w : Int := 0
    let mut start : Option Float := none
    for (x, d) in xs do
      w := w + d
      let insideNow := if rule == "nonzero" then w != 0 else w.natAbs % 2 == 1
      if insideNow && start.isNone then
        start := some x
      if !insideNow && start.isSome then
        out := out.push (start.get!, x)
        start := none
    return out

/-- Crossings and spans together, for one pixel row, sampled at its
    center: `y = row + 0.5`. -/
def spans (p : Path) (rule : String) (row : Nat) : Array (Float × Float) :=
  spansFromCrossings (crossingsOnRow (edgeTable p) (row.toFloat + 0.5)) rule

/-- Sets to 1 every pixel of `row` whose center lies in `[x0, x1)`: the
    first is `ceil(x0 - 0.5)`, the last is `ceil(x1 - 0.5) - 1`, clipped to
    the buffer. Half-open at the right end, so two spans meeting at a
    pixel center fill it exactly once. -/
def fillSpan (cov : Coverage) (row : Nat) (x0 x1 : Float) : Coverage := Id.run do
  let first := ceilInt (x0 - 0.5)
  let last := ceilInt (x1 - 0.5) - 1
  let lo := max first 0
  let hi := min last ((cov.width : Int) - 1)
  let mut c := cov
  if lo <= hi then
    for x in [lo.toNat : hi.toNat + 1] do
      c := setCoverage c x row 1.0
  return c

/-! ## § 6.3  The sweep -/

/-- The classical scanline fill: sweep the rows top to bottom, keeping the
    edges that currently span the row's sample height (an edge joins once
    its `y_top` is reached and reads off the sorted table without
    searching; it leaves once its `y_bottom` is passed), sort their
    crossings, and fill the spans. -/
def fillPathAliased (p : Path) (rule : String) (w h : Nat) : Coverage := Id.run do
  let table := edgeTable p
  let mut cov := coverageBuffer w h
  let mut active : Array Edge := #[]
  let mut next := 0
  for row in [0:h] do
    let y := row.toFloat + 0.5
    while next < table.size && table[next]!.yTop <= y do
      active := active.push table[next]!
      next := next + 1
    active := active.filter (fun e => e.yBottom > y)
    let xs := (active.map (fun e => (xAt e y, e.direction))).qsort (fun a b => a.1 < b.1)
    for (x0, x1) in spansFromCrossings xs rule do
      cov := fillSpan cov row x0 x1
  return cov

/-- Chapter 1's `max_channel_difference`, for coverage buffers: the
    largest difference between corresponding entries, or 1 when the sizes
    differ. -/
def maxCoverageDifference (a b : Coverage) : Float :=
  if a.width != b.width || a.height != b.height then 1.0
  else Id.run do
    let n := min a.values.size b.values.size
    let mut m := 0.0
    for i in [0:n] do
      let d := (a.values[i]! - b.values[i]!).abs
      if d > m then m := d
    return m

/-! ## § 6.4  Paths through matrices -/

/-- `transform_points` with the subpath structure kept: a new path, every
    point of every subpath taken through `m`, closed flags and all. The
    original is untouched. -/
def transformPath (p : Path) (m : Matrix3) : Path :=
  { subpaths := p.subpaths.map (fun sp => { sp with points := sp.points.map (fun pt => m * pt) }) }

/-! ## § 6.5  Putting it together -/

/-- The chapter 5 star, moved to the origin and shrunk to radius 1, so one
    matrix can put it anywhere at any size. -/
def unitStar : Path :=
  transformPath star (scaling (1.0 / 70.0) (1.0 / 70.0) * translation (-80.5) (-80.5))

def spiral : IO Canvas := do
  let mut c := canvas 320 320
  c := fill c (color 0.02 0.02 0.025)
  let inks := #[color 0.9 0.55 0.1, color 0.2 0.55 0.85, color 0.85 0.25 0.3]
  for k in [0:24] do
    let a := k.toFloat * 25.0 * (pi / 180.0)
    let rr := 20.0 + 5.0 * k.toFloat
    let m := translation (160.5 + rr * Float.cos a) (160.5 + rr * Float.sin a) * rotation a *
             scaling (6.0 + 1.25 * k.toFloat) (6.0 + 1.25 * k.toFloat)
    let cov := fillPathAliased (transformPath unitStar m) "nonzero" 320 320
    c ← paintThrough c cov inks[k % 3]!
  return c

def plate06 : IO Canvas := do
  let s ← spiral
  return magnify s 2

end Renderer
