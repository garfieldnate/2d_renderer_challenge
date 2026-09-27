/**
 * §12.1: a clip is a coverage buffer, no new machinery required.
 * multiply_coverage(a, b) is clipping's whole operation, cell by cell.
 * full_clip(w, h) is coverage 1 everywhere, so multiplying by it is a
 * no-op. clip_rect and clip_path are only fills that produce a clip --
 * there was never a difference between a clip and a shape, so clip_path is
 * chapter 7's fill_path under a name that says what the caller means to do
 * with the result.
 *
 * §12.2: soft_mask(cx, cy, r, w, h) is a radial falloff, coverage 1 at its
 * centre dropping to 0 at radius r (clamped there, never negative), and it
 * multiplies in exactly the same way a hard clip does.
 */
public final class Clipping {
    private Clipping() {}

    public static CoverageBuffer multiplyCoverage(CoverageBuffer a, CoverageBuffer b) {
        CoverageBuffer out = new CoverageBuffer(a.width, a.height);
        for (int y = 0; y < a.height; y++) {
            for (int x = 0; x < a.width; x++) {
                out.setCoverage(x, y, a.coverageAt(x, y) * b.coverageAt(x, y));
            }
        }
        return out;
    }

    /** §20.10: union_coverage(a, b) is 1 - (1 - a)(1 - b) at every pixel, the alpha of one silhouette over the other. */
    public static CoverageBuffer unionCoverage(CoverageBuffer a, CoverageBuffer b) {
        CoverageBuffer out = new CoverageBuffer(a.width, a.height);
        for (int y = 0; y < a.height; y++) {
            for (int x = 0; x < a.width; x++) {
                double p = a.coverageAt(x, y);
                double q = b.coverageAt(x, y);
                out.setCoverage(x, y, 1 - (1 - p) * (1 - q));
            }
        }
        return out;
    }

    public static CoverageBuffer fullClip(int w, int h) {
        CoverageBuffer cov = new CoverageBuffer(w, h);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                cov.setCoverage(x, y, 1.0);
            }
        }
        return cov;
    }

    public static CoverageBuffer clipRect(double x0, double y0, double x1, double y1, int w, int h) {
        Path rect = Paths.polygon(
                Tuple.point(x0, y0), Tuple.point(x1, y0), Tuple.point(x1, y1), Tuple.point(x0, y1));
        return Fill.fillPath(rect, "nonzero", w, h);
    }

    public static CoverageBuffer clipPath(Path p, String rule, int w, int h) {
        return Fill.fillPath(p, rule, w, h);
    }

    public static CoverageBuffer softMask(double cx, double cy, double r, int w, int h) {
        CoverageBuffer cov = new CoverageBuffer(w, h);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                double d = Math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r;
                double v = 1 - d;
                cov.setCoverage(x, y, Math.max(0, v));
            }
        }
        return cov;
    }
}
