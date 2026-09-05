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
        Bytes ref = read_file("reference/chapter-01/gray-match.ppm");
        if (!ref.data) h_fail("could not read reference/chapter-01/gray-match.ppm");
        else { LEI(max_channel_difference(ppm, ref), 1); free(ref.data); }
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
        Bytes ref = read_file("reference/chapter-01/quarter-match.ppm");
        if (!ref.data) h_fail("could not read reference/chapter-01/quarter-match.ppm");
        else { LEI(max_channel_difference(ppm, ref), 1); free(ref.data); }
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
        Bytes ref = read_file("reference/chapter-01/ramp.ppm");
        if (!ref.data) h_fail("could not read reference/chapter-01/ramp.ppm");
        else { LEI(max_channel_difference(ppm, ref), 1); free(ref.data); }
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
        Bytes ref = read_file("reference/chapter-01/clamp-pair.ppm");
        if (!ref.data) h_fail("could not read reference/chapter-01/clamp-pair.ppm");
        else { LEI(max_channel_difference(ppm, ref), 1); free(ref.data); }
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
        Bytes ref = read_file("reference/chapter-01/plate-01.ppm");
        if (!ref.data) h_fail("could not read reference/chapter-01/plate-01.ppm");
        else { LEI(max_channel_difference(ppm, ref), 1); free(ref.data); }
        free(ppm); canvas_free(c);
    }
    S(F, "The switch was left on") {
        Canvas *c = plate_01();
        TRUEP(linear_blending);
        canvas_free(c);
    }
}

/* ============ features/chapter02-shapes.feature ====================== */
static void feature_shapes(void) {
    const char *F = "Shapes are questions";

    S(F, "A point inside a circle") {
        Shape s = circle(8, 8, 5);
        TRUEP (inside(s, 8, 8));
        TRUEP (inside(s, 12, 8));
        TRUEP (inside(s, 13, 8));
        FALSEP(inside(s, 13.01, 8));
        FALSEP(inside(s, 11.6, 11.6));
    }
    S(F, "A point inside a rectangle") {
        Shape s = rectangle(1.25, 2.0, 4.75, 5.0);
        TRUEP (inside(s, 3, 3));
        TRUEP (inside(s, 1.25, 2.0));
        TRUEP (inside(s, 4.75, 5.0));
        FALSEP(inside(s, 1.2, 3));
        FALSEP(inside(s, 3, 5.1));
    }
    S(F, "A point inside a half-plane") {
        Shape s = half_plane(2.5, 0, 1, 0);
        TRUEP (inside(s, 2.5, 7));
        TRUEP (inside(s, 3, -4));
        FALSEP(inside(s, 2.4, 0));
    }
    S(F, "The normal picks the side") {
        Shape s = half_plane(2.5, 0, -1, 0);
        TRUEP (inside(s, 2.4, 0));
        FALSEP(inside(s, 3, 0));
    }
}

/* ============ features/chapter02-p6.feature ========================== */
static void feature_p6(void) {
    const char *F = "Binary PPM";

    S(F, "The header, then the bytes") {
        Canvas *c = canvas(2, 1);
        write_pixel(c, 0, 0, color(1, 0, 0));
        write_pixel(c, 1, 0, color(0, 0.5, 0));
        Bytes p6 = canvas_to_p6(c);
        TRUEP(p6.len >= 11 && memcmp(p6.data, "P6\n2 1\n255\n", 11) == 0);
        EQI((long)p6.len, 17);
        EQI(p6.data[11], 255);   /* byte 12, counting from 1 */
        EQI(p6.data[12], 0);     /* byte 13 */
        EQI(p6.data[15], 188);   /* byte 16 */
        free(p6.data); canvas_free(c);
    }
    S(F, "The same pixel comes back out of either format") {
        Canvas *c = canvas(2, 1);
        write_pixel(c, 1, 0, color(0, 0.5, 0));
        char *p3 = canvas_to_ppm(c);
        Bytes p6 = canvas_to_p6(c);
        EQP(p6, 1, 0, 0, 188, 0);
        EQP(p3, 1, 0, 0, 188, 0);
        EQI(max_channel_difference(p3, p6), 0);
        EQI(distinct_values(p6), 2);
        free(p3); free(p6.data); canvas_free(c);
    }
    S(F, "Sizes still have to match") {
        Canvas *c1 = canvas(2, 1), *c2 = canvas(1, 2);
        Bytes p6a = canvas_to_p6(c1), p6b = canvas_to_p6(c2);
        EQI(max_channel_difference(p6a, p6b), 255);
        free(p6a.data); free(p6b.data); canvas_free(c1); canvas_free(c2);
    }
}

