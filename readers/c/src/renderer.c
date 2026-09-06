#include "renderer.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* No fused multiply-add. thick_line's half-plane test relies on exact
   cancellation for sample points that land exactly on an edge; contracting
   a*b + c*d into an fma changes the last bit and loses four samples out of
   sixty-four in the 45 degree scenario. */
#pragma STDC FP_CONTRACT OFF

/* ---- colors ---------------------------------------------------------- */
Color color(double r, double g, double b) { Color c = {r, g, b}; return c; }
Color color_add(Color a, Color b) { return color(a.red+b.red, a.green+b.green, a.blue+b.blue); }
Color color_sub(Color a, Color b) { return color(a.red-b.red, a.green-b.green, a.blue-b.blue); }
Color color_scale(Color c, double s) { return color(c.red*s, c.green*s, c.blue*s); }
Color color_mul(Color a, Color b) { return color(a.red*b.red, a.green*b.green, a.blue*b.blue); }

/* ---- canvas ---------------------------------------------------------- */
Canvas *canvas(int width, int height) {
    Canvas *c = malloc(sizeof *c);
    if (!c) abort();
    c->width = width;
    c->height = height;
    c->pixels = calloc((size_t)width * (size_t)height, sizeof *c->pixels);
    if (!c->pixels) abort();
    return c;   /* calloc gives every pixel color(0,0,0) */
}

void canvas_free(Canvas *c) { if (c) { free(c->pixels); free(c); } }

void write_pixel(Canvas *c, int x, int y, Color col) {
    if (x < 0 || y < 0 || x >= c->width || y >= c->height) return;  /* silently dropped */
    c->pixels[(size_t)y * c->width + x] = col;
}

Color pixel_at(const Canvas *c, int x, int y) {
    if (x < 0 || y < 0 || x >= c->width || y >= c->height) return color(0, 0, 0);
    return c->pixels[(size_t)y * c->width + x];
}

void fill(Canvas *c, Color col) {
    size_t n = (size_t)c->width * c->height;
    for (size_t i = 0; i < n; i++) c->pixels[i] = col;
}

/* ---- sRGB ------------------------------------------------------------ */
double decode(double v) {
    return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4);
}

double encode(double l) {
    return l <= 0.0031308 ? l * 12.92 : 1.055 * pow(l, 1.0 / 2.4) - 0.055;
}

/* ---- mixing ---------------------------------------------------------- */
bool linear_blending = true;

/* The light's way never clamps: a + (b-a)*t can leave 0-1 in either
   direction, and the file writer is the only place that clamps. The
   browser's way clamps each end to 0-1 *before* encoding it, which is
   what a browser's own color parsing does -- clamping the result instead
   passes every scenario except the one that mixes at t = 0.5 with an
   out-of-range end. */
static double mix1(double a, double b, double t, bool linear) {
    if (linear) return a + (b - a) * t;
    double ca = a < 0.0 ? 0.0 : (a > 1.0 ? 1.0 : a);
    double cb = b < 0.0 ? 0.0 : (b > 1.0 ? 1.0 : b);
    double ea = encode(ca), eb = encode(cb);
    return decode(ea + (eb - ea) * t);
}

Color mix4(Color a, Color b, double t, bool linear) {
    return color(mix1(a.red, b.red, t, linear),
                 mix1(a.green, b.green, t, linear),
                 mix1(a.blue, b.blue, t, linear));
}

Color mix3(Color a, Color b, double t) { return mix4(a, b, t, linear_blending); }

/* ---- a growable string ------------------------------------------------ */
typedef struct { char *s; size_t len, cap; } Buf;

static void buf_push(Buf *b, const char *t) {
    size_t n = strlen(t);
    if (b->len + n + 1 > b->cap) {
        while (b->len + n + 1 > b->cap) b->cap = b->cap ? b->cap * 2 : 256;
        b->s = realloc(b->s, b->cap);
        if (!b->s) abort();
    }
    memcpy(b->s + b->len, t, n + 1);
    b->len += n;
}

/* ---- PPM out --------------------------------------------------------- */
static int channel_to_file(double v) {
    if (v < 0.0) v = 0.0;            /* 1. clamp */
    if (v > 1.0) v = 1.0;
    double e = encode(v);            /* 2. encode */
    return (int)lround(e * 255.0);   /* 3. scale, 4. round */
}

#define PPM_LINE_MAX 70

char *canvas_to_ppm(const Canvas *c) {
    Buf b = {0};
    char tmp[32];
    snprintf(tmp, sizeof tmp, "P3\n%d %d\n255\n", c->width, c->height);
    buf_push(&b, tmp);

    for (int y = 0; y < c->height; y++) {
        size_t line = 0;                       /* each row starts a fresh line */
        for (int x = 0; x < c->width; x++) {
            Color p = pixel_at(c, x, y);
            double ch[3] = {p.red, p.green, p.blue};
            for (int k = 0; k < 3; k++) {
                snprintf(tmp, sizeof tmp, "%d", channel_to_file(ch[k]));
                size_t n = strlen(tmp);
                if (line > 0 && line + 1 + n > PPM_LINE_MAX) {
                    buf_push(&b, "\n");
                    line = 0;
                } else if (line > 0) {
                    buf_push(&b, " ");
                    line += 1;
                }
                buf_push(&b, tmp);
                line += n;
            }
        }
        buf_push(&b, "\n");
    }
    if (!b.s) buf_push(&b, "");
    return b.s;
}

/* P6: the same header with a 6, one newline, then one byte per channel. */
Bytes canvas_to_p6(const Canvas *c) {
    char head[32];
    int hn = snprintf(head, sizeof head, "P6\n%d %d\n255\n", c->width, c->height);
    size_t body = (size_t)c->width * (size_t)c->height * 3;
    unsigned char *out = malloc((size_t)hn + body + 1);
    if (!out) abort();
    memcpy(out, head, (size_t)hn);
    size_t i = (size_t)hn;
    for (int y = 0; y < c->height; y++)
        for (int x = 0; x < c->width; x++) {
            Color p = pixel_at(c, x, y);
            out[i++] = (unsigned char)channel_to_file(p.red);
            out[i++] = (unsigned char)channel_to_file(p.green);
            out[i++] = (unsigned char)channel_to_file(p.blue);
        }
    out[i] = '\0';
    Bytes b = { out, i };
    return b;
}

Bytes bytes_of(const char *s) {
    Bytes b = { (unsigned char *)s, s ? strlen(s) : 0 };
    return b;
}

Bytes read_file(const char *path) {
    Bytes b = {NULL, 0};
    FILE *f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "read_file: cannot open %s\n", path); return b; }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    unsigned char *s = malloc((size_t)n + 1);
    if (!s) abort();
    size_t got = fread(s, 1, (size_t)n, f);
    s[got] = '\0';           /* so a P3 file is still usable as a string */
    fclose(f);
    b.data = s; b.len = got;
    return b;
}

static int isspace_like(unsigned char ch) {
    return ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r' || ch == '\v' || ch == '\f';
}

/* The channel values of either format, in order, plus the width.
   P3: whitespace-separated numbers after the four header tokens.
   P6: the raw bytes after the header's single trailing whitespace byte. */
