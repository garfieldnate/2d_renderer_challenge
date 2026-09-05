/* Every scenario in the feature files, in order. Scenario outlines are
   expanded to one scenario per example row. Run from the project root so
   the reference/ paths resolve. */
#include "harness.h"
#include <stdlib.h>
#include <stdio.h>

#define S(feature, name) for (int _once = (h_begin(feature, name), 1); _once; _once = 0, h_end())

#define EVERY_PIXEL(c, col) h_eqi("every pixel of c is " #col, count_pixels((c), (col)), (c)->width * (c)->height)

/* ============ features/chapter01-equality.feature ==================== */
static void feature_equality(void) {
    const char *F = "Comparing numbers";

    S(F, "Two numbers that differ by less than the tolerance are equal") {
        EQ_EPS(1.0, 1.0000001, 0.00001);
    }
    S(F, "Two numbers that differ by more than the tolerance are not") {
        NE_EPS(1.0, 1.001, 0.00001);
    }
    S(F, "The default tolerance is 0.0001") {
        EQ(0.1 + 0.2, 0.3);
        EQ(1.0, 1.00009);
        NE(1.0, 1.0002);
    }
}

/* ============ features/chapter01-colors.feature ====================== */
static void feature_colors(void) {
    const char *F = "Colors";

    S(F, "A color is a red, green, blue tuple") {
        Color c = color(-0.5, 0.4, 1.7);
        EQ(c.red, -0.5);
        EQ(c.green, 0.4);
        EQ(c.blue, 1.7);
    }
    S(F, "Adding colors") {
        Color c1 = color(0.9, 0.6, 0.75), c2 = color(0.7, 0.1, 0.25);
        EQC(color_add(c1, c2), 1.6, 0.7, 1.0);
    }
    S(F, "Subtracting colors") {
        Color c1 = color(0.9, 0.6, 0.75), c2 = color(0.7, 0.1, 0.25);
        EQC(color_sub(c1, c2), 0.2, 0.5, 0.5);
    }
    S(F, "Scaling a color by a number") {
        Color c = color(0.2, 0.3, 0.4);
        EQC(color_scale(c, 2), 0.4, 0.6, 0.8);
        EQC(color_scale(c, 0.5), 0.1, 0.15, 0.2);
    }
    S(F, "Multiplying two colors filters one through the other") {
        Color c1 = color(1, 0.2, 0.4), c2 = color(0.9, 1, 0.1);
        EQC(color_mul(c1, c2), 0.9, 0.2, 0.04);
    }
    S(F, "Colors compare component by component, with the usual tolerance") {
        Color c1 = color(0.1, 0.5, 1), c2 = color(0.2, 0, 0);
        EQC(color_add(c1, c2), 0.3, 0.5, 1);
        NECC(color_add(c1, c2), color(0.3, 0.5, 1.001));
    }
}

/* ============ features/chapter01-canvas.feature ====================== */
static void feature_canvas(void) {
    const char *F = "Canvas";

    S(F, "A new canvas is black") {
        Canvas *c = canvas(10, 20);
        EQI(c->width, 10);
        EQI(c->height, 20);
        EVERY_PIXEL(c, color(0, 0, 0));
        canvas_free(c);
    }
    S(F, "Writing a pixel") {
        Canvas *c = canvas(10, 20);
        Color red = color(1, 0, 0);
        write_pixel(c, 2, 3, red);
        EQCC(pixel_at(c, 2, 3), red);
        canvas_free(c);
    }
    S(F, "x is the column and y is the row") {
        Canvas *c = canvas(10, 20);
        write_pixel(c, 2, 3, color(1, 0, 0));
        EQC(pixel_at(c, 3, 2), 0, 0, 0);
        EQC(pixel_at(c, 2, 3), 1, 0, 0);
        canvas_free(c);
    }
    S(F, "Writing outside the canvas is ignored") {
        Canvas *c = canvas(10, 20);
        write_pixel(c, -1, 5, color(1, 0, 0));
        write_pixel(c, 10, 5, color(1, 0, 0));
        write_pixel(c, 5, -1, color(1, 0, 0));
        write_pixel(c, 5, 20, color(1, 0, 0));
        EVERY_PIXEL(c, color(0, 0, 0));
        canvas_free(c);
    }
    S(F, "A pixel can be written more than once") {
        Canvas *c = canvas(10, 20);
        write_pixel(c, 2, 3, color(1, 0, 0));
        write_pixel(c, 2, 3, color(0, 1, 0));
        EQC(pixel_at(c, 2, 3), 0, 1, 0);
        canvas_free(c);
    }
    S(F, "Filling a canvas") {
        Canvas *c = canvas(10, 20);
        fill(c, color(0.1, 0.2, 0.3));
        EVERY_PIXEL(c, color(0.1, 0.2, 0.3));
        canvas_free(c);
    }
}

