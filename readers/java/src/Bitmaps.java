/**
 * §17.1: subpipxel_of(x) splits a fractional pen position into a whole
 * pixel and one of four quarters, the fraction rounded to the nearest
 * quarter and carried into the next pixel when it rounds all the way up.
 *
 * glyph_bitmap(font, name, size, subpixel) takes the glyph's bounds
 * (chapter 16), scales them, shifts them right by the quarter, and rounds
 * outward to whole pixels: the buffer's columns run from floor(xmin) to
 * ceil(xmax) - 1, its rows likewise with y turned over, and the path is
 * filled into it through a text_matrix whose origin is the quarter, offset
 * by the buffer's own corner.
 *
 * paint_bitmap(canvas, bitmap, x, y, color, linear) puts a bitmap on the
 * canvas with its pen at a whole pixel, mixing every covered pixel toward
 * the color by its coverage -- linear picks which lane of chapter 1's mix
 * does the blending.
 *
 * §17.3: embolden(font, name, size, amount) is the glyph's fill plus
 * chapter 13's stroke of its outline, amount wide, the two coverages added
 * and clamped to one, in a bitmap grown a pixel all round to make room.
 */
public final class Bitmaps {
    private static final int SUBPIXELS = 4;

    private Bitmaps() {}

    public static Subpixel subpixelOf(double x) {
        double whole = Math.floor(x);
        int q = (int) Math.floor((x - whole) * SUBPIXELS + 0.5);
        if (q == SUBPIXELS) {
            return new Subpixel((int) whole + 1, 0);
        }
        return new Subpixel((int) whole, q);
    }

    private static final Bitmap EMPTY = new Bitmap(new CoverageBuffer(0, 0), 0, 0);

    public static Bitmap glyphBitmap(Font font, String name, double size, int subpixel) {
        double s = size / font.unitsPerEm;
        Bounds bb = Glyphs.glyphBounds(font, name);
        if (bb.minX() == 0 && bb.minY() == 0 && bb.maxX() == 0 && bb.maxY() == 0) {
            return EMPTY;
        }
        double dx = subpixel / (double) SUBPIXELS;
        int left = (int) Math.floor(bb.minX() * s + dx);
        int right = (int) Math.ceil(bb.maxX() * s + dx);
        int top = (int) Math.floor(-bb.maxY() * s);
        int bottom = (int) Math.ceil(-bb.minY() * s);
        int w = Math.max(1, right - left);
        int h = Math.max(1, bottom - top);
        Matrix m = Glyphs.textMatrix(font, size, dx - left, -top);
        CoverageBuffer cov = Fill.fillPath(Glyphs.glyphPath(font, name, m, 0.1), "nonzero", w, h);
        return new Bitmap(cov, left, top);
    }

    public static void paintBitmap(Canvas c, Bitmap bm, int x, int y, Color color, boolean linear) {
        for (int j = 0; j < bm.height; j++) {
            for (int i = 0; i < bm.width; i++) {
                double k = bm.coverage.coverageAt(i, j);
                if (k <= 0) {
                    continue;
                }
                int px = x + bm.left + i;
                int py = y + bm.top + j;
                if (px < 0 || py < 0 || px >= c.width || py >= c.height) {
                    continue;
                }
                c.writePixel(px, py, Mixer.mix(c.pixelAt(px, py), color, k, linear));
            }
        }
    }

    private static CoverageBuffer addClamped(CoverageBuffer a, CoverageBuffer b) {
        CoverageBuffer out = new CoverageBuffer(a.width, a.height);
        for (int y = 0; y < a.height; y++) {
            for (int x = 0; x < a.width; x++) {
                out.setCoverage(x, y, Math.min(1.0, a.coverageAt(x, y) + b.coverageAt(x, y)));
            }
        }
        return out;
    }

    public static Bitmap embolden(Font font, String name, double size, double amount) {
        double s = size / font.unitsPerEm;
        Bounds bb = Glyphs.glyphBounds(font, name);
        int left = (int) Math.floor(bb.minX() * s) - 1;
        int top = (int) Math.floor(-bb.maxY() * s) - 1;
        int w = (int) Math.ceil(bb.maxX() * s) + 1 - left;
        int h = (int) Math.ceil(-bb.minY() * s) + 1 - top;
        Matrix m = Glyphs.textMatrix(font, size, -left, -top);
        Path p = Glyphs.glyphPath(font, name, m, 0.1);
        CoverageBuffer fill = Fill.fillPath(p, "nonzero", w, h);
        Path strokeOutline = Stroke.strokeToPath(p, amount, "butt", "round", 4.0);
        CoverageBuffer edge = Fill.fillPath(strokeOutline, "nonzero", w, h);
        return new Bitmap(addClamped(fill, edge), left, top);
    }
}