/* ============ features/chapter02-magnify.feature ===================== */
static void feature_magnify(void) {
    const char *F = "Magnify";

    S(F, "Every pixel becomes a block") {
        Canvas *c = canvas(2, 1);
        write_pixel(c, 0, 0, color(1, 0, 0));
        write_pixel(c, 1, 0, color(0, 0.5, 0));
        Canvas *m = magnify(c, 3);
        EQI(m->width, 6);
        EQI(m->height, 3);
        EQC(pixel_at(m, 0, 0), 1, 0, 0);
        EQC(pixel_at(m, 2, 2), 1, 0, 0);
        EQC(pixel_at(m, 3, 0), 0, 0.5, 0);
        EQC(pixel_at(m, 5, 2), 0, 0.5, 0);
        EQI(count_pixels(m, color(1, 0, 0)), 9);
        canvas_free(m); canvas_free(c);
    }
    S(F, "Magnifying by one changes nothing") {
        Canvas *c = canvas(2, 1);
        write_pixel(c, 1, 0, color(0, 0.5, 0));
        Canvas *m = magnify(c, 1);
        Bytes a = canvas_to_p6(c), b = canvas_to_p6(m);
        EQI(max_channel_difference(a, b), 0);
        free(a.data); free(b.data); canvas_free(m); canvas_free(c);
    }
}

/* ============ features/chapter02-centers.feature ===================== */
static void feature_centers(void) {
    const char *F = "The coverage buffer, and the first question";

    S(F, "A new coverage buffer is empty") {
        CoverageBuffer *cov = coverage_buffer(4, 3);
        EQI(cov->width, 4);
        EQI(cov->height, 3);
        EQ(coverage_at(cov, 2, 1), 0);
        EQ(ink(cov), 0);
        coverage_free(cov);
    }
    S(F, "Setting coverage") {
        CoverageBuffer *cov = coverage_buffer(4, 3);
        set_coverage(cov, 2, 1, 0.75);
        EQ(coverage_at(cov, 2, 1), 0.75);
        EQ(coverage_at(cov, 1, 2), 0);
        EQ(ink(cov), 0.75);
        coverage_free(cov);
    }
    S(F, "Setting coverage outside the buffer is ignored") {
        CoverageBuffer *cov = coverage_buffer(4, 3);
        set_coverage(cov, -1, 1, 1);
        set_coverage(cov, 4, 1, 1);
        set_coverage(cov, 1, 3, 1);
        EQ(ink(cov), 0);
        coverage_free(cov);
    }
    S(F, "The center of pixel (x, y) is (x + 0.5, y + 0.5)") {
        Shape s = half_plane(2.5, 0, 1, 0);
        EQ(center_inside(s, 2, 4), 1);
        EQ(center_inside(s, 1, 4), 0);
        Shape t = half_plane(2.6, 0, 1, 0);
        EQ(center_inside(t, 2, 4), 0);
    }
    S(F, "A disc, by asking each center") {
        Shape s = circle(8, 8, 5);
        CoverageBuffer *cov = rasterize_centers(s, 16, 16);
        EQI(cov->width, 16);
        EQI(cov->height, 16);
        EQ(coverage_at(cov,  8, 8), 1);
        EQ(coverage_at(cov,  3, 8), 1);
        EQ(coverage_at(cov, 12, 8), 1);
        EQ(coverage_at(cov,  2, 8), 0);
        EQ(coverage_at(cov, 13, 8), 0);
        EQ(coverage_at(cov,  4, 4), 1);
        EQ(coverage_at(cov,  3, 4), 0);
        EQ(ink(cov), 80);
        coverage_free(cov);
    }
}

