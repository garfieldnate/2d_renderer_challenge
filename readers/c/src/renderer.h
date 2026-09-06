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

/* ---- chapter 5: paths and insideness -----------------------------------
   A path is a list of subpaths; a subpath is a list of points and a flag
   for whether it was closed. move_to starts a new subpath, line_to
   extends the last one (or behaves as move_to if there isn't one, or
   starts a fresh one at the closed subpath's start if the last one was
   closed), close marks the last subpath closed. The struct's fields are
   public, the way Canvas's are: p->subpaths[i], p->n_subpaths. */
typedef struct { Tuple *points; int n, cap; bool closed; } Subpath;
typedef struct Path {
    Subpath *subpaths; int n_subpaths, cap_subpaths;
} Path;

typedef struct { Tuple a, b; } Edge;
typedef struct { double min_x, min_y, max_x, max_y; } Bounds;

Path *path(void);
void  path_free(Path *p);
void  move_to(Path *p, Tuple pt);
void  line_to(Path *p, Tuple pt);
void  close(Path *p);

/* every edge of every subpath as (a, b) pairs, treating every subpath as
   closed whether or not close() was called; a subpath of one point
   contributes none. Heap array, caller frees. */
Edge *edges(const Path *p, int *n);
/* the smallest axis-aligned box around every point of every subpath;
   (0, 0, 0, 0) for an empty path */
Bounds bounds(const Path *p);

/* polygon(p1, p2, ...): a closed subpath through the points */
Path *polygon_pts(const Tuple *pts, int n);
#define polygon(...) polygon_pts((Tuple[]){__VA_ARGS__}, \
        (int)(sizeof((Tuple[]){__VA_ARGS__}) / sizeof(Tuple)))

/* a regular n-gon standing in for a circle: first point at angle 0 (to
   the right of center), going clockwise on the screen as k increases */
Path *circle_path(double cx, double cy, double r, int n);

/* the number of times a ray from (x, y) toward +x crosses an edge, and
   the signed version of the same walk: the winding number. Both use the
   half-open rule (a.y <= y < b.y, or the reverse) so a vertex on the ray
   counts once, not twice. */
int crossings(const Path *p, double x, double y);
int winding_at(const Path *p, double x, double y);
bool inside_nonzero(const Path *p, double x, double y);
bool inside_evenodd(const Path *p, double x, double y);

/* ---- shapes: a shape is a thing that answers "is this point inside?" -- */
typedef enum { SHAPE_CIRCLE, SHAPE_RECTANGLE, SHAPE_HALF_PLANE, SHAPE_THICK_LINE,
               SHAPE_UNION, SHAPE_TRANSFORMED, SHAPE_EMPTY, SHAPE_FILLED_PATH } ShapeKind;
/* h[] holds a thick line's four half-planes, each as px, py, nx, ny.
   parts/nparts belong to a union, base/inv to a transformed shape.
   path/rule belong to a filled path (rule 0 = nonzero, 1 = evenodd); the
   path is owned, a private deep copy made by filled(). */
typedef struct Shape Shape;
struct Shape {
    ShapeKind kind;
    double a, b, c, d;
    double h[4][4];
    Shape *parts; int nparts;
    Shape *base;  Matrix3 inv;
    Path *path;   int rule;
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

/* rule is "nonzero" or "evenodd". filled() copies the path it's given, so
   the caller's path outlives the shape either way; shape_free gives the
   copy back. */
Shape filled(const Path *p, const char *rule);

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
/* rasterize restricted to the pixels the box touches: columns from
   floor(min x) up to but not including ceil(max x), rows likewise,
   clipped to the buffer, the rest left at zero */
CoverageBuffer *rasterize_within(Shape s, Bounds box, int w, int h);

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

/* ---- chapter 5: putting it together ------------------------------------ */
/* five points on a circle of radius 70 about (80.5, 80.5), the first
   straight up, visited every second one so the pen crosses itself */
Path *star(void);
Canvas *star_panel(const char *rule, const char *method);  /* method: "centers" or "coverage" */
Canvas *star_centers(void);
Canvas *star_coverage(void);
Canvas *plate_05(void);

/* ---- chapter 6: filling a polygon ---------------------------------------
   The classical scanline fill: prepare every non-horizontal edge for the
   sweep (edge_table), find where the current row crosses the table
   (crossings_on_row), turn crossings into filled stretches
   (spans_from_crossings), and fill a stretch's pixels (fill_span).
   fill_path_aliased does all four, with an active edge list so the table
   is read once, front to back. */
typedef struct { double y_top, y_bottom, x_top, slope; int direction; } EdgeEntry;
typedef struct { double x; int direction; } Crossing;
typedef struct { double x0, x1; } Span;

/* sorted by y_top, then by x_top; horizontal edges (a.y == b.y exactly)
   are dropped. Heap array, caller frees. */
EdgeEntry *edge_table(const Path *p, int *n);
double x_at(EdgeEntry e, double y);   /* where the edge crosses height y */

/* (x, direction) for every edge of the table spanning height y, sorted by
   x, under the half-open rule y_top <= y < y_bottom. Heap array, caller
   frees. */
Crossing *crossings_on_row(const EdgeEntry *t, int n, double y, int *out_n);
/* walks sorted crossings left to right, accumulating the winding number,
   and returns the maximal intervals where rule ("nonzero" or "evenodd")
   says inside. Heap array, caller frees. */
Span *spans_from_crossings(const Crossing *xs, int n, const char *rule, int *out_n);
/* edge_table + crossings_on_row + spans_from_crossings for one pixel row,
   sampled at height row + 0.5. Heap array, caller frees. */
Span *spans(const Path *p, const char *rule, int row, int *out_n);
/* sets every pixel of the row whose center lies in [x0, x1) to 1 */
void fill_span(CoverageBuffer *cov, int row, double x0, double x1);

/* the scanline fill: a coverage buffer of 0s and 1s, exactly what
   rasterize_centers(filled(p, rule), w, h) would give */
CoverageBuffer *fill_path_aliased(const Path *p, const char *rule, int w, int h);
/* the largest difference between corresponding entries of two coverage
   buffers, or 1 when their sizes differ */
double max_coverage_difference(const CoverageBuffer *a, const CoverageBuffer *b);

/* every point of every subpath through m, closed flags kept; the
   original is untouched */
Path *transform_path(const Path *p, Matrix3 m);

/* the chapter 5 star shrunk to radius 1 about the origin */
Path *unit_star(void);
Canvas *spiral(void);
Canvas *plate_06(void);

#endif
