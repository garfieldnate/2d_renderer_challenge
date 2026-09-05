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
Color mix(Color a, Color b, double t);

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

/* ---- shapes: a shape is a thing that answers "is this point inside?" -- */
typedef enum { SHAPE_CIRCLE, SHAPE_RECTANGLE, SHAPE_HALF_PLANE } ShapeKind;
typedef struct { ShapeKind kind; double a, b, c, d; } Shape;

Shape circle(double cx, double cy, double r);
Shape rectangle(double x0, double y0, double x1, double y1);
Shape half_plane(double px, double py, double nx, double ny);
bool inside(Shape s, double x, double y);

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

#endif
