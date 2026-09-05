/** §2.1: a circle, given its center and radius. Inside means within the radius, boundary included. */
public final class Circle implements Shape {
    public final double cx;
    public final double cy;
    public final double r;

    public Circle(double cx, double cy, double r) {
        this.cx = cx;
        this.cy = cy;
        this.r = r;
    }

    @Override
    public boolean inside(double x, double y) {
        double dx = x - cx;
        double dy = y - cy;
        return dx * dx + dy * dy <= r * r;
    }
}
