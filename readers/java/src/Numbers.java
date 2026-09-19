/** Floating point comparison helper. §1.1: a = b means |a - b| <= 0.0001 by default. */
public final class Numbers {
    public static final double DEFAULT_EPSILON = 0.0001;

    private Numbers() {}

    public static boolean approxEqual(double a, double b) {
        return approxEqual(a, b, DEFAULT_EPSILON);
    }

    public static boolean approxEqual(double a, double b, double epsilon) {
        return Math.abs(a - b) <= epsilon;
    }

    /** Round to nearest, halves up (floor(x + 0.5)) -- chapter 1's rule, used everywhere a coordinate is rounded to a pixel. */
    public static long round(double x) {
        return Math.round(x);
    }
}
