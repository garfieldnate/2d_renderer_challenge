import java.util.ArrayList;
import java.util.List;

/**
 * §3.1: Bresenham's integer-only line algorithm, one pixel lit per step
 * along the longer axis, chosen with a running error term. §3.2: Wu's
 * antialiased version, two pixels per step, weighted by how far the ideal
 * line falls between them and painted with mix.
 */
public final class Lines {
    private Lines() {}

    /**
     * The exact algorithm from the chapter: steep swap so a vertical-ish
     * line walks along y, then a left-to-right swap so the pixels don't
     * depend on which end was named first. Integer arithmetic only.
     */
    public static void lineBresenham(Canvas c, int x0, int y0, int x1, int y1, Color col) {
        boolean steep = Math.abs(y1 - y0) > Math.abs(x1 - x0);
        if (steep) {
            int t = x0; x0 = y0; y0 = t;
            t = x1; x1 = y1; y1 = t;
        }
        if (x0 > x1) {
            int t = x0; x0 = x1; x1 = t;
            t = y0; y0 = y1; y1 = t;
        }
        int dx = x1 - x0;
        int dy = Math.abs(y1 - y0);
        int ystep = (y0 < y1) ? 1 : -1;
        int err = dx / 2;
        int y = y0;
        for (int x = x0; x <= x1; x++) {
            if (steep) {
                c.writePixel(y, x, col);
            } else {
                c.writePixel(x, y, col);
            }
            err -= dy;
            if (err < 0) {
                y += ystep;
                err += dx;
            }
        }
    }

    /**
     * §3.2: paint_through for one pixel. Drops writes off the canvas, same
     * rule as Canvas itself, and skips a weight of zero.
     */
    public static void plot(Canvas c, int x, int y, Color col, double weight) {
        if (weight == 0) {
            return;
        }
        if (x < 0 || x >= c.width || y < 0 || y >= c.height) {
            return;
        }
        c.writePixel(x, y, Mixer.mix(c.pixelAt(x, y), col, weight));
    }

    /**
     * Two pixels per step along the longer axis: the ideal y splits into a
     * whole part and a fraction, and the fraction is the weight of the row
     * below. Integer endpoints only -- see §3.2 for why.
     */
    public static void lineWu(Canvas c, int x0, int y0, int x1, int y1, Color col) {
        boolean steep = Math.abs(y1 - y0) > Math.abs(x1 - x0);
        if (steep) {
            int t = x0; x0 = y0; y0 = t;
            t = x1; x1 = y1; y1 = t;
        }
        if (x0 > x1) {
            int t = x0; x0 = x1; x1 = t;
            t = y0; y0 = y1; y1 = t;
        }
        int dx = x1 - x0;
        double slope = (dx == 0) ? 0 : (double) (y1 - y0) / dx;
        for (int x = x0; x <= x1; x++) {
            double y = y0 + (x - x0) * slope;
            int yi = (int) Math.floor(y);
            double f = y - yi;
            if (steep) {
                plot(c, yi, x, col, 1 - f);
                plot(c, yi + 1, x, col, f);
            } else {
                plot(c, x, yi, col, 1 - f);
                plot(c, x, yi + 1, col, f);
            }
        }
    }

    /**
     * A test helper: every pixel of the canvas that isn't black, as a list
     * of (x, y) pairs in reading order -- top row first, left to right.
     */
    public static List<int[]> litPixels(Canvas c) {
        List<int[]> result = new ArrayList<>();
        Color black = new Color(0, 0, 0);
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                if (!c.pixelAt(x, y).approxEquals(black)) {
                    result.add(new int[] {x, y});
                }
            }
        }
        return result;
    }

    /** The sum of every pixel's red channel: how much paint went down. */
    public static double totalInk(Canvas c) {
        double sum = 0;
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                sum += c.pixelAt(x, y).red;
            }
        }
        return sum;
    }
}
