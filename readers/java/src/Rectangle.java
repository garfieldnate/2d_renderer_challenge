/**
 * §2.1: a rectangle, given its left, top, right and bottom edges as
 * rectangle(x0, y0, x1, y1). Boundary included.
 */
public final class Rectangle implements Shape {
    public final double x0;
    public final double y0;
    public final double x1;
    public final double y1;

    public Rectangle(double x0, double y0, double x1, double y1) {
        this.x0 = x0;
        this.y0 = y0;
        this.x1 = x1;
        this.y1 = y1;
    }

    @Override
    public boolean inside(double x, double y) {
        return x >= x0 && x <= x1 && y >= y0 && y <= y1;
    }
}
