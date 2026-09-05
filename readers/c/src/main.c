/* Writes the chapter's five pictures into out/. */
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

int main(void) {
    save("out/gray-match.ppm",    gray_match());
    save("out/quarter-match.ppm", quarter_match());
    save("out/ramp.ppm",          ramp());
    save("out/clamp-pair.ppm",    clamp_pair());
    save("out/plate-01.ppm",      plate_01());
    return 0;
}
