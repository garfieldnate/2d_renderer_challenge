#ifndef RENDERER_H
#define RENDERER_H

#include <stdbool.h>
#include <stddef.h>

/* ---- colors: three numbers measuring light -------------------------- */
typedef struct { double red, green, blue; } Color;

Color color(double r, double g, double b);
Color color_add(Color a, Color b);
Color color_sub(Color a, Color b);
Color color_scale(Color c, double s);
Color color_mul(Color a, Color b);   /* Hadamard product */

/* ---- the canvas ------------------------------------------------------ */
typedef struct { int width, height; Color *pixels; } Canvas;

Canvas *canvas(int width, int height);
void canvas_free(Canvas *c);
void write_pixel(Canvas *c, int x, int y, Color col);
Color pixel_at(const Canvas *c, int x, int y);
void fill(Canvas *c, Color col);
Canvas *magnify(const Canvas *c, int k);   /* every pixel into a k by k block */

/* ---- sRGB transfer functions ----------------------------------------- */
double decode(double v);   /* file value -> light */
double encode(double l);   /* light -> file value */

/* ---- mixing ---------------------------------------------------------- */
extern bool linear_blending;   /* defaults to true */

/* mix(a, b, t) uses the global switch; mix(a, b, t, linear) takes the
   switch as an explicit fourth argument instead, without touching the
   global, for languages (or callers) that would rather not have one. */
Color mix3(Color a, Color b, double t);
Color mix4(Color a, Color b, double t, bool linear);
#define MIX_PICK(_1, _2, _3, _4, NAME, ...) NAME
#define mix(...) MIX_PICK(__VA_ARGS__, mix4, mix3)(__VA_ARGS__)

/* ---- PPM ------------------------------------------------------------- */
/* A run of bytes, because a P6 file is not a string: it has NULs in it.
   read_file and canvas_to_p6 hand out heap blocks the caller frees
   (free(b.data)); bytes_of only borrows an existing string. */
typedef struct { unsigned char *data; size_t len; } Bytes;

Bytes bytes_of(const char *s);              /* a view of a NUL-terminated string */
static inline Bytes bytes_same(Bytes b) { return b; }

char *canvas_to_ppm(const Canvas *c);       /* P3, text, caller frees */
Bytes canvas_to_p6(const Canvas *c);        /* P6, bytes, caller frees .data */
Bytes read_file(const char *path);          /* .data is NULL if it could not be read */

/* The readers take either format. The macros let a call site pass a P3
   string or a P6 Bytes without saying which, the way the scenarios do. */
#define AS_BYTES(x) _Generic((x), \
        Bytes: bytes_same, char *: bytes_of, const char *: bytes_of)(x)

void ppm_pixel_bytes(Bytes ppm, int x, int y, int out[3]);
int  max_channel_difference_bytes(Bytes a, Bytes b);
int  distinct_values_bytes(Bytes ppm);

#define ppm_pixel(p, x, y, out)      ppm_pixel_bytes(AS_BYTES(p), (x), (y), (out))
#define max_channel_difference(a, b) max_channel_difference_bytes(AS_BYTES(a), AS_BYTES(b))
#define distinct_values(p)           distinct_values_bytes(AS_BYTES(p))


/* ---- chapter 4: points, vectors and matrices --------------------------
   These sit above the shapes because a shape can now be seen through a
   Matrix3. pi is here because the scenarios write it. */
#define PI 3.14159265358979323846

/* A tuple is (x, y, w): w = 1 for a point, w = 0 for a vector, so the
   arithmetic keeps the two straight and a translation can be a matrix. */
typedef struct { double x, y, w; } Tuple;

Tuple point(double x, double y);        /* w = 1 */
Tuple vector(double x, double y);       /* w = 0 */
Tuple tuple_add(Tuple a, Tuple b);
Tuple tuple_sub(Tuple a, Tuple b);
Tuple tuple_neg(Tuple a);
Tuple tuple_scale(Tuple a, double s);
Tuple tuple_div(Tuple a, double s);
double magnitude(Tuple v);
Tuple  normalize(Tuple v);
double dot(Tuple a, Tuple b);
double cross(Tuple a, Tuple b);         /* a scalar in two dimensions */

/* <sys/types.h> owns the name "minor" on this platform, as a macro.
   The book's function wins. */
#ifdef minor
#undef minor
#endif

/* 3 by 3, stored row by row. m[r][c] is row r, column c, both from 0. */
typedef struct { double m[3][3]; } Matrix3;

Matrix3 matrix3(double a, double b, double c,
                double d, double e, double f,
                double g, double h, double i);
double  m3_at(Matrix3 m, int r, int c);     /* M[r, c] */
Matrix3 identity(void);
Matrix3 transpose(Matrix3 m);
double  minor(Matrix3 m, int r, int c);
double  cofactor(Matrix3 m, int r, int c);
double  determinant(Matrix3 m);
bool    is_invertible(Matrix3 m);
Matrix3 inverse(Matrix3 m);

