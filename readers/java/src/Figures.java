import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

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

    // ---- chapter 9: compositing ------------------------------------------

    private static final Color DST9 = new Color(0.2, 0.5, 0.85);
    private static final Color SRC9 = new Color(0.95, 0.55, 0.1);
    private static final int TILE = 64;

    private static final String[] PORTER_DUFF_OPS = {
        "clear", "src", "dst", "src-over", "dst-over", "src-in", "dst-in",
        "src-out", "dst-out", "src-atop", "dst-atop", "xor"
    };

    private static final String[] BLEND_MODE_NAMES = {
        "normal", "multiply", "screen", "overlay", "darken", "lighten",
        "color-dodge", "color-burn", "hard-light", "soft-light", "difference", "exclusion",
        "hue", "saturation", "color", "luminosity"
    };

    /** §9.6: a layer with a 32 by 32 blue square painted into a 64 by 64 tile. */
    private static Layer dstLayer9() {
        Layer l = new Layer(TILE, TILE);
        Path square = Paths.polygon(
                Tuple.point(10, 10), Tuple.point(42, 10), Tuple.point(42, 42), Tuple.point(10, 42));
        Layers.paintShape(l, Fill.fillPath(square, "nonzero", TILE, TILE), DST9);
        return l;
    }

    /** §9.6: a layer with an orange circle painted into a 64 by 64 tile. */
    private static Layer srcLayer9() {
        Layer l = new Layer(TILE, TILE);
        Path circle = Paths.circlePath(38, 38, 20, 48);
        Layers.paintShape(l, Fill.fillPath(circle, "nonzero", TILE, TILE), SRC9);
        return l;
    }

    /** §9.6: lay one flattened tile per name into a grid four columns wide, over paper. */
    private static Canvas tileGrid(int count, java.util.function.IntFunction<Canvas> tileAt) {
        int cols = 4;
        int rows = (count + cols - 1) / cols;
        Canvas c = new Canvas(cols * TILE, rows * TILE);
        c.fill(PAPER);
        for (int i = 0; i < count; i++) {
            Canvas tile = tileAt.apply(i);
            int ox = (i % cols) * TILE;
            int oy = (i / cols) * TILE;
            for (int y = 0; y < TILE; y++) {
                for (int x = 0; x < TILE; x++) {
                    c.writePixel(ox + x, oy + y, tile.pixelAt(x, y));
                }
            }
        }
        return c;
    }

    /**
     * §9.6: porter_duff_table() -- a blue square as destination, an orange
     * circle as source, each of the twelve operators composited and
     * flattened over paper, laid four to a row.
     */
    public static Canvas porterDuffTable() {
        Layer src = srcLayer9();
        Layer dst = dstLayer9();
        return tileGrid(PORTER_DUFF_OPS.length, i ->
                Layers.flattenLayer(Layers.compositeLayers(PORTER_DUFF_OPS[i], src, dst), PAPER));
    }

    /** §9.6: plate_09() -- porter_duff_table(), magnified by 2. */
    public static Canvas plate09() {
        return Magnify.magnify(porterDuffTable(), 2);
    }

    /** §9.6: blend_strip() -- the same square and circle, all sixteen blend modes, four to a row. */
    public static Canvas blendStrip() {
        Layer src = srcLayer9();
        Layer dst = dstLayer9();
        return tileGrid(BLEND_MODE_NAMES.length, i ->
                Layers.flattenLayer(Layers.blendLayers(BLEND_MODE_NAMES[i], src, dst), PAPER));
    }

    /**
     * §9.6, the trap: seam() -- two opaque triangles sharing the diagonal
     * of an 80 by 80 square, each composited src-over the one before, so
     * the shared edge's antialiasing double-counts and leaves a seam where
     * the square should read as one solid color.
     */
    public static Canvas seam() {
        int w = 80;
        Layer base = new Layer(w, w);
        for (int y = 0; y < w; y++) {
            for (int x = 0; x < w; x++) {
                base.setPixel(x, y, Pixel.opaque(PAPER));
            }
        }
        Path[] tris = {
            Paths.polygon(Tuple.point(4, 4), Tuple.point(76, 76), Tuple.point(4, 76)),
            Paths.polygon(Tuple.point(4, 4), Tuple.point(76, 4), Tuple.point(76, 76))
        };
        for (Path tri : tris) {
            Layer s = new Layer(w, w);
            Layers.paintShape(s, Fill.fillPath(tri, "nonzero", w, w), SRC9);
            Layer next = new Layer(w, w);
            for (int y = 0; y < w; y++) {
                for (int x = 0; x < w; x++) {
                    next.setPixel(x, y, Compositing.composite("src-over", s.pixelAt(x, y), base.pixelAt(x, y)));
                }
            }
            base = next;
        }
        Canvas c = new Canvas(w, w);
        for (int y = 0; y < w; y++) {
            for (int x = 0; x < w; x++) {
                c.writePixel(x, y, base.pixelAt(x, y).pixelColor());
            }
        }
        return Magnify.magnify(c, 4);
    }

    // ---- chapter 10: paint servers and gradients --------------------------

    private static final java.util.List<Stop> SUNSET = java.util.List.of(
            new Stop(0.0, new Color(0.05, 0.02, 0.15)),
            new Stop(0.35, new Color(0.75, 0.15, 0.25)),
            new Stop(0.7, new Color(0.98, 0.6, 0.15)),
            new Stop(1.0, new Color(1.0, 0.95, 0.75)));

    private static CoverageBuffer fullCoverage(int w, int h) {
        CoverageBuffer cov = new CoverageBuffer(w, h);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                cov.setCoverage(x, y, 1.0);
            }
        }
        return cov;
    }

    /**
     * §10.6: three_gradients() -- one sunset stop table, addressed three
     * ways: a linear ramp across the diagonal, a focal radial with its
     * highlight up and to the left, and a conic sweep, each a 150 by 150
     * panel, left to right with a 4 pixel gap.
     */
    public static Canvas threeGradients() {
        LinearGradient lin = new LinearGradient(Tuple.point(10, 10), Tuple.point(140, 140), SUNSET, "pad");
        RadialGradient rad = new RadialGradient(Tuple.point(55, 55), 0, Tuple.point(75, 75), 85, SUNSET, "pad");
        ConicGradient con = new ConicGradient(Tuple.point(75, 75), -Math.PI / 2, SUNSET, "pad");
        Paint[] paints = {lin, rad, con};
        int panel = 150;
        int gap = 4;
        Canvas c = new Canvas(panel * 3 + gap * 2, panel);
        c.fill(PAPER);
        CoverageBuffer full = fullCoverage(panel, panel);
        for (int i = 0; i < 3; i++) {
            Canvas p = new Canvas(panel, panel);
            Painter.paintFill(p, full, paints[i]);
            int ox = i * (panel + gap);
            for (int y = 0; y < panel; y++) {
                for (int x = 0; x < panel; x++) {
                    c.writePixel(ox + x, y, p.pixelAt(x, y));
                }
            }
        }
        return c;
    }

    /** §10.6: plate_10() is three_gradients(). */
    public static Canvas plate10() {
        return threeGradients();
    }

    /**
     * §10.2: extend_strip() -- one short gradient (axis only the middle
     * third of the strip), stacked three ways: pad, repeat, reflect, each
     * 30 rows of a 180 by 90 canvas, magnified by 2.
     */
    public static Canvas extendStrip() {
        int w = 180;
        int h = 90;
        java.util.List<Stop> stops = java.util.List.of(
                new Stop(0, new Color(0.1, 0.15, 0.5)), new Stop(1, new Color(1.0, 0.7, 0.1)));
        String[] modes = {"pad", "repeat", "reflect"};
        Canvas c = new Canvas(w, h);
        for (int r = 0; r < modes.length; r++) {
            LinearGradient g = new LinearGradient(Tuple.point(60, 0), Tuple.point(100, 0), stops, modes[r]);
            for (int y = r * 30; y < r * 30 + 30; y++) {
                for (int x = 0; x < w; x++) {
                    c.writePixel(x, y, g.paintAt(x + 0.5, y + 0.5));
                }
            }
        }
        return Magnify.magnify(c, 2);
    }

    // ---- chapter 11: images and resampling --------------------------------

    private static final Color SPRITE_K = new Color(0.06, 0.06, 0.08);
    private static final Color SPRITE_B = new Color(0.15, 0.45, 0.85);
    private static final Color SPRITE_W = new Color(0.95, 0.93, 0.85);
    private static final Color SPRITE_O = new Color(0.95, 0.55, 0.1);

    /** §11.5: the 8-by-8 sprite -- built as a canvas, written to a PPM, and read straight back. */
    public static Image sprite() {
        Color[] palette = {SPRITE_K, SPRITE_B, SPRITE_W, SPRITE_O};
        int[] grid = {
            0, 0, 1, 1, 1, 1, 0, 0,
            0, 1, 1, 1, 1, 1, 1, 0,
            1, 1, 2, 1, 1, 2, 1, 1,
            1, 1, 2, 1, 1, 2, 1, 1,
            1, 1, 1, 1, 1, 1, 1, 1,
            3, 1, 1, 3, 3, 1, 1, 3,
            0, 3, 3, 1, 1, 3, 3, 0,
            0, 0, 3, 3, 3, 3, 0, 0,
        };
        Canvas c = new Canvas(8, 8);
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x++) {
                c.writePixel(x, y, palette[grid[y * 8 + x]]);
            }
        }
        return Images.readImage(Ppm.canvasToP6(c));
    }

    /**
     * §11.5: the sprite scaled up k times through one filter, sampled at
     * each output pixel's centre in image space -- (x + 0.5) / k, (y + 0.5)
     * / k -- clamped at the edge.
     */
    public static Canvas magnified(Image img, int k, String filter) {
        Canvas c = new Canvas(img.width * k, img.height * k);
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                double sx = (x + 0.5) / k;
                double sy = (y + 0.5) / k;
                Pixel p = Sampling.sample(img, sx, sy, filter, "clamp");
                c.writePixel(x, y, p.pixelColor());
            }
        }
        return c;
    }

    /** §11.5: the sprite magnified 20x, nearest on the left, bilinear on the right. */
    public static Canvas twoFilters() {
        Image s = sprite();
        return sideBySide(magnified(s, 20, "nearest"), magnified(s, 20, "bilinear"));
    }

    /** §11.5: plate_11() is two_filters(). */
    public static Canvas plate11() {
        return twoFilters();
    }

    /** §11.5: the sprite magnified 16x, nearest, bilinear and bicubic, three across. */
    public static Canvas threeFilters() {
        Image s = sprite();
        return sideBySide(
                sideBySide(magnified(s, 16, "nearest"), magnified(s, 16, "bilinear")),
                magnified(s, 16, "bicubic"));
    }

    // ---- chapter 12: clipping, masks and groups ----------------------------

    private static final Color[] GROUP_INKS = {
        new Color(0.95, 0.55, 0.1), new Color(0.2, 0.55, 0.85), new Color(0.85, 0.25, 0.3)
    };

    private record CircleInk(Path path, Color color) {}

    /** §12.4: three overlapping circles in three inks, on a 150 by 150 stage. */
    private static List<CircleInk> threeCircles() {
        double[][] centers = {{60, 62}, {90, 62}, {75, 92}};
        List<CircleInk> out = new ArrayList<>();
        for (int i = 0; i < centers.length; i++) {
            Path p = Paths.circlePath(centers[i][0], centers[i][1], 34, 64);
            out.add(new CircleInk(p, GROUP_INKS[i]));
        }
        return out;
    }

    private static Canvas layerToCanvas(Layer l) {
        Canvas c = new Canvas(l.width, l.height);
        for (int y = 0; y < l.height; y++) {
            for (int x = 0; x < l.width; x++) {
                c.writePixel(x, y, l.pixelAt(x, y).pixelColor());
            }
        }
        return c;
    }

    private static final int GROUP_SIZE = 150;

    private static Layer opaquePaper(int w, int h) {
        Layer l = new Layer(w, h);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                l.setPixel(x, y, Pixel.opaque(PAPER));
            }
        }
        return l;
    }

    /** §12.3: each circle painted straight onto the canvas at 50% opacity -- the overlaps double-composite. */
    public static Canvas perChild() {
        Layer base = opaquePaper(GROUP_SIZE, GROUP_SIZE);
        for (CircleInk ci : threeCircles()) {
            CoverageBuffer cov = Fill.fillPath(ci.path(), "nonzero", GROUP_SIZE, GROUP_SIZE);
            base = Groups.paintInto(base, cov, ci.color(), 0.5);
        }
        return layerToCanvas(base);
    }

    /** §12.3: the three circles drawn opaque into a group, the group composited once at 50%. */
    public static Canvas groupOpacity() {
        Layer base = opaquePaper(GROUP_SIZE, GROUP_SIZE);
        Layer group = Groups.pushGroup(GROUP_SIZE, GROUP_SIZE);
        for (CircleInk ci : threeCircles()) {
            CoverageBuffer cov = Fill.fillPath(ci.path(), "nonzero", GROUP_SIZE, GROUP_SIZE);
            group = Groups.paintInto(group, cov, ci.color(), 1.0);
        }
        return layerToCanvas(Groups.popGroupWithOpacity(group, base, 0.5));
    }

    /** §12.4: per_child() and group_opacity(), side by side. */
    public static Canvas opacityPlate() {
        return sideBySide(perChild(), groupOpacity());
    }

    /** §12.4: plate_12() is opacity_plate(), magnified by 2. */
    public static Canvas plate12() {
        return Magnify.magnify(opacityPlate(), 2);
    }

    /**
     * §12.4: clip_demo() -- one pentagram, shown two ways on a 300 by 150
     * stage: on the left, filled and clipped hard to a circle;
     * on the right, the same fill multiplied by a soft radial mask, so its
     * interior stays full strength and only its rim fades.
     */
    public static Canvas clipDemo() {
        double cx = 75;
        double cy = 75;
        double r = 60;
        Path star = Paths.transformPath(unitStar(), Transforms.translation(cx, cy).multiply(Transforms.scaling(r, r)));
        CoverageBuffer starCoverage = Fill.fillPath(star, "nonzero", GROUP_SIZE, GROUP_SIZE);

        Canvas left = new Canvas(GROUP_SIZE, GROUP_SIZE);
        left.fill(PAPER);
        CoverageBuffer circleClip = Clipping.clipPath(Paths.circlePath(cx, cy, 45, 64), "nonzero", GROUP_SIZE, GROUP_SIZE);
        Painter.paintThrough(left, Clipping.multiplyCoverage(starCoverage, circleClip), GROUP_INKS[0]);

        Canvas right = new Canvas(GROUP_SIZE, GROUP_SIZE);
        right.fill(PAPER);
        CoverageBuffer mask = Clipping.softMask(cx, cy, 70, GROUP_SIZE, GROUP_SIZE);
        Painter.paintThrough(right, Clipping.multiplyCoverage(starCoverage, mask), GROUP_INKS[0]);

        return sideBySide(left, right);
    }

    // ---------------------------------------------------------------------
    // Chapter 13: stroking is filling.

    private static final Color STROKE_GRAY = new Color(0.62, 0.62, 0.66);
    private static final Color STROKE_MAGENTA = new Color(0.85, 0.2, 0.55);
    private static final int STROKE_SIZE = 160;
    private static final int CAP_HEIGHT = 80;

    /** §13.1, §13.5: chevron() -- the open "V" the plate strokes three ways. */
    public static Path chevron() {
        Path p = new Path();
        p.moveTo(Tuple.point(30, 40));
        p.lineTo(Tuple.point(80, 120));
        p.lineTo(Tuple.point(130, 40));
        return p;
    }

    /**
     * §13.2: u_turn() -- nine points on the upper half of a circle of
     * radius 10 about (50, 50), from 180 degrees to 360 degrees in steps
     * of 22.5 degrees, stroked wide enough to overlap itself all the way
     * round the bend.
     */
    public static Path uTurn() {
        Path p = new Path();
        for (int i = 0; i <= 8; i++) {
            double deg = 180 + 22.5 * i;
            double rad = Math.toRadians(deg);
            Tuple pt = Tuple.point(50 + 10 * Math.cos(rad), 50 + 10 * Math.sin(rad));
            if (i == 0) {
                p.moveTo(pt);
            } else {
                p.lineTo(pt);
            }
        }
        return p;
    }

    /**
     * §13.5: one panel of the plate -- the chevron stroked with the given
     * join, filled gray, with the generated outline traced over it in
     * magenta (chapter 3's line_wu, integer endpoints, so the outline's
     * coordinates are rounded).
     */
    private static Canvas strokePanel(String join) {
        return tracedPanel(chevron(), 26, "butt", join, STROKE_SIZE, STROKE_SIZE);
    }

    private static Canvas tracedPanel(Path path, double width, String cap, String join, int w, int h) {
        Canvas c = new Canvas(w, h);
        c.fill(PAPER);
        Path outline = Stroke.strokeToPath(path, width, cap, join, 4.0);
        CoverageBuffer cov = Fill.fillPath(outline, "nonzero", w, h);
        Painter.paintThrough(c, cov, STROKE_GRAY);
        for (Edge e : outline.edges()) {
            Lines.lineWu(c, (int) Numbers.round(e.a().x), (int) Numbers.round(e.a().y),
                    (int) Numbers.round(e.b().x), (int) Numbers.round(e.b().y), STROKE_MAGENTA);
        }
        return c;
    }

    private static Canvas threeAcross(Canvas a, Canvas b, Canvas c, int panelW, int panelH) {
        Canvas out = new Canvas(3 * panelW, panelH);
        for (int y = 0; y < panelH; y++) {
            for (int x = 0; x < panelW; x++) {
                out.writePixel(x, y, a.pixelAt(x, y));
                out.writePixel(x + panelW, y, b.pixelAt(x, y));
                out.writePixel(x + 2 * panelW, y, c.pixelAt(x, y));
            }
        }
        return out;
    }

    /** §13.5: joins_plate() -- the chevron stroked miter, round, bevel, each outline traced in magenta. */
    public static Canvas joinsPlate() {
        return threeAcross(strokePanel("miter"), strokePanel("round"), strokePanel("bevel"),
                STROKE_SIZE, STROKE_SIZE);
    }

    /** §13.5: plate_13() -- joins_plate(), magnified by 2. */
    public static Canvas plate13() {
        return Magnify.magnify(joinsPlate(), 2);
    }

    /** §13.4: caps_demo() -- one horizontal segment stroked with butt, round and square caps. */
    public static Canvas capsDemo() {
        Path seg = new Path();
        seg.moveTo(Tuple.point(45, 40));
        seg.lineTo(Tuple.point(115, 40));
        Canvas butt = tracedPanel(seg, 30, "butt", "miter", STROKE_SIZE, CAP_HEIGHT);
        Canvas round = tracedPanel(seg, 30, "round", "miter", STROKE_SIZE, CAP_HEIGHT);
        Canvas square = tracedPanel(seg, 30, "square", "miter", STROKE_SIZE, CAP_HEIGHT);
        return threeAcross(butt, round, square, STROKE_SIZE, CAP_HEIGHT);
    }

    // ---------------------------------------------------------------------
    // Chapter 14: offsetting curves.

    private static final Color WHITE_INK = new Color(0.9, 0.9, 0.92);
    private static final Color[] WARM = {
        new Color(0.95, 0.75, 0.2), new Color(0.95, 0.55, 0.15),
        new Color(0.9, 0.35, 0.15), new Color(0.8, 0.2, 0.2)
    };
    private static final Color[] COOL = {
        new Color(0.35, 0.8, 0.9), new Color(0.25, 0.6, 0.9),
        new Color(0.3, 0.4, 0.85), new Color(0.45, 0.3, 0.8)
    };
    private static final int CURVE_SIZE = 160;

    /** §14.1, §14.5: hairpin() -- a cubic that bends back on itself, tightest radius about 8. */
    public static Curve hairpin() {
        return Curve.cubic(Tuple.point(35, 140), Tuple.point(65, -30), Tuple.point(95, -30), Tuple.point(125, 140));
    }

    /** §14.6: arch() -- the cubic the plate offsets on both sides. */
    public static Curve arch() {
        return Curve.cubic(Tuple.point(60, 250), Tuple.point(130, 5), Tuple.point(190, 5), Tuple.point(260, 250));
    }

    /**
     * §14.5: one panel showing an already-built outline -- filled gray under
     * the given rule, with every edge traced over it in magenta.
     */
    private static Canvas outlinePanel(Path outline, String rule, int w, int h) {
        Canvas c = new Canvas(w, h);
        c.fill(PAPER);
        CoverageBuffer cov = Fill.fillPath(outline, rule, w, h);
        Painter.paintThrough(c, cov, STROKE_GRAY);
        for (Edge e : outline.edges()) {
            Lines.lineWu(c, (int) Numbers.round(e.a().x), (int) Numbers.round(e.a().y),
                    (int) Numbers.round(e.b().x), (int) Numbers.round(e.b().y), STROKE_MAGENTA);
        }
        return c;
    }

    /** §14.5: two_strokes() -- the hairpin stroked flatten-first on the left, one outline on the right. */
    public static Canvas twoStrokes() {
        Path flattened = Offset.flattenThenStroke(hairpin(), 60, "butt", 0.25);
        Path outline = Offset.strokeCurveToPath(hairpin(), 60, "butt", 0.25);
        return sideBySide(
                outlinePanel(flattened, "nonzero", CURVE_SIZE, CURVE_SIZE),
                outlinePanel(outline, "nonzero", CURVE_SIZE, CURVE_SIZE));
    }

    /** §14.5: fold_demo() -- the outline filled nonzero on the left, even-odd on the right. */
    public static Canvas foldDemo() {
        Path outline = Offset.strokeCurveToPath(hairpin(), 60, "butt", 0.25);
        return sideBySide(
                outlinePanel(outline, "nonzero", CURVE_SIZE, CURVE_SIZE),
                outlinePanel(outline, "evenodd", CURVE_SIZE, CURVE_SIZE));
    }

    /** §14.6: one hairline-thin stroke of a raw polyline, painted through the canvas. */
    private static void hairline(Canvas c, List<Tuple> pts, Color col, double width) {
        Path p = new Path();
        boolean first = true;
        for (Tuple pt : pts) {
            if (first) {
                p.moveTo(pt);
                first = false;
            } else {
                p.lineTo(pt);
            }
        }
        Path outline = Stroke.strokeToPath(p, width, "butt", "round", 4.0);
        CoverageBuffer cov = Fill.fillPath(outline, "nonzero", c.width, c.height);
        Painter.paintThrough(c, cov, col);
    }

    /**
     * §14.6: offsets_plate() -- arch(), its offsets at 15, 30, 45 and 60 on
     * both sides (warm where they fold, cool outside), the curve itself in
     * white, and every cusp a magenta dot.
     */
    public static Canvas offsetsPlate() {
        int w = 320;
        int h = 270;
        Canvas c = new Canvas(w, h);
        c.fill(PAPER);
        Curve curve = arch();
        double[] ds = {15, 30, 45, 60};
        for (int k = 0; k < ds.length; k++) {
            hairline(c, Offset.offsetPath(curve, -ds[k], 0.1), COOL[k], 1.5);
        }
        for (int k = 0; k < ds.length; k++) {
            hairline(c, Offset.offsetPath(curve, ds[k], 0.1), WARM[k], 1.5);
        }
        hairline(c, Curves.flatten(curve, 0.1), WHITE_INK, 2.0);
        for (double d : ds) {
            for (double t : Offset.cusps(curve, d)) {
                Tuple q = Offset.offsetPoint(curve, t, d);
                Path dot = Paths.circlePath(q.x, q.y, 2.5, 24);
                CoverageBuffer cov = Fill.fillPath(dot, "nonzero", w, h);
                Painter.paintThrough(c, cov, STROKE_MAGENTA);
            }
        }
        return c;
    }

    /** §14.6: plate_14() -- offsets_plate(), magnified by 2. */
    public static Canvas plate14() {
        return Magnify.magnify(offsetsPlate(), 2);
    }

    // ---------------------------------------------------------------------
    // Chapter 15: dashes.

    private static final Color DASH_DIM = new Color(0.25, 0.25, 0.28);
    private static final Color[] DASH_INKS = {
        new Color(0.9, 0.55, 0.1), new Color(0.2, 0.55, 0.85), new Color(0.85, 0.25, 0.3)
    };
    private static final double GOLDEN_KAPPA = 0.5522847498;

    /** §15.1: lopsided() -- one short handle, one long, so the parameter and the length disagree. */
    public static Curve lopsided() {
        return Curve.cubic(Tuple.point(15, 100), Tuple.point(25, 85), Tuple.point(100, 5), Tuple.point(185, 95));
    }

    private static void strokeOpenAndPaint(Canvas c, Path open, double width, Color color) {
        Path outline = Stroke.strokeToPath(open, width, "butt", "round", 4.0);
        Painter.paintThrough(c, Fill.fillPath(outline, "nonzero", c.width, c.height), color);
    }

    private static void dot(Canvas c, Tuple q, double r, Color color) {
        Path circle = Paths.circlePath(q.x, q.y, r, 24);
        Painter.paintThrough(c, Fill.fillPath(circle, "nonzero", c.width, c.height), color);
    }

    /** §15.1: even_marks() -- lopsided() with eleven marks, by parameter on the left, by length on the right. */
    public static Canvas evenMarks() {
        int w = 200;
        int h = 120;
        Curve c = lopsided();
        Path spine = new Path();
        Curves.flattenIntoPath(spine, c, 0.1);

        Canvas left = new Canvas(w, h);
        left.fill(PAPER);
        Canvas right = new Canvas(w, h);
        right.fill(PAPER);
        strokeOpenAndPaint(left, spine, 1.5, DASH_DIM);
        strokeOpenAndPaint(right, spine, 1.5, DASH_DIM);

        double totalLength = Length.arcLength(c, 256);
        for (int i = 0; i <= 10; i++) {
            dot(left, Curves.pointAt(c, i / 10.0), 3, DASH_INKS[0]);
            dot(right, Length.pointAtLength(c, totalLength * i / 10.0, 256), 3, DASH_INKS[1]);
        }
        return sideBySide(left, right);
    }

    /** §15.5: wave(dy) -- one flattened cubic wave, offset vertically by dy. */
    private static Path wave(double dy) {
        Curve c = Curve.cubic(Tuple.point(20, 20 + dy), Tuple.point(120, -20 + dy),
                Tuple.point(200, 60 + dy), Tuple.point(300, 20 + dy));
        Path p = new Path();
        Curves.flattenIntoPath(p, c, 0.1);
        return p;
    }

    /** §15.4: dash_strip() -- one wave four ways: solid, dashed, the same at a phase, and dotted. */
    public static Canvas dashStrip() {
        int w = 320;
        int h = 160;
        Canvas c = new Canvas(w, h);
        c.fill(PAPER);
        Object[][] rows = {
            {new double[0], 0.0, "butt", STROKE_GRAY},
            {new double[] {12, 6}, 0.0, "butt", DASH_INKS[0]},
            {new double[] {12, 6}, 9.0, "butt", DASH_INKS[1]},
            {new double[] {0, 9}, 0.0, "round", DASH_INKS[2]},
        };
        for (int k = 0; k < rows.length; k++) {
            double[] pattern = (double[]) rows[k][0];
            double phase = (double) rows[k][1];
            String cap = (String) rows[k][2];
            Color color = (Color) rows[k][3];
            Path dashed = Dash.dash(wave(40.0 * k), pattern, phase);
            Path outline = Stroke.strokeToPath(dashed, 5, cap, "round", 4.0);
            Painter.paintThrough(c, Fill.fillPath(outline, "nonzero", w, h), color);
        }
        return c;
    }

    /**
     * §15.5: golden_spiral() -- seven quarter circles, each phi times the
     * radius of the last and tangent to it, flattened into one open
     * subpath.
     */
    public static Path goldenSpiral() {
        Path p = new Path();
        double r = 6;
        double cx = 148;
        double cy = 130;
        double theta = Math.PI;
        double phi = (1 + Math.sqrt(5)) / 2;
        for (int k = 0; k < 7; k++) {
            double a0 = theta;
            double a1 = theta + Math.PI / 2;
            Tuple d0 = Tuple.vector(Math.cos(a0), Math.sin(a0));
            Tuple d1 = Tuple.vector(Math.cos(a1), Math.sin(a1));
            Tuple p0 = Tuple.point(cx + r * d0.x, cy + r * d0.y);
            Tuple p3 = Tuple.point(cx + r * d1.x, cy + r * d1.y);
            Tuple p1 = p0.add(d1.scale(GOLDEN_KAPPA * r));
            Tuple p2 = p3.add(d0.scale(GOLDEN_KAPPA * r));
            Curves.flattenIntoPath(p, Curve.cubic(p0, p1, p2, p3), 0.05);
            double nr = r * phi;
            cx = p3.x - nr * d1.x;
            cy = p3.y - nr * d1.y;
            r = nr;
            theta = a1;
        }
        return p;
    }

    private static Path singleSubpath(Subpath sp) {
        Path p = new Path();
        boolean first = true;
        for (Tuple pt : sp.points) {
            if (first) {
                p.moveTo(pt);
                first = false;
            } else {
                p.lineTo(pt);
            }
        }
        if (sp.closed) {
            p.close();
        }
        return p;
    }

    /**
     * §15.5: spiral_dashes() -- the spiral drawn faintly, then dashed 16 on
     * 10 off, each dash stroked 7 wide with round caps in the next of
     * three inks.
     */
    public static Canvas spiralDashes() {
        int w = 340;
        int h = 340;
        Canvas c = new Canvas(w, h);
        c.fill(PAPER);
        Path spiral = goldenSpiral();
        strokeOpenAndPaint(c, spiral, 1.0, DASH_DIM);
        Path dashed = Dash.dash(spiral, new double[] {16, 10}, 0);
        List<Subpath> subs = dashed.subpaths();
        for (int k = 0; k < subs.size(); k++) {
            Path one = singleSubpath(subs.get(k));
            Path outline = Stroke.strokeToPath(one, 7, "round", "round", 4.0);
            Painter.paintThrough(c, Fill.fillPath(outline, "nonzero", w, h), DASH_INKS[k % 3]);
        }
        return c;
    }

    /** §15.5: plate_15() -- spiral_dashes(), magnified by 2. */
    public static Canvas plate15() {
        return Magnify.magnify(spiralDashes(), 2);
    }

    // ---------------------------------------------------------------------
    // Chapter 16: what a glyph is.

    private static final Color GLYPH_GRAY = new Color(0.62, 0.62, 0.66);
    private static final Color GLYPH_DIM = new Color(0.3, 0.3, 0.34);
    private static final Color GLYPH_MAGENTA = new Color(0.85, 0.2, 0.55);
    private static final Color GLYPH_CYAN = new Color(0.2, 0.75, 0.9);
    private static final Color[] GLYPH_INKS = {
        new Color(0.9, 0.55, 0.1), new Color(0.2, 0.55, 0.85), new Color(0.85, 0.25, 0.3)
    };

    /** §16.1: the book's font, loaded fresh every time a render needs it. */
    static Font robotoFont() {
        try {
            String text = java.nio.file.Files.readString(
                    java.nio.file.Path.of("reference/chapter-16/roboto.json"));
            return Fonts.loadFont(text);
        } catch (java.io.IOException e) {
            throw new RuntimeException(e);
        }
    }

    private static Path squarePath(Tuple q, double half) {
        Path p = new Path();
        p.moveTo(Tuple.point(q.x - half, q.y - half));
        p.lineTo(Tuple.point(q.x + half, q.y - half));
        p.lineTo(Tuple.point(q.x + half, q.y + half));
        p.lineTo(Tuple.point(q.x - half, q.y + half));
        p.close();
        return p;
    }

    /** A hairline through a list of points, closed or open, in the given color -- §13's stroke, butt/round, width 1. */
    private static void paintHairline(Canvas c, List<Tuple> pts, boolean closed, Color color, double width) {
        Path p = new Path();
        boolean first = true;
        for (Tuple pt : pts) {
            if (first) {
                p.moveTo(pt);
                first = false;
            } else {
                p.lineTo(pt);
            }
        }
        if (closed) {
            p.close();
        }
        Path outline = Stroke.strokeToPath(p, width, "butt", "round", 4.0);
        Painter.paintThrough(c, Fill.fillPath(outline, "nonzero", c.width, c.height), color);
    }

    /**
     * §16.5: glyph_plate() -- fill Roboto's a at a 300 pixel em, then draw
     * its own file data over it: the control polygon as a hairline,
     * on-curve points as filled squares, off-curve points as hollow
     * circles, and the implied on-curve points as smaller squares.
     */
    public static Canvas glyphPlate() {
        int w = 320, h = 320;
        Canvas c = new Canvas(w, h);
        c.fill(PAPER);
        Font font = robotoFont();
        Matrix m = Glyphs.textMatrix(font, 300, 40, 250);
        Painter.paintThrough(c, Fill.fillPath(Glyphs.glyphPath(font, "a", m, 0.1), "nonzero", w, h), GLYPH_GRAY);

        Glyph a = font.glyphs.get("a");
        for (List<ContourPoint> contour : a.contours()) {
            List<Tuple> pts = new ArrayList<>();
            for (ContourPoint p : contour) {
                pts.add(m.multiply(Tuple.point(p.x(), p.y())));
            }
            paintHairline(c, pts, true, GLYPH_DIM, 1.0);
        }
        for (List<ContourPoint> contour : a.contours()) {
            Set<List<Double>> explicit = new HashSet<>();
            for (ContourPoint p : contour) {
                explicit.add(List.of(p.x(), p.y()));
            }
            for (ContourPoint p : Contours.impliedPoints(contour)) {
                Tuple q = m.multiply(Tuple.point(p.x(), p.y()));
                if (!p.on()) {
                    Path circle = Paths.circlePath(q.x, q.y, 4, 24);
                    Path outline = Stroke.strokeToPath(circle, 1.5, "butt", "round", 4.0);
                    Painter.paintThrough(c, Fill.fillPath(outline, "nonzero", w, h), GLYPH_MAGENTA);
                } else if (explicit.contains(List.of(p.x(), p.y()))) {
                    Painter.paintThrough(c, Fill.fillPath(squarePath(q, 3), "nonzero", w, h), GLYPH_CYAN);
                } else {
                    Painter.paintThrough(c, Fill.fillPath(squarePath(q, 2), "nonzero", w, h), GLYPH_CYAN);
                }
            }
        }
        return c;
    }

    /** §16.5: plate_16() -- glyph_plate(), magnified by 2. */
    public static Canvas plate16() {
        return Magnify.magnify(glyphPlate(), 2);
    }

    /**
     * §16.5: composite_demo() -- eacute drawn as its two components, each
     * in its own ink, with glyph_bounds traced as a hairline box.
     */
    public static Canvas compositeDemo() {
        int w = 240, h = 240;
        Canvas c = new Canvas(w, h);
        c.fill(PAPER);
        Font font = robotoFont();
        Matrix m = Glyphs.textMatrix(font, 240, 50, 190);
        Glyph eacute = font.glyphs.get("eacute");
        List<Component> comps = eacute.components();
        for (int k = 0; k < comps.size(); k++) {
            Matrix cm = m.multiply(Glyphs.componentMatrix(comps.get(k).transform()));
            Path p = Glyphs.glyphPath(font, comps.get(k).glyph(), cm, 0.1);
            Painter.paintThrough(c, Fill.fillPath(p, "nonzero", w, h), GLYPH_INKS[k % 3]);
        }
        Bounds bb = Glyphs.glyphBounds(font, "eacute");
        Tuple lo = m.multiply(Tuple.point(bb.minX(), bb.minY()));
        Tuple hi = m.multiply(Tuple.point(bb.maxX(), bb.maxY()));
        List<Tuple> box = List.of(
                Tuple.point(lo.x, lo.y), Tuple.point(hi.x, lo.y),
                Tuple.point(hi.x, hi.y), Tuple.point(lo.x, hi.y));
        paintHairline(c, box, true, GLYPH_MAGENTA, 1.0);
        return c;
    }

    /** §16.5: sizes() -- the g at 12, 24, 48 and 96 pixels, on one baseline. */
    public static Canvas sizes() {
        int w = 240, h = 120;
        Canvas c = new Canvas(w, h);
        c.fill(PAPER);
        Font font = robotoFont();
        Glyph g = font.glyphs.get("g");
        double x = 8;
        for (int size : new int[] {12, 24, 48, 96}) {
            Matrix m = Glyphs.textMatrix(font, size, x, 80);
            Painter.paintThrough(c, Fill.fillPath(Glyphs.glyphPath(font, "g", m, 0.1), "nonzero", w, h), GLYPH_GRAY);
            x += g.advance() * size / font.unitsPerEm + 8;
        }
        return c;
    }

    /**
     * §16.4: flip_trap() -- R through text_matrix on the left, and through
     * a scale that forgot to turn y over (a positive y scale) on the
     * right: the trap's picture of what a forgotten flip looks like.
     */
    public static Canvas flipTrap() {
        int w = 120, h = 120;
        Font font = robotoFont();
        double s = 60.0 / font.unitsPerEm;
        Canvas left = new Canvas(w, h);
        left.fill(PAPER);
        Canvas right = new Canvas(w, h);
        right.fill(PAPER);
        Matrix mLeft = Glyphs.textMatrix(font, 60, 35, 60);
        Painter.paintThrough(left,
                Fill.fillPath(Glyphs.glyphPath(font, "R", mLeft, 0.1), "nonzero", w, h), GLYPH_GRAY);
        Matrix mRight = Transforms.translation(35, 60).multiply(Transforms.scaling(s, s));
        Painter.paintThrough(right,
                Fill.fillPath(Glyphs.glyphPath(font, "R", mRight, 0.1), "nonzero", w, h), GLYPH_MAGENTA);
        paintHairline(left, List.of(Tuple.point(0, 60), Tuple.point(w, 60)), false, GLYPH_DIM, 1.0);
        paintHairline(right, List.of(Tuple.point(0, 60), Tuple.point(w, 60)), false, GLYPH_DIM, 1.0);
        return sideBySide(left, right);
    }

    // ---------------------------------------------------------------------
    // Chapter 17: rasterizing type well.

    private static final Color TYPE_WHITE = new Color(1, 1, 1);
    private static final Color TYPE_BLACK = new Color(0, 0, 0);

    /**
     * §17.1: pen advances by penAdvance, each glyph rendered at its nearest
     * quarter; answers the pen's final position, per features/chapter17-plate.feature.
     */
    public static double drawText(Canvas c, Font font, String text, double size, double x, double y,
                                    Color color, boolean linear) {
        double pen = x;
        for (int i = 0; i < text.length(); i++) {
            String name = Fonts.glyphName(font, text.charAt(i));
            Subpixel sq = Bitmaps.subpixelOf(pen);
            Bitmaps.paintBitmap(c, Bitmaps.glyphBitmap(font, name, size, sq.quarter()),
                    sq.whole(), (int) Math.floor(y), color, linear);
            pen += Glyphs.penAdvance(font, name, size);
        }
        return pen;
    }

    private static Canvas stackVertical(Canvas top, Canvas bottom) {
        Canvas out = new Canvas(Math.max(top.width, bottom.width), top.height + bottom.height);
        for (int y = 0; y < top.height; y++) {
            for (int x = 0; x < top.width; x++) {
                out.writePixel(x, y, top.pixelAt(x, y));
            }
        }
        for (int y = 0; y < bottom.height; y++) {
            for (int x = 0; x < bottom.width; x++) {
                out.writePixel(x, top.height + y, bottom.pixelAt(x, y));
            }
        }
        return out;
    }

    /** §17.5: subpixel_strip() -- l at 11 pixels with its pen at x = 4, 4.25, 4.5, 4.75, magnified 8x. */
    public static Canvas subpixelStrip() {
        Font font = robotoFont();
        Canvas[] panels = new Canvas[4];
        for (int k = 0; k < 4; k++) {
            Canvas panel = new Canvas(10, 14);
            panel.fill(TYPE_WHITE);
            Subpixel sq = Bitmaps.subpixelOf(4 + k / 4.0);
            Bitmaps.paintBitmap(panel, Bitmaps.glyphBitmap(font, "l", 11, sq.quarter()), sq.whole(), 11,
                    TYPE_BLACK, true);
            panels[k] = panel;
        }
        Canvas row = sideBySide(sideBySide(panels[0], panels[1]), sideBySide(panels[2], panels[3]));
        return Magnify.magnify(row, 8);
    }

    /**
     * §17.5: smoothing_demo() -- "Hamburg" at 11 pixels three ways: linear
     * light, encoded-space blending (the universal cheat), and linear with
     * the stems emboldened by a third of a pixel. Magnified 4x.
     */
    public static Canvas smoothingDemo() {
        Font font = robotoFont();
        Canvas b = new Canvas(72, 42);
        b.fill(TYPE_WHITE);
        drawText(b, font, "Hamburg", 11, 2, 11, TYPE_BLACK, true);
        drawText(b, font, "Hamburg", 11, 2, 25, TYPE_BLACK, false);
        double pen = 2;
        String word = "Hamburg";
        for (int i = 0; i < word.length(); i++) {
            String name = Fonts.glyphName(font, word.charAt(i));
            Subpixel sq = Bitmaps.subpixelOf(pen);
            Bitmaps.paintBitmap(b, Bitmaps.embolden(font, name, 11, 1.0 / 3), sq.whole(), 39, TYPE_BLACK, true);
            pen += Glyphs.penAdvance(font, name, 11);
        }
        return Magnify.magnify(b, 4);
    }

    /**
     * §17.5: lcd_plate() -- "ea" at 13 pixels twice, grayscale coverage
     * above and LCD-filtered stripes below, magnified 6x.
     */
    public static Canvas lcdPlate() {
        Font font = robotoFont();
        int w = 24, h = 16;
        Canvas top = new Canvas(w, h);
        top.fill(TYPE_WHITE);
        Canvas bottom = new Canvas(w, h);
        bottom.fill(TYPE_WHITE);
        double pen = 2;
        String word = "ea";
        for (int i = 0; i < word.length(); i++) {
            String name = Fonts.glyphName(font, word.charAt(i));
            Matrix m = Glyphs.textMatrix(font, 13, pen, 12);
            Painter.paintThrough(top, Fill.fillPath(Glyphs.glyphPath(font, name, m, 0.1), "nonzero", w, h), TYPE_BLACK);
            Lcd.paintLcd(bottom, Lcd.lcdCoverage(font, name, 13, pen, 12, w, h), TYPE_BLACK);
            pen += Glyphs.penAdvance(font, name, 13);
        }
        return Magnify.magnify(stackVertical(top, bottom), 6);
    }

    /** §17.5: plate_17() -- lcd_plate(), magnified by 2. */
    public static Canvas plate17() {
        return Magnify.magnify(lcdPlate(), 2);
    }
}
