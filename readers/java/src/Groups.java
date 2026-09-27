/**
 * §12.3: a group is an offscreen layer -- chapter 9's premultiplied buffer
 * -- that children are drawn into, then composited back as one thing.
 * push_group(w, h) starts a fresh transparent one, the same as layer(w, h);
 * the separate name says what it's for. paint_into(layer, cov, color,
 * alpha) draws one child through its coverage at a given opacity and
 * returns a new layer, src-over the one handed in -- it does not mutate
 * its argument, matching every other buffer operation in this book.
 * scale_opacity(layer, op) lowers every premultiplied channel together,
 * alpha included. pop_group_with_opacity(group, base, opacity) scales the
 * whole flattened group by opacity, then composites it over base once --
 * at opacity 1 this is pixel-identical to drawing the children straight
 * onto base, because scaling by 1 does nothing and compositing the group
 * is compositing its children. Below 1 it differs at every overlap,
 * because the group's overlaps were already resolved before the opacity
 * applied, instead of being composited twice.
 */
public final class Groups {
    private Groups() {}

    public static Layer pushGroup(int w, int h) {
        return new Layer(w, h);
    }

    public static Layer paintInto(Layer layer, CoverageBuffer cov, Color color, double alpha) {
        Layer out = new Layer(layer.width, layer.height);
        for (int y = 0; y < layer.height; y++) {
            for (int x = 0; x < layer.width; x++) {
                double k = cov.coverageAt(x, y) * alpha;
                Pixel src = k > 0 ? Pixel.fromColor(color, k) : Pixel.CLEAR;
                out.setPixel(x, y, Compositing.over(src, layer.pixelAt(x, y)));
            }
        }
        return out;
    }

    public static Layer scaleOpacity(Layer layer, double opacity) {
        Layer out = new Layer(layer.width, layer.height);
        for (int y = 0; y < layer.height; y++) {
            for (int x = 0; x < layer.width; x++) {
                Pixel p = layer.pixelAt(x, y);
                out.setPixel(x, y, new Pixel(p.r * opacity, p.g * opacity, p.b * opacity, p.a * opacity));
            }
        }
        return out;
    }

    public static Layer popGroupWithOpacity(Layer group, Layer base, double opacity) {
        Layer faded = scaleOpacity(group, opacity);
        Layer out = new Layer(base.width, base.height);
        for (int y = 0; y < base.height; y++) {
            for (int x = 0; x < base.width; x++) {
                out.setPixel(x, y, Compositing.over(faded.pixelAt(x, y), base.pixelAt(x, y)));
            }
        }
        return out;
    }

    /**
     * §20.10: draw_coverage(l, cov, paint, alpha) paints into a layer: at
     * every pixel whose coverage times alpha is above 0, the paint's colour
     * at the pixel center becomes the premultiplied pixel, source-over what
     * is already there. Mutates the layer in place, the same as chapter 9's
     * paint_shape.
     */
    public static void drawCoverage(Layer l, CoverageBuffer cov, Paint paint, double alpha) {
        for (int y = 0; y < l.height; y++) {
            for (int x = 0; x < l.width; x++) {
                double k = cov.coverageAt(x, y) * alpha;
                if (k > 0) {
                    Color c = paint.paintAt(x + 0.5, y + 0.5);
                    l.setPixel(x, y, Compositing.over(Pixel.fromColor(c, k), l.pixelAt(x, y)));
                }
            }
        }
    }

    /** §20.10: mask_layer(l, cov) multiplies every premultiplied channel of every pixel by the coverage under it. */
    public static void maskLayer(Layer l, CoverageBuffer cov) {
        for (int y = 0; y < l.height; y++) {
            for (int x = 0; x < l.width; x++) {
                double k = cov.coverageAt(x, y);
                Pixel p = l.pixelAt(x, y);
                l.setPixel(x, y, new Pixel(p.r * k, p.g * k, p.b * k, p.a * k));
            }
        }
    }
}
