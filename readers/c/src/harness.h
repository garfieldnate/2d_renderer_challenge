#ifndef HARNESS_H
#define HARNESS_H
/* A tiny assert-style harness. One "scenario" per Gherkin scenario; a
   scenario passes when none of its steps failed. */

#include <math.h>
#include <stdio.h>
#include <string.h>
#include "renderer.h"

extern int h_total, h_failed, h_fail_here;
extern const char *h_name;

void h_begin(const char *feature, const char *name);
void h_end(void);
void h_subtotal(const char *label);   /* since the last subtotal */
void h_report(void);
void h_fail(const char *fmt, ...);

#define EPS 0.0001

/* a = b, with the book's default or an explicit tolerance */
#define EQ(a, b)          h_eq(#a " = " #b, (a), (b), EPS)
#define EQ_EPS(a, b, e)   h_eq(#a " = " #b " ± " #e, (a), (b), (e))
#define NE(a, b)          h_ne(#a " ≠ " #b, (a), (b), EPS)
#define NE_EPS(a, b, e)   h_ne(#a " ≠ " #b " ± " #e, (a), (b), (e))
#define EQI(a, b)         h_eqi(#a " = " #b, (a), (b))
#define LEI(a, b)         h_lei(#a " ≤ " #b, (a), (b))
#define TRUEP(a)          h_true(#a " is true", !!(a))
#define FALSEP(a)         h_true(#a " is false", !(a))

/* colors compare component by component */
#define EQC(c, r, g, b)   h_eqc(#c " = color(" #r ", " #g ", " #b ")", (c), color((r),(g),(b)), EPS)
#define EQCC(a, b)        h_eqc(#a " = " #b, (a), (b), EPS)
#define NECC(a, b)        h_nec(#a " ≠ " #b, (a), (b), EPS)

/* file pixels are whole numbers and compare exactly unless ± 1.
   ppm may be a P3 string or a P6 Bytes. */
#define EQP(ppm, x, y, r, g, b)      h_eqp(AS_BYTES(ppm), x, y, r, g, b, 0)
#define EQP1(ppm, x, y, r, g, b)     h_eqp(AS_BYTES(ppm), x, y, r, g, b, 1)

void h_eq(const char *what, double a, double b, double eps);
void h_ne(const char *what, double a, double b, double eps);
void h_eqi(const char *what, long a, long b);
void h_lei(const char *what, long a, long b);
void h_true(const char *what, int ok);
void h_eqc(const char *what, Color a, Color b, double eps);
void h_nec(const char *what, Color a, Color b, double eps);
void h_eqp(Bytes ppm, int x, int y, int r, int g, int b, int tol);
void h_eqstr(const char *what, const char *got, const char *want);

/* chapter 3 test helpers: not renderer functions.
   lit_pixels lists every pixel that isn't black, in reading order;
   total_ink sums the red channel, which for white on black is the paint. */
#define LIT_MAX 8192
typedef struct { int n; int xy[LIT_MAX][2]; } PixelList;

void lit_pixels(const Canvas *c, PixelList *out);
double total_ink(const Canvas *c);
void h_eq_pixels(const char *what, const Canvas *c, const int (*want)[2], int n);
void h_same_pixels(const char *what, const Canvas *a, const Canvas *b);

/* EQ_PIXELS(c, {{0,0},{1,1}}) — the list literal from the scenario */
#define EQ_PIXELS(c, ...) do { \
    static const int _want[][2] = __VA_ARGS__; \
    h_eq_pixels("lit_pixels(" #c ")", (c), _want, (int)(sizeof _want / sizeof _want[0])); \
} while (0)

/* ---- chapter 4: tuples and matrices ------------------------------------ */
/* Tuples compare on all three components, so a point never equals a
   vector. Matrices compare entry by entry, both with the usual tolerance. */
#define EQT(a, b)   h_eqt(#a " = " #b, (a), (b), EPS)
#define EQM(a, b)   h_eqm(#a " = " #b, (a), (b), EPS)
#define NEM(a, b)   h_nem(#a " ≠ " #b, (a), (b), EPS)

void h_eqt(const char *what, Tuple a, Tuple b, double eps);
void h_eqm(const char *what, Matrix3 a, Matrix3 b, double eps);
void h_nem(const char *what, Matrix3 a, Matrix3 b, double eps);

/* text helpers for the PPM scenarios */
char *ppm_lines(const char *ppm, int from, int to);  /* 1-based, inclusive; caller frees */
int  ppm_longest_line(const char *ppm);
int  count_pixels(const Canvas *c, Color want);

#endif
