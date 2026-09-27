/**
 * §22.1: a grid of 1/256 of a pixel. grid(v) is floor(v * 256 + 0.5), halves
 * up, and snap_point(p) is point(grid(p.x), grid(p.y)). Coordinates are kept
 * within 1024 pixels of the origin (262144 units) so that orient(a, b, c) --
 * chapter 4's cross product of b - a and c - a, computed on grid points --
 * is exact even in a language whose only number is a double: every
 * difference is below 2^19 and every product below 2^40. lex_less(p, q) is
 * the sweep's order, top to bottom and then left to right.
 */
public final class Grid {
    private Grid() {}

    public static long grid(double v) {
        return (long) Math.floor(v * 256.0 + 0.5);
    }

    public static Tuple snapPoint(Tuple p) {
        return Tuple.point(grid(p.x), grid(p.y));
    }

    public static double orient(Tuple a, Tuple b, Tuple c) {
        return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    }

    public static boolean lexLess(Tuple p, Tuple q) {
        return p.y < q.y || (p.y == q.y && p.x < q.x);
    }

    /** Exact equality of two grid points -- they hold whole numbers, so == is safe. */
    public static boolean samePoint(Tuple a, Tuple b) {
        return a.x == b.x && a.y == b.y;
    }

    /** A point is strictly inside a segment (a, b) when lex_less puts it strictly between. */
    public static boolean between(Tuple p, Tuple a, Tuple b) {
        return lexLess(a, p) && lexLess(p, b);
    }

    public static String key(Tuple p) {
        return ((long) p.x) + "," + ((long) p.y);
    }
}