static int *ppm_numbers(Bytes ppm, int *count, int *width) {
    const unsigned char *p = ppm.data, *end = ppm.data + ppm.len;
    if (width) *width = 0;
    *count = 0;
    if (!p) return NULL;

    if (ppm.len >= 2 && p[0] == 'P' && p[1] == '6') {
        int header[3] = {0, 0, 0};
        p += 2;
        for (int i = 0; i < 3; i++) {
            while (p < end && isspace_like(*p)) p++;
            int v = 0;
            while (p < end && *p >= '0' && *p <= '9') v = v * 10 + (*p++ - '0');
            header[i] = v;
        }
        if (p < end) p++;                  /* exactly one whitespace byte */
        if (width) *width = header[0];
        int n = (int)(end - p);
        int *v = malloc((size_t)(n ? n : 1) * sizeof *v);
        if (!v) abort();
        for (int i = 0; i < n; i++) v[i] = p[i];
        *count = n;
        return v;
    }

    int cap = 256, n = 0, tok = 0;
    int *v = malloc((size_t)cap * sizeof *v);
    if (!v) abort();
    while (p < end) {
        while (p < end && isspace_like(*p)) p++;
        if (p >= end) break;
        const unsigned char *start = p;
        while (p < end && !isspace_like(*p)) p++;
        tok++;
        if (tok == 2 && width) *width = atoi((const char *)start);
        if (tok <= 4) continue;            /* P3, width, height, maxval */
        if (n == cap) { cap *= 2; v = realloc(v, (size_t)cap * sizeof *v); if (!v) abort(); }
        v[n++] = atoi((const char *)start);
    }
    *count = n;
    return v;
}

void ppm_pixel_bytes(Bytes ppm, int x, int y, int out[3]) {
    int n, w;
    int *v = ppm_numbers(ppm, &n, &w);
    long i = ((long)y * w + x) * 3;
    if (!v || i < 0 || i + 2 >= n) { out[0] = out[1] = out[2] = -1; }
    else { out[0] = v[i]; out[1] = v[i+1]; out[2] = v[i+2]; }
    free(v);
}

int max_channel_difference_bytes(Bytes a, Bytes b) {
    int na, nb, wa, wb;
    int *va = ppm_numbers(a, &na, &wa);
    int *vb = ppm_numbers(b, &nb, &wb);
    int n = na < nb ? na : nb;
    int worst = (na == nb && wa == wb) ? 0 : 255;   /* different sizes: not comparable */
    for (int i = 0; i < n; i++) {
        int d = va[i] - vb[i];
        if (d < 0) d = -d;
        if (d > worst) worst = d;
    }
    free(va); free(vb);
    return worst;
}

int distinct_values_bytes(Bytes ppm) {
    int n, w;
    int *v = ppm_numbers(ppm, &n, &w);
    char seen[256] = {0};
    int count = 0;
    for (int i = 0; i < n; i++) {
        if (v[i] >= 0 && v[i] < 256 && !seen[v[i]]) { seen[v[i]] = 1; count++; }
    }
    free(v);
    return count;
}

/* ---- magnify ---------------------------------------------------------- */
Canvas *magnify(const Canvas *c, int k) {
    Canvas *m = canvas(c->width * k, c->height * k);
    for (int y = 0; y < m->height; y++)
        for (int x = 0; x < m->width; x++)
            write_pixel(m, x, y, pixel_at(c, x / k, y / k));
    return m;
}

/* ---- points and vectors ----------------------------------------------- */
/* w is the whole trick: 1 for a point, 0 for a vector. Do the arithmetic
   on all three and the bookkeeping does itself. */
Tuple point(double x, double y)  { Tuple t = {x, y, 1}; return t; }
Tuple vector(double x, double y) { Tuple t = {x, y, 0}; return t; }

Tuple tuple_add(Tuple a, Tuple b) { Tuple t = {a.x+b.x, a.y+b.y, a.w+b.w}; return t; }
Tuple tuple_sub(Tuple a, Tuple b) { Tuple t = {a.x-b.x, a.y-b.y, a.w-b.w}; return t; }
Tuple tuple_neg(Tuple a)          { Tuple t = {-a.x, -a.y, -a.w}; return t; }
Tuple tuple_scale(Tuple a, double s) { Tuple t = {a.x*s, a.y*s, a.w*s}; return t; }
Tuple tuple_div(Tuple a, double s)   { Tuple t = {a.x/s, a.y/s, a.w/s}; return t; }

double magnitude(Tuple v) { return sqrt(v.x * v.x + v.y * v.y); }
Tuple  normalize(Tuple v) { return tuple_div(v, magnitude(v)); }
double dot(Tuple a, Tuple b)   { return a.x * b.x + a.y * b.y; }
/* In two dimensions there is nowhere perpendicular to go, so what is left
   of the cross product is one number: the signed area of the
   parallelogram, and with it which way you turned. */
double cross(Tuple a, Tuple b) { return a.x * b.y - a.y * b.x; }

/* ---- matrices ---------------------------------------------------------- */
Matrix3 matrix3(double a, double b, double c,
                double d, double e, double f,
                double g, double h, double i) {
    Matrix3 m = {{{a, b, c}, {d, e, f}, {g, h, i}}};
    return m;
}

double m3_at(Matrix3 m, int r, int c) { return m.m[r][c]; }

Matrix3 identity(void) { return matrix3(1, 0, 0, 0, 1, 0, 0, 0, 1); }

Matrix3 transpose(Matrix3 m) {
    Matrix3 t;
    for (int r = 0; r < 3; r++)
        for (int c = 0; c < 3; c++) t.m[r][c] = m.m[c][r];
    return t;
}

/* (A * B)[r, c] is row r of A dotted with column c of B. */
Matrix3 m3_mul(Matrix3 a, Matrix3 b) {
    Matrix3 p;
    for (int r = 0; r < 3; r++)
        for (int c = 0; c < 3; c++)
            p.m[r][c] = a.m[r][0]*b.m[0][c] + a.m[r][1]*b.m[1][c] + a.m[r][2]*b.m[2][c];
    return p;
}

/* The tuple is a column. The last column of the matrix multiplies w, so
   for a vector it contributes nothing and a translation leaves it alone. */
Tuple m3_mul_tuple(Matrix3 a, Tuple t) {
    Tuple r;
    r.x = a.m[0][0]*t.x + a.m[0][1]*t.y + a.m[0][2]*t.w;
    r.y = a.m[1][0]*t.x + a.m[1][1]*t.y + a.m[1][2]*t.w;
    r.w = a.m[2][0]*t.x + a.m[2][1]*t.y + a.m[2][2]*t.w;
    return r;
}

/* the 2 by 2 determinant left when row r and column c are deleted */
double minor(Matrix3 m, int r, int c) {
    int rows[2], cols[2], nr = 0, nc = 0;
    for (int i = 0; i < 3; i++) {
        if (i != r) rows[nr++] = i;
        if (i != c) cols[nc++] = i;
    }
    return m.m[rows[0]][cols[0]] * m.m[rows[1]][cols[1]]
         - m.m[rows[0]][cols[1]] * m.m[rows[1]][cols[0]];
}

double cofactor(Matrix3 m, int r, int c) {
    double d = minor(m, r, c);
    return ((r + c) % 2) ? -d : d;
}

