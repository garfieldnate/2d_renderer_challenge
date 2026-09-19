/**
 * §17.4: a pixel on an LCD is three stripes, red, green and blue, side by
 * side. lcd_coverage(font, name, size, x, y, w, h) rasterizes the glyph
 * three times wider, one coverage per stripe, into a buffer 3w wide and h
 * tall, and runs lcd_filter along every row: each value replaced by the
 * average of itself and its two neighbours, zero beyond the ends, the
 * three taps summing to one so ink spreads across neighbouring stripes but
 * is never lost. paint_lcd(canvas, cov3, color) composites it, red through
 * the first stripe of each pixel, green the second, blue the third, each
 * channel mixed on its own.
 */
public final class Lcd {
    public static final double[] LCD_TAPS = {1.0 / 3, 1.0 / 3, 1.0 / 3};

    private Lcd() {}

    public static double[] lcdFilter(double[] v) {
        int n = v.length;
        double[] out = new double[n];
        for (int i = 0; i < n; i++) {
            double a = i > 0 ? v[i - 1] : 0;
            double b = v[i];
            double c = i + 1 < n ? v[i + 1] : 0;
            out[i] = LCD_TAPS[0] * a + LCD_TAPS[1] * b + LCD_TAPS[2] * c;
        }
        return out;
    }

    public static CoverageBuffer lcdCoverage(Font font, String name, double size, double x, double y, int w, int h) {
        Matrix m = Transforms.scaling(3, 1).multiply(Glyphs.textMatrix(font, size, x, y));
        CoverageBuffer raw = Fill.fillPath(Glyphs.glyphPath(font, name, m, 0.1), "nonzero", 3 * w, h);
        CoverageBuffer out = new CoverageBuffer(3 * w, h);
        for (int row = 0; row < h; row++) {
            double[] line = new double[3 * w];
            for (int i = 0; i < 3 * w; i++) {
                line[i] = raw.coverageAt(i, row);
            }
            double[] filtered = lcdFilter(line);
            for (int i = 0; i < 3 * w; i++) {
                out.setCoverage(i, row, filtered[i]);
            }
        }
        return out;
    }

    public static void paintLcd(Canvas c, CoverageBuffer cov3, Color color) {
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                double kr = cov3.coverageAt(3 * x, y);
                double kg = cov3.coverageAt(3 * x + 1, y);
                double kb = cov3.coverageAt(3 * x + 2, y);
                if (kr <= 0 && kg <= 0 && kb <= 0) {
                    continue;
                }
                Color d = c.pixelAt(x, y);
                Color mixed = new Color(
                        d.red + (color.red - d.red) * kr,
                        d.green + (color.green - d.green) * kg,
                        d.blue + (color.blue - d.blue) * kb);
                c.writePixel(x, y, mixed);
            }
        }
    }
}
