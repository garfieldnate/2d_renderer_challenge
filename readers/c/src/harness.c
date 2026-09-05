#include "harness.h"
#include <stdarg.h>
#include <stdlib.h>

int h_total = 0, h_failed = 0, h_fail_here = 0;
const char *h_name = "";
static const char *h_feature = "";

void h_begin(const char *feature, const char *name) {
    h_feature = feature; h_name = name; h_fail_here = 0; h_total++;
    linear_blending = true;   /* every scenario that doesn't say otherwise expects it on */
}

void h_end(void) {
    if (h_fail_here) h_failed++;
    linear_blending = true;
}

void h_fail(const char *fmt, ...) {
    if (!h_fail_here) printf("FAIL  %s / %s\n", h_feature, h_name);
    h_fail_here++;
    va_list ap; va_start(ap, fmt);
    printf("        ");
    vprintf(fmt, ap);
    printf("\n");
    va_end(ap);
}

static int h_mark_total = 0, h_mark_failed = 0;

void h_subtotal(const char *label) {
    int t = h_total - h_mark_total, f = h_failed - h_mark_failed;
    printf("%s: %d scenarios, %d passed, %d failed\n", label, t, t - f, f);
    h_mark_total = h_total; h_mark_failed = h_failed;
}

void h_report(void) {
    printf("\n%d scenarios, %d passed, %d failed\n", h_total, h_total - h_failed, h_failed);
}

void h_eq(const char *what, double a, double b, double eps) {
    if (!(fabs(a - b) <= eps)) h_fail("%s: got %.10g, wanted %.10g (tolerance %g)", what, a, b, eps);
}
void h_ne(const char *what, double a, double b, double eps) {
    if (fabs(a - b) <= eps) h_fail("%s: %.10g and %.10g are within %g", what, a, b, eps);
}
void h_eqi(const char *what, long a, long b) {
    if (a != b) h_fail("%s: got %ld, wanted %ld", what, a, b);
}
void h_lei(const char *what, long a, long b) {
    if (a > b) h_fail("%s: got %ld, wanted at most %ld", what, a, b);
}
void h_true(const char *what, int ok) {
    if (!ok) h_fail("%s: false", what);
}
static int ceq(Color a, Color b, double eps) {
    return fabs(a.red - b.red) <= eps && fabs(a.green - b.green) <= eps && fabs(a.blue - b.blue) <= eps;
}
void h_eqc(const char *what, Color a, Color b, double eps) {
    if (!ceq(a, b, eps)) h_fail("%s: got (%.6g, %.6g, %.6g), wanted (%.6g, %.6g, %.6g)",
                                what, a.red, a.green, a.blue, b.red, b.green, b.blue);
}
void h_nec(const char *what, Color a, Color b, double eps) {
    if (ceq(a, b, eps)) h_fail("%s: (%.6g, %.6g, %.6g) equals (%.6g, %.6g, %.6g)",
                               what, a.red, a.green, a.blue, b.red, b.green, b.blue);
}
void h_eqp(Bytes ppm, int x, int y, int r, int g, int b, int tol) {
    int got[3];
    ppm_pixel(ppm, x, y, got);
    int want[3] = {r, g, b};
    for (int i = 0; i < 3; i++) {
        int d = got[i] - want[i];
        if (d < 0) d = -d;
        if (d > tol) {
            h_fail("ppm_pixel(ppm, %d, %d) = (%d, %d, %d)%s: got (%d, %d, %d)",
                   x, y, r, g, b, tol ? " ± 1" : "", got[0], got[1], got[2]);
            return;
        }
    }
}
void h_eqstr(const char *what, const char *got, const char *want) {
    if (!got || strcmp(got, want) != 0)
        h_fail("%s:\n          got  <<%s>>\n          want <<%s>>", what, got ? got : "(null)", want);
}

char *ppm_lines(const char *ppm, int from, int to) {
    const char *p = ppm;
    for (int i = 1; i < from && p; i++) { p = strchr(p, '\n'); if (p) p++; }
    if (!p) return NULL;
    const char *q = p;
    for (int i = from; i <= to && q; i++) { const char *n = strchr(q, '\n'); if (!n) { q = q + strlen(q); break; } q = n + 1; }
    size_t len = (size_t)(q - p);
    if (len && q[-1] == '\n') len--;   /* drop the final newline of the range */
    char *out = malloc(len + 1);
    memcpy(out, p, len);
    out[len] = '\0';
    return out;
}

int ppm_longest_line(const char *ppm) {
    int best = 0, cur = 0;
    for (const char *p = ppm; *p; p++) {
        if (*p == '\n') { if (cur > best) best = cur; cur = 0; }
        else cur++;
    }
    if (cur > best) best = cur;
    return best;
}

int count_pixels(const Canvas *c, Color want) {
    int n = 0;
    for (int y = 0; y < c->height; y++)
        for (int x = 0; x < c->width; x++)
            if (ceq(pixel_at(c, x, y), want, EPS)) n++;
    return n;
}
