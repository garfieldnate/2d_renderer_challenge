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
line that starts off-canvas never touch a pixel outside it. -/

def plot (c : Canvas) (x y : Int) (col : Color) (weight : Float) : IO Canvas := do
  if weight == 0.0 then
    return c
  else if x < 0 || y < 0 || x >= (c.width : Int) || y >= (c.height : Int) then
    return c
  else
    return writePixel c x y (← mix (pixelAt c x y) col weight)

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
rasterizer already knows what to do with it. -/

/-- The rectangle of `width` centered on the segment from the center of pixel
    `(x0, y0)` to the center of pixel `(x1, y1)`, with square ends. A line of
    no length has no direction, so it gets `(1, 0)` and its two ends are
    pushed apart by half the width each, making it a `width`-by-`width`
    square. -/
def thickLine (x0 y0 x1 y1 : Int) (width : Float) : Shape :=
  let ax0 := intToFloat x0 + 0.5
  let ay0 := intToFloat y0 + 0.5
  let bx0 := intToFloat x1 + 0.5
  let by0 := intToFloat y1 + 0.5
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

/-! ## § 3.1, 3.2, 3.3, 3.4  The renders -/

private def fanPaper : Color := color 0.02 0.02 0.025
private def fanInk : Color := color 0.92 0.92 0.88
private def pi : Float := 3.14159265358979323846

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

end Renderer
