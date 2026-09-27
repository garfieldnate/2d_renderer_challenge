/**
 * §21.3: a path can only touch the pixels under its bounds. fill_bounds(p,
 * width, height) is that window of the canvas in whole pixels: x0 and y0
 * the floors of the path's least x and y, x1 and y1 one more than the
 * floors of its greatest, each cut to the canvas; (0, 0, 0, 0) for an empty
 * path or a window with nothing left in it. fill_path_bounded(p, rule,
 * width, height, st) moves the path by (-x0, -y0), fills it with chapter 7
 * into an accumulator the window's size, and answers a window: the
 * coverage buffer and its (x0, y0). draw_window(l, win, paint, alpha, st)
 * is draw_coverage over the window's pixels only.
 */
public final class BoundedFill {
    private BoundedFill() {}

    public record IntBounds(int x0, int y0, int x1, int y1) {
        public static final IntBounds EMPTY = new IntBounds(0, 0, 0, 0);
    }

    public record FillWindow(int x0, int y0, CoverageBuffer cov) {
        public double coverageAt(int x, int y) {
            return cov.coverageAt(x - x0, y - y0);
        }
    }

    public static IntBounds fillBounds(Path p, int width, int height) {
        if (p.subpaths().isEmpty()) {
            return IntBounds.EMPTY;
        }
        Bounds b = p.bounds();
        int x0 = Math.max(0, (int) Math.floor(b.minX()));
        int y0 = Math.max(0, (int) Math.floor(b.minY()));
        int x1 = Math.min(width, (int) Math.floor(b.maxX()) + 1);
        int y1 = Math.min(height, (int) Math.floor(b.maxY()) + 1);
        if (x1 <= x0 || y1 <= y0) {
            return IntBounds.EMPTY;
        }
        return new IntBounds(x0, y0, x1, y1);
    }

    public static FillWindow fillPathBounded(Path p, String rule, int width, int height, Stats st) {
        IntBounds b = fillBounds(p, width, height);
        int ww = b.x1() - b.x0();
        int wh = b.y1() - b.y0();
        if (ww <= 0 || wh <= 0) {
            return new FillWindow(0, 0, new CoverageBuffer(0, 0));
        }
        Path shifted = Paths.transformPath(p, Transforms.translation(-b.x0(), -b.y0()));
        Accumulator acc = new Accumulator(ww, wh);
        for (Edge e : shifted.edges()) {
            Fill.accumulate(acc, e.a(), e.b());
        }
        CoverageBuffer cov = Fill.resolve(acc, rule);
        st.cells += (long) ww * wh;
        return new FillWindow(b.x0(), b.y0(), cov);
    }

    public static void drawWindow(Layer l, FillWindow win, Paint paint, double alpha, Stats st) {
        for (int j = 0; j < win.cov().height; j++) {
            for (int i = 0; i < win.cov().width; i++) {
                double k = win.cov().coverageAt(i, j) * alpha;
                if (k > 0) {
                    int x = win.x0() + i;
                    int y = win.y0() + j;
                    Color c = paint.paintAt(x + 0.5, y + 0.5);
                    l.setPixel(x, y, Compositing.over(Pixel.fromColor(c, k), l.pixelAt(x, y)));
                    st.blends++;
                }
            }
        }
    }
}
