/** §10: a solid paint ignores the point and returns its color, unchanged. */
public final class Solid implements Paint {
    public final Color color;

    public Solid(Color color) {
        this.color = color;
    }

    @Override
    public Color paintAt(double x, double y) {
        return color;
    }
}
