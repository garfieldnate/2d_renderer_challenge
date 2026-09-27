/**
 * §20.9: transformed_paint(paint, m) is a chapter 10 paint seen through a
 * matrix: its colour at a device point is the inner paint's colour at
 * inverse(m) times that point, so a gradient can be written in any
 * coordinates and m puts it on the canvas.
 */
public final class TransformedPaint implements Paint {
    private final Paint inner;
    private final Matrix inverse;

    public TransformedPaint(Paint inner, Matrix m) {
        this.inner = inner;
        this.inverse = m.inverse();
    }

    public static Paint transformedPaint(Paint inner, Matrix m) {
        return new TransformedPaint(inner, m);
    }

    @Override
    public Color paintAt(double x, double y) {
        Tuple q = inverse.multiply(Tuple.point(x, y));
        return inner.paintAt(q.x, q.y);
    }
}
