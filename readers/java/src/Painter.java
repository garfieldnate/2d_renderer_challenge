/**
 * §2.5: paint_through(canvas, coverage, color) moves every pixel of the
 * canvas toward the color by that pixel's coverage. Zero coverage leaves a
 * pixel alone, full coverage replaces it, and in between it's mix(pixel,
 * color, coverage), in light. The one place the renderer touches the canvas.
 */
public final class Painter {
    private Painter() {}

    public static void paintThrough(Canvas c, CoverageBuffer cov, Color color) {
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                double k = cov.coverageAt(x, y);
                c.writePixel(x, y, Mixer.mix(c.pixelAt(x, y), color, k));
            }
        }
    }
}
