/**
 * §25.4: a selection is a coverage mask. marquee(x0, y0, x1, y1, w, h) is
 * chapter 12's clip_rect. add_selection(a, b) is 1 - (1 - a)(1 - b),
 * subtract_selection(a, b) is a * (1 - b), intersect_selection(a, b) is
 * chapter 12's multiply_coverage. feather(m, r) is a box blur of radius r,
 * along the rows and then down the columns, each value the mean of the 2r
 * + 1 centred on it with those off the buffer counted as 0.
 * float_selection(c, sel, backfill) lifts the selection's pixels into a
 * chapter 9 layer, each premultiplied by the selection's coverage k, and
 * mixes the canvas under them toward backfill by k; move_floating(f, dx,
 * dy) moves it; drop_floating(c, f) composites every pixel of it with
 * alpha above 0, moved, source-over the canvas, dropping those that land
 * off the canvas.
 */
public final class Selection {
    private Selection() {}

    public static CoverageBuffer marquee(double x0, double y0, double x1, double y1, int w, int h) {
        return Clipping.clipRect(x0, y0, x1, y1, w, h);
    }

    public static CoverageBuffer addSelection(CoverageBuffer a, CoverageBuffer b) {
        return Clipping.unionCoverage(a, b);
    }

    public static CoverageBuffer subtractSelection(CoverageBuffer a, CoverageBuffer b) {
        CoverageBuffer out = new CoverageBuffer(a.width, a.height);
        for (int y = 0; y < a.height; y++) {
            for (int x = 0; x < a.width; x++) {
                out.setCoverage(x, y, a.coverageAt(x, y) * (1 - b.coverageAt(x, y)));
            }
        }
        return out;
    }

    public static CoverageBuffer intersectSelection(CoverageBuffer a, CoverageBuffer b) {
        return Clipping.multiplyCoverage(a, b);
    }

    public static CoverageBuffer feather(CoverageBuffer m, int r) {
        int w = m.width;
        int h = m.height;
        int win = 2 * r + 1;
        double[] tmp = new double[w * h];
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                double sum = 0;
                for (int dx = -r; dx <= r; dx++) {
                    int xx = x + dx;
                    if (xx >= 0 && xx < w) {
                        sum += m.coverageAt(xx, y);
                    }
                }
                tmp[y * w + x] = sum / win;
            }
        }
        CoverageBuffer out = new CoverageBuffer(w, h);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                double sum = 0;
                for (int dy = -r; dy <= r; dy++) {
                    int yy = y + dy;
                    if (yy >= 0 && yy < h) {
                        sum += tmp[yy * w + x];
                    }
                }
                out.setCoverage(x, y, sum / win);
            }
        }
        return out;
    }

    public static Floating floatSelection(Canvas c, CoverageBuffer sel, Color backfill) {
        Layer l = new Layer(c.width, c.height);
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                double k = sel.coverageAt(x, y);
                if (k > 0) {
                    Color p = c.pixelAt(x, y);
                    l.setPixel(x, y, Pixel.fromColor(p, k));
                    c.writePixel(x, y, Mixer.mix(p, backfill, k, true));
                }
            }
        }
        return new Floating(l);
    }

    public static void moveFloating(Floating f, double dx, double dy) {
        f.dx += dx;
        f.dy += dy;
    }

    public static void dropFloating(Canvas c, Floating f) {
        int w = c.width;
        int h = c.height;
        int offX = (int) Math.round(f.dx);
        int offY = (int) Math.round(f.dy);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                Pixel p = f.layer.pixelAt(x, y);
                if (p.a <= 0) {
                    continue;
                }
                int nx = x + offX;
                int ny = y + offY;
                if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
                    Pixel dst = Pixel.opaque(c.pixelAt(nx, ny));
                    Pixel result = Compositing.over(p, dst);
                    c.writePixel(nx, ny, result.pixelColor());
                }
            }
        }
    }
}