/* ============ features/chapter02-paint.feature ======================= */
static void feature_paint(void) {
    const char *F = "Painting through coverage";

    S(F, "Half coverage is half the paint") {
        Canvas *c = canvas(1, 1);
        CoverageBuffer *cov = coverage_buffer(1, 1);
        set_coverage(cov, 0, 0, 0.5);
        paint_through(c, cov, color(1, 1, 1));
        EQC(pixel_at(c, 0, 0), 0.5, 0.5, 0.5);
        coverage_free(cov); canvas_free(c);
    }
    S(F, "Paint over something that isn't black") {
        Canvas *c = canvas(1, 1);
        CoverageBuffer *cov = coverage_buffer(1, 1);
        fill(c, color(0.2, 0.2, 0.2));
        set_coverage(cov, 0, 0, 0.25);
        paint_through(c, cov, color(1, 0, 0));
        EQC(pixel_at(c, 0, 0), 0.4, 0.15, 0.15);
        coverage_free(cov); canvas_free(c);
    }
    S(F, "Zero leaves it alone and one replaces it") {
        Canvas *c = canvas(2, 1);
        CoverageBuffer *cov = coverage_buffer(2, 1);
        fill(c, color(0.2, 0.2, 0.2));
        set_coverage(cov, 1, 0, 1);
        paint_through(c, cov, color(1, 0, 0));
        EQC(pixel_at(c, 0, 0), 0.2, 0.2, 0.2);
        EQC(pixel_at(c, 1, 0), 1, 0, 0);
        coverage_free(cov); canvas_free(c);
    }
    S(F, "The arithmetic is on light") {
        Canvas *c = canvas(1, 1);
        CoverageBuffer *cov = coverage_buffer(1, 1);
        set_coverage(cov, 0, 0, 0.5);
        paint_through(c, cov, color(1, 1, 1));
        char *ppm = canvas_to_ppm(c);
        EQP(ppm, 0, 0, 188, 188, 188);
        free(ppm); coverage_free(cov); canvas_free(c);
    }
    S(F, "The disc by centers") {
        Canvas *c = disc_centers();
        Bytes ref = read_file("reference/chapter-02/disc-centers.ppm");
        Bytes p6 = canvas_to_p6(c);
        EQI(c->width, 320);
        EQI(c->height, 320);
        EQP1(p6, 160, 160, 243, 196, 89);
        EQP1(p6, 124,  36,  39,  39, 44);
        EQP1(p6, 132,  36, 243, 196, 89);
        EQI(distinct_values(p6), 5);
        if (!ref.data) h_fail("could not read reference/chapter-02/disc-centers.ppm");
        else { LEI(max_channel_difference(p6, ref), 1); free(ref.data); }
        free(p6.data); canvas_free(c);
    }
}

/* ============ features/chapter02-coverage.feature ==================== */
static void feature_coverage(void) {
    const char *F = "The better question";

    S(F, "The sixty-four sample points") {
        Shape s = half_plane(2.5, 0, 1, 0);
        EQ(coverage(s, 2, 4), 0.5);
        EQ(coverage(s, 1, 4), 0);
        EQ(coverage(s, 3, 4), 1);
    }
    S(F, "A rectangle is covered exactly, when its edges land on sample boundaries") {
        Shape s = rectangle(1.25, 2.0, 4.75, 5.0);
        CoverageBuffer *cov = rasterize(s, 8, 8);
        EQ(coverage_at(cov, 0, 2), 0);
        EQ(coverage_at(cov, 1, 2), 0.75);
        EQ(coverage_at(cov, 2, 2), 1);
        EQ(coverage_at(cov, 3, 2), 1);
        EQ(coverage_at(cov, 4, 2), 0.75);
        EQ(coverage_at(cov, 5, 2), 0);
        EQ(coverage_at(cov, 2, 1), 0);
        EQ(coverage_at(cov, 2, 5), 0);
        EQ(ink(cov), 10.5);
        coverage_free(cov);
    }
    S(F, "A half-plane through a pixel center covers half of it") {
        Shape s = half_plane(2.5, 4.5, 0.6, 0.8);
        EQ(coverage(s, 2, 4), 0.5);
    }
    S(F, "Except when the grid conspires") {
        Shape s = half_plane(2.5, 4.5, 1, 1);
        EQ(coverage(s, 2, 4), 0.5625);
    }
    S(F, "A disc is only ever approximately covered") {
        Shape s = circle(8, 8, 5);
        CoverageBuffer *cov = rasterize(s, 16, 16);
        EQ(coverage_at(cov,  8, 8), 1);
        EQ(coverage_at(cov,  3, 8), 0.96875);
        EQ(coverage_at(cov, 12, 8), 0.96875);
        EQ(coverage_at(cov,  4, 4), 0.5625);
        EQ(coverage_at(cov,  3, 4), 0);
        EQ(ink(cov), 78.5);
        EQ_EPS(ink(cov), 78.5398, 0.1);
        coverage_free(cov);
    }
    S(F, "The disc by coverage") {
        Canvas *c = disc_coverage();
        Bytes ref = read_file("reference/chapter-02/disc-coverage.ppm");
        Bytes p6 = canvas_to_p6(c);
        EQI(c->width, 320);
        EQI(c->height, 320);
        EQP1(p6, 160, 160, 243, 196, 89);
        EQP1(p6, 124,  36, 157, 127, 64);
        if (!ref.data) h_fail("could not read reference/chapter-02/disc-coverage.ppm");
        else { LEI(max_channel_difference(p6, ref), 1); free(ref.data); }
        free(p6.data); canvas_free(c);
    }
}

