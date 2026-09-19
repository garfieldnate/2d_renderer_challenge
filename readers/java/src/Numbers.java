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

    public static long round(double x) {
        return Math.round(x);
    }

    /**
     * Round half to even (banker's rounding), matching the reference
     * implementation's pyround: used where a coordinate can land exactly
     * on a half-integer tie, so an ordinary round-half-up would pick a
     * different pixel than the reference.
     */
    public static long roundHalfEven(double x) {
        long r = Math.round(x);
        if (Math.abs(x % 1) == 0.5 && r % 2 != 0) {
            r -= 1;
        }
        return r;
    }
}
