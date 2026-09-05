/**
 * §2.3: magnify(canvas, k) returns a canvas k times wider and taller, with
 * every pixel repeated into a k-by-k block. No smoothing, no averaging.
 */
public final class Magnify {
    private Magnify() {}

    public static Canvas magnify(Canvas c, int k) {
        Canvas out = new Canvas(c.width * k, c.height * k);
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                Color col = c.pixelAt(x, y);
                for (int dy = 0; dy < k; dy++) {
                    for (int dx = 0; dx < k; dx++) {
                        out.writePixel(x * k + dx, y * k + dy, col);
                    }
                }
            }
        }
        return out;
    }
}
