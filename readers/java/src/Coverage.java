/**
 * §21.3: coverage_in(c, x, y) reads a window at a canvas pixel, 0 outside
 * it, and also reads a plain coverage buffer and the tiled coverage of
 * §21.4. full_coverage(c, width, height) turns any of them into a
 * canvas-sized buffer.
 */
public final class Coverage {
    private Coverage() {}

    public static double coverageIn(Object c, int x, int y) {
        if (c instanceof CoverageBuffer cb) {
            return cb.coverageAt(x, y);
        }
        if (c instanceof BoundedFill.FillWindow win) {
            if (x < win.x0() || y < win.y0() || x >= win.x0() + win.cov().width || y >= win.y0() + win.cov().height) {
                return 0;
            }
            return win.coverageAt(x, y);
        }
        if (c instanceof TiledCoverage t) {
            return t.coverageAt(x, y);
        }
        throw new IllegalArgumentException("not a coverage-like value: " + c);
    }

    public static CoverageBuffer fullCoverage(Object c, int width, int height) {
        CoverageBuffer out = new CoverageBuffer(width, height);
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                out.setCoverage(x, y, coverageIn(c, x, y));
            }
        }
        return out;
    }
}
