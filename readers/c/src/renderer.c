#include "renderer.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

static double mix1(double a, double b, double t) {
    if (linear_blending) return a + (b - a) * t;
    double ea = encode(a), eb = encode(b);
    return decode(ea + (eb - ea) * t);
}

Color mix(Color a, Color b, double t) {
    return color(mix1(a.red, b.red, t),
                 mix1(a.green, b.green, t),
                 mix1(a.blue, b.blue, t));
}

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

/* ---- shapes ----------------------------------------------------------- */
Shape circle(double cx, double cy, double r) {
    Shape s = {SHAPE_CIRCLE, cx, cy, r, 0};
    return s;
}
Shape rectangle(double x0, double y0, double x1, double y1) {
    Shape s = {SHAPE_RECTANGLE, x0, y0, x1, y1};
    return s;
}
Shape half_plane(double px, double py, double nx, double ny) {
    Shape s = {SHAPE_HALF_PLANE, px, py, nx, ny};
    return s;
}

bool inside(Shape s, double x, double y) {
    switch (s.kind) {
    case SHAPE_CIRCLE: {
        double dx = x - s.a, dy = y - s.b;
        return dx * dx + dy * dy <= s.c * s.c;          /* boundary included */
    }
    case SHAPE_RECTANGLE:
        return x >= s.a && x <= s.c && y >= s.b && y <= s.d;
    case SHAPE_HALF_PLANE:
        return (x - s.a) * s.c + (y - s.b) * s.d >= 0;  /* normal points inward */
    }
    return false;
}

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
    return inside(s, x + 0.5, y + 0.5) ? 1.0 : 0.0;
}

#define SAMPLES 8   /* an 8 by 8 grid of sample points inside each pixel */

double coverage(Shape s, int x, int y) {
    int n = 0;
    for (int j = 0; j < SAMPLES; j++)
        for (int i = 0; i < SAMPLES; i++)
            if (inside(s, x + (i + 0.5) / SAMPLES, y + (j + 0.5) / SAMPLES)) n++;
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

/* ---- the one place the renderer touches the canvas -------------------- */
void paint_through(Canvas *c, const CoverageBuffer *cov, Color col) {
    for (int y = 0; y < c->height; y++)
        for (int x = 0; x < c->width; x++)
            write_pixel(c, x, y, mix(pixel_at(c, x, y), col, coverage_at(cov, x, y)));
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
            linear_blending = false;
            Color naive = mix(a, b, t);
            linear_blending = true;
            Color light = mix(a, b, t);
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
