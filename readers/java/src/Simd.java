/**
 * §21.6: composite_span(l, y, x, ks, c) composites the colour c into row y
 * of a layer through a run of coverages, one pixel at a time, with no test
 * for k = 0. composite_span4 does the same four pixels to a step, each
 * lane doing exactly the scalar arithmetic in the same order with no fused
 * multiply-add, and the leftover pixels one at a time. layers_equal(a, b)
 * is true when every channel of every pixel is the same number.
 */
public final class Simd {
    private Simd() {}

    private static void compositeOne(Layer l, int y, int x, double k, Color c) {
        double t = 1 - k;
        Pixel p = l.pixelAt(x, y);
        l.setPixel(x, y, new Pixel(c.red * k + t * p.r, c.green * k + t * p.g, c.blue * k + t * p.b, k + t * p.a));
    }

    public static void compositeSpan(Layer l, int y, int x, double[] ks, Color c) {
        for (int i = 0; i < ks.length; i++) {
            compositeOne(l, y, x + i, ks[i], c);
        }
    }

    public static void compositeSpan4(Layer l, int y, int x, double[] ks, Color c) {
        int i = 0;
        int n = ks.length;
        for (; i + 4 <= n; i += 4) {
            for (int lane = 0; lane < 4; lane++) {
                compositeOne(l, y, x + i + lane, ks[i + lane], c);
            }
        }
        for (; i < n; i++) {
            compositeOne(l, y, x + i, ks[i], c);
        }
    }

    public static boolean layersEqual(Layer a, Layer b) {
        if (a.width != b.width || a.height != b.height) {
            return false;
        }
        for (int y = 0; y < a.height; y++) {
            for (int x = 0; x < a.width; x++) {
                Pixel pa = a.pixelAt(x, y);
                Pixel pb = b.pixelAt(x, y);
                if (pa.r != pb.r || pa.g != pb.g || pa.b != pb.b || pa.a != pb.a) {
                    return false;
                }
            }
        }
        return true;
    }
}