double determinant(Matrix3 m) {
    return m.m[0][0] * cofactor(m, 0, 0)
         + m.m[0][1] * cofactor(m, 0, 1)
         + m.m[0][2] * cofactor(m, 0, 2);
}

bool is_invertible(Matrix3 m) { return determinant(m) != 0; }

/* cofactors, transposed, divided by the determinant. The transpose is the
   part everyone forgets, so it happens in the [c][r] on the left. */
Matrix3 inverse(Matrix3 m) {
    double d = determinant(m);
    Matrix3 r;
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++) r.m[j][i] = cofactor(m, i, j) / d;
    return r;
}

/* ---- the four transforms ----------------------------------------------- */
Matrix3 translation(double tx, double ty) { return matrix3(1, 0, tx, 0, 1, ty, 0, 0, 1); }
Matrix3 scaling(double sx, double sy)     { return matrix3(sx, 0, 0, 0, sy, 0, 0, 0, 1); }

/* A positive angle turns x toward y. On a canvas, where y points down,
   that is clockwise on the screen. The numbers do not care; you do. */
Matrix3 rotation(double r) {
    double c = cos(r), s = sin(r);
    return matrix3(c, -s, 0, s, c, 0, 0, 0, 1);
}

Matrix3 shearing(double xy, double yx) { return matrix3(1, xy, 0, yx, 1, 0, 0, 0, 1); }

/* The square root of the area factor: the uniform scale that would change
   area by the same amount. Exact for uniform scales and rotations, a
   compromise for stretches and shears, 0 for a collapsed matrix. */
double approx_scale(Matrix3 m) {
    return sqrt(fabs(m.m[0][0] * m.m[1][1] - m.m[0][1] * m.m[1][0]));
}

/* ---- shapes ----------------------------------------------------------- */
Shape circle(double cx, double cy, double r) {
    Shape s = {SHAPE_CIRCLE, cx, cy, r, 0, {{0}}, NULL, 0, NULL, {{{0}}}, NULL, 0};
    return s;
}
Shape rectangle(double x0, double y0, double x1, double y1) {
    Shape s = {SHAPE_RECTANGLE, x0, y0, x1, y1, {{0}}, NULL, 0, NULL, {{{0}}}, NULL, 0};
    return s;
}
Shape half_plane(double px, double py, double nx, double ny) {
    Shape s = {SHAPE_HALF_PLANE, px, py, nx, ny, {{0}}, NULL, 0, NULL, {{{0}}}, NULL, 0};
    return s;
}

/* A line is a very thin rectangle: four half-planes, all facing inward.
   The segment runs center to center, so (x0, y0) contributes its half pixel. */
static void set_half(double h[4], double px, double py, double nx, double ny) {
    h[0] = px; h[1] = py; h[2] = nx; h[3] = ny;
}

Shape segment(Tuple a_, Tuple b_, double width) {
    double ax = a_.x, ay = a_.y, bx = b_.x, by = b_.y;
    double dx = bx - ax, dy = by - ay;
    double len = sqrt(dx * dx + dy * dy);
    double half = width / 2;
    /* A line of no length has no direction to pick a normal from. Give it
       one anyway (dx, dy) = (1, 0), and push the two end caps out by half
       the width too, the same as the sides -- otherwise they meet at a
       single point and the "line" is a segment of zero area instead of
       the width-by-width square the reader would draw by hand. */
    double cap = 0;
    if (len == 0) { dx = 1; dy = 0; cap = half; } else { dx /= len; dy /= len; }
    double nx = -dy, ny = dx;          /* the unit normal */

    Shape s = {SHAPE_THICK_LINE, ax, ay, bx, by, {{0}}, NULL, 0, NULL, {{{0}}}, NULL, 0};
    set_half(s.h[0], ax - dx * cap, ay - dy * cap,  dx,  dy);        /* across the start */
    set_half(s.h[1], bx + dx * cap, by + dy * cap, -dx, -dy);        /* across the end */
    set_half(s.h[2], ax + nx * half, ay + ny * half, -nx, -ny);      /* one side */
    set_half(s.h[3], ax - nx * half, ay - ny * half,  nx,  ny);      /* the other */
    return s;
}

/* Chapter 3's line is a segment between two pixel centers. That is the
   whole of the refactor: the + 0.5 that used to live inside now lives
   here, where you can see it. */
Shape thick_line(double x0, double y0, double x1, double y1, double width) {
    return segment(point(x0 + 0.5, y0 + 0.5), point(x1 + 0.5, y1 + 0.5), width);
}

/* ---- composite shapes -------------------------------------------------- */
static Shape *shapes_copy(const Shape *src, int n) {
    Shape *dst = malloc((size_t)(n ? n : 1) * sizeof *dst);
    if (!dst) abort();
    for (int i = 0; i < n; i++) dst[i] = src[i];
    return dst;
}

Shape union_of(const Shape *parts, int n) {
    Shape s = {SHAPE_UNION, 0, 0, 0, 0, {{0}}, shapes_copy(parts, n), n, NULL, {{{0}}}, NULL, 0};
    return s;
}

/* A circle is a question, not a list of points. To ask it about a device
   point, send the point back through the inverse and ask the original.
   No inverse means the shape has been flattened away: nothing is inside. */
Shape transformed(Shape base, Matrix3 m) {
    if (!is_invertible(m)) {
        Shape e = {SHAPE_EMPTY, 0, 0, 0, 0, {{0}}, NULL, 0, NULL, {{{0}}}, NULL, 0};
        return e;
    }
    Shape s = {SHAPE_TRANSFORMED, 0, 0, 0, 0, {{0}}, NULL, 0, shapes_copy(&base, 1), inverse(m), NULL, 0};
    return s;
}

/* The points go through m first; every edge is then a segment of that
   width in device space. One shape, so a corner pixel is painted once. */
Shape outline(const Tuple *pts, int n, Matrix3 m, double width) {
    Tuple *t = malloc((size_t)(n ? n : 1) * sizeof *t);
    Shape *edges = malloc((size_t)(n ? n : 1) * sizeof *edges);
    if (!t || !edges) abort();
    transform_points(pts, n, m, t);
    for (int i = 0; i < n; i++) edges[i] = segment(t[i], t[(i + 1) % n], width);
    Shape s = union_of(edges, n);
    free(t); free(edges);
    return s;
}

void shape_free(Shape s) {
    if (s.kind == SHAPE_UNION) {
        for (int i = 0; i < s.nparts; i++) shape_free(s.parts[i]);
        free(s.parts);
    } else if (s.kind == SHAPE_TRANSFORMED) {
        shape_free(*s.base);
        free(s.base);
    } else if (s.kind == SHAPE_FILLED_PATH) {
        path_free(s.path);
    }
}

/* The supersampler asks this eight thousand times a pixel, so it walks
   pointers: a Shape is big and copying one per sample is not free. */
