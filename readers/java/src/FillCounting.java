/**
 * §21.2: fill_path_counted(p, rule, width, height, st) is chapter 7's
 * fill_path, adding width times height to st.cells, because chapter 7
 * resolves every cell of the canvas whatever the path.
 * draw_coverage_counted(l, cov, paint, alpha, st) is chapter 20's
 * draw_coverage, adding 1 to st.blends for every pixel it composites, the
 * ones whose coverage times alpha is above 0.
 */
public final class FillCounting {
    private FillCounting() {}

    public static CoverageBuffer fillPathCounted(Path p, String rule, int width, int height, Stats st) {
        CoverageBuffer cov = Fill.fillPath(p, rule, width, height);
        st.cells += (long) width * height;
        return cov;
    }

    public static void drawCoverageCounted(Layer l, CoverageBuffer cov, Paint paint, double alpha, Stats st) {
        for (int y = 0; y < l.height; y++) {
            for (int x = 0; x < l.width; x++) {
                double k = cov.coverageAt(x, y) * alpha;
                if (k > 0) {
                    Color c = paint.paintAt(x + 0.5, y + 0.5);
                    l.setPixel(x, y, Compositing.over(Pixel.fromColor(c, k), l.pixelAt(x, y)));
                    st.blends++;
                }
            }
        }
    }
}
