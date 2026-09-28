import java.util.ArrayList;
import java.util.List;

/**
 * §25.5: ring_canvas, plate_25, dither_strip, halo_demo, brush_demo and
 * paint_by_script, exactly as chapter25-plate.feature's own prose spells
 * them out.
 */
public final class Chapter25Figures {
    private Chapter25Figures() {}

    private static final Color PALE = new Color(0.92, 0.9, 0.82);
    private static final Color INK_DARK = new Color(0.05, 0.05, 0.08);
    private static final Color CYAN = new Color(0.2, 0.75, 0.9);
    private static final Color MAGENTA = new Color(0.85, 0.2, 0.55);
    private static final Color SUN = new Color(1, 0.8, 0.3);
    private static final List<int[]> BW = List.of(new int[] {0, 0, 0}, new int[] {255, 255, 255});

    private static void place(Canvas dst, Canvas src, int ox, int oy) {
        for (int y = 0; y < src.height; y++) {
            for (int x = 0; x < src.width; x++) {
                dst.writePixel(ox + x, oy + y, src.pixelAt(x, y));
            }
        }
    }

    public static Canvas ringCanvas() {
        Canvas c = new Canvas(160, 160);
        c.fill(PALE);
        Path circle = Paths.circlePath(80, 80, 60, 96);
        Path outline = Stroke.strokeToPath(circle, 4, "butt", "round", 4);
        CoverageBuffer cov = Fill.fillPath(outline, "nonzero", 160, 160);
        Painter.paintThrough(c, cov, INK_DARK);
        return c;
    }

    public static Canvas plate25() {
        Canvas c = ringCanvas();
        FloodFill.bucket(c, 80, 80, CYAN, 32, true, false, 4);
        Canvas crop = new Canvas(60, 60);
        for (int y = 0; y < 60; y++) {
            for (int x = 0; x < 60; x++) {
                crop.writePixel(x, y, c.pixelAt(100 + x, 50 + y));
            }
        }
        Canvas left = Magnify.magnify(crop, 4);

        Canvas r = Quantize.rampCanvas(240, 240);
        int[] idx = Quantize.errorDiffuse(r, BW);
        Canvas right = Quantize.indexedCanvas(idx, BW, 240, 240);

        Canvas out = new Canvas(480, 240);
        place(out, left, 0, 0);
        place(out, right, 240, 0);
        return out;
    }

    public static Canvas ditherStrip() {
        Canvas r = Quantize.rampCanvas(256, 32);
        int[] th = Quantize.threshold(r, BW);
        int[] od = Quantize.orderedDither(r, BW);
        int[] ed = Quantize.errorDiffuse(r, BW);
        Canvas out = new Canvas(256, 96);
        place(out, Quantize.indexedCanvas(th, BW, 256, 32), 0, 0);
        place(out, Quantize.indexedCanvas(od, BW, 256, 32), 0, 32);
        place(out, Quantize.indexedCanvas(ed, BW, 256, 32), 0, 64);
        return out;
    }

    public static Canvas haloDemo() {
        int[] tolerances = {0, 32, 32, 160};
        boolean[] antiAlias = {false, false, true, false};
        Canvas out = new Canvas(640, 160);
        for (int i = 0; i < 4; i++) {
            Canvas c = ringCanvas();
            FloodFill.bucket(c, 80, 80, CYAN, tolerances[i], true, antiAlias[i], 4);
            place(out, c, i * 160, 0);
        }
        return out;
    }

    public static Canvas brushDemo() {
        Canvas c = new Canvas(400, 240);
        c.fill(PALE);
        List<Tuple> ev = Brushes.wobblyEvents();
        Brush b = new Brush(8, 0.5, 0.25, 0.6, 1);
        Brushes.paintStroke(c, ev, b, INK_DARK, false);
        List<Tuple> shifted = new ArrayList<>();
        for (Tuple q : ev) {
            shifted.add(Tuple.point(q.x, q.y + 110));
        }
        Brushes.paintStroke(c, shifted, b, INK_DARK, true);
        return c;
    }

    public static Canvas paintByScript() {
        int w = 480;
        int h = 320;
        Canvas c = new Canvas(w, h);

        CoverageBuffer sky = Selection.marquee(0, 0, w, 210, w, h);
        List<Stop> stops = List.of(
                Stop.stop(0, new Color(0.05, 0.12, 0.35)), Stop.stop(1, new Color(0.95, 0.45, 0.2)));
        LinearGradient gradient = new LinearGradient(Tuple.point(0, 0), Tuple.point(0, 210), stops, "pad");
        Painter.paintFill(c, sky, gradient);

        Color seaColor = new Color(0.02, 0.1, 0.2);
        CoverageBuffer sea = Selection.marquee(0, 210, w, h, w, h);
        Painter.paintThrough(c, sea, seaColor);

        Brushes.paintStroke(c, List.of(Tuple.point(370, 110)), new Brush(46, 0.55, 0.25, 1, 1), SUN, true);

        List<Tuple> hills = new ArrayList<>();
        for (int i = 0; i <= 20; i++) {
            hills.add(Tuple.point(-20 + 26 * i, 205 - 30 * Math.sin(i / 3.1) - 12 * Math.sin(i * 1.7)));
        }
        Brushes.paintStroke(c, hills, new Brush(34, 0.7, 0.2, 0.8, 1), new Color(0.04, 0.12, 0.06), true);

        Color[] saved = new Color[w * h];
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                saved[y * w + x] = c.pixelAt(x, y);
            }
        }
        Brushes.paintStroke(c, List.of(Tuple.point(40, 40), Tuple.point(460, 300)),
                new Brush(30, 0.5, 0.2, 1, 1), MAGENTA, true);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                c.writePixel(x, y, saved[y * w + x]);
            }
        }

        for (int k = 0; k < 6; k++) {
            List<Tuple> wave = new ArrayList<>();
            for (int j = 0; j < 12; j++) {
                wave.add(Tuple.point(60 + 60 * k + 8 * j, 232 + 14 * k + 2 * Math.sin(j)));
            }
            Brushes.paintStroke(c, wave, new Brush(1.6, 0.2, 0.3, 0.7, 0.8), SUN, true);
        }

        CoverageBuffer boat = Selection.marquee(150, 262, 210, 272, w, h);
        Painter.paintThrough(c, boat, INK_DARK);
        Floating f = Selection.floatSelection(c, boat, seaColor);
        Selection.moveFloating(f, 40, -6);
        Selection.dropFloating(c, f);

        List<int[]> cols = Quantize.canvasBytes(c);
        List<int[]> pal = Quantize.medianCut(cols, 16);
        int[] indices = Quantize.errorDiffuse(c, pal);
        byte[] bmp = Quantize.canvasToBmp8(indices, pal, w, h);
        Quantize.BmpImage read = Quantize.readBmp8(bmp);
        return Quantize.indexedCanvas(read.indices(), read.palette(), read.width(), read.height());
    }
}