static bool inside_p(const Shape *s, double x, double y) {
    switch (s->kind) {
    case SHAPE_CIRCLE: {
        double dx = x - s->a, dy = y - s->b;
        return dx * dx + dy * dy <= s->c * s->c;          /* boundary included */
    }
    case SHAPE_RECTANGLE:
        return x >= s->a && x <= s->c && y >= s->b && y <= s->d;
    case SHAPE_HALF_PLANE:
        return (x - s->a) * s->c + (y - s->b) * s->d >= 0;  /* normal points inward */
    case SHAPE_THICK_LINE:
        /* inside all four half-planes, same test as above, written out so the
           supersampler isn't copying a Shape twenty million times */
        for (int i = 0; i < 4; i++) {
            const double *h = s->h[i];
            if ((x - h[0]) * h[2] + (y - h[1]) * h[3] < 0) return false;
        }
        return true;
    case SHAPE_UNION:
        for (int i = 0; i < s->nparts; i++)
            if (inside_p(&s->parts[i], x, y)) return true;   /* early exit */
        return false;
    case SHAPE_TRANSFORMED: {
        Tuple q = m3_mul_tuple(s->inv, point(x, y));
        return inside_p(s->base, q.x, q.y);
    }
    case SHAPE_EMPTY:
        return false;
    case SHAPE_FILLED_PATH: {
        int w = winding_at(s->path, x, y);
        return s->rule ? (w % 2) != 0 : w != 0;   /* rule: 0 nonzero, 1 evenodd */
    }
    }
    return false;
}

bool inside(Shape s, double x, double y) { return inside_p(&s, x, y); }

/* ---- the coverage buffer ---------------------------------------------- */
CoverageBuffer *coverage_buffer(int width, int height) {
    CoverageBuffer *cov = malloc(sizeof *cov);
    if (!cov) abort();
    cov->width = width;
    cov->height = height;
    cov->values = calloc((size_t)width * (size_t)height, sizeof *cov->values);
    if (!cov->values) abort();
    return cov;   /* calloc gives every pixel coverage 0 */
}

void coverage_free(CoverageBuffer *cov) { if (cov) { free(cov->values); free(cov); } }

void set_coverage(CoverageBuffer *cov, int x, int y, double v) {
    if (x < 0 || y < 0 || x >= cov->width || y >= cov->height) return;  /* dropped */
    cov->values[(size_t)y * cov->width + x] = v;
}

double coverage_at(const CoverageBuffer *cov, int x, int y) {
    if (x < 0 || y < 0 || x >= cov->width || y >= cov->height) return 0;
    return cov->values[(size_t)y * cov->width + x];
}

double ink(const CoverageBuffer *cov) {
    double total = 0;
    size_t n = (size_t)cov->width * cov->height;
    for (size_t i = 0; i < n; i++) total += cov->values[i];
    return total;
}

/* ---- the two questions ------------------------------------------------ */
/* Pixel (x, y) is the square from (x, y) to (x+1, y+1); its center is
   (x + 0.5, y + 0.5). Getting that half pixel wrong shifts every shape. */
double center_inside(Shape s, int x, int y) {
    return inside_p(&s, x + 0.5, y + 0.5) ? 1.0 : 0.0;
}

#define SAMPLES 8   /* an 8 by 8 grid of sample points inside each pixel */

double coverage(Shape s, int x, int y) {
    int n = 0;
    for (int j = 0; j < SAMPLES; j++)
        for (int i = 0; i < SAMPLES; i++)
            if (inside_p(&s, x + (i + 0.5) / SAMPLES, y + (j + 0.5) / SAMPLES)) n++;
    return (double)n / (SAMPLES * SAMPLES);
}

static CoverageBuffer *rasterize_with(Shape s, int w, int h, double (*ask)(Shape, int, int)) {
    CoverageBuffer *cov = coverage_buffer(w, h);
    for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++)
            set_coverage(cov, x, y, ask(s, x, y));
    return cov;
}

CoverageBuffer *rasterize_centers(Shape s, int w, int h) { return rasterize_with(s, w, h, center_inside); }
CoverageBuffer *rasterize(Shape s, int w, int h)         { return rasterize_with(s, w, h, coverage); }

/* the box is inclusive of every pixel it touches, and clipped to the
   buffer; the rest of the buffer is left at zero (coverage_buffer already
   calloc's it). */
CoverageBuffer *rasterize_within(Shape s, Bounds box, int w, int h) {
    CoverageBuffer *cov = coverage_buffer(w, h);
    int x0 = (int)floor(box.min_x), x1 = (int)ceil(box.max_x);
    int y0 = (int)floor(box.min_y), y1 = (int)ceil(box.max_y);
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 > w) x1 = w;
    if (y1 > h) y1 = h;
    for (int y = y0; y < y1; y++)
        for (int x = x0; x < x1; x++)
            set_coverage(cov, x, y, coverage(s, x, y));
    return cov;
}

/* ---- the one place the renderer touches the canvas -------------------- */
/* The browser-style switch exists so you can compare gradients against
   other tools; it has no business inside the rasterizer, so this forces
   the light's way regardless of what linear_blending is set to. */
void paint_through(Canvas *c, const CoverageBuffer *cov, Color col) {
    for (int y = 0; y < c->height; y++)
        for (int x = 0; x < c->width; x++)
            write_pixel(c, x, y, mix4(pixel_at(c, x, y), col, coverage_at(cov, x, y), true));
}

/* ---- the pictures ----------------------------------------------------- */
Canvas *gray_match(void) {
    Canvas *c = canvas(300, 100);
    for (int y = 0; y <= 99; y++)
        for (int x = 0; x <= 99; x++)
            write_pixel(c, x, y, ((x + y) % 2 == 0) ? color(1,1,1) : color(0,0,0));
    double g = decode(128.0 / 255.0);
    for (int y = 0; y <= 99; y++)
        for (int x = 100; x <= 199; x++)
            write_pixel(c, x, y, color(g, g, g));
    for (int y = 0; y <= 99; y++)
        for (int x = 200; x <= 299; x++)
            write_pixel(c, x, y, color(0.5, 0.5, 0.5));
    return c;
}

Canvas *quarter_match(void) {
    Canvas *c = canvas(200, 100);
    for (int y = 0; y <= 99; y++)
        for (int x = 0; x <= 99; x++)
            write_pixel(c, x, y, ((x + y) % 4 == 0) ? color(1,1,1) : color(0,0,0));
    for (int y = 0; y <= 99; y++)
        for (int x = 100; x <= 199; x++)
            write_pixel(c, x, y, color(0.25, 0.25, 0.25));
    return c;
}

Canvas *ramp(void) {
    Canvas *c = canvas(256, 32);
    for (int x = 0; x <= 255; x++) {
        double g = x / 255.0;
        for (int y = 0; y <= 31; y++) write_pixel(c, x, y, color(g, g, g));
    }
    return c;
}

Canvas *clamp_pair(void) {
    Canvas *c = canvas(200, 100);
    for (int y = 0; y <= 99; y++) {
        for (int x = 0; x <= 99; x++)   write_pixel(c, x, y, color(2, 0.5, 0.5));
        for (int x = 100; x <= 199; x++) write_pixel(c, x, y, color(1, 0.25, 0.25));
    }
    return c;
}

Canvas *plate_01(void) {
    Canvas *c = canvas(400, 180);
    Color ends[2][2] = {
        { {0, 0, 0},   {1, 1, 1} },
        { {0.7, 0, 0}, {0, 0.3, 0.02} }
    };
    for (int i = 0; i < 2; i++) {
        Color a = ends[i][0], b = ends[i][1];
        int top = i * 90;
        for (int x = 0; x <= 399; x++) {
            double t = x / 399.0;
            Color naive = mix4(a, b, t, false);   /* the browser's way */
            Color light = mix4(a, b, t, true);    /* the light's way */
            for (int y = top; y <= top + 39; y++)      write_pixel(c, x, y, naive);
            for (int y = top + 45; y <= top + 84; y++) write_pixel(c, x, y, light);
        }
    }
    return c;
}