Matrix3 m3_mul(Matrix3 a, Matrix3 b);
Tuple   m3_mul_tuple(Matrix3 a, Tuple t);
/* mul(A, B) and mul(A, p): the book writes both with a star. */
#define mul(a, b) _Generic((b), Matrix3: m3_mul, Tuple: m3_mul_tuple)((a), (b))

Matrix3 translation(double tx, double ty);
Matrix3 scaling(double sx, double sy);
Matrix3 rotation(double r);             /* radians; turns x toward y */
Matrix3 shearing(double xy, double yx);

/* one number for how much m stretches lengths: the square root of the
   absolute determinant of its upper-left 2 by 2 */
double approx_scale(Matrix3 m);

/* ---- shapes: a shape is a thing that answers "is this point inside?" -- */
typedef enum { SHAPE_CIRCLE, SHAPE_RECTANGLE, SHAPE_HALF_PLANE, SHAPE_THICK_LINE,
               SHAPE_UNION, SHAPE_TRANSFORMED, SHAPE_EMPTY } ShapeKind;
/* h[] holds a thick line's four half-planes, each as px, py, nx, ny.
   parts/nparts belong to a union, base/inv to a transformed shape. */
typedef struct Shape Shape;
struct Shape {
    ShapeKind kind;
    double a, b, c, d;
    double h[4][4];
    Shape *parts; int nparts;
    Shape *base;  Matrix3 inv;
};

Shape circle(double cx, double cy, double r);
Shape rectangle(double x0, double y0, double x1, double y1);
Shape half_plane(double px, double py, double nx, double ny);
/* the rectangle of the given width centered on the segment from point a to
   point b, with square ends */
Shape segment(Tuple a, Tuple b, double width);
/* the same rectangle between the centers of pixel (x0, y0) and (x1, y1) */
Shape thick_line(double x0, double y0, double x1, double y1, double width);
bool inside(Shape s, double x, double y);

/* Composite shapes. C has no `union` to spare, so it is union_of, and
   because a Shape cannot contain itself the children live on the heap:
   union_of and transformed copy what you give them, and shape_free gives
   it back. Copying a composite Shape by value shares the children, so
   free the copy or the original, not both. Leaf shapes need no free. */
Shape union_of(const Shape *parts, int n);
Shape transformed(Shape base, Matrix3 m);
/* the closed polygon through the points after m, every edge a segment of
   that width in device space, as one shape */
Shape outline(const Tuple *pts, int n, Matrix3 m, double width);
void  shape_free(Shape s);

/* ---- coverage -------------------------------------------------------- */
typedef struct { int width, height; double *values; } CoverageBuffer;

CoverageBuffer *coverage_buffer(int width, int height);
void coverage_free(CoverageBuffer *cov);
void set_coverage(CoverageBuffer *cov, int x, int y, double v);
double coverage_at(const CoverageBuffer *cov, int x, int y);
double ink(const CoverageBuffer *cov);      /* the sum: the shape's area in pixels */

double center_inside(Shape s, int x, int y);        /* 1 or 0 */
double coverage(Shape s, int x, int y);             /* 8x8 samples, count / 64 */
CoverageBuffer *rasterize_centers(Shape s, int w, int h);
CoverageBuffer *rasterize(Shape s, int w, int h);

void paint_through(Canvas *c, const CoverageBuffer *cov, Color col);

/* ---- the chapters' pictures ------------------------------------------ */
Canvas *gray_match(void);
Canvas *quarter_match(void);
Canvas *ramp(void);
Canvas *clamp_pair(void);
Canvas *plate_01(void);

Canvas *disc_centers(void);
Canvas *disc_coverage(void);
Canvas *painted_twice(void);
Canvas *plate_02(void);

/* ---- chapter 3: lines ------------------------------------------------- */
void line_bresenham(Canvas *c, int x0, int y0, int x1, int y1, Color col);
void plot(Canvas *c, int x, int y, Color col, double weight);  /* paint_through, one pixel */
void line_wu(Canvas *c, int x0, int y0, int x1, int y1, Color col);

void ray_ends(int out[12][2]);   /* twelve points 72 pixels out, every 30 degrees */
Canvas *fan_bresenham(void);
Canvas *fan_wu(void);
Canvas *fan_coverage(void);
Canvas *plate_03(void);

/* ---- chapter 4: transforms -------------------------------------------- */
void transform_points(const Tuple *in, int n, Matrix3 m, Tuple *out);
Canvas *side_by_side(const Canvas *a, const Canvas *b);
Canvas *canvas_copy(const Canvas *c);

#define FAN_POINTS 13
#define LETTER_F_POINTS 10
int fan_points(Tuple *out);      /* the center, then twelve ends at radius 36 */
int letter_f(Tuple *out);        /* ten corners, clockwise from the top left */
Canvas *fan_transformed(Matrix3 m);
Canvas *fan_both_orders(void);
Canvas *f_both_orders(void);
Canvas *plate_04(void);

#endif
