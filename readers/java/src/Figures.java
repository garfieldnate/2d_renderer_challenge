import java.util.ArrayList;
import java.util.List;

/**
 * §1.6, §1.8, §1.9: the five renders chapter 1 asks for, plus §2.5, §2.6,
 * §2.7, §2.8: the four renders chapter 2 asks for, plus §3.1, §3.2, §3.3,
 * §3.4: the fan drawn three ways and the plate that puts two of them
 * side by side, plus §4.6: the fan described as points and transformed in
 * both orders, and the letter F that shows the difference the fan couldn't.
 */
public final class Figures {
    private static final Color PAPER = new Color(0.02, 0.02, 0.025);
    private static final Color INK = new Color(0.9, 0.55, 0.1);
    private static final Color FAN_INK = new Color(0.92, 0.92, 0.88);
    private static final Color DIM = new Color(0.16, 0.16, 0.17);

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

    /** §4.6: the fan, described as points around the origin, center first, twelve ends at radius 36. */
    public static List<Tuple> fanPoints() {
        List<Tuple> pts = new ArrayList<>();
        pts.add(Tuple.point(0, 0));
        for (int k = 0; k < 12; k++) {
            double a = Math.toRadians(k * 30);
            pts.add(Tuple.point(36 * Math.cos(a), 36 * Math.sin(a)));
        }
        return pts;
    }

    /** §4.6: ten corners, clockwise from the top left, in a box 40 wide and 60 tall centered on the origin. */
    public static List<Tuple> letterF() {
        return List.of(
                Tuple.point(-20, -30), Tuple.point(20, -30), Tuple.point(20, -20), Tuple.point(-10, -20),
                Tuple.point(-10, -5), Tuple.point(12, -5), Tuple.point(12, 5), Tuple.point(-10, 5),
                Tuple.point(-10, 30), Tuple.point(-20, 30));
    }

    /** §4.6: the fan's points run through m and drawn as one union of segments. */
    public static Canvas fanTransformed(Matrix m) {
        Canvas c = new Canvas(160, 160);
        c.fill(PAPER);
        List<Tuple> pts = Shapes.transformPoints(fanPoints(), m);
        List<Shape> rays = new ArrayList<>();
        for (int k = 1; k <= 12; k++) {
            rays.add(new Segment(pts.get(0), pts.get(k), 1));
        }
        Painter.paintThrough(c, Rasterizer.rasterize(new Union(rays), 160, 160), FAN_INK);
        return c;
    }

    /** §4.6: copies a into the left half of a wider canvas and b into the right. */
    public static Canvas sideBySide(Canvas a, Canvas b) {
        Canvas out = new Canvas(a.width + b.width, Math.max(a.height, b.height));
        for (int y = 0; y < a.height; y++) {
            for (int x = 0; x < a.width; x++) {
                out.writePixel(x, y, a.pixelAt(x, y));
            }
        }
        for (int y = 0; y < b.height; y++) {
            for (int x = 0; x < b.width; x++) {
                out.writePixel(a.width + x, y, b.pixelAt(x, y));
            }
        }
        return out;
    }

    /** §4.6: the same fan, drawn through rotation(pi/6) and translation(104.5, 76.5), in both orders. */
    public static Canvas fanBothOrders() {
        Matrix turn = Transforms.rotation(Math.PI / 6);
        Matrix move = Transforms.translation(104.5, 76.5);
        return sideBySide(fanTransformed(move.multiply(turn)), fanTransformed(turn.multiply(move)));
    }

