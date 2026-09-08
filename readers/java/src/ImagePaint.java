/**
 * §11.3: image_paint(img, m, filter, extend) is a paint that samples an
 * image placed on the canvas by m. m maps image space to device space, so
 * paint_at walks backward: it takes the device point through the inverse
 * of m to find where in the image to look, then samples there. That's the
 * only way every output pixel gets filled exactly once -- looping over
 * source texels forward would leave gaps under magnification and overlaps
 * under rotation.
 */
public final class ImagePaint implements Paint {
    public final Image img;
    public final Matrix m;
    public final String filter;
    public final String extend;
    private final Matrix inverse;

    public ImagePaint(Image img, Matrix m, String filter, String extend) {
        this.img = img;
        this.m = m;
        this.filter = filter;
        this.extend = extend;
        this.inverse = m.inverse();
    }

    @Override
    public Color paintAt(double x, double y) {
        Tuple src = inverse.multiply(Tuple.point(x, y));
        return Sampling.sample(img, src.x, src.y, filter, extend).pixelColor();
    }
}
