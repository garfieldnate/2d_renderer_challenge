import java.util.List;

/**
 * §23.3: a field is a width, a height, and one number per pixel, row by row.
 * field(width, height, fn) samples fn at every pixel center, point(x + 0.5,
 * y + 0.5).
 */
public final class Field {
    public final int width;
    public final int height;
    public final double[] values;

    public Field(int width, int height, double[] values) {
        this.width = width;
        this.height = height;
        this.values = values;
    }

    public interface PointFn {
        double at(double x, double y);
    }

    public static Field field(int width, int height, PointFn fn) {
        double[] values = new double[width * height];
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                values[y * width + x] = fn.at(x + 0.5, y + 0.5);
            }
        }
        return new Field(width, height, values);
    }

    public static Field fieldOf(int width, int height, List<Double> values) {
        double[] arr = new double[values.size()];
        for (int i = 0; i < arr.length; i++) {
            arr[i] = values.get(i);
        }
        return new Field(width, height, arr);
    }

    public static Field fieldOf(int width, int height, double[] values) {
        return new Field(width, height, values);
    }

    public static double fieldAt(Field f, int x, int y) {
        return f.values[y * f.width + x];
    }

    /** {least, greatest}. */
    public static double[] fieldRange(Field f) {
        double lo = Double.POSITIVE_INFINITY, hi = Double.NEGATIVE_INFINITY;
        for (double v : f.values) {
            lo = Math.min(lo, v);
            hi = Math.max(hi, v);
        }
        return new double[] {lo, hi};
    }
}
