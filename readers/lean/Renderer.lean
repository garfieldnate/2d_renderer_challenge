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

/-! ### Reading PPM text back (test helpers, not renderer functions) -/

def ppmTokens (s : String) : Array String :=
  let flat := ((s.replace "\r" " ").replace "\n" " ").replace "\t" " "
  ((flat.splitOn " ").filter (· != "")).toArray

structure PpmInfo where
  width : Nat
  height : Nat
  data : Array Nat
deriving Inhabited

def parsePpm (s : String) : PpmInfo :=
  let toks := ppmTokens s
  let w := (toks[1]!).toNat!
  let h := (toks[2]!).toNat!
  let data := (toks.extract 4 toks.size).map (·.toNat!)
  { width := w, height := h, data := data }

/-- The three whole numbers at pixel (x, y) of a PPM's text. -/
def ppmPixel (s : String) (x y : Nat) : Nat × Nat × Nat :=
  let p := parsePpm s
  let i := (y * p.width + x) * 3
  (p.data[i]!, p.data[i+1]!, p.data[i+2]!)

/-- How many different numbers appear in the pixel data. -/
def distinctValues (s : String) : Nat :=
  let d := (parsePpm s).data.qsort (fun a b => a < b)
  Id.run do
    let mut n := 0
    let mut prev : Option Nat := none
    for v in d do
      if prev != some v then
        n := n + 1
        prev := some v
    return n

/-- Largest absolute difference between corresponding pixel numbers.
    Files of different sizes are as different as it gets. -/
def maxChannelDifference (a b : String) : Nat :=
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

def readFile (path : String) : IO String := IO.FS.readFile path

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

def mix (a b : Color) (t : Float) : IO Color := do
  return mixWith (← linearBlendingIsOn) a b t

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

end Renderer
