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

char *read_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "read_file: cannot open %s\n", path); return NULL; }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *s = malloc((size_t)n + 1);
    if (!s) abort();
    size_t got = fread(s, 1, (size_t)n, f);
    s[got] = '\0';
    fclose(f);
    return s;
}

static int isspace_like(char ch) {
    return ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r' || ch == '\v' || ch == '\f';
}

/* split on whitespace; returns the numbers after the four header tokens */
static int *ppm_numbers(const char *ppm, int *count, int *width) {
    int cap = 256, n = 0, tok = 0;
    int *v = malloc((size_t)cap * sizeof *v);
    if (!v) abort();
    if (width) *width = 0;
    const char *p = ppm;
    while (*p) {
        while (*p && isspace_like(*p)) p++;
        if (!*p) break;
        const char *start = p;
        while (*p && !isspace_like(*p)) p++;
        tok++;
        if (tok == 2 && width) *width = atoi(start);
        if (tok <= 4) continue;            /* P3, width, height, maxval */
        if (n == cap) { cap *= 2; v = realloc(v, (size_t)cap * sizeof *v); if (!v) abort(); }
        v[n++] = atoi(start);
    }
    *count = n;
    return v;
}

void ppm_pixel(const char *ppm, int x, int y, int out[3]) {
    int n, w;
    int *v = ppm_numbers(ppm, &n, &w);
    long i = ((long)y * w + x) * 3;
    if (i < 0 || i + 2 >= n) { out[0] = out[1] = out[2] = -1; }
    else { out[0] = v[i]; out[1] = v[i+1]; out[2] = v[i+2]; }
    free(v);
}

int max_channel_difference(const char *a, const char *b) {
    int na, nb, wa, wb;
    int *va = ppm_numbers(a, &na, &wa);
    int *vb = ppm_numbers(b, &nb, &wb);
    int n = na < nb ? na : nb;
    int worst = (na == nb) ? 0 : 255;   /* different sizes: not comparable */
    for (int i = 0; i < n; i++) {
        int d = va[i] - vb[i];
        if (d < 0) d = -d;
        if (d > worst) worst = d;
    }
    free(va); free(vb);
    return worst;
}

int distinct_values(const char *ppm) {
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
