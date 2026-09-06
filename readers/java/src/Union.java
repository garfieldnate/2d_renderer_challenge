import java.util.List;

/** §4.5: union(shapes) is inside when any of its shapes is: one more case in inside, a loop with an early exit. */
public final class Union implements Shape {
    private final List<Shape> shapes;

    public Union(List<Shape> shapes) {
        this.shapes = shapes;
    }

    @Override
    public boolean inside(double x, double y) {
        for (Shape s : shapes) {
            if (s.inside(x, y)) {
                return true;
            }
        }
        return false;
    }
}
