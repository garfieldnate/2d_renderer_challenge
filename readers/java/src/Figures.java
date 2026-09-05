/**
 * §1.6, §1.8, §1.9: the five renders chapter 1 asks for, plus §2.5, §2.6,
 * §2.7, §2.8: the four renders chapter 2 asks for, plus §3.1, §3.2, §3.3,
 * §3.4: the fan drawn three ways and the plate that puts two of them
 * side by side.
 */
public final class Figures {
    private static final Color PAPER = new Color(0.02, 0.02, 0.025);
    private static final Color INK = new Color(0.9, 0.55, 0.1);
    private static final Color FAN_INK = new Color(0.92, 0.92, 0.88);

    private Figures() {}

    public static Canvas grayMatch() {
        Canvas c = new Canvas(300, 100);
        for (int y = 0; y <= 99; y++) {
            for (int x = 0; x <= 99; x++) {
                boolean on = (x + y) % 2 == 0;
                c.writePixel(x, y, on ? new Color(1, 1, 1) : new Color(0, 0, 0));
            }
        }
        double g = Srgb.decode(128.0 / 255.0);
        for (int y = 0; y <= 99; y++) {
            for (int x = 100; x <= 199; x++) {
                c.writePixel(x, y, new Color(g, g, g));
            }
        }
        for (int y = 0; y <= 99; y++) {
            for (int x = 200; x <= 299; x++) {
                c.writePixel(x, y, new Color(0.5, 0.5, 0.5));
            }
        }
        return c;
    }

    public static Canvas quarterMatch() {
        Canvas c = new Canvas(200, 100);
        for (int y = 0; y <= 99; y++) {
            for (int x = 0; x <= 99; x++) {
                boolean on = (x + y) % 4 == 0;
                c.writePixel(x, y, on ? new Color(1, 1, 1) : new Color(0, 0, 0));
            }
        }
        for (int y = 0; y <= 99; y++) {
            for (int x = 100; x <= 199; x++) {
                c.writePixel(x, y, new Color(0.25, 0.25, 0.25));
            }
        }
        return c;
    }

    public static Canvas ramp() {
        Canvas c = new Canvas(256, 32);
        for (int x = 0; x <= 255; x++) {
            double g = x / 255.0;
            for (int y = 0; y <= 31; y++) {
                c.writePixel(x, y, new Color(g, g, g));
            }
        }
        return c;
    }

    public static Canvas clampPair() {
        Canvas c = new Canvas(200, 100);
        for (int y = 0; y <= 99; y++) {
            for (int x = 0; x <= 99; x++) {
                c.writePixel(x, y, new Color(2, 0.5, 0.5));
            }
        }
        for (int y = 0; y <= 99; y++) {
            for (int x = 100; x <= 199; x++) {
                c.writePixel(x, y, new Color(1, 0.25, 0.25));
            }
        }
        return c;
    }

    public static Canvas plate01() {
        Canvas c = new Canvas(400, 180);
        Color[][] ramps = {
            {new Color(0, 0, 0), new Color(1, 1, 1)},
            {new Color(0.7, 0, 0), new Color(0, 0.3, 0.02)}
        };
        boolean savedBlending = Mixer.linearBlending;
        try {
            for (int i = 0; i < ramps.length; i++) {
                Color a = ramps[i][0];
                Color b = ramps[i][1];
                int top = i * 90;
                for (int x = 0; x <= 399; x++) {
                    double t = x / 399.0;
                    Mixer.linearBlending = false;
                    Color naive = Mixer.mix(a, b, t);
                    Mixer.linearBlending = true;
                    Color light = Mixer.mix(a, b, t);
                    for (int y = top; y <= top + 39; y++) {
                        c.writePixel(x, y, naive);
                    }
                    for (int y = top + 45; y <= top + 84; y++) {
                        c.writePixel(x, y, light);
                    }
                }
            }
        } finally {
            // The switch is left on: it's turned back on inside the loop
            // above on every iteration, matching the book's rule that a
            // scenario which turns it off must turn it back on.
            Mixer.linearBlending = true;
        }
        return c;
    }

    /** §2.5: a disc rasterized by asking each pixel's center -- the 1985 way. */
    public static Canvas discCenters() {
        Canvas c = new Canvas(40, 40);
        c.fill(PAPER);
        CoverageBuffer cov = Rasterizer.rasterizeCenters(new Circle(20, 20, 16), 40, 40);
        Painter.paintThrough(c, cov, INK);
        return Magnify.magnify(c, 8);
    }

