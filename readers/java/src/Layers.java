/**
 * §9.6: paint_shape(layer, cov, color) paints a shape into a layer through
 * its coverage, the way chapter 2's paint_through painted onto a canvas --
 * except now the uncovered parts stay genuinely transparent instead of
 * paper-colored. composite_layers(op, src, dst) composites two layers pixel
 * by pixel with one Porter-Duff operator; flatten_layer(layer, bg) is
 * over(layer, opaque(bg)) per pixel, read off into an ordinary Canvas.
 */
public final class Layers {
    private Layers() {}

    public static void paintShape(Layer layer, CoverageBuffer cov, Color color) {
        for (int y = 0; y < layer.height; y++) {
            for (int x = 0; x < layer.width; x++) {
                double k = cov.coverageAt(x, y);
                if (k > 0) {
                    layer.setPixel(x, y, Pixel.fromColor(color, k));
                }
            }
        }
    }

    public static Layer compositeLayers(String op, Layer src, Layer dst) {
        Layer out = new Layer(dst.width, dst.height);
        for (int y = 0; y < dst.height; y++) {
            for (int x = 0; x < dst.width; x++) {
                out.setPixel(x, y, Compositing.composite(op, src.pixelAt(x, y), dst.pixelAt(x, y)));
            }
        }
        return out;
    }

    /** §9.6's plate, the blend-mode grid: composite_layers with blend in place of composite. */
    public static Layer blendLayers(String mode, Layer src, Layer dst) {
        Layer out = new Layer(dst.width, dst.height);
        for (int y = 0; y < dst.height; y++) {
            for (int x = 0; x < dst.width; x++) {
                out.setPixel(x, y, Blend.blend(mode, src.pixelAt(x, y), dst.pixelAt(x, y)));
            }
        }
        return out;
    }

    public static Canvas flattenLayer(Layer layer, Color bg) {
        Canvas c = new Canvas(layer.width, layer.height);
        Pixel base = Pixel.opaque(bg);
        for (int y = 0; y < layer.height; y++) {
            for (int x = 0; x < layer.width; x++) {
                Pixel q = Compositing.over(layer.pixelAt(x, y), base);
                c.writePixel(x, y, q.pixelColor());
            }
        }
        return c;
    }
}
