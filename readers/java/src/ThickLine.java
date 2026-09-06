/**
 * §3.3, revisited in §4.5: a line as a shape, between the centers of pixel
 * (x0, y0) and pixel (x1, y1). Now a one-liner: segment(point(x0 + 0.5,
 * y0 + 0.5), point(x1 + 0.5, y1 + 0.5), width), the rectangle of the given
 * width with square ends. Every chapter 3 scenario still passes, because
 * the geometry Segment builds is exactly what this class used to build by
 * hand.
 */
public final class ThickLine implements Shape {
    private final Segment segment;

    public ThickLine(double x0, double y0, double x1, double y1, double width) {
        segment = new Segment(Tuple.point(x0 + 0.5, y0 + 0.5), Tuple.point(x1 + 0.5, y1 + 0.5), width);
    }

    @Override
    public boolean inside(double x, double y) {
        return segment.inside(x, y);
    }
}
