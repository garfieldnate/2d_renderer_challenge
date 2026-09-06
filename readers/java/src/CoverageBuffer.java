/**
 * §2.4: a canvas of numbers instead of colors. One number per pixel, from 0
 * ("none of this pixel is inside") to 1 ("all of it"). Starts at zero.
 * Writes outside the buffer are silently dropped, same rule as Canvas.
 */
public final class CoverageBuffer {
    public final int width;
    public final int height;
    private final double[] values;

    public CoverageBuffer(int width, int height) {
        this.width = width;
        this.height = height;
        this.values = new double[width * height];
    }

    public void setCoverage(int x, int y, double v) {
        if (x < 0 || x >= width || y < 0 || y >= height) {
            return;
        }
        values[y * width + x] = v;
    }

    public double coverageAt(int x, int y) {
        if (x < 0 || x >= width || y < 0 || y >= height) {
            return 0;
        }
        return values[y * width + x];
    }

    /** The sum of every value: the area of the shape, in pixels, as the buffer sees it. */
    public double ink() {
        double sum = 0;
        for (double v : values) {
            sum += v;
        }
        return sum;
    }

    /**
     * §6.3: the largest difference between corresponding entries of two
     * coverage buffers, chapter 1's max_channel_difference for coverage
     * instead of file bytes -- and 1 when the sizes differ, because two
     * buffers of different shapes aren't the same picture.
     */
    public static double maxCoverageDifference(CoverageBuffer a, CoverageBuffer b) {
        if (a.width != b.width || a.height != b.height) {
            return 1.0;
        }
        double max = 0;
        for (int i = 0; i < a.values.length; i++) {
            max = Math.max(max, Math.abs(a.values[i] - b.values[i]));
        }
        return max;
    }
}
