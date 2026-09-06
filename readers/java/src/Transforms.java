/**
 * §4.3: the four matrices a renderer actually builds, plus §4.4's
 * approx_scale. Angles are in radians. A positive rotation turns the x axis
 * toward the y axis, which is clockwise on a canvas whose y runs downward.
 */
public final class Transforms {
    private Transforms() {}

    public static Matrix translation(double tx, double ty) {
        return Matrix.matrix3(
                1, 0, tx,
                0, 1, ty,
                0, 0, 1);
    }

    public static Matrix scaling(double sx, double sy) {
        return Matrix.matrix3(
                sx, 0, 0,
                0, sy, 0,
                0, 0, 1);
    }

    public static Matrix rotation(double r) {
        double c = Math.cos(r);
        double s = Math.sin(r);
        return Matrix.matrix3(
                c, -s, 0,
                s, c, 0,
                0, 0, 1);
    }

    public static Matrix shearing(double xy, double yx) {
        return Matrix.matrix3(
                1, xy, 0,
                yx, 1, 0,
                0, 0, 1);
    }

    /**
     * §4.4: approx_scale(m), the book's one number for how much m stretches
     * lengths -- the square root of the absolute value of the determinant
     * of its upper-left 2 by 2. Exact for uniform scales and rotations, the
     * geometric mean for a non-uniform scale, and a compromise for a shear.
     */
    public static double approxScale(Matrix m) {
        double det2 = m.get(0, 0) * m.get(1, 1) - m.get(0, 1) * m.get(1, 0);
        return Math.sqrt(Math.abs(det2));
    }
}