    /** §2.6: disc_centers with rasterize in place of rasterize_centers, nothing else changed. */
    public static Canvas discCoverage() {
        Canvas c = new Canvas(40, 40);
        c.fill(PAPER);
        CoverageBuffer cov = Rasterizer.rasterize(new Circle(20, 20, 16), 40, 40);
        Painter.paintThrough(c, cov, INK);
        return Magnify.magnify(c, 8);
    }

    /** §2.7: the same coverage, painted through once and painted through twice. */
    public static Canvas paintedTwice() {
        Canvas c = new Canvas(80, 40);
        c.fill(PAPER);
        CoverageBuffer cov = Rasterizer.rasterize(new Circle(20, 20, 16), 40, 40);

        CoverageBuffer once = new CoverageBuffer(80, 40); // the disc in both halves
        for (int y = 0; y < 40; y++) {
            for (int x = 0; x < 40; x++) {
                once.setCoverage(x, y, cov.coverageAt(x, y));
                once.setCoverage(x + 40, y, cov.coverageAt(x, y));
            }
        }
        Painter.paintThrough(c, once, INK);

        CoverageBuffer twice = new CoverageBuffer(80, 40); // the disc in the right half only
        for (int y = 0; y < 40; y++) {
            for (int x = 0; x < 40; x++) {
                twice.setCoverage(x + 40, y, cov.coverageAt(x, y));
            }
        }
        Painter.paintThrough(c, twice, INK);

        return Magnify.magnify(c, 6);
    }

    /** §2.8: the same circle, the same grid, the two questions, side by side. */
    public static Canvas plate02() {
        Canvas c = new Canvas(80, 40);
        c.fill(PAPER);
        Shape shape = new Circle(20, 20, 16);
        CoverageBuffer left = Rasterizer.rasterizeCenters(shape, 40, 40);
        CoverageBuffer right = Rasterizer.rasterize(shape, 40, 40);
        CoverageBuffer both = new CoverageBuffer(80, 40);
        for (int y = 0; y < 40; y++) {
            for (int x = 0; x < 40; x++) {
                both.setCoverage(x, y, left.coverageAt(x, y));
                both.setCoverage(x + 40, y, right.coverageAt(x, y));
            }
        }
        Painter.paintThrough(c, both, INK);
        return Magnify.magnify(c, 6);
    }

    /** §3.1: twelve points 72 pixels from (80, 80), one every 30 degrees, rounded to integers. */
    public static int[][] rayEnds() {
        int[][] ends = new int[12][2];
        for (int k = 0; k < 12; k++) {
            double a = Math.toRadians(k * 30);
            ends[k][0] = (int) Numbers.round(80 + 72 * Math.cos(a));
            ends[k][1] = (int) Numbers.round(80 + 72 * Math.sin(a));
        }
        return ends;
    }

    /** §3.1: the fan, drawn with Bresenham -- solid bars on the axes, a beaded texture elsewhere. */
    public static Canvas fanBresenham() {
        Canvas c = new Canvas(160, 160);
        c.fill(PAPER);
        for (int[] end : rayEnds()) {
            Lines.lineBresenham(c, 80, 80, end[0], end[1], FAN_INK);
        }
        return c;
    }

    /** §3.2: the same fan, drawn with Wu -- the beads are gone, but slanted rays carry less ink. */
    public static Canvas fanWu() {
        Canvas c = new Canvas(160, 160);
        c.fill(PAPER);
        for (int[] end : rayEnds()) {
            Lines.lineWu(c, 80, 80, end[0], end[1], FAN_INK);
        }
        return c;
    }

    /** §3.3: the fan a third time, each ray a thick_line rasterized and painted through. */
    public static Canvas fanCoverage() {
        Canvas c = new Canvas(160, 160);
        c.fill(PAPER);
        for (int[] end : rayEnds()) {
            CoverageBuffer cov = Rasterizer.rasterize(
                    new ThickLine(80, 80, end[0], end[1], 1), 160, 160);
            Painter.paintThrough(c, cov, FAN_INK);
        }
        return Magnify.magnify(c, 2);
    }

    /** §3.4: Bresenham's fan and Wu's, side by side, magnified twice. */
    public static Canvas plate03() {
        Canvas both = new Canvas(320, 160);
        Canvas a = fanBresenham();
        Canvas b = fanWu();
        for (int y = 0; y < 160; y++) {
            for (int x = 0; x < 160; x++) {
                both.writePixel(x, y, a.pixelAt(x, y));
                both.writePixel(x + 160, y, b.pixelAt(x, y));
            }
        }
        return Magnify.magnify(both, 2);
    }
}