/* ---- chapter 2's pictures --------------------------------------------- */
static const Color PAPER = {0.02, 0.02, 0.025};
static const Color INK   = {0.9, 0.55, 0.1};

static Canvas *disc(bool by_coverage) {
    Canvas *c = canvas(40, 40);
    fill(c, PAPER);
    Shape s = circle(20, 20, 16);
    CoverageBuffer *cov = by_coverage ? rasterize(s, 40, 40) : rasterize_centers(s, 40, 40);
    paint_through(c, cov, INK);
    coverage_free(cov);
    Canvas *m = magnify(c, 8);
    canvas_free(c);
    return m;
}

Canvas *disc_centers(void)  { return disc(false); }
Canvas *disc_coverage(void) { return disc(true); }

Canvas *painted_twice(void) {
    Canvas *c = canvas(80, 40);
    fill(c, PAPER);
    CoverageBuffer *cov = rasterize(circle(20, 20, 16), 40, 40);

    CoverageBuffer *once = coverage_buffer(80, 40);   /* the disc in both halves */
    for (int y = 0; y <= 39; y++)
        for (int x = 0; x <= 39; x++) {
            set_coverage(once, x, y, coverage_at(cov, x, y));
            set_coverage(once, x + 40, y, coverage_at(cov, x, y));
        }
    paint_through(c, once, INK);

    CoverageBuffer *twice = coverage_buffer(80, 40);  /* the right half again */
    for (int y = 0; y <= 39; y++)
        for (int x = 0; x <= 39; x++)
            set_coverage(twice, x + 40, y, coverage_at(cov, x, y));
    paint_through(c, twice, INK);

    coverage_free(cov); coverage_free(once); coverage_free(twice);
    Canvas *m = magnify(c, 6);
    canvas_free(c);
    return m;
}

Canvas *plate_02(void) {
    Canvas *c = canvas(80, 40);
    fill(c, PAPER);
    Shape shape = circle(20, 20, 16);
    CoverageBuffer *left  = rasterize_centers(shape, 40, 40);
    CoverageBuffer *right = rasterize(shape, 40, 40);

    CoverageBuffer *both = coverage_buffer(80, 40);
    for (int y = 0; y <= 39; y++)
        for (int x = 0; x <= 39; x++) {
            set_coverage(both, x, y, coverage_at(left, x, y));
            set_coverage(both, x + 40, y, coverage_at(right, x, y));
        }
    paint_through(c, both, INK);

    coverage_free(left); coverage_free(right); coverage_free(both);
    Canvas *m = magnify(c, 6);
    canvas_free(c);
    return m;
}


/* ---- chapter 3: lines -------------------------------------------------- */
/* Bresenham 1962: one pixel per step along the longer axis, integer only.
   err starts at dx/2 with integer division, so an exact half stays put. */
void line_bresenham(Canvas *c, int x0, int y0, int x1, int y1, Color col) {
    int steep = abs(y1 - y0) > abs(x1 - x0);
    if (steep) { int t; t = x0; x0 = y0; y0 = t; t = x1; x1 = y1; y1 = t; }
    if (x0 > x1) { int t; t = x0; x0 = x1; x1 = t; t = y0; y0 = y1; y1 = t; }

    int dx = x1 - x0;
    int dy = abs(y1 - y0);
    int ystep = y0 < y1 ? 1 : -1;
    int err = dx / 2;
    int y = y0;

    for (int x = x0; x <= x1; x++) {
        if (steep) write_pixel(c, y, x, col);
        else       write_pixel(c, x, y, col);
        err -= dy;
        if (err < 0) { y += ystep; err += dx; }
    }
}

/* paint_through for a single pixel. Like paint_through, this ignores the
   browser-style switch and always blends in light: the switch is for
   comparing gradients against other tools, and has no business inside
   the rasterizer. */
void plot(Canvas *c, int x, int y, Color col, double weight) {
    if (weight == 0) return;
    if (x < 0 || y < 0 || x >= c->width || y >= c->height) return;
    write_pixel(c, x, y, mix4(pixel_at(c, x, y), col, weight, true));
}

/* Wu 1991: the same walk, but each step splits its paint between the two
   pixels the ideal line falls between. Integer endpoints only. */
void line_wu(Canvas *c, int x0, int y0, int x1, int y1, Color col) {
    int steep = abs(y1 - y0) > abs(x1 - x0);
    if (steep) { int t; t = x0; x0 = y0; y0 = t; t = x1; x1 = y1; y1 = t; }
    if (x0 > x1) { int t; t = x0; x0 = x1; x1 = t; t = y0; y0 = y1; y1 = t; }

    int dx = x1 - x0;
    double slope = dx == 0 ? 0.0 : (double)(y1 - y0) / dx;

    for (int x = x0; x <= x1; x++) {
        double y = y0 + (x - x0) * slope;
        double yi = floor(y);
        double f = y - yi;
        int iy = (int)yi;
        if (steep) { plot(c, iy, x, col, 1 - f); plot(c, iy + 1, x, col, f); }
        else       { plot(c, x, iy, col, 1 - f); plot(c, x, iy + 1, col, f); }
    }
}

/* ---- the fan ----------------------------------------------------------- */

static const Color FAN_PAPER = {0.02, 0.02, 0.025};
static const Color FAN_INK   = {0.92, 0.92, 0.88};

void ray_ends(int out[12][2]) {
    for (int k = 0; k < 12; k++) {
        double a = k * 30.0 * PI / 180.0;
        out[k][0] = (int)lround(80 + 72 * cos(a));
        out[k][1] = (int)lround(80 + 72 * sin(a));
    }
}

static Canvas *fan(void (*draw)(Canvas *, int, int, int, int, Color)) {
    Canvas *c = canvas(160, 160);
    fill(c, FAN_PAPER);
    int ends[12][2];
    ray_ends(ends);
    for (int k = 0; k < 12; k++) draw(c, 80, 80, ends[k][0], ends[k][1], FAN_INK);
    return c;
}

Canvas *fan_bresenham(void) { return fan(line_bresenham); }
Canvas *fan_wu(void)        { return fan(line_wu); }

Canvas *fan_coverage(void) {
    Canvas *c = canvas(160, 160);
    fill(c, FAN_PAPER);
    int ends[12][2];
    ray_ends(ends);
    for (int k = 0; k < 12; k++) {
        CoverageBuffer *cov = rasterize(thick_line(80, 80, ends[k][0], ends[k][1], 1), 160, 160);
        paint_through(c, cov, FAN_INK);
        coverage_free(cov);
    }
    Canvas *m = magnify(c, 2);
    canvas_free(c);
    return m;
}

Canvas *plate_03(void) {
    Canvas *both = canvas(320, 160);
    Canvas *a = fan_bresenham();
    Canvas *b = fan_wu();
    for (int y = 0; y <= 159; y++)
        for (int x = 0; x <= 159; x++) {
            write_pixel(both, x,       y, pixel_at(a, x, y));
            write_pixel(both, x + 160, y, pixel_at(b, x, y));
        }
    canvas_free(a); canvas_free(b);
    Canvas *m = magnify(both, 2);
    canvas_free(both);
    return m;
}


