import java.util.ArrayList;
import java.util.List;

/**
 * §4.5: transform_points(points, m) runs every point of a list through m.
 * outline(points, m, width) takes the points through m and returns the
 * union of the segments between consecutive points, last back to first, as
 * one shape -- so a shared corner is painted once by the union's coverage
 * rather than twice, once by each edge that ends there.
 */
public final class Shapes {
    private Shapes() {}

    public static List<Tuple> transformPoints(List<Tuple> points, Matrix m) {
        List<Tuple> result = new ArrayList<>(points.size());
        for (Tuple p : points) {
            result.add(m.multiply(p));
        }
        return result;
    }

    public static Shape outline(List<Tuple> points, Matrix m, double width) {
        List<Tuple> pts = transformPoints(points, m);
        List<Shape> segments = new ArrayList<>();
        int n = pts.size();
        for (int i = 0; i < n; i++) {
            Tuple a = pts.get(i);
            Tuple b = pts.get((i + 1) % n);
            segments.add(new Segment(a, b, width));
        }
        return new Union(segments);
    }
}
