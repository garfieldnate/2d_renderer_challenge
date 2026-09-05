/**
 * §2.4, §2.6: two ways to turn a shape into a coverage buffer. The first
 * (centers) asks a single yes-or-no question per pixel. The second (the
 * reference method, kept for good) samples an 8-by-8 grid of points per
 * pixel and counts. Pixel (x, y) is the square from (x, y) to (x + 1, y + 1);
 * its center is (x + 0.5, y + 0.5).
 */
public final class Rasterizer {
    private static final int GRID = 8;

    private Rasterizer() {}

    /** 1 if the pixel's center is inside the shape, 0 otherwise. */
    public static double centerInside(Shape s, int x, int y) {
        return s.inside(x + 0.5, y + 0.5) ? 1.0 : 0.0;
    }

    /** The fraction of the pixel's 64 sample points that land inside the shape. */
    public static double coverage(Shape s, int x, int y) {
        int count = 0;
        for (int j = 0; j < GRID; j++) {
            double sy = y + (j + 0.5) / GRID;
            for (int i = 0; i < GRID; i++) {
                double sx = x + (i + 0.5) / GRID;
                if (s.inside(sx, sy)) {
                    count++;
                }
            }
        }
        return count / (double) (GRID * GRID);
    }

    public static CoverageBuffer rasterizeCenters(Shape s, int width, int height) {
        CoverageBuffer cov = new CoverageBuffer(width, height);
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                cov.setCoverage(x, y, centerInside(s, x, y));
            }
        }
        return cov;
    }

    public static CoverageBuffer rasterize(Shape s, int width, int height) {
        CoverageBuffer cov = new CoverageBuffer(width, height);
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                cov.setCoverage(x, y, coverage(s, x, y));
            }
        }
        return cov;
    }
}
