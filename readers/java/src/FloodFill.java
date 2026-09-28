import java.util.ArrayDeque;
import java.util.Deque;

/**
 * §25.2: bytes_at(c, x, y) is the pixel's three file bytes by chapter 1's
 * to_byte. A pixel matches the seed at a tolerance when every channel's
 * byte is within tolerance of the seed pixel's. flood_mask(c, x, y,
 * tolerance, connectivity, fs) is the scanline flood fill, as a coverage
 * mask of 1s. select_color(c, x, y, tolerance) is the bucket with
 * Contiguous off: every pixel of the canvas that matches. anti_alias_mask
 * is the bucket's Anti-alias box. naive_depth(w, h) is how deep the
 * recursive four-way fill goes.
 */
public final class FloodFill {
    private FloodFill() {}

    public static int[] bytesAt(Canvas c, int x, int y) {
        Color p = c.pixelAt(x, y);
        return new int[] {Ppm.toByte(p.red), Ppm.toByte(p.green), Ppm.toByte(p.blue)};
    }

    private static boolean matches(Canvas c, int x, int y, int[] seed, int tolerance) {
        int[] b = bytesAt(c, x, y);
        return Math.abs(b[0] - seed[0]) <= tolerance
                && Math.abs(b[1] - seed[1]) <= tolerance
                && Math.abs(b[2] - seed[2]) <= tolerance;
    }

    public static CoverageBuffer floodMask(Canvas c, int x, int y, int tolerance, int connectivity, FillStats fs) {
        int w = c.width;
        int h = c.height;
        boolean[] mask = new boolean[w * h];
        int[] seed = bytesAt(c, x, y);
        int reach = connectivity == 8 ? 1 : 0;
        Deque<int[]> stack = new ArrayDeque<>();
        stack.push(new int[] {x, y});
        fs.pushes++;
        fs.deepest = Math.max(fs.deepest, stack.size());
        while (!stack.isEmpty()) {
            int[] s = stack.pop();
            int px = s[0];
            int py = s[1];
            if (mask[py * w + px] || !matches(c, px, py, seed, tolerance)) {
                continue;
            }
            int lx = px;
            int rx = px;
            while (lx > 0 && !mask[py * w + lx - 1] && matches(c, lx - 1, py, seed, tolerance)) {
                lx--;
            }
            while (rx < w - 1 && !mask[py * w + rx + 1] && matches(c, rx + 1, py, seed, tolerance)) {
                rx++;
            }
            for (int k = lx; k <= rx; k++) {
                mask[py * w + k] = true;
            }
            for (int ny : new int[] {py - 1, py + 1}) {
                if (ny < 0 || ny >= h) {
                    continue;
                }
                boolean inrun = false;
                int from = Math.max(0, lx - reach);
                int to = Math.min(w - 1, rx + reach);
                for (int k = from; k <= to; k++) {
                    boolean ok = !mask[ny * w + k] && matches(c, k, ny, seed, tolerance);
                    if (ok && !inrun) {
                        stack.push(new int[] {k, ny});
                        fs.pushes++;
                        fs.deepest = Math.max(fs.deepest, stack.size());
                    }
                    inrun = ok;
                }
            }
        }
        CoverageBuffer cov = new CoverageBuffer(w, h);
        for (int yy = 0; yy < h; yy++) {
            for (int xx = 0; xx < w; xx++) {
                if (mask[yy * w + xx]) {
                    cov.setCoverage(xx, yy, 1.0);
                }
            }
        }
        return cov;
    }

    public static CoverageBuffer selectColor(Canvas c, int x, int y, int tolerance) {
        int[] seed = bytesAt(c, x, y);
        CoverageBuffer cov = new CoverageBuffer(c.width, c.height);
        for (int yy = 0; yy < c.height; yy++) {
            for (int xx = 0; xx < c.width; xx++) {
                if (matches(c, xx, yy, seed, tolerance)) {
                    cov.setCoverage(xx, yy, 1.0);
                }
            }
        }
        return cov;
    }

    public static CoverageBuffer antiAliasMask(CoverageBuffer m) {
        int w = m.width;
        int h = m.height;
        CoverageBuffer out = new CoverageBuffer(w, h);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                double v = m.coverageAt(x, y);
                if (v != 0) {
                    out.setCoverage(x, y, v);
                    continue;
                }
                boolean neighbour = (x > 0 && m.coverageAt(x - 1, y) != 0)
                        || (x < w - 1 && m.coverageAt(x + 1, y) != 0)
                        || (y > 0 && m.coverageAt(x, y - 1) != 0)
                        || (y < h - 1 && m.coverageAt(x, y + 1) != 0);
                out.setCoverage(x, y, neighbour ? 0.5 : 0);
            }
        }
        return out;
    }

    public static CoverageBuffer bucket(Canvas c, int x, int y, Color col, int tolerance, boolean contiguous,
            boolean antiAlias, int connectivity) {
        CoverageBuffer m = contiguous
                ? floodMask(c, x, y, tolerance, connectivity, new FillStats())
                : selectColor(c, x, y, tolerance);
        if (antiAlias) {
            m = antiAliasMask(m);
        }
        Painter.paintThrough(c, m, col);
        return m;
    }

    /** naive_depth(w, h): the deepest chain of calls filling an empty w by h canvas from (0, 0). */
    public static int naiveDepth(int w, int h) {
        int[] result = new int[1];
        Thread t = new Thread(null, () -> {
            boolean[] visited = new boolean[w * h];
            int[] maxDepth = {0};
            naiveDepthRec(visited, w, h, 0, 0, 1, maxDepth);
            result[0] = maxDepth[0];
        }, "naive-depth", 256L * 1024 * 1024);
        t.start();
        try {
            t.join();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RuntimeException(e);
        }
        return result[0];
    }

    private static void naiveDepthRec(boolean[] visited, int w, int h, int x, int y, int depth, int[] maxDepth) {
        if (x < 0 || x >= w || y < 0 || y >= h) {
            return;
        }
        int idx = y * w + x;
        if (visited[idx]) {
            return;
        }
        visited[idx] = true;
        if (depth > maxDepth[0]) {
            maxDepth[0] = depth;
        }
        naiveDepthRec(visited, w, h, x + 1, y, depth + 1, maxDepth);
        naiveDepthRec(visited, w, h, x - 1, y, depth + 1, maxDepth);
        naiveDepthRec(visited, w, h, x, y + 1, depth + 1, maxDepth);
        naiveDepthRec(visited, w, h, x, y - 1, depth + 1, maxDepth);
    }
}