/* ============ features/chapter02-twice.feature ======================= */
static void feature_twice(void) {
    const char *F = "Coverage is not opacity";

    S(F, "Half coverage, painted twice, is three quarters") {
        Canvas *c = canvas(1, 1);
        CoverageBuffer *cov = coverage_buffer(1, 1);
        set_coverage(cov, 0, 0, 0.5);
        paint_through(c, cov, color(1, 1, 1));
        paint_through(c, cov, color(1, 1, 1));
        EQC(pixel_at(c, 0, 0), 0.75, 0.75, 0.75);
        coverage_free(cov); canvas_free(c);
    }
    S(F, "The disc, once and twice") {
        Canvas *c = painted_twice();
        Bytes ref = read_file("reference/chapter-02/painted-twice.ppm");
        Bytes p6 = canvas_to_p6(c);
        EQI(c->width, 480);
        EQI(c->height, 240);
        EQP1(p6, 120, 120, 243, 196, 89);
        EQP1(p6, 360, 120, 243, 196, 89);
        EQP1(p6,  93,  27, 157, 127, 64);
        EQP1(p6, 333,  27, 194, 156, 74);
        if (!ref.data) h_fail("could not read reference/chapter-02/painted-twice.ppm");
        else { LEI(max_channel_difference(p6, ref), 1); free(ref.data); }
        free(p6.data); canvas_free(c);
    }
}

/* ============ features/chapter02-plate.feature ======================= */
static void feature_plate_02(void) {
    const char *F = "Plate 2";

    S(F, "The plate") {
        Canvas *c = plate_02();
        Bytes ref = read_file("reference/chapter-02/plate-02.ppm");
        Bytes p6 = canvas_to_p6(c);
        EQI(c->width, 480);
        EQI(c->height, 240);
        EQP1(p6, 120, 120, 243, 196, 89);
        EQP1(p6, 360, 120, 243, 196, 89);
        EQP1(p6,  93,  27,  39,  39, 44);
        EQP1(p6, 333,  27, 157, 127, 64);
        if (!ref.data) h_fail("could not read reference/chapter-02/plate-02.ppm");
        else { LEI(max_channel_difference(p6, ref), 1); free(ref.data); }
        free(p6.data); canvas_free(c);
    }
}