/* ============ features/chapter01-srgb.feature ======================== */
static void feature_srgb(void) {
    const char *F = "sRGB transfer functions";
    char name[96];

    struct { double light, value; } enc[] = {
        {0.0, 0.0}, {0.0025, 0.0323}, {0.0031308, 0.0405}, {0.01, 0.0999},
        {0.1, 0.3492}, {0.216, 0.5021}, {0.25, 0.5371}, {0.5, 0.7354},
        {0.75, 0.8808}, {1.0, 1.0}
    };
    for (unsigned i = 0; i < sizeof enc / sizeof *enc; i++) {
        snprintf(name, sizeof name, "Encoding light into a file value [%g -> %g]", enc[i].light, enc[i].value);
        S(F, name) { h_eq("encode(l) = <value>", encode(enc[i].light), enc[i].value, EPS); }
    }

    struct { double value, light; } dec[] = {
        {0.0, 0.0}, {0.04, 0.0031}, {0.04045, 0.0031}, {0.05, 0.0039},
        {0.1, 0.0100}, {0.5, 0.2140}, {0.75, 0.5225}, {1.0, 1.0}
    };
    for (unsigned i = 0; i < sizeof dec / sizeof *dec; i++) {
        snprintf(name, sizeof name, "Decoding a file value into light [%g -> %g]", dec[i].value, dec[i].light);
        S(F, name) { h_eq("decode(v) = <light>", decode(dec[i].value), dec[i].light, EPS); }
    }

    S(F, "Decode undoes encode")  { EQ_EPS(decode(encode(0.2)), 0.2, 0.000000001); }
    S(F, "Encode undoes decode")  { EQ_EPS(encode(decode(0.7)), 0.7, 0.000000001); }
    S(F, "The half gray that isn't 128") { EQI(lround(encode(0.5) * 255), 188); }
    S(F, "What 128 actually is")  { EQ(decode(128.0 / 255.0), 0.2159); }
}

/* ============ features/chapter01-ppm.feature ========================= */
static void feature_ppm(void) {
    const char *F = "PPM output";

    S(F, "The PPM header") {
        Canvas *c = canvas(5, 3);
        char *ppm = canvas_to_ppm(c);
        char *got = ppm_lines(ppm, 1, 3);
        h_eqstr("lines 1-3 of ppm", got, "P3\n5 3\n255");
        free(got); free(ppm); canvas_free(c);
    }
    S(F, "Pixel values are encoded, not scaled") {
        Canvas *c = canvas(3, 1);
        write_pixel(c, 0, 0, color(1, 0, 0));
        write_pixel(c, 1, 0, color(0, 0.5, 0));
        write_pixel(c, 2, 0, color(0, 0, 0.216));
        char *ppm = canvas_to_ppm(c);
        char *got = ppm_lines(ppm, 4, 4);
        h_eqstr("line 4 of ppm", got, "255 0 0 0 188 0 0 0 128");
        free(got); free(ppm); canvas_free(c);
    }
    S(F, "Colors out of range are clamped, not wrapped") {
        Canvas *c = canvas(2, 1);
        write_pixel(c, 0, 0, color(1.5, 0, -0.5));
        char *ppm = canvas_to_ppm(c);
        char *got = ppm_lines(ppm, 4, 4);
        h_eqstr("line 4 of ppm", got, "255 0 0 0 0 0");
        free(got); free(ppm); canvas_free(c);
    }
    S(F, "Every row starts a new line, and no line exceeds 70 characters") {
        Canvas *c = canvas(10, 2);
        fill(c, color(1, 0.8, 0.6));
        char *ppm = canvas_to_ppm(c);
        char *got = ppm_lines(ppm, 4, 7);
        h_eqstr("lines 4-7 of ppm", got,
            "255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231\n"
            "203 255 231 203 255 231 203 255 231 203 255 231 203\n"
            "255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231\n"
            "203 255 231 203 255 231 203 255 231 203 255 231 203");
        LEI(ppm_longest_line(ppm), 70);
        free(got); free(ppm); canvas_free(c);
    }
    S(F, "The file ends with a newline") {
        Canvas *c = canvas(5, 3);
        char *ppm = canvas_to_ppm(c);
        TRUEP(ppm[0] && ppm[strlen(ppm) - 1] == '\n');
        free(ppm); canvas_free(c);
    }
    S(F, "Reading a pixel back out of the text") {
        Canvas *c = canvas(3, 2);
        write_pixel(c, 2, 1, color(0, 0.5, 1));
        char *ppm = canvas_to_ppm(c);
        EQP(ppm, 2, 1, 0, 188, 255);
        EQP(ppm, 1, 1, 0, 0, 0);
        free(ppm); canvas_free(c);
    }
    S(F, "Comparing two files") {
        Canvas *c1 = canvas(2, 1), *c2 = canvas(2, 1);
        write_pixel(c2, 0, 0, color(0.5, 0, 0));
        char *ppm1 = canvas_to_ppm(c1), *ppm2 = canvas_to_ppm(c2);
        EQI(max_channel_difference(ppm1, ppm1), 0);
        EQI(max_channel_difference(ppm1, ppm2), 188);
        free(ppm1); free(ppm2); canvas_free(c1); canvas_free(c2);
    }
}

