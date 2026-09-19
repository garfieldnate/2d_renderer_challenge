/**
 * §7.2, §7.3, §7.4, §7.5: the analytic fill.
 *
 * accumulate_row(acc, row, x0, x1, height) deposits the piece of an edge
 * that lies in a single row, running from x0 at the top to x1 at the
 * bottom, carrying a signed height. When the piece stays inside one cell,
 * that cell gets the whole height as its cover, and its area is the height
 * weighted by how far the piece's midpoint sits from the cell's right edge
 * -- a trapezoid's area is its height times its width at the midline. When
 * the piece spans several cells, the height is shared among them in
 * proportion to the width each one holds, and each slice uses the same
 * midpoint rule inside its own cell.
 *
 * accumulate(acc, a, b) walks a whole edge down the rows it crosses,
 * clipping to each one and handing the piece to accumulate_row. Heading up
 * the canvas (decreasing y) carries a positive height, heading down a
 * negative one. A horizontal edge deposits nothing -- same drop as chapter
 * 6's edge table, and for the same reason: its slope would divide by zero.
 *
 * resolve(acc, rule) sweeps each row left to right: a cell's winding number
 * is the running cover of everything to its left plus its own area, and
 * apply_rule turns that (possibly fractional) number into coverage.
 *
 * fill_path(p, rule, w, h) is the fill: deposit every edge, then resolve.
 * polygon_area(p) is the shoelace formula, unsigned, so the total ink of a
 * simple polygon's fill can be checked against its true area regardless of
 * which way the path was wound.
 */
public final class Fill {
    private Fill() {}

    // A rotated edge that's mathematically vertical still lands here with
    // x0 and x1 differing by a bit of floating point noise (a rotation by
    // pi/2 doesn't produce an exact 0 for cos) rather than being bit-equal.
    // Treated as the general multi-cell case, that noise sits in the
    // denominator of segHeight = height * segWidth / dx and blows up by
    // twelve or so orders of magnitude -- caught by a spiral star landing
    // at a right angle, in reader testing.
    private static final double VERTICAL_EPSILON = 1e-9;

    public static void accumulateRow(Accumulator acc, int row, double x0, double x1, double height) {
        if (Math.abs(x1 - x0) < VERTICAL_EPSILON) {
            double xMid = (x0 + x1) / 2.0;
            int cell = (int) Math.floor(xMid);
            double frac = xMid - cell;
            acc.addCell(cell, row, height * (1 - frac), height);
            return;
        }

        double xleft = Math.min(x0, x1);
        double xright = Math.max(x0, x1);
        double dx = xright - xleft;

        // The visible portion of the piece, cell by cell.
        double segStart = Math.max(xleft, 0.0);
        double segEnd = Math.min(xright, (double) acc.width);
        if (segStart < segEnd) {
            double x = segStart;
            int cell = (int) Math.floor(segStart);
            while (x < segEnd - 1e-12) {
                double nextBoundary = Math.min(cell + 1.0, segEnd);
                double segWidth = nextBoundary - x;
                double segHeight = height * segWidth / dx;
                double mid = (x + nextBoundary) / 2.0 - cell;
                acc.addCell(cell, row, segHeight * (1 - mid), segHeight);
                x = nextBoundary;
                cell++;
            }
        }

        // The portion left of the buffer folds onto column 0 as pure cover,
        // in one lump -- add_cell discards whatever area it's handed there,
        // so the individual slices' areas never matter.
        if (xleft < 0) {
            double clipRight = Math.min(0.0, xright);
            double segWidth = clipRight - xleft;
            if (segWidth > 0) {
                double segHeight = height * segWidth / dx;
                acc.addCell(-1, row, 0, segHeight);
            }
        }
        // The portion right of the buffer vanishes -- nothing to add.
    }

    public static void accumulate(Accumulator acc, Tuple a, Tuple b) {
        double y0 = a.y;
        double y1 = b.y;
        if (y0 == y1) {
            return; // horizontal: dropped, same reason as the edge table
        }
        double x0 = a.x;
        double x1 = b.x;
        int dir = (y0 > y1) ? 1 : -1; // heading up the canvas is positive

        double yMin = Math.min(y0, y1);
        double yMax = Math.max(y0, y1);
        double clippedYMin = Math.max(yMin, 0.0);
        double clippedYMax = Math.min(yMax, (double) acc.height);
        if (clippedYMin >= clippedYMax) {
            return; // entirely above or below the buffer
        }

        int rowStart = (int) Math.floor(clippedYMin);
        int rowEnd = (int) Math.ceil(clippedYMax);
        for (int row = rowStart; row < rowEnd; row++) {
            double segYlo = Math.max((double) row, clippedYMin);
            double segYhi = Math.min((double) (row + 1), clippedYMax);
            if (segYhi <= segYlo) {
                continue;
            }
            double localHeight = dir * (segYhi - segYlo);
            double xAtLo = x0 + (segYlo - y0) * (x1 - x0) / (y1 - y0);
            double xAtHi = x0 + (segYhi - y0) * (x1 - x0) / (y1 - y0);
            accumulateRow(acc, row, xAtLo, xAtHi, localHeight);
        }
    }

    public static double applyRule(double winding, String rule) {
        double w = Math.abs(winding);
        if (rule.equals("nonzero")) {
            return Math.min(1.0, w);
        }
        double folded = w % 2.0;
        return folded > 1.0 ? 2.0 - folded : folded;
    }

    public static CoverageBuffer resolve(Accumulator acc, String rule) {
        CoverageBuffer cov = new CoverageBuffer(acc.width, acc.height);
        for (int row = 0; row < acc.height; row++) {
            double running = 0;
            for (int x = 0; x < acc.width; x++) {
                double winding = running + acc.areaAt(x, row);
                cov.setCoverage(x, row, applyRule(winding, rule));
                running += acc.coverAt(x, row);
            }
        }
        return cov;
    }

    public static CoverageBuffer fillPath(Path p, String rule, int w, int h) {
        Accumulator acc = new Accumulator(w, h);
        for (Edge e : p.edges()) {
            accumulate(acc, e.a(), e.b());
        }
        return resolve(acc, rule);
    }

    /**
     * The shoelace formula, signed: positive when the path winds clockwise
     * on screen, negative counterclockwise (chapter 13 reuses the sign to
     * orient every stroke piece the same way).
     */
    public static double polygonArea(Path p) {
        double sum = 0;
        for (Edge e : p.edges()) {
            sum += e.a().x * e.b().y - e.b().x * e.a().y;
        }
        return sum / 2.0;
    }
}