/* ============ features/chapter03-bresenham.feature =================== */
static void feature_bresenham(void) {
    const char *F = "Bresenham's line";
    const Color W = {1, 1, 1};

    S(F, "A diagonal") {
        Canvas *c = canvas(10, 10);
        line_bresenham(c, 0, 0, 5, 5, W);
        EQ_PIXELS(c, {{0,0},{1,1},{2,2},{3,3},{4,4},{5,5}});
        canvas_free(c);
    }
    S(F, "A horizontal line lights one row and nothing else") {
        Canvas *c = canvas(10, 10);
        line_bresenham(c, 0, 3, 7, 3, W);
        EQ_PIXELS(c, {{0,3},{1,3},{2,3},{3,3},{4,3},{5,3},{6,3},{7,3}});
        canvas_free(c);
    }
    S(F, "A shallow line steps along x") {
        Canvas *c = canvas(10, 10);
        line_bresenham(c, 0, 0, 7, 3, W);
        EQ_PIXELS(c, {{0,0},{1,0},{2,1},{3,1},{4,2},{5,2},{6,3},{7,3}});
        canvas_free(c);
    }
    S(F, "A steep line steps along y") {
        Canvas *c = canvas(10, 10);
        line_bresenham(c, 1, 1, 3, 7, W);
        EQ_PIXELS(c, {{1,1},{1,2},{2,3},{2,4},{2,5},{3,6},{3,7}});
        canvas_free(c);
    }
    S(F, "The pixels don't depend on which end you start from") {
        Canvas *c1 = canvas(10, 10), *c2 = canvas(10, 10);
        line_bresenham(c1, 1, 1, 3, 7, W);
        line_bresenham(c2, 3, 7, 1, 1, W);
        h_same_pixels("lit_pixels(c1) = lit_pixels(c2)", c1, c2);
        Bytes a = canvas_to_p6(c1), b = canvas_to_p6(c2);
        EQI(max_channel_difference(a, b), 0);
        free(a.data); free(b.data); canvas_free(c1); canvas_free(c2);
    }
    S(F, "A line going up and to the right") {
        Canvas *c = canvas(10, 10);
        line_bresenham(c, 0, 6, 7, 3, W);
        EQ_PIXELS(c, {{6,3},{7,3},{4,4},{5,4},{2,5},{3,5},{0,6},{1,6}});
        canvas_free(c);
    }
    S(F, "At an exact half the line stays on its row one step longer") {
        Canvas *c = canvas(10, 10);
        line_bresenham(c, 0, 0, 4, 2, W);
        EQ_PIXELS(c, {{0,0},{1,0},{2,1},{3,1},{4,2}});
        canvas_free(c);
    }
    S(F, "A line of one point") {
        Canvas *c = canvas(10, 10);
        line_bresenham(c, 3, 3, 3, 3, W);
        EQ_PIXELS(c, {{3,3}});
        canvas_free(c);
    }
    S(F, "A line may run off the canvas") {
        Canvas *c = canvas(10, 10);
        line_bresenham(c, 0, 0, 12, 6, W);
        static PixelList lit;
        lit_pixels(c, &lit);
        EQI(lit.n, 10);
        canvas_free(c);
    }
}

