/**
 * §4.5: transformed(shape, m) is shape seen through m. A point is inside it
 * when the inverse of m takes that point inside the original shape --
 * pulling the query backward through shape space instead of pushing the
 * shape's geometry forward. A shape seen through a matrix with no inverse
 * is empty: nothing can be inside a shape that's been flattened to a line.
 */
public final class Transformed implements Shape {
    private final Shape shape;
    private final boolean invertible;
    private final Matrix inverse;

    public Transformed(Shape shape, Matrix m) {
        this.shape = shape;
        this.invertible = m.isInvertible();
        this.inverse = invertible ? m.inverse() : null;
    }

    @Override
    public boolean inside(double x, double y) {
        if (!invertible) {
            return false;
        }
        Tuple p = inverse.multiply(Tuple.point(x, y));
        return shape.inside(p.x, p.y);
    }
}