/* ---- chapter 4: transforms --------------------------------------------- */
void transform_points(const Tuple *in, int n, Matrix3 m, Tuple *out) {
    for (int i = 0; i < n; i++) out[i] = m3_mul_tuple(m, in[i]);
}

Canvas *canvas_copy(const Canvas *c) {
    Canvas *d = canvas(c->width, c->height);
    for (int y = 0; y < c->height; y++)
        for (int x = 0; x < c->width; x++) write_pixel(d, x, y, pixel_at(c, x, y));
    return d;
}

/* a into the left half of a wider canvas, b into the right */
Canvas *side_by_side(const Canvas *a, const Canvas *b) {
    Canvas *both = canvas(a->width + b->width, a->height);
    for (int y = 0; y < a->height; y++) {
        for (int x = 0; x < a->width; x++) write_pixel(both, x, y, pixel_at(a, x, y));
        for (int x = 0; x < b->width; x++) write_pixel(both, a->width + x, y, pixel_at(b, x, y));
    }
    return both;
}

/* the center, then twelve ends at radius 36, one every 30 degrees */
int fan_points(Tuple *out) {
    out[0] = point(0, 0);
    for (int k = 0; k <= 11; k++) {
        double a = k * 30.0 * PI / 180.0;
        out[k + 1] = point(36 * cos(a), 36 * sin(a));
    }
    return FAN_POINTS;
}

/* ten corners, clockwise from the top left, in a box 40 by 60 centered on
   the origin, so a rotation about the origin turns the letter in place */
int letter_f(Tuple *out) {
    static const double xy[LETTER_F_POINTS][2] = {
        {-20, -30}, {20, -30}, {20, -20}, {-10, -20},
        {-10,  -5}, {12,  -5}, {12,   5}, {-10,   5},
        {-10,  30}, {-20, 30}
    };
    for (int i = 0; i < LETTER_F_POINTS; i++) out[i] = point(xy[i][0], xy[i][1]);
    return LETTER_F_POINTS;
}

Canvas *fan_transformed(Matrix3 m) {
    Canvas *c = canvas(160, 160);
    fill(c, FAN_PAPER);

    Tuple pts[FAN_POINTS], t[FAN_POINTS];
    int n = fan_points(pts);
    transform_points(pts, n, m, t);

    Shape rays[FAN_POINTS - 1];
    for (int k = 1; k < n; k++) rays[k - 1] = segment(t[0], t[k], 1);
    Shape s = union_of(rays, n - 1);

    CoverageBuffer *cov = rasterize(s, 160, 160);
    paint_through(c, cov, FAN_INK);
    coverage_free(cov);
    shape_free(s);
    return c;
}

Canvas *fan_both_orders(void) {
    Matrix3 turn = rotation(PI / 6);
    Matrix3 move = translation(104.5, 76.5);
    Canvas *a = fan_transformed(m3_mul(move, turn));
    Canvas *b = fan_transformed(m3_mul(turn, move));
    Canvas *both = side_by_side(a, b);
    canvas_free(a); canvas_free(b);
    return both;
}

/* The F through both orders, over a dim copy of where it started. */
Canvas *f_both_orders(void) {
    Matrix3 turn = rotation(PI / 6);
    Matrix3 move = translation(104.5, 76.5);
    Matrix3 home = translation(44.5, 44.5);
    Color ink_col = color(0.92, 0.92, 0.88);
    Color dim     = color(0.16, 0.16, 0.17);

    Tuple f[LETTER_F_POINTS];
    int n = letter_f(f);

    Canvas *ghost = canvas(160, 160);
    fill(ghost, color(0.02, 0.02, 0.025));
    Shape g = outline(f, n, home, 1);
    CoverageBuffer *gc = rasterize(g, 160, 160);
    paint_through(ghost, gc, dim);
    coverage_free(gc); shape_free(g);

    Canvas *a = canvas_copy(ghost);
    Canvas *b = canvas_copy(ghost);

    Shape sa = outline(f, n, m3_mul(move, turn), 1);
    CoverageBuffer *ca = rasterize(sa, 160, 160);
    paint_through(a, ca, ink_col);
    coverage_free(ca); shape_free(sa);

    Shape sb = outline(f, n, m3_mul(turn, move), 1);
    CoverageBuffer *cb = rasterize(sb, 160, 160);
    paint_through(b, cb, ink_col);
    coverage_free(cb); shape_free(sb);

    Canvas *both = side_by_side(a, b);
    canvas_free(ghost); canvas_free(a); canvas_free(b);
    return both;
}

Canvas *plate_04(void) {
    Canvas *f = f_both_orders();
    Canvas *m = magnify(f, 2);
    canvas_free(f);
    return m;
}


/* ---- chapter 5: paths and insideness ------------------------------------ */
static void subpath_push_point(Subpath *sp, Tuple pt) {
    if (sp->n == sp->cap) {
        sp->cap = sp->cap ? sp->cap * 2 : 4;
        sp->points = realloc(sp->points, (size_t)sp->cap * sizeof *sp->points);
        if (!sp->points) abort();
    }
    sp->points[sp->n++] = pt;
}

static Subpath *path_push_subpath(Path *p) {
    if (p->n_subpaths == p->cap_subpaths) {
        p->cap_subpaths = p->cap_subpaths ? p->cap_subpaths * 2 : 4;
        p->subpaths = realloc(p->subpaths, (size_t)p->cap_subpaths * sizeof *p->subpaths);
        if (!p->subpaths) abort();
    }
    Subpath *sp = &p->subpaths[p->n_subpaths++];
    sp->points = NULL; sp->n = 0; sp->cap = 0; sp->closed = false;
    return sp;
}

Path *path(void) {
    Path *p = malloc(sizeof *p);
    if (!p) abort();
    p->subpaths = NULL; p->n_subpaths = 0; p->cap_subpaths = 0;
    return p;
}

void path_free(Path *p) {
    if (!p) return;
    for (int i = 0; i < p->n_subpaths; i++) free(p->subpaths[i].points);
    free(p->subpaths);
    free(p);
}

void move_to(Path *p, Tuple pt) {
    Subpath *sp = path_push_subpath(p);
    subpath_push_point(sp, pt);
}

/* With nothing to extend, behaves as move_to. After a close, starts a new
   subpath at the point the closed one began -- that's where the pen was
   last put down, and PostScript and SVG both do this. */
void line_to(Path *p, Tuple pt) {
    if (p->n_subpaths == 0) { move_to(p, pt); return; }
    Subpath *last = &p->subpaths[p->n_subpaths - 1];
    if (last->closed) {
        Tuple start = last->points[0];
        Subpath *sp = path_push_subpath(p);
        subpath_push_point(sp, start);
        subpath_push_point(sp, pt);
        return;
    }
    subpath_push_point(last, pt);
}

/* Nothing to close does nothing; closing twice is the same as once. */
void close(Path *p) {
    if (p->n_subpaths == 0) return;
    p->subpaths[p->n_subpaths - 1].closed = true;
}