/* ============ features/chapter03-wu.feature =========================== */
static void feature_wu(void) {
    const char *F = "Wu's line";
    const Color W = {1, 1, 1};
    char name[96];

    S(F, "A half step lights two pixels equally") {
        Canvas *c = canvas(10, 10);
        line_wu(c, 0, 0, 4, 2, W);
        EQC(pixel_at(c, 0, 0), 1, 1, 1);
        EQC(pixel_at(c, 1, 0), 0.5, 0.5, 0.5);
        EQC(pixel_at(c, 1, 1), 0.5, 0.5, 0.5);
        EQC(pixel_at(c, 2, 1), 1, 1, 1);
        EQC(pixel_at(c, 2, 2), 0, 0, 0);
        EQC(pixel_at(c, 4, 2), 1, 1, 1);
        EQ(total_ink(c), 5);
        canvas_free(c);
    }
    S(F, "A diagonal has uniform weights") {
        Canvas *c = canvas(10, 10);
        line_wu(c, 0, 0, 5, 5, W);
        EQ_PIXELS(c, {{0,0},{1,1},{2,2},{3,3},{4,4},{5,5}});
        EQC(pixel_at(c, 3, 3), 1, 1, 1);
        EQ(total_ink(c), 6);
        canvas_free(c);
    }
    S(F, "A horizontal line has weight 1 on its row and 0 on the neighbors") {
        Canvas *c = canvas(10, 10);
        line_wu(c, 0, 3, 7, 3, W);
        EQ_PIXELS(c, {{0,3},{1,3},{2,3},{3,3},{4,3},{5,3},{6,3},{7,3}});
        EQC(pixel_at(c, 3, 3), 1, 1, 1);
        EQC(pixel_at(c, 3, 2), 0, 0, 0);
        EQC(pixel_at(c, 3, 4), 0, 0, 0);
        EQ(total_ink(c), 8);
        canvas_free(c);
    }
    S(F, "A steep line weights across columns") {
        Canvas *c = canvas(10, 10);
        line_wu(c, 1, 1, 3, 7, W);
        EQC(pixel_at(c, 1, 1), 1, 1, 1);
        EQC(pixel_at(c, 1, 2), 0.6667, 0.6667, 0.6667);
        EQC(pixel_at(c, 2, 2), 0.3333, 0.3333, 0.3333);
        EQC(pixel_at(c, 2, 4), 1, 1, 1);
        EQC(pixel_at(c, 3, 7), 1, 1, 1);
        EQ(total_ink(c), 7);
        canvas_free(c);
    }
    S(F, "The weights don't depend on which end you start from") {
        Canvas *c1 = canvas(10, 10), *c2 = canvas(10, 10);
        line_wu(c1, 1, 1, 3, 7, W);
        line_wu(c2, 3, 7, 1, 1, W);
        Bytes a = canvas_to_p6(c1), b = canvas_to_p6(c2);
        EQI(max_channel_difference(a, b), 0);
        free(a.data); free(b.data); canvas_free(c1); canvas_free(c2);
    }
    S(F, "Sevenths") {
        Canvas *c = canvas(10, 10);
        line_wu(c, 0, 0, 7, 3, W);
        EQC(pixel_at(c, 1, 0), 0.5714, 0.5714, 0.5714);
        EQC(pixel_at(c, 1, 1), 0.4286, 0.4286, 0.4286);
        EQC(pixel_at(c, 2, 0), 0.1429, 0.1429, 0.1429);
        EQC(pixel_at(c, 2, 1), 0.8571, 0.8571, 0.8571);
        EQ(total_ink(c), 8);
        canvas_free(c);
    }

    struct { int x1, y1, ink; } rows[] = {
        {12, 2, 11}, {10, 8, 9}, {8, 10, 9}, {2, 12, 11}
    };
    for (size_t i = 0; i < sizeof rows / sizeof rows[0]; i++) {
        snprintf(name, sizeof name, "The ink depends on the angle [%d, %d, %d]",
                 rows[i].x1, rows[i].y1, rows[i].ink);
        S(F, name) {
            Canvas *c = canvas(20, 20);
            line_wu(c, 2, 2, rows[i].x1, rows[i].y1, W);
            EQ(total_ink(c), rows[i].ink);
            canvas_free(c);
        }
    }
}

/* ============ features/chapter03-quad.feature ========================= */
static void feature_quad(void) {
    const char *F = "A line is a thin rectangle";
    char name[96];

    S(F, "Inside a thick line") {
        Shape s = thick_line(0, 0, 4, 0, 1);
        TRUEP(inside(s, 2.5, 0.5));
        TRUEP(inside(s, 2.5, 1.0));
        FALSEP(inside(s, 2.5, 1.01));
        TRUEP(inside(s, 0.5, 0.5));
        FALSEP(inside(s, 0.4, 0.5));
        TRUEP(inside(s, 4.5, 0.5));
        FALSEP(inside(s, 4.6, 0.5));
    }
    S(F, "A horizontal thick line covers its row, with half pixels at the ends") {
        Shape s = thick_line(0, 3, 7, 3, 1);
        CoverageBuffer *cov = rasterize(s, 10, 10);
        EQ(coverage_at(cov, 0, 3), 0.5);
        EQ(coverage_at(cov, 1, 3), 1);
        EQ(coverage_at(cov, 6, 3), 1);
        EQ(coverage_at(cov, 7, 3), 0.5);
        EQ(coverage_at(cov, 8, 3), 0);
        EQ(coverage_at(cov, 3, 2), 0);
        EQ(coverage_at(cov, 3, 4), 0);
        EQ(ink(cov), 7);
        coverage_free(cov);
    }

    struct { int x1, y1; } rows[] = { {12, 2}, {10, 8}, {8, 10}, {2, 12} };
    for (size_t i = 0; i < sizeof rows / sizeof rows[0]; i++) {
        snprintf(name, sizeof name, "The ink is the length, whatever the angle [%d, %d]",
                 rows[i].x1, rows[i].y1);
        S(F, name) {
            Shape s = thick_line(2, 2, rows[i].x1, rows[i].y1, 1);
            CoverageBuffer *cov = rasterize(s, 20, 20);
            EQ(ink(cov), 10);
            coverage_free(cov);
        }
    }

    S(F, "Except that the grid is blind along the diagonal") {
        Shape s = thick_line(2, 2, 9, 9, 1);
        CoverageBuffer *cov = rasterize(s, 20, 20);
        EQ(ink(cov), 9.7188);
        EQ_EPS(ink(cov), 9.8995, 0.25);
        coverage_free(cov);
    }
}