    private static Canvas copyOf(Canvas c) {
        Canvas out = new Canvas(c.width, c.height);
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                out.writePixel(x, y, c.pixelAt(x, y));
            }
        }
        return out;
    }

    /** §4.6: the letter F, drawn through both orders next to a dim copy of itself at home. */
    public static Canvas fBothOrders() {
        Matrix turn = Transforms.rotation(Math.PI / 6);
        Matrix move = Transforms.translation(104.5, 76.5);
        Matrix home = Transforms.translation(44.5, 44.5);
        Canvas ghost = new Canvas(160, 160);
        ghost.fill(PAPER);
        Painter.paintThrough(ghost, Rasterizer.rasterize(Shapes.outline(letterF(), home, 1), 160, 160), DIM);
        Canvas a = copyOf(ghost);
        Canvas b = copyOf(ghost);
        Painter.paintThrough(a,
                Rasterizer.rasterize(Shapes.outline(letterF(), move.multiply(turn), 1), 160, 160), FAN_INK);
        Painter.paintThrough(b,
                Rasterizer.rasterize(Shapes.outline(letterF(), turn.multiply(move), 1), 160, 160), FAN_INK);
        return sideBySide(a, b);
    }

    /** §4.6: f_both_orders(), magnified by 2. */
    public static Canvas plate04() {
        return Magnify.magnify(fBothOrders(), 2);
    }

    /**
     * §5.4: the pentagram -- five points on a circle of radius 70 about
     * (80.5, 80.5), the first straight up, visited every second one, closed
     * so the pen crosses itself.
     */
    public static Path star() {
        Path p = new Path();
        for (int k = 0; k < 5; k++) {
            double a = Math.toRadians(-90 + 144 * k);
            Tuple q = Tuple.point(80.5 + 70 * Math.cos(a), 80.5 + 70 * Math.sin(a));
            if (k == 0) {
                p.moveTo(q);
            } else {
                p.lineTo(q);
            }
        }
        p.close();
        return p;
    }

    /**
     * §5.4: one panel of plate 5 -- the star filled under `rule`
     * ("nonzero" or "evenodd"), rasterized by `method` ("centers" or
     * "coverage"), painted onto a 160-by-160 canvas.
     */
    public static Canvas starPanel(String rule, String method) {
        Canvas c = new Canvas(160, 160);
        c.fill(PAPER);
        Path star = star();
        Shape s = Paths.filled(star, rule);
        CoverageBuffer cov = method.equals("centers")
                ? Rasterizer.rasterizeCenters(s, 160, 160)
                : Paths.rasterizeWithin(s, star.bounds(), 160, 160);
        Painter.paintThrough(c, cov, INK);
        return c;
    }

    /** §5.4: the star under both rules, by the center question, side by side. */
    public static Canvas starCenters() {
        return sideBySide(starPanel("nonzero", "centers"), starPanel("evenodd", "centers"));
    }

    /** §5.4: the star under both rules, by coverage within its bounds, side by side. */
    public static Canvas starCoverage() {
        return sideBySide(starPanel("nonzero", "coverage"), starPanel("evenodd", "coverage"));
    }

    /** §5.4: star_centers() over star_coverage(), magnified by 2. */
    public static Canvas plate05() {
        Canvas top = starCenters();
        Canvas bottom = starCoverage();
        Canvas both = new Canvas(320, 320);
        for (int y = 0; y < 160; y++) {
            for (int x = 0; x < 320; x++) {
                both.writePixel(x, y, top.pixelAt(x, y));
                both.writePixel(x, y + 160, bottom.pixelAt(x, y));
            }
        }
        return Magnify.magnify(both, 2);
    }

    /** §6.5: the chapter 5 star, moved to the origin and shrunk to radius 1. */
    public static Path unitStar() {
        return Paths.transformPath(star(),
                Transforms.scaling(1.0 / 70, 1.0 / 70).multiply(Transforms.translation(-80.5, -80.5)));
    }

    /** §6.5: twenty-four unit stars along a spiral, filled nonzero by the sweep, in three inks. */
    public static Canvas spiral() {
        Canvas c = new Canvas(320, 320);
        c.fill(PAPER);
        Color[] inks = {new Color(0.9, 0.55, 0.1), new Color(0.2, 0.55, 0.85), new Color(0.85, 0.25, 0.3)};
        Path unit = unitStar();
        for (int k = 0; k <= 23; k++) {
            double a = Math.toRadians(k * 25);
            double r = 20 + 5 * k;
            Matrix m = Transforms.translation(160.5 + r * Math.cos(a), 160.5 + r * Math.sin(a))
                    .multiply(Transforms.rotation(a))
                    .multiply(Transforms.scaling(6 + 1.25 * k, 6 + 1.25 * k));
            CoverageBuffer cov = Sweep.fillPathAliased(Paths.transformPath(unit, m), "nonzero", 320, 320);
            Painter.paintThrough(c, cov, inks[k % 3]);
        }
        return c;
    }

    /** §6.5: spiral(), magnified by 2. */
    public static Canvas plate06() {
        return Magnify.magnify(spiral(), 2);
    }

    // ---- chapter 7: analytic antialiasing ---------------------------------

    private static final Color[] SPIRAL_INKS = {
        new Color(0.9, 0.55, 0.1), new Color(0.2, 0.55, 0.85), new Color(0.85, 0.25, 0.3)
    };
    private static final Color PALE = new Color(0.92, 0.90, 0.82);

    /**
     * §7.6: a wedge from (cx, cy) out to radius r, spanning angleDeg minus
     * halfDeg to angleDeg plus halfDeg -- the shared shape behind every
     * needle and every ray of the sunburst.
     */
    private static void addWedge(Path p, double cx, double cy, double r, double angleDeg, double halfDeg) {
        double a0 = Math.toRadians(angleDeg - halfDeg);
        double a1 = Math.toRadians(angleDeg + halfDeg);
        p.moveTo(Tuple.point(cx, cy));
        p.lineTo(Tuple.point(cx + r * Math.cos(a0), cy + r * Math.sin(a0)));
        p.lineTo(Tuple.point(cx + r * Math.cos(a1), cy + r * Math.sin(a1)));
        p.close();
    }

    /**
     * §7.6: twelve thin triangles from the center of a 60 by 60 canvas to
     * its rim, thin enough that most of them would fall through chapter
     * 6's center test. Figure 7.1's picture.
     */
    public static Path needlePath() {
        Path p = new Path();
        for (int k = 0; k <= 11; k++) {
            addWedge(p, 30.5, 30.5, 29, 30 * k + 7, 1.6);
        }
        return p;
    }

    /**
     * §7.6: the needles, chapter 6's aliased fill on the left and this
     * chapter's exact fill on the right, each a 60 by 60 canvas magnified
     * by 4.
     */
    public static Canvas needles() {
        Path p = needlePath();
        Canvas left = new Canvas(60, 60);
        left.fill(PAPER);
        Painter.paintThrough(left, Sweep.fillPathAliased(p, "nonzero", 60, 60), INK);
        Canvas right = new Canvas(60, 60);
        right.fill(PAPER);
        Painter.paintThrough(right, Fill.fillPath(p, "nonzero", 60, 60), INK);
        return sideBySide(Magnify.magnify(left, 4), Magnify.magnify(right, 4));
    }

    /**
     * §7.5: a small square whose edges sit on pixel centers, filled
     * exactly, on an 8 by 8 canvas magnified by 24.
     */
    public static Canvas softSquare() {
        Canvas c = new Canvas(8, 8);
        c.fill(PAPER);
        Path square = Paths.polygon(
                Tuple.point(1.5, 1.5), Tuple.point(5.5, 1.5), Tuple.point(5.5, 5.5), Tuple.point(1.5, 5.5));
        Painter.paintThrough(c, Fill.fillPath(square, "nonzero", 8, 8), INK);
        return Magnify.magnify(c, 24);
    }

    /** §7.5: chapter 5's star, filled exactly under both rules, side by side. */
    public static Canvas starExact() {
        return sideBySide(starExactPanel("nonzero"), starExactPanel("evenodd"));
    }

    private static Canvas starExactPanel(String rule) {
        Canvas c = new Canvas(160, 160);
        c.fill(PAPER);
        Painter.paintThrough(c, Fill.fillPath(star(), rule, 160, 160), INK);
        return c;
    }

    /** §7.6: chapter 6's spiral of stars, filled exactly instead of by the sweep. */
    public static Canvas spiralSmooth() {
        Canvas c = new Canvas(320, 320);
        c.fill(PAPER);
        Path unit = unitStar();
        for (int k = 0; k <= 23; k++) {
            double a = Math.toRadians(k * 25);
            double r = 20 + 5 * k;
            Matrix m = Transforms.translation(160.5 + r * Math.cos(a), 160.5 + r * Math.sin(a))
                    .multiply(Transforms.rotation(a))
                    .multiply(Transforms.scaling(6 + 1.25 * k, 6 + 1.25 * k));
            CoverageBuffer cov = Fill.fillPath(Paths.transformPath(unit, m), "nonzero", 320, 320);
            Painter.paintThrough(c, cov, SPIRAL_INKS[k % 3]);
        }
        return c;
    }

    /**
     * §7.6: every third ray of the sunburst -- the rays that wear ink i,
     * seventy-two wedges in all, each a couple of degrees wide, k in i,
     * i + 3, i + 6, ... while k &lt; 72, ray k at angle 5k degrees.
     */
    private static Path rays(int i) {
        Path p = new Path();
        for (int k = i; k < 72; k += 3) {
            addWedge(p, 240, 240, 232, 5.0 * k, 1.4);
        }
        return p;
    }

    /** §7.6: the payoff -- a sunburst, a punched disc and an even-odd star, all filled exactly. */
    public static Canvas sunburst() {
        Canvas c = new Canvas(480, 480);
        c.fill(PAPER);
        for (int i = 0; i <= 2; i++) {
            Painter.paintThrough(c, Fill.fillPath(rays(i), "nonzero", 480, 480), SPIRAL_INKS[i]);
        }
        Path disc = Paths.circlePath(240, 240, 78, 180);
        Painter.paintThrough(c, Fill.fillPath(disc, "nonzero", 480, 480), PAPER);
        Matrix m = Transforms.translation(240, 240).multiply(Transforms.scaling(64, 64));
        Painter.paintThrough(c,
                Fill.fillPath(Paths.transformPath(unitStar(), m), "evenodd", 480, 480), PALE);
        return c;
    }

    /** §7.6: sunburst(). */
    public static Canvas plate07() {
        return sunburst();
    }

    // ---- chapter 8: curves --------------------------------------------------

    /**
     * §8.5: one petal -- two cubics, tip to base and back, bulging out to
     * the sides, about one unit tall, base at the origin. Index 0 is the
     * "right" curve, base to tip bulging toward +x; index 1 is "left", tip
     * back to base bulging toward -x.
     */
    private static Curve[] petal() {
        Tuple base = Tuple.point(0, 0);
        Tuple tip = Tuple.point(0, -1);
        Curve right = Curve.cubic(base, Tuple.point(0.55, -0.35), Tuple.point(0.4, -0.92), tip);
        Curve left = Curve.cubic(tip, Tuple.point(-0.4, -0.92), Tuple.point(-0.55, -0.35), base);
        return new Curve[] {right, left};
    }

    /**
     * §8.5: flower_at(p, m, n, tolerance) -- n petals around the origin,
     * placed by m, each flattened in device space (after the transform) at
     * one shared tolerance.
     */
    private static void flowerAt(Path p, Matrix m, int n, double tolerance) {
        Curve[] pet = petal();
        for (int k = 0; k < n; k++) {
            Matrix spin = m.multiply(Transforms.rotation(2 * Math.PI * k / n));
            Curves.flattenIntoPath(p, Curves.transformCurve(pet[0], spin), tolerance);
            Curves.flattenIntoPath(p, Curves.transformCurve(pet[1], spin), tolerance);
            p.close();
        }
    }

    /** The three flowers' spots: center x, center y, scale, petal count, rotation. */
    private static final double[][] FLOWER_SPOTS = {
        {108, 250, 44, 8, 0.0},
        {200, 145, 74, 8, 0.39},
        {286, 252, 54, 7, 0.8},
    };

    /** §8.5: three flowers of curved petals at three sizes, a disc punched out of each center. */
    public static Canvas flower() {
        Canvas c = new Canvas(360, 360);
        c.fill(PAPER);
        for (int i = 0; i < FLOWER_SPOTS.length; i++) {
            double cx = FLOWER_SPOTS[i][0];
            double cy = FLOWER_SPOTS[i][1];
            double s = FLOWER_SPOTS[i][2];
            int n = (int) FLOWER_SPOTS[i][3];
            double rot = FLOWER_SPOTS[i][4];
            Matrix m = Transforms.translation(cx, cy).multiply(Transforms.scaling(s, s)).multiply(Transforms.rotation(rot));
            Path petals = new Path();
            flowerAt(petals, m, n, 0.2);
            Painter.paintThrough(c, Fill.fillPath(petals, "nonzero", 360, 360), SPIRAL_INKS[i % 3]);
            Path disc = Paths.circlePath(cx, cy, s * 0.3, 64);
            Painter.paintThrough(c, Fill.fillPath(disc, "nonzero", 360, 360), PAPER);
        }
        return c;
    }

    /** §8.5: flower(), magnified by 2. */
    public static Canvas plate08() {
        return Magnify.magnify(flower(), 2);
    }

    /**
     * §8.3: the teardrop -- two cubics in a 60 by 60 box, a round top and a
     * pointed bottom.
     */
    private static Curve[] teardrop() {
        Curve right = Curve.cubic(
                Tuple.point(30.5, 12), Tuple.point(58, 16), Tuple.point(46, 52), Tuple.point(30.5, 52));
        Curve left = Curve.cubic(
                Tuple.point(30.5, 52), Tuple.point(15, 52), Tuple.point(3, 16), Tuple.point(30.5, 12));
        return new Curve[] {right, left};
    }

    /** §8.3: the teardrop, flattened coarse (tolerance 4) on the left and fine (tolerance 0.1) on the right. */
    public static Canvas drops() {
        Curve[] td = teardrop();
        Canvas left = new Canvas(60, 60);
        left.fill(PAPER);
        Canvas right = new Canvas(60, 60);
        right.fill(PAPER);
        double[] tolerances = {4.0, 0.1};
        Canvas[] panels = {left, right};
        for (int i = 0; i < 2; i++) {
            Path q = new Path();
            Curves.flattenIntoPath(q, td[0], tolerances[i]);
            Curves.flattenIntoPath(q, td[1], tolerances[i]);
            q.close();
            Painter.paintThrough(panels[i], Fill.fillPath(q, "nonzero", 60, 60), SPIRAL_INKS[2]);
        }
        return Magnify.magnify(sideBySide(left, right), 4);
    }
}
