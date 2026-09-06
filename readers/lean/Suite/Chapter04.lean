/-
  Every scenario in features/chapter04-*.feature, one named check each.
-/
import Suite.Harness
open Renderer

def chapter04 (r : Runner) : IO Unit := do

  ----------------------------------------------------------------- tuples
  IO.println "# features/chapter04-tuples.feature"

  r.run "A point has w = 1" do
    let p := point 4 (-4)
    eqF "p.x" p.x 4
    eqF "p.y" p.y (-4)
    eqF "p.w" p.w 1

  r.run "A vector has w = 0" do
    let v := vector 4 (-4)
    eqF "v.x" v.x 4
    eqF "v.y" v.y (-4)
    eqF "v.w" v.w 0

  r.run "The difference of two points is the vector between them" do
    let a := point 3 2
    let b := point 5 6
    eqT "b - a" (b - a) (vector 2 4)
    eqT "a - b" (a - b) (vector (-2) (-4))

  r.run "A point plus a vector is a point" do
    let p := point 3 (-2)
    let v := vector (-2) 3
    eqT "p + v" (p + v) (point 1 1)
    eqT "p - v" (p - v) (point 5 (-5))

  r.run "A vector plus a vector is a vector" do
    let a := vector 3 (-2)
    let b := vector (-2) 3
    eqT "a + b" (a + b) (vector 1 1)
    eqT "a - b" (a - b) (vector 5 (-5))

  r.run "Negating, scaling and dividing a vector" do
    let v := vector 1 (-2)
    eqT "-v" (-v) (vector (-1) 2)
    eqT "v * 3.5" (v * (3.5 : Float)) (vector 3.5 (-7))
    eqT "v * 0.5" (v * (0.5 : Float)) (vector 0.5 (-1))
    eqT "v / 2" (v / (2.0 : Float)) (vector 0.5 (-1))

  r.run "The magnitude of a vector" do
    eqF "magnitude(vector(1, 0))" (magnitude (vector 1 0)) 1
    eqF "magnitude(vector(0, 1))" (magnitude (vector 0 1)) 1
    eqF "magnitude(vector(3, 4))" (magnitude (vector 3 4)) 5
    eqF "magnitude(vector(-3, -4))" (magnitude (vector (-3) (-4))) 5
    eqF "magnitude(vector(-1, -2))" (magnitude (vector (-1) (-2))) 2.2361

  r.run "Normalizing a vector" do
    eqT "normalize(vector(4, 0))" (normalize (vector 4 0)) (vector 1 0)
    eqT "normalize(vector(1, 2))" (normalize (vector 1 2)) (vector 0.4472 0.8944)
    eqF "magnitude(normalize(vector(1, 2)))" (magnitude (normalize (vector 1 2))) 1

  r.run "The dot product of two vectors" do
    let a := vector 1 2
    let b := vector 2 3
    eqF "dot(a, b)" (dot a b) 8
    eqF "dot(a, vector(-2, 1))" (dot a (vector (-2) 1)) 0

  r.run "magnitude and dot look at x and y only" do
    eqF "magnitude(point(3, 4))" (magnitude (point 3 4)) 5
    eqF "dot(point(1, 2), point(2, 3))" (dot (point 1 2) (point 2 3)) 8

  r.run "The cross product of two vectors is a number" do
    let a := vector 1 0
    let b := vector 0 1
    eqF "cross(a, b)" (cross a b) 1
    eqF "cross(b, a)" (cross b a) (-1)
    eqF "cross(a, a)" (cross a a) 0
    eqF "cross(vector(2, 3), vector(4, 5))" (cross (vector 2 3) (vector 4 5)) (-2)

  r.run "The sign of the cross product says which side of a line a point is on" do
    let a := point 0 0
    let b := point 10 0
    eqF "cross(b - a, point(5, 3) - a)" (cross (b - a) (point 5 3 - a)) 30
    eqF "cross(b - a, point(5, -3) - a)" (cross (b - a) (point 5 (-3) - a)) (-30)
    eqF "cross(b - a, point(20, 0) - a)" (cross (b - a) (point 20 0 - a)) 0

  --------------------------------------------------------------- matrices
  IO.println "# features/chapter04-matrices.feature"

  r.run "Constructing and inspecting a matrix" do
    let m := matrix3 1 2 3 4 5 6 7 8 9
    eqF "M.get(0, 0)" (m.get 0 0) 1
    eqF "M.get(0, 2)" (m.get 0 2) 3
    eqF "M.get(1, 0)" (m.get 1 0) 4
    eqF "M.get(1, 1)" (m.get 1 1) 5
    eqF "M.get(2, 0)" (m.get 2 0) 7
    eqF "M.get(2, 2)" (m.get 2 2) 9
    eqM "M" m (matrix3 1 2 3 4 5 6 7 8 9)

  r.run "Matrix equality with identical matrices" do
    let a := matrix3 1 2 3 4 5 6 7 8 9
    let b := matrix3 1 2 3 4 5 6 7 8 9
    eqM "A" a b

  r.run "Matrix equality with different matrices" do
    let a := matrix3 1 2 3 4 5 6 7 8 9
    let b := matrix3 1 2 3 4 5 6 7 8 8
    neM "A" a b

  r.run "Multiplying two matrices" do
    let a := matrix3 1 2 3 4 5 6 7 8 9
    let b := matrix3 2 (-1) 0 1 3 1 0 1 2
    eqM "A * B" (a * b) (matrix3 4 8 8 13 17 17 22 26 26)

  r.run "Matrix multiplication is not commutative" do
    let a := matrix3 1 2 3 4 5 6 7 8 9
    let b := matrix3 2 (-1) 0 1 3 1 0 1 2
    neM "A * B" (a * b) (b * a)

  r.run "A matrix multiplied by a point" do
    let a := matrix3 1 2 3 4 5 6 0 0 1
    let p := point 1 2
    eqT "A * p" (a * p) (point 8 20)

  r.run "A matrix multiplied by a vector ignores the last column" do
    let a := matrix3 1 2 3 4 5 6 0 0 1
    let v := vector 1 2
    eqT "A * v" (a * v) (vector 5 14)

  r.run "Multiplying by the identity matrix changes nothing" do
    let a := matrix3 0 1 2 1 2 4 2 4 8
    let p := point 1 2
    eqM "A * identity()" (a * identity) a
    eqM "identity() * A" (identity * a) a
    eqT "identity() * p" (identity * p) p

  r.run "Transposing a matrix" do
    let a := matrix3 0 9 3 9 8 0 1 8 5
    eqM "transpose(A)" (transpose a) (matrix3 0 9 1 9 8 8 3 0 5)

  r.run "Transposing the identity matrix" do
    eqM "transpose(identity())" (transpose identity) identity

  r.run "The determinant of a 3 by 3 matrix" do
    let a := matrix3 1 2 6 (-5) 8 (-4) 2 6 4
    eqF "determinant(A)" (determinant a) (-196)

  r.run "The determinant of a transform is the area factor" do
    eqF "determinant(identity())" (determinant identity) 1
    eqF "determinant(scaling(2, 3))" (determinant (scaling 2 3)) 6
    eqF "determinant(rotation(0.7))" (determinant (rotation 0.7)) 1
    eqF "determinant(translation(4, 9))" (determinant (translation 4 9)) 1
    eqF "determinant(scaling(-1, 1))" (determinant (scaling (-1) 1)) (-1)

  r.run "Testing an invertible matrix for invertibility" do
    let a := matrix3 3 0 2 2 0 (-2) 0 1 1
    eqF "determinant(A)" (determinant a) 10
    eqB "is_invertible(A)" (isInvertible a) true

  r.run "Testing a non-invertible matrix for invertibility" do
    let a := matrix3 1 2 3 2 4 6 0 0 1
    eqF "determinant(A)" (determinant a) 0
    eqB "is_invertible(A)" (isInvertible a) false

  r.run "Invertibility is an exact test against zero" do
    eqB "is_invertible(scaling(0.0001, 1))" (isInvertible (scaling 0.0001 1)) true
    eqF "determinant(scaling(0.0001, 1))" (determinant (scaling 0.0001 1)) 0.0001
    eqT "inverse(scaling(0.0001, 1)) * point(0.0001, 3)"
      (inverse (scaling 0.0001 1) * point 0.0001 3) (point 1 3)

  r.run "Calculating the inverse of a matrix" do
    let a := matrix3 3 0 2 2 0 (-2) 0 1 1
    let b := inverse a
    eqF "B.get(0, 0)" (b.get 0 0) 0.2
    eqF "B.get(1, 2)" (b.get 1 2) 1
    eqF "B.get(2, 1)" (b.get 2 1) (-0.3)
    eqM "B" b (matrix3 0.2 0.2 0 (-0.2) 0.3 1 0.2 (-0.3) 0)
    eqM "A * B" (a * b) identity

  r.run "Multiplying a product by its inverse" do
    let a := matrix3 1 2 3 4 5 6 7 8 9
    let b := matrix3 2 (-1) 0 1 3 1 0 1 2
    let c := a * b
    eqM "C * inverse(B)" (c * inverse b) a

  r.run "The inverse of a transform is a transform" do
    let a := translation 5 (-3) * rotation (pi / 6.0) * scaling 2 3
    let b := inverse a
    eqF "B.get(2, 0)" (b.get 2 0) 0
    eqF "B.get(2, 1)" (b.get 2 1) 0
    eqF "B.get(2, 2)" (b.get 2 2) 1
    eqF "B.get(0, 0)" (b.get 0 0) 0.4330
    eqF "B.get(0, 2)" (b.get 0 2) (-1.4151)
    eqF "B.get(1, 2)" (b.get 1 2) 1.6994
    eqM "B * A" (b * a) identity

  ------------------------------------------------------------- transforms
  IO.println "# features/chapter04-transforms.feature"

  r.run "Multiplying by a translation matrix" do
    let t := translation 5 (-3)
    let p := point (-3) 4
    eqT "t * p" (t * p) (point 2 1)

  r.run "The inverse of a translation moves the other way" do
    let t := translation 5 (-3)
    let p := point (-3) 4
    eqT "inverse(t) * p" (inverse t * p) (point (-8) 7)

  r.run "Translation does not affect vectors" do
    let t := translation 5 (-3)
    let v := vector (-3) 4
    eqT "t * v" (t * v) v

  r.run "A scaling matrix applied to a point" do
    let s := scaling 2 3
    let p := point (-4) 6
    eqT "s * p" (s * p) (point (-8) 18)

  r.run "A scaling matrix applied to a vector" do
    let s := scaling 2 3
    let v := vector (-4) 6
    eqT "s * v" (s * v) (vector (-8) 18)

  r.run "The inverse of a scaling shrinks" do
    let s := scaling 2 3
    let v := vector (-4) 6
    eqT "inverse(s) * v" (inverse s * v) (vector (-2) 2)

  r.run "Reflection is scaling by a negative value" do
    let s := scaling (-1) 1
    let p := point 2 3
    eqT "s * p" (s * p) (point (-2) 3)

  r.run "A positive rotation turns x toward y" do
    let p := point 1 0
    eqT "rotation(π / 4) * p" (rotation (pi / 4.0) * p) (point 0.7071 0.7071)
    eqT "rotation(π / 2) * p" (rotation (pi / 2.0) * p) (point 0 1)
    eqT "rotation(π) * p" (rotation pi * p) (point (-1) 0)

  r.run "The inverse of a rotation turns the other way" do
    let p := point 1 0
    eqT "inverse(rotation(π / 4)) * p" (inverse (rotation (pi / 4.0)) * p) (point 0.7071 (-0.7071))
    eqT "rotation(-π / 4) * p" (rotation (-(pi / 4.0)) * p) (point 0.7071 (-0.7071))

  r.run "A rotation preserves length" do
    let v := vector 3 4
    eqF "magnitude(rotation(1.2) * v)" (magnitude (rotation 1.2 * v)) 5
    eqF "magnitude(rotation(-2.8) * v)" (magnitude (rotation (-2.8) * v)) 5

  r.run "Shearing moves x in proportion to y" do
    let s := shearing 1 0
    let p := point 2 3
    eqT "s * p" (s * p) (point 5 3)

  r.run "Shearing moves y in proportion to x" do
    let s := shearing 0 1
    let p := point 2 3
    eqT "s * p" (s * p) (point 2 5)

  r.run "Individual transformations are applied in sequence" do
    let p := point 1 0
    let a := rotation (pi / 2.0)
    let b := scaling 5 5
    let c := translation 10 5
    let p2 := a * p
    let p3 := b * p2
    let p4 := c * p3
    eqT "p2" p2 (point 0 1)
    eqT "p3" p3 (point 0 5)
    eqT "p4" p4 (point 10 10)

  r.run "Chained transformations must be applied in reverse order" do
    let p := point 1 0
    let a := rotation (pi / 2.0)
    let b := scaling 5 5
    let c := translation 10 5
    let t := c * b * a
    eqT "T * p" (t * p) (point 10 10)

  r.run "The other order is a different transform" do
    let p := point 1 0
    let a := rotation (pi / 2.0)
    let b := scaling 5 5
    let c := translation 10 5
    let t := a * b * c
    eqT "T * p" (t * p) (point (-25) 55)

  r.run "Rotating about a point that isn't the origin" do
    let t := translation 4 4 * rotation (pi / 2.0) * translation (-4) (-4)
    eqT "T * point(6, 4)" (t * point 6 4) (point 4 6)
    eqT "T * point(4, 4)" (t * point 4 4) (point 4 4)

  ------------------------------------------------------------------- scale
  IO.println "# features/chapter04-scale.feature"

  r.run "The identity, a translation and a rotation don't stretch" do
    eqF "approx_scale(identity())" (approxScale identity) 1
    eqF "approx_scale(translation(7, 9))" (approxScale (translation 7 9)) 1
    eqF "approx_scale(rotation(1.1))" (approxScale (rotation 1.1)) 1

  r.run "A uniform scale is reported exactly" do
    eqF "approx_scale(scaling(2, 2))" (approxScale (scaling 2 2)) 2
    eqF "approx_scale(scaling(0.5, 0.5))" (approxScale (scaling 0.5 0.5)) 0.5
    eqF "approx_scale(scaling(3, 3) * rotation(0.7))" (approxScale (scaling 3 3 * rotation 0.7)) 3
    eqF "approx_scale(translation(5, 5) * scaling(3, 3))"
      (approxScale (translation 5 5 * scaling 3 3)) 3

  r.run "A reflection is not a negative scale" do
    eqF "approx_scale(scaling(-2, 2))" (approxScale (scaling (-2) 2)) 2

  r.run "A non-uniform scale is reported as the geometric mean" do
    eqF "approx_scale(scaling(4, 1))" (approxScale (scaling 4 1)) 2
    eqF "approx_scale(scaling(4, 1) * rotation(0.4))" (approxScale (scaling 4 1 * rotation 0.4)) 2
    eqF "approx_scale(scaling(9, 1))" (approxScale (scaling 9 1)) 3

  r.run "A shear that preserves area reports 1" do
    eqF "approx_scale(shearing(1, 0))" (approxScale (shearing 1 0)) 1
    eqF "approx_scale(shearing(0.5, 0.5))" (approxScale (shearing 0.5 0.5)) 0.8660

  r.run "A collapsed transform reports 0" do
    eqF "approx_scale(scaling(0, 1))" (approxScale (scaling 0 1)) 0
    eqF "approx_scale(matrix3(1, 2, 0, 2, 4, 0, 0, 0, 1))"
      (approxScale (matrix3 1 2 0 2 4 0 0 0 1)) 0

  ----------------------------------------------------------------- drawing
  IO.println "# features/chapter04-drawing.feature"

  r.run "A segment between pixel centers is a thick line" do
    let s := segment (point 2.5 2.5) (point 11.5 5.5) 1
    let cov := rasterize s 16 10
    eqF "coverage_at(cov, 2, 2)" (coverageAt cov 2 2) 0.484375
    eqF "coverage_at(cov, 11, 5)" (coverageAt cov 11 5) 0.484375
    eqF "coverage_at(cov, 6, 3)" (coverageAt cov 6 3) 0.6875
    eqF "coverage_at(cov, 7, 3)" (coverageAt cov 7 3) 0.359375
    eqF "coverage_at(cov, 2, 1)" (coverageAt cov 2 1) 0
    eqF "ink(cov)" (ink cov) 9.4063

  r.run "A segment need not start on a pixel center" do
    let s := segment (point 1 3.5) (point 7 3.5) 1
    let cov := rasterize s 10 10
    eqF "coverage_at(cov, 0, 3)" (coverageAt cov 0 3) 0
    eqF "coverage_at(cov, 1, 3)" (coverageAt cov 1 3) 1
    eqF "coverage_at(cov, 6, 3)" (coverageAt cov 6 3) 1
    eqF "coverage_at(cov, 7, 3)" (coverageAt cov 7 3) 0
    eqF "coverage_at(cov, 3, 2)" (coverageAt cov 3 2) 0
    eqF "ink(cov)" (ink cov) 6

  r.run "A segment of no length is a square" do
    let s := segment (point 3.5 3.5) (point 3.5 3.5) 1
    let cov := rasterize s 8 8
    eqF "coverage_at(cov, 3, 3)" (coverageAt cov 3 3) 1
    eqF "ink(cov)" (ink cov) 1

  r.run "A union of nothing is inside nowhere" do
    let s := union #[]
    eqB "inside(s, 0, 0)" (inside s 0 0) false
    eqF "ink(rasterize(s, 4, 4))" (ink (rasterize s 4 4)) 0

  r.run "A union is inside when any of its parts is" do
    let s := union #[circle 2 2 1, rectangle 5 0 7 4]
    eqB "inside(s, 2, 2)" (inside s 2 2) true
    eqB "inside(s, 6, 1)" (inside s 6 1) true
    eqB "inside(s, 4, 2)" (inside s 4 2) false
    eqF "ink(rasterize(s, 8, 8))" (ink (rasterize s 8 8)) 11.25

  r.run "A circle seen through a scale is an ellipse" do
    let s := transformed (circle 0 0 4) (scaling 2 1)
    eqB "inside(s, 7.9, 0)" (inside s 7.9 0) true
    eqB "inside(s, 8.1, 0)" (inside s 8.1 0) false
    eqB "inside(s, 0, 3.9)" (inside s 0 3.9) true
    eqB "inside(s, 0, 4.1)" (inside s 0 4.1) false
    eqB "inside(s, 5.6, 1.4)" (inside s 5.6 1.4) true
    eqB "inside(s, 5.6, 2.9)" (inside s 5.6 2.9) false

  r.run "The transform is applied in the order the matrix says" do
    let s := transformed (circle 0 0 4) (translation 10 10 * scaling 2 1)
    eqB "inside(s, 10, 10)" (inside s 10 10) true
    eqB "inside(s, 17.9, 10)" (inside s 17.9 10) true
    eqB "inside(s, 18.1, 10)" (inside s 18.1 10) false
    eqB "inside(s, 10, 13.9)" (inside s 10 13.9) true
    eqB "inside(s, 10, 14.1)" (inside s 10 14.1) false

  r.run "A shape seen through a collapsed transform is empty" do
    let s := transformed (circle 0 0 4) (scaling 0 1)
    eqB "inside(s, 0, 0)" (inside s 0 0) false
    eqF "ink(rasterize(s, 10, 10))" (ink (rasterize s 10 10)) 0

  r.run "A pen in shape space scales with the shape" do
    let s := transformed (thickLine 5 0 5 9 1) (scaling 3 1)
    let cov := rasterize s 24 10
    eqF "coverage_at(cov, 14, 4)" (coverageAt cov 14 4) 0
    eqF "coverage_at(cov, 15, 4)" (coverageAt cov 15 4) 1
    eqF "coverage_at(cov, 16, 4)" (coverageAt cov 16 4) 1
    eqF "coverage_at(cov, 17, 4)" (coverageAt cov 17 4) 1
    eqF "coverage_at(cov, 18, 4)" (coverageAt cov 18 4) 0
    eqF "ink(cov)" (ink cov) 27

  r.run "A pen in device space does not" do
    let m := scaling 3 1
    let s := segment (m * point 5.5 0.5) (m * point 5.5 9.5) 1
    let cov := rasterize s 24 10
    eqF "coverage_at(cov, 15, 4)" (coverageAt cov 15 4) 0
    eqF "coverage_at(cov, 16, 4)" (coverageAt cov 16 4) 1
    eqF "coverage_at(cov, 17, 4)" (coverageAt cov 17 4) 0
    eqF "ink(cov)" (ink cov) 9

  r.run "Dividing the width by approx_scale makes the two pens agree" do
    let m := scaling 2 2
    let s := transformed (segment (point 5.5 0.5) (point 5.5 9.5) (1.0 / approxScale m)) m
    let cov := rasterize s 24 20
    eqF "coverage_at(cov, 9, 5)" (coverageAt cov 9 5) 0
    eqF "coverage_at(cov, 10, 5)" (coverageAt cov 10 5) 0.5
    eqF "coverage_at(cov, 11, 5)" (coverageAt cov 11 5) 0.5
    eqF "coverage_at(cov, 12, 5)" (coverageAt cov 12 5) 0
    eqF "ink(cov)" (ink cov) 18

  r.run "Under a non-uniform scale the compromise shows" do
    let m := scaling 4 1
    let w := 1.0 / approxScale m
    let v := transformed (segment (point 2.5 0.5) (point 2.5 9.5) w) m
    let h := transformed (segment (point 0.5 5.5) (point 4.5 5.5) w) m
    let cv := rasterize v 24 12
    let ch := rasterize h 24 12
    eqF "coverage_at(cv, 8, 5)" (coverageAt cv 8 5) 0
    eqF "coverage_at(cv, 9, 5)" (coverageAt cv 9 5) 1
    eqF "coverage_at(cv, 10, 5)" (coverageAt cv 10 5) 1
    eqF "coverage_at(cv, 11, 5)" (coverageAt cv 11 5) 0
    eqF "ink(cv)" (ink cv) 18
    eqF "coverage_at(ch, 10, 4)" (coverageAt ch 10 4) 0
    eqF "coverage_at(ch, 10, 5)" (coverageAt ch 10 5) 0.5
    eqF "coverage_at(ch, 10, 6)" (coverageAt ch 10 6) 0
    eqF "ink(ch)" (ink ch) 8

  r.run "An outline is one shape, so its corners are painted once" do
    let pts : Array Tuple := #[point 1.5 1.5, point 6.5 1.5, point 6.5 6.5, point 1.5 6.5]
    let c := canvas 8 8
    let c ← paintThrough c (rasterize (outline pts identity 1) 8 8) (color 1 1 1)
    eqN "length(lit_pixels(c))" (litPixels c).size 20
    eqC "pixel_at(c, 3, 1)" (pixelAt c 3 1) (color 1 1 1)
    eqC "pixel_at(c, 1, 3)" (pixelAt c 1 3) (color 1 1 1)
    eqC "pixel_at(c, 1, 1)" (pixelAt c 1 1) (color 0.75 0.75 0.75)
    eqC "pixel_at(c, 3, 3)" (pixelAt c 3 3) (color 0 0 0)
    eqC "pixel_at(c, 0, 1)" (pixelAt c 0 1) (color 0 0 0)
    eqF "total_ink(c)" (totalInk c) 19

  r.run "An outline takes its points through the matrix first" do
    let pts : Array Tuple := #[point 1.5 1.5, point 6.5 1.5, point 6.5 6.5, point 1.5 6.5]
    let c := canvas 16 16
    let c ← paintThrough c (rasterize (outline pts (scaling 2 2) 1) 16 16) (color 1 1 1)
    eqN "length(lit_pixels(c))" (litPixels c).size 76
    eqC "pixel_at(c, 3, 3)" (pixelAt c 3 3) (color 0.75 0.75 0.75)
    eqC "pixel_at(c, 8, 2)" (pixelAt c 8 2) (color 0.5 0.5 0.5)
    eqC "pixel_at(c, 8, 3)" (pixelAt c 8 3) (color 0.5 0.5 0.5)
    eqC "pixel_at(c, 8, 4)" (pixelAt c 8 4) (color 0 0 0)

  --------------------------------------------------------------------- plate
  IO.println "# features/chapter04-plate.feature"

  r.run "The fan as points" do
    let pts := fanPoints
    eqN "length(pts)" pts.size 13
    eqT "pts[0]" pts[0]! (point 0 0)
    eqT "pts[1]" pts[1]! (point 36 0)
    eqT "pts[4]" pts[4]! (point 0 36)
    eqT "pts[7]" pts[7]! (point (-36) 0)
    eqT "pts[2]" pts[2]! (point 31.1769 18)

  r.run "Rotate, then translate: the fan turns about its own center" do
    let m := translation 104.5 76.5 * rotation (pi / 6.0)
    let pts := transformPoints fanPoints m
    eqT "pts[0]" pts[0]! (point 104.5 76.5)
    eqT "pts[1]" pts[1]! (point 135.6769 94.5)
    eqT "pts[4]" pts[4]! (point 86.5 107.6769)

  r.run "Translate, then rotate: the fan swings about the canvas corner" do
    let m := rotation (pi / 6.0) * translation 104.5 76.5
    let pts := transformPoints fanPoints m
    eqT "pts[0]" pts[0]! (point 52.2497 118.5009)
    eqT "pts[1]" pts[1]! (point 83.4266 136.5009)

  r.run "The letter F" do
    let f := letterF
    eqN "length(f)" f.size 10
    eqT "f[0]" f[0]! (point (-20) (-30))
    eqT "f[1]" f[1]! (point 20 (-30))
    eqT "f[5]" f[5]! (point 12 (-5))
    eqT "f[9]" f[9]! (point (-20) 30)

  r.run "The F at home" do
    let f := transformPoints letterF (translation 44.5 44.5)
    eqT "f[0]" f[0]! (point 24.5 14.5)
    eqT "f[1]" f[1]! (point 64.5 14.5)
    eqT "f[9]" f[9]! (point 24.5 74.5)

  r.run "The F, rotated then translated" do
    let m := translation 104.5 76.5 * rotation (pi / 6.0)
    let f := transformPoints letterF m
    eqT "f[0]" f[0]! (point 102.1795 40.5192)
    eqT "f[1]" f[1]! (point 136.8205 60.5192)
    eqT "f[5]" f[5]! (point 117.3923 78.1699)
    eqT "f[9]" f[9]! (point 72.1795 92.4808)

  r.run "The F, translated then rotated" do
    let m := rotation (pi / 6.0) * translation 104.5 76.5
    let f := transformPoints letterF m
    eqT "f[0]" f[0]! (point 49.9291 82.5202)
    eqT "f[1]" f[1]! (point 84.5702 102.5202)
    eqT "f[5]" f[5]! (point 65.142 120.1708)
    eqT "f[9]" f[9]! (point 19.9291 134.4817)

  r.run "side_by_side puts the first canvas on the left" do
    let a := canvas 2 3
    let b := canvas 4 3
    let a := fill a (color 1 0 0)
    let b := fill b (color 0 0 1)
    let c := sideBySide a b
    eqN "c.width" c.width 6
    eqN "c.height" c.height 3
    eqC "pixel_at(c, 0, 0)" (pixelAt c 0 0) (color 1 0 0)
    eqC "pixel_at(c, 1, 2)" (pixelAt c 1 2) (color 1 0 0)
    eqC "pixel_at(c, 2, 0)" (pixelAt c 2 0) (color 0 0 1)
    eqC "pixel_at(c, 5, 2)" (pixelAt c 5 2) (color 0 0 1)

  r.run "The fan, both orders" do
    let c ← fanBothOrders
    let ref ← readFile "reference/chapter-04/fan-both-orders.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 320
    eqN "c.height" c.height 160
    eqTri "ppm_pixel(p6, 104, 76)" (ppmPixel p6 104 76) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 124, 76)" (ppmPixel p6 124 76) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 104, 56)" (ppmPixel p6 104 56) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 125, 88)" (ppmPixel p6 125 88) (236, 236, 231) 1
    eqTri "ppm_pixel(p6, 116, 97)" (ppmPixel p6 116 97) (236, 236, 231) 1
    eqTri "ppm_pixel(p6, 141, 76)" (ppmPixel p6 141 76) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 10, 10)" (ppmPixel p6 10 10) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 212, 118)" (ppmPixel p6 212 118) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 232, 118)" (ppmPixel p6 232 118) (246, 246, 241) 1
    eqTri "ppm_pixel(p6, 233, 130)" (ppmPixel p6 233 130) (223, 223, 219) 1
    eqTri "ppm_pixel(p6, 224, 139)" (ppmPixel p6 224 139) (236, 236, 231) 1
    eqTri "ppm_pixel(p6, 200, 139)" (ppmPixel p6 200 139) (211, 211, 207) 1
    eqTri "ppm_pixel(p6, 310, 10)" (ppmPixel p6 310 10) (39, 39, 44) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1

  r.run "Plate 4" do
    let c ← plate04
    let ref ← readFile "reference/chapter-04/plate-04.ppm"
    let p6 := canvasToP6 c
    eqN "c.width" c.width 640
    eqN "c.height" c.height 320
    eqTri "ppm_pixel(p6, 48, 28)" (ppmPixel p6 48 28) (99, 99, 102) 1
    eqTri "ppm_pixel(p6, 80, 28)" (ppmPixel p6 80 28) (111, 111, 115) 1
    eqTri "ppm_pixel(p6, 48, 100)" (ppmPixel p6 48 100) (111, 111, 115) 1
    eqTri "ppm_pixel(p6, 10, 10)" (ppmPixel p6 10 10) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 200, 150)" (ppmPixel p6 200 150) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 268, 129)" (ppmPixel p6 268 129) (237, 237, 233) 1
    eqTri "ppm_pixel(p6, 215, 145)" (ppmPixel p6 215 145) (237, 237, 233) 1
    eqTri "ppm_pixel(p6, 239, 101)" (ppmPixel p6 239 101) (237, 237, 233) 1
    eqTri "ppm_pixel(p6, 174, 173)" (ppmPixel p6 174 173) (217, 217, 213) 1
    eqTri "ppm_pixel(p6, 368, 28)" (ppmPixel p6 368 28) (99, 99, 102) 1
    eqTri "ppm_pixel(p6, 500, 60)" (ppmPixel p6 500 60) (39, 39, 44) 1
    eqTri "ppm_pixel(p6, 453, 207)" (ppmPixel p6 453 207) (236, 236, 231) 1
    eqTri "ppm_pixel(p6, 431, 229)" (ppmPixel p6 431 229) (234, 234, 229) 1
    eqTri "ppm_pixel(p6, 445, 249)" (ppmPixel p6 445 249) (234, 234, 229) 1
    eqTri "ppm_pixel(p6, 368, 273)" (ppmPixel p6 368 273) (177, 177, 174) 1
    leN "max_channel_difference(p6, ref)" (maxChannelDifference p6 ref) 1
