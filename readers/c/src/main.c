/* Writes the chapters' pictures into out/: chapter 1's as P3, chapters 2 to 4's as P6. */
#include "renderer.h"
#include <stdio.h>
#include <stdlib.h>

static void save(const char *path, Canvas *c) {
    char *ppm = canvas_to_ppm(c);
    FILE *f = fopen(path, "wb");
    if (!f) { fprintf(stderr, "cannot write %s\n", path); exit(1); }
    fputs(ppm, f);
    fclose(f);
    printf("wrote %s (%dx%d)\n", path, c->width, c->height);
    free(ppm);
    canvas_free(c);
}

static void save_p6(const char *path, Canvas *c) {
    Bytes p6 = canvas_to_p6(c);
    FILE *f = fopen(path, "wb");
    if (!f) { fprintf(stderr, "cannot write %s\n", path); exit(1); }
    fwrite(p6.data, 1, p6.len, f);
    fclose(f);
    printf("wrote %s (%dx%d, P6)\n", path, c->width, c->height);
    free(p6.data);
    canvas_free(c);
}

int main(void) {
    save("out/gray-match.ppm",    gray_match());
    save("out/quarter-match.ppm", quarter_match());
    save("out/ramp.ppm",          ramp());
    save("out/clamp-pair.ppm",    clamp_pair());
    save("out/plate-01.ppm",      plate_01());

    save_p6("out/disc-centers.ppm",  disc_centers());
    save_p6("out/disc-coverage.ppm", disc_coverage());
    save_p6("out/painted-twice.ppm", painted_twice());
    save_p6("out/plate-02.ppm",      plate_02());

    save_p6("out/fan-bresenham.ppm", fan_bresenham());
    save_p6("out/fan-wu.ppm",        fan_wu());
    save_p6("out/fan-coverage.ppm",  fan_coverage());
    save_p6("out/plate-03.ppm",      plate_03());

    save_p6("out/fan-both-orders.ppm", fan_both_orders());
    save_p6("out/plate-04.ppm",        plate_04());
    return 0;
}
