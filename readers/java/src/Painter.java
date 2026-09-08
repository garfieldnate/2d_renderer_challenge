/**
 * §2.5: paint_through(canvas, coverage, color) moves every pixel of the
 * canvas toward the color by that pixel's coverage. Zero coverage leaves a
 * pixel alone, full coverage replaces it, and in between it's mix(pixel,
 * color, coverage) with the switch forced to the light's way: mix(pixel,
 * color, coverage, true). The browser-style switch has no business inside
 * the rasterizer. The one place the renderer touches the canvas.
 *
 * §10.4: paint_fill(c, cov, paint) is paint_through with the color replaced
 * by a function -- for every covered pixel it samples paint_at at the
 * pixel's center and blends that color in through the coverage, in linear
 * light. A solid paint makes it paint_through exactly.
 */
public final class Painter {
    private Painter() {}

    public static void paintThrough(Canvas c, CoverageBuffer cov, Color color) {
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                double k = cov.coverageAt(x, y);
                c.writePixel(x, y, Mixer.mix(c.pixelAt(x, y), color, k, true));
            }
        }
    }

    public static void paintFill(Canvas c, CoverageBuffer cov, Paint paint) {
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                double k = cov.coverageAt(x, y);
                if (k == 0) {
                    continue;
                }
                Color color = paint.paintAt(x + 0.5, y + 0.5);
                c.writePixel(x, y, Mixer.mix(c.pixelAt(x, y), color, k, true));
            }
        }
    }
}
