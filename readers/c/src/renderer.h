#ifndef RENDERER_H
#define RENDERER_H

#include <stdbool.h>

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

/* ---- sRGB transfer functions ----------------------------------------- */
double decode(double v);   /* file value -> light */
double encode(double l);   /* light -> file value */

/* ---- mixing ---------------------------------------------------------- */
extern bool linear_blending;   /* defaults to true */
Color mix(Color a, Color b, double t);

/* ---- PPM ------------------------------------------------------------- */
/* all of these return heap strings / arrays the caller frees */
char *canvas_to_ppm(const Canvas *c);
char *read_file(const char *path);
void ppm_pixel(const char *ppm, int x, int y, int out[3]);
int max_channel_difference(const char *a, const char *b);
int distinct_values(const char *ppm);

/* ---- the chapter's pictures ------------------------------------------ */
Canvas *gray_match(void);
Canvas *quarter_match(void);
Canvas *ramp(void);
Canvas *clamp_pair(void);
Canvas *plate_01(void);

#endif