/* ============ features/chapter03-plate.feature ======================== */
static void feature_plate_03(void) {
    const char *F = "Plate 3";

    S(F, "The ray endpoints") {
        static const int want[12][2] = {
            {152,80},{142,116},{116,142},{80,152},{44,142},{18,116},
            {8,80},{18,44},{44,18},{80,8},{116,18},{142,44}
        };
        int got[12][2];
        ray_ends(got);
        for (int k = 0; k < 12; k++) {
            EQI(got[k][0], want[k][0]);
            EQI(got[k][1], want[k][1]);
        }
    }
    S(F, "Bresenham's fan") {
        Canvas *c = fan_bresenham();
        Bytes p6 = canvas_to_p6(c);
        EQI(c->width, 160);
        EQI(c->height, 160);
        EQP1(p6,  80, 80, 246, 246, 241);
        EQP1(p6, 120, 80, 246, 246, 241);
        EQP1(p6,  10, 10,  39,  39,  44);
        EQP1(p6, 100, 91,  39,  39,  44);
        EQP1(p6, 100, 92, 246, 246, 241);
        free(p6.data); canvas_free(c);
    }
    S(F, "Wu's fan") {
        Canvas *c = fan_wu();
        Bytes p6 = canvas_to_p6(c);
        EQP1(p6,  80, 80, 246, 246, 241);
        EQP1(p6, 120, 80, 246, 246, 241);
        EQP1(p6, 100, 91, 163, 163, 161);
        EQP1(p6, 100, 92, 199, 199, 196);
        free(p6.data); canvas_free(c);
    }
    S(F, "The fan as twelve thin rectangles") {
        Canvas *c = fan_coverage();
        Bytes ref = read_file("reference/chapter-03/fan-coverage.ppm");
        Bytes p6 = canvas_to_p6(c);
        EQI(c->width, 320);
        EQI(c->height, 320);
        EQP1(p6, 160, 160, 246, 246, 241);
        EQP1(p6,  10,  10,  39,  39,  44);
        EQP1(p6, 240, 160, 246, 246, 241);
        EQP1(p6, 240, 158,  39,  39,  44);
        EQP1(p6, 200, 183, 177, 177, 174);
        EQP1(p6, 200, 185, 209, 209, 205);
        if (!ref.data) h_fail("could not read reference/chapter-03/fan-coverage.ppm");
        else { LEI(max_channel_difference(p6, ref), 1); free(ref.data); }
        free(p6.data); canvas_free(c);
    }
    S(F, "Plate 3") {
        Canvas *c = plate_03();
        Bytes ref = read_file("reference/chapter-03/plate-03.ppm");
        Bytes p6 = canvas_to_p6(c);
        EQI(c->width, 640);
        EQI(c->height, 320);
        EQP1(p6, 160, 160, 246, 246, 241);
        EQP1(p6, 480, 160, 246, 246, 241);
        EQP1(p6,  10,  10,  39,  39,  44);
        EQP1(p6, 200, 183,  39,  39,  44);
        EQP1(p6, 200, 185, 246, 246, 241);
        EQP1(p6, 520, 183, 163, 163, 161);
        EQP1(p6, 520, 185, 199, 199, 196);
        if (!ref.data) h_fail("could not read reference/chapter-03/plate-03.ppm");
        else { LEI(max_channel_difference(p6, ref), 1); free(ref.data); }
        free(p6.data); canvas_free(c);
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
    h_subtotal("chapter 1");

    T(feature_shapes);
    T(feature_p6);
    T(feature_magnify);
    T(feature_centers);
    T(feature_paint);
    T(feature_coverage);
    T(feature_twice);
    T(feature_plate_02);
    h_subtotal("chapter 2");

    T(feature_bresenham);
    T(feature_wu);
    T(feature_quad);
    T(feature_plate_03);
    h_subtotal("chapter 3");
    h_report();
    return h_failed ? 1 : 0;
}