/* ============ features/chapter01-gray-match.feature ================== */
static void feature_gray_match(void) {
    const char *F = "The gray match";

    S(F, "The gray match") {
        Canvas *c = gray_match();
        EQI(c->width, 300);
        EQI(c->height, 100);
        EQC(pixel_at(c, 0, 0), 1, 1, 1);
        EQC(pixel_at(c, 1, 0), 0, 0, 0);
        EQC(pixel_at(c, 0, 1), 0, 0, 0);
        EQC(pixel_at(c, 1, 1), 1, 1, 1);
        EQC(pixel_at(c, 150, 50), 0.2159, 0.2159, 0.2159);
        EQC(pixel_at(c, 250, 50), 0.5, 0.5, 0.5);
        EQI(count_pixels(c, color(1, 1, 1)), 5000);
        canvas_free(c);
    }
    S(F, "The gray match, as a file") {
        Canvas *c = gray_match();
        char *ppm = canvas_to_ppm(c);
        EQP(ppm, 0, 0, 255, 255, 255);
        EQP(ppm, 1, 0, 0, 0, 0);
        EQP(ppm, 150, 50, 128, 128, 128);
        EQP(ppm, 250, 50, 188, 188, 188);
        char *ref = read_file("reference/chapter-01/gray-match.ppm");
        if (!ref) h_fail("could not read reference/chapter-01/gray-match.ppm");
        else { LEI(max_channel_difference(ppm, ref), 1); free(ref); }
        free(ppm); canvas_free(c);
    }
    S(F, "One pixel in four") {
        Canvas *c = quarter_match();
        EQI(c->width, 200);
        EQI(c->height, 100);
        EQC(pixel_at(c, 0, 0), 1, 1, 1);
        EQC(pixel_at(c, 1, 0), 0, 0, 0);
        EQC(pixel_at(c, 2, 2), 1, 1, 1);
        EQC(pixel_at(c, 3, 1), 1, 1, 1);
        EQC(pixel_at(c, 150, 50), 0.25, 0.25, 0.25);
        EQI(count_pixels(c, color(1, 1, 1)), 2500);
        char *ppm = canvas_to_ppm(c);
        EQP(ppm, 150, 50, 137, 137, 137);
        char *ref = read_file("reference/chapter-01/quarter-match.ppm");
        if (!ref) h_fail("could not read reference/chapter-01/quarter-match.ppm");
        else { LEI(max_channel_difference(ppm, ref), 1); free(ref); }
        free(ppm); canvas_free(c);
    }
}

/* ============ features/chapter01-mix.feature ========================= */
static void feature_mix(void) {
    const char *F = "Mixing two colors";

    S(F, "Linear blending is on by default") {
        TRUEP(linear_blending);
    }
    S(F, "Halfway between black and white") {
        Color a = color(0, 0, 0), b = color(1, 1, 1);
        EQC(mix(a, b, 0.5), 0.5, 0.5, 0.5);
    }
    S(F, "The ends of a mix are its inputs") {
        Color a = color(0.7, 0, 0), b = color(0, 0.3, 0.02);
        EQCC(mix(a, b, 0), a);
        EQCC(mix(a, b, 1), b);
    }
    S(F, "Red to green, in light") {
        Color a = color(0.7, 0, 0), b = color(0, 0.3, 0.02);
        EQC(mix(a, b, 0.5), 0.35, 0.15, 0.01);
        EQC(mix(a, b, 0.25), 0.525, 0.075, 0.005);
    }
    S(F, "Halfway between black and white, the way browsers do it") {
        linear_blending = false;
        Color a = color(0, 0, 0), b = color(1, 1, 1);
        EQC(mix(a, b, 0.5), 0.2140, 0.2140, 0.2140);
    }
    S(F, "Red to green, the way browsers do it") {
        linear_blending = false;
        Color a = color(0.7, 0, 0), b = color(0, 0.3, 0.02);
        EQC(mix(a, b, 0.5), 0.1527, 0.0693, 0.0067);
    }
    S(F, "The ends of a mix are its inputs either way") {
        linear_blending = false;
        Color a = color(0.7, 0, 0), b = color(0, 0.3, 0.02);
        EQCC(mix(a, b, 0), a);
        EQCC(mix(a, b, 1), b);
    }
}