/* Every subpath contributes the edge from its last point back to its
   first, whether or not it was actually closed -- filling closes every
   subpath itself. A subpath of one point contributes no edges. */
Edge *edges(const Path *p, int *out_n) {
    int total = 0;
    for (int i = 0; i < p->n_subpaths; i++)
        if (p->subpaths[i].n >= 2) total += p->subpaths[i].n;
    Edge *e = malloc((size_t)(total ? total : 1) * sizeof *e);
    if (!e) abort();
    int k = 0;
    for (int i = 0; i < p->n_subpaths; i++) {
        Subpath *sp = &p->subpaths[i];
        if (sp->n < 2) continue;
        for (int j = 0; j < sp->n; j++) {
            e[k].a = sp->points[j];
            e[k].b = sp->points[(j + 1) % sp->n];
            k++;
        }
    }
    *out_n = total;
    return e;
}

Bounds bounds(const Path *p) {
    Bounds b = {0, 0, 0, 0};
    bool any = false;
    for (int i = 0; i < p->n_subpaths; i++) {
        Subpath *sp = &p->subpaths[i];
        for (int j = 0; j < sp->n; j++) {
            Tuple t = sp->points[j];
            if (!any) { b.min_x = b.max_x = t.x; b.min_y = b.max_y = t.y; any = true; continue; }
            if (t.x < b.min_x) b.min_x = t.x;
            if (t.x > b.max_x) b.max_x = t.x;
            if (t.y < b.min_y) b.min_y = t.y;
            if (t.y > b.max_y) b.max_y = t.y;
        }
    }
    return b;
}

Path *polygon_pts(const Tuple *pts, int n) {
    Path *p = path();
    if (n > 0) {
        move_to(p, pts[0]);
        for (int i = 1; i < n; i++) line_to(p, pts[i]);
        close(p);
    }
    return p;
}

Path *circle_path(double cx, double cy, double r, int n) {
    Path *p = path();
    for (int k = 0; k < n; k++) {
        double a = k * 2.0 * PI / n;
        Tuple q = point(cx + r * cos(a), cy + r * sin(a));
        if (k == 0) move_to(p, q); else line_to(p, q);
    }
    close(p);
    return p;
}

/* Neither of these materializes edges(): they walk each subpath's points
   with wraparound directly, because coverage() calls winding_at() up to
   sixty-four times a pixel and a path only has a handful of edges. */
int crossings(const Path *p, double x, double y) {
    int count = 0;
    for (int i = 0; i < p->n_subpaths; i++) {
        Subpath *sp = &p->subpaths[i];
        if (sp->n < 2) continue;
        for (int j = 0; j < sp->n; j++) {
            Tuple a = sp->points[j], b = sp->points[(j + 1) % sp->n];
            bool spans = (a.y <= y && y < b.y) || (b.y <= y && y < a.y);
            if (!spans) continue;
            double t = (y - a.y) / (b.y - a.y);
            if (a.x + t * (b.x - a.x) > x) count++;
        }
    }
    return count;
}

int winding_at(const Path *p, double x, double y) {
    Tuple q = point(x, y);
    int w = 0;
    for (int i = 0; i < p->n_subpaths; i++) {
        Subpath *sp = &p->subpaths[i];
        if (sp->n < 2) continue;
        for (int j = 0; j < sp->n; j++) {
            Tuple a = sp->points[j], b = sp->points[(j + 1) % sp->n];
            if (a.y <= y) {
                if (b.y > y && cross(tuple_sub(b, a), tuple_sub(q, a)) > 0) w++;
            } else {
                if (b.y <= y && cross(tuple_sub(b, a), tuple_sub(q, a)) < 0) w--;
            }
        }
    }
    return w;
}

bool inside_nonzero(const Path *p, double x, double y) { return winding_at(p, x, y) != 0; }
bool inside_evenodd(const Path *p, double x, double y) { return (winding_at(p, x, y) % 2) != 0; }

static Path *path_copy(const Path *src) {
    Path *p = path();
    for (int i = 0; i < src->n_subpaths; i++) {
        Subpath *s = &src->subpaths[i];
        Subpath *d = path_push_subpath(p);
        for (int j = 0; j < s->n; j++) subpath_push_point(d, s->points[j]);
        d->closed = s->closed;
    }
    return p;
}

Shape filled(const Path *p, const char *rule) {
    int r = (strcmp(rule, "evenodd") == 0) ? 1 : 0;
    Shape s = {SHAPE_FILLED_PATH, 0, 0, 0, 0, {{0}}, NULL, 0, NULL, {{{0}}}, path_copy(p), r};
    return s;
}

/* five points on a circle of radius 70 about (80.5, 80.5), the first
   straight up, visited every second one so the pen crosses itself */
Path *star(void) {
    Path *p = path();
    for (int k = 0; k < 5; k++) {
        double a = (-90.0 + 144.0 * k) * PI / 180.0;
        Tuple q = point(80.5 + 70 * cos(a), 80.5 + 70 * sin(a));
        if (k == 0) move_to(p, q); else line_to(p, q);
    }
    close(p);
    return p;
}

Canvas *star_panel(const char *rule, const char *method) {
    Canvas *c = canvas(160, 160);
    fill(c, color(0.02, 0.02, 0.025));
    Path *s_path = star();
    Shape s = filled(s_path, rule);
    CoverageBuffer *cov;
    if (strcmp(method, "centers") == 0) {
        cov = rasterize_centers(s, 160, 160);
    } else {
        Path *b_path = star();
        Bounds b = bounds(b_path);
        path_free(b_path);
        cov = rasterize_within(s, b, 160, 160);
    }
    paint_through(c, cov, color(0.9, 0.55, 0.1));
    coverage_free(cov);
    shape_free(s);
    path_free(s_path);
    return c;
}

Canvas *star_centers(void) {
    Canvas *a = star_panel("nonzero", "centers");
    Canvas *b = star_panel("evenodd", "centers");
    Canvas *both = side_by_side(a, b);
    canvas_free(a); canvas_free(b);
    return both;
}

Canvas *star_coverage(void) {
    Canvas *a = star_panel("nonzero", "coverage");
    Canvas *b = star_panel("evenodd", "coverage");
    Canvas *both = side_by_side(a, b);
    canvas_free(a); canvas_free(b);
    return both;
}

Canvas *plate_05(void) {
    Canvas *top = star_centers();
    Canvas *bottom = star_coverage();
    Canvas *both = canvas(320, 320);
    for (int y = 0; y <= 159; y++)
        for (int x = 0; x <= 319; x++) {
            write_pixel(both, x, y,       pixel_at(top, x, y));
            write_pixel(both, x, y + 160, pixel_at(bottom, x, y));
        }
    canvas_free(top); canvas_free(bottom);
    Canvas *m = magnify(both, 2);
    canvas_free(both);
    return m;
}


/* ---- chapter 6: filling a polygon --------------------------------------- */
static int cmp_edge_entry(const void *pa, const void *pb) {
    const EdgeEntry *a = pa, *b = pb;
    if (a->y_top < b->y_top) return -1;
    if (a->y_top > b->y_top) return 1;
    if (a->x_top < b->x_top) return -1;
    if (a->x_top > b->x_top) return 1;
    return 0;
}

