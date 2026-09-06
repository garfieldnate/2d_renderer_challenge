/**
 * §4.1: a point or a vector, both (x, y, w). point(x, y) has w = 1;
 * vector(x, y) has w = 0. The arithmetic below does the bookkeeping: point
 * minus point is a vector (w = 0), point plus vector is a point (w = 1),
 * vector plus vector is a vector (w = 0). Adding two points gives w = 2,
 * which is nobody's job to interpret -- the arithmetic doesn't stop you,
 * but nothing in this book ever does it on purpose.
 */
public final class Tuple {
    public final double x;
    public final double y;
    public final double w;

    Tuple(double x, double y, double w) {
        this.x = x;
        this.y = y;
        this.w = w;
    }

    public static Tuple point(double x, double y) {
        return new Tuple(x, y, 1);
    }

    public static Tuple vector(double x, double y) {
        return new Tuple(x, y, 0);
    }

    public Tuple add(Tuple o) {
        return new Tuple(x + o.x, y + o.y, w + o.w);
    }

    public Tuple subtract(Tuple o) {
        return new Tuple(x - o.x, y - o.y, w - o.w);
    }

    public Tuple negate() {
        return new Tuple(-x, -y, -w);
    }

    public Tuple scale(double s) {
        return new Tuple(x * s, y * s, w * s);
    }

    public Tuple divide(double s) {
        return new Tuple(x / s, y / s, w / s);
    }

    /** magnitude(v) = sqrt(x^2 + y^2); w plays no part. */
    public double magnitude() {
        return Math.hypot(x, y);
    }

    /** normalize(v): the same direction, length 1. */
    public Tuple normalize() {
        double m = magnitude();
        return new Tuple(x / m, y / m, w / m);
    }

    /** dot(a, b) = a.x*b.x + a.y*b.y: how much of a points along b. */
    public static double dot(Tuple a, Tuple b) {
        return a.x * b.x + a.y * b.y;
    }

    /**
     * cross(a, b) = a.x*b.y - a.y*b.x: the 2D cross product, a single
     * number whose sign says which way you turned from a to b.
     */
    public static double cross(Tuple a, Tuple b) {
        return a.x * b.y - a.y * b.x;
    }

    public boolean approxEquals(Tuple o) {
        return Numbers.approxEqual(x, o.x) && Numbers.approxEqual(y, o.y) && Numbers.approxEqual(w, o.w);
    }

    @Override
    public String toString() {
        return "(" + x + ", " + y + ", " + w + ")";
    }
}