/* ============ features/chapter01-limits.feature ====================== */
static void feature_limits(void) {
    const char *F = "The edges of the range";

    S(F, "A 256-step ramp") {
        Canvas *c = ramp();
        EQI(c->width, 256);
        EQI(c->height, 32);
        EQC(pixel_at(c, 0, 0), 0, 0, 0);
        EQC(pixel_at(c, 128, 0), 0.5020, 0.5020, 0.5020);
        EQC(pixel_at(c, 255, 31), 1, 1, 1);
        canvas_free(c);
    }
    S(F, "Encoding stretches the dark end and squeezes the bright end") {
        Canvas *c = ramp();
        char *ppm = canvas_to_ppm(c);
        char *got = ppm_lines(ppm, 4, 4);
        h_eqstr("line 4 of ppm", got,
                "0 0 0 13 13 13 22 22 22 28 28 28 34 34 34 38 38 38 42 42 42 46 46 46");
        EQP(ppm, 75, 0, 148, 148, 148);
        EQP(ppm, 76, 0, 148, 148, 148);
        EQP(ppm, 254, 0, 255, 255, 255);
        EQI(distinct_values(ppm), 183);
        char *ref = read_file("reference/chapter-01/ramp.ppm");
        if (!ref) h_fail("could not read reference/chapter-01/ramp.ppm");
        else { LEI(max_channel_difference(ppm, ref), 1); free(ref); }
        free(got); free(ppm); canvas_free(c);
    }
    S(F, "Clamping changes the color, not only the brightness") {
        Canvas *c = clamp_pair();
        EQI(c->width, 200);
        EQI(c->height, 100);
        EQC(pixel_at(c, 50, 50), 2, 0.5, 0.5);
        EQC(pixel_at(c, 150, 50), 1, 0.25, 0.25);
        char *ppm = canvas_to_ppm(c);
        EQP(ppm, 50, 50, 255, 188, 188);
        EQP(ppm, 150, 50, 255, 137, 137);
        char *ref = read_file("reference/chapter-01/clamp-pair.ppm");
        if (!ref) h_fail("could not read reference/chapter-01/clamp-pair.ppm");
        else { LEI(max_channel_difference(ppm, ref), 1); free(ref); }
        free(ppm); canvas_free(c);
    }
}

/* ============ features/chapter01-plate.feature ======================= */
static void feature_plate(void) {
    const char *F = "Plate 1";

    S(F, "The plate") {
        Canvas *c = plate_01();
        EQI(c->width, 400);
        EQI(c->height, 180);
        char *ppm = canvas_to_ppm(c);
        EQP (ppm,   0,  20,   0,   0,   0);
        EQP (ppm, 399,  20, 255, 255, 255);
        EQP1(ppm, 200,  20, 128, 128, 128);
        EQP1(ppm, 200,  65, 188, 188, 188);
        EQP (ppm, 200,  42,   0,   0,   0);
        EQP (ppm,   0, 110, 218,   0,   0);
        EQP (ppm, 399, 110,   0, 149,  39);
        EQP1(ppm, 200, 110, 109,  75,  19);
        EQP1(ppm, 200, 155, 160, 108,  26);
        EQP (ppm, 200,  87,   0,   0,   0);
        char *ref = read_file("reference/chapter-01/plate-01.ppm");
        if (!ref) h_fail("could not read reference/chapter-01/plate-01.ppm");
        else { LEI(max_channel_difference(ppm, ref), 1); free(ref); }
        free(ppm); canvas_free(c);
    }
    S(F, "The switch was left on") {
        Canvas *c = plate_01();
        TRUEP(linear_blending);
        canvas_free(c);
    }
}

#include <time.h>
#define T(f) do { clock_t _s = clock(); f(); if (getenv("TIMING")) fprintf(stderr, "  %-22s %6.1f ms\n", #f, (clock()-_s)*1000.0/CLOCKS_PER_SEC); } while (0)

int main(void) {
    T(feature_equality);
    T(feature_colors);
    T(feature_canvas);
    T(feature_srgb);
    T(feature_ppm);
    T(feature_gray_match);
    T(feature_mix);
    T(feature_limits);
    T(feature_plate);
    h_report();
    return h_failed ? 1 : 0;
}