static int cmp_crossing(const void *pa, const void *pb) {
    const Crossing *a = pa, *b = pb;
    if (a->x < b->x) return -1;
    if (a->x > b->x) return 1;
    return 0;
}

double x_at(EdgeEntry e, double y) { return e.x_top + (y - e.y_top) * e.slope; }

/* "Horizontal" means a.y == b.y exactly: no clamping, no slope of zero
   kept around, dropped, the same rule chapter 5's half-open crossing
   test already applies, here for a second reason -- the slope would be a
   division by zero. */
EdgeEntry *edge_table(const Path *p, int *out_n) {
    int en; Edge *e = edges(p, &en);
    EdgeEntry *t = malloc((size_t)(en ? en : 1) * sizeof *t);
    if (!t) abort();
    int k = 0;
    for (int i = 0; i < en; i++) {
        Tuple a = e[i].a, b = e[i].b;
        if (a.y == b.y) continue;
        EdgeEntry te;
        if (a.y < b.y) {
            te.y_top = a.y; te.y_bottom = b.y; te.x_top = a.x;
            te.slope = (b.x - a.x) / (b.y - a.y);
            te.direction = 1;
        } else {
            te.y_top = b.y; te.y_bottom = a.y; te.x_top = b.x;
            te.slope = (a.x - b.x) / (a.y - b.y);
            te.direction = -1;
        }
        t[k++] = te;
    }
    free(e);
    qsort(t, (size_t)k, sizeof *t, cmp_edge_entry);
    *out_n = k;
    return t;
}

Crossing *crossings_on_row(const EdgeEntry *t, int n, double y, int *out_n) {
    Crossing *c = malloc((size_t)(n ? n : 1) * sizeof *c);
    if (!c) abort();
    int k = 0;
    for (int i = 0; i < n; i++) {
        if (t[i].y_top <= y && y < t[i].y_bottom) {
            c[k].x = x_at(t[i], y);
            c[k].direction = t[i].direction;
            k++;
        }
    }
    qsort(c, (size_t)k, sizeof *c, cmp_crossing);
    *out_n = k;
    return c;
}

Span *spans_from_crossings(const Crossing *xs, int n, const char *rule, int *out_n) {
    bool evenodd = strcmp(rule, "evenodd") == 0;
    Span *out = malloc((size_t)(n ? n : 1) * sizeof *out);
    if (!out) abort();
    int k = 0, w = 0;
    bool inside = false;
    double start = 0;
    for (int i = 0; i < n; i++) {
        w += xs[i].direction;
        bool now = evenodd ? (w % 2) != 0 : w != 0;
        if (now && !inside) { start = xs[i].x; inside = true; }
        else if (!now && inside) { out[k].x0 = start; out[k].x1 = xs[i].x; k++; inside = false; }
    }
    *out_n = k;
    return out;
}

Span *spans(const Path *p, const char *rule, int row, int *out_n) {
    int tn; EdgeEntry *t = edge_table(p, &tn);
    int xn; Crossing *xs = crossings_on_row(t, tn, row + 0.5, &xn);
    Span *s = spans_from_crossings(xs, xn, rule, out_n);
    free(xs); free(t);
    return s;
}

/* half-open at the right end, so two spans that meet at a pixel center
   fill that pixel exactly once. */
void fill_span(CoverageBuffer *cov, int row, double x0, double x1) {
    int first = (int)ceil(x0 - 0.5);
    int last  = (int)ceil(x1 - 0.5) - 1;
    if (first < 0) first = 0;
    if (last > cov->width - 1) last = cov->width - 1;
    for (int x = first; x <= last; x++) set_coverage(cov, x, row, 1);
}

/* The active edge list: the table is read once, front to back, and every
   row touches only the edges that cross it. An edge that starts exactly
   on a sample height is active there; one that ends there is not -- the
   half-open rule again, this time between rows. */
CoverageBuffer *fill_path_aliased(const Path *p, const char *rule, int w, int h) {
    CoverageBuffer *cov = coverage_buffer(w, h);
    int tn; EdgeEntry *table = edge_table(p, &tn);
    EdgeEntry *active = malloc((size_t)(tn ? tn : 1) * sizeof *active);
    if (!active) abort();
    int nactive = 0, next = 0;

    for (int row = 0; row < h; row++) {
        double y = row + 0.5;
        while (next < tn && table[next].y_top <= y) active[nactive++] = table[next++];
        int k = 0;
        for (int i = 0; i < nactive; i++)
            if (active[i].y_bottom > y) active[k++] = active[i];
        nactive = k;

        Crossing *xs = malloc((size_t)(nactive ? nactive : 1) * sizeof *xs);
        if (!xs) abort();
        for (int i = 0; i < nactive; i++) {
            xs[i].x = x_at(active[i], y);
            xs[i].direction = active[i].direction;
        }
        qsort(xs, (size_t)nactive, sizeof *xs, cmp_crossing);

        int sn; Span *sp = spans_from_crossings(xs, nactive, rule, &sn);
        for (int i = 0; i < sn; i++) fill_span(cov, row, sp[i].x0, sp[i].x1);
        free(xs); free(sp);
    }
    free(active); free(table);
    return cov;
}

double max_coverage_difference(const CoverageBuffer *a, const CoverageBuffer *b) {
    if (a->width != b->width || a->height != b->height) return 1;
    double worst = 0;
    size_t n = (size_t)a->width * a->height;
    for (size_t i = 0; i < n; i++) {
        double d = fabs(a->values[i] - b->values[i]);
        if (d > worst) worst = d;
    }
    return worst;
}

Path *transform_path(const Path *p, Matrix3 m) {
    Path *q = path();
    for (int i = 0; i < p->n_subpaths; i++) {
        Subpath *sp = &p->subpaths[i];
        Subpath *d = path_push_subpath(q);
        for (int j = 0; j < sp->n; j++) subpath_push_point(d, m3_mul_tuple(m, sp->points[j]));
        d->closed = sp->closed;
    }
    return q;
}

/* ---- chapter 6: putting it together -------------------------------------- */
Path *unit_star(void) {
    Path *s = star();
    Path *u = transform_path(s, mul(scaling(1.0 / 70, 1.0 / 70), translation(-80.5, -80.5)));
    path_free(s);
    return u;
}

Canvas *spiral(void) {
    Canvas *c = canvas(320, 320);
    fill(c, color(0.02, 0.02, 0.025));
    Color inks[3] = { color(0.9, 0.55, 0.1), color(0.2, 0.55, 0.85), color(0.85, 0.25, 0.3) };
    Path *u = unit_star();
    for (int k = 0; k < 24; k++) {
        double a = k * 25.0 * PI / 180.0;
        double r = 20 + 5 * k;
        double s = 6 + 1.25 * k;
        Matrix3 m = mul(translation(160.5 + r * cos(a), 160.5 + r * sin(a)),
                        mul(rotation(a), scaling(s, s)));
        Path *t = transform_path(u, m);
        CoverageBuffer *cov = fill_path_aliased(t, "nonzero", 320, 320);
        paint_through(c, cov, inks[k % 3]);
        coverage_free(cov);
        path_free(t);
    }
    path_free(u);
    return c;
}

Canvas *plate_06(void) {
    Canvas *s = spiral();
    Canvas *m = magnify(s, 2);
    canvas_free(s);
    return m;
}
