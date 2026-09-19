/**
 * §15.1: how long is a curve. path_length(p) sums the segments of every
 * subpath -- a closed subpath's last point connects back to its first.
 * arc_length_table(c, n) is n + 1 running lengths of the polyline through
 * point_at(c, i / n); arc_length(c, n) is its last entry, a little short
 * because chords cut corners, less short the bigger n is. t_at_length(
 * table, s) finds the parameter where the running length reaches s by a
 * binary search for the spanning chord, then linear interpolation inside
 * it -- 0 before the start, 1 past the end. point_at_length and
 * split_at_length hand that parameter to chapter 8's point_at and
 * split_at.
 */
public final class Length {
    private Length() {}

    public static double pathLength(Path p) {
        double total = 0;
        for (Subpath sp : p.subpaths()) {
            var pts = sp.points;
            for (int i = 0; i < pts.size() - 1; i++) {
                total += pts.get(i + 1).subtract(pts.get(i)).magnitude();
            }
            if (sp.closed && pts.size() > 1) {
                total += pts.get(0).subtract(pts.get(pts.size() - 1)).magnitude();
            }
        }
        return total;
    }

    /** n + 1 running lengths of the polyline through point_at(c, i / n), table[0] = 0. */
    public static double[] arcLengthTable(Curve c, int n) {
        double[] table = new double[n + 1];
        table[0] = 0;
        Tuple prev = Curves.pointAt(c, 0);
        for (int i = 1; i <= n; i++) {
            Tuple q = Curves.pointAt(c, (double) i / n);
            table[i] = table[i - 1] + q.subtract(prev).magnitude();
            prev = q;
        }
        return table;
    }

    public static double arcLength(Curve c, int n) {
        return arcLengthTable(c, n)[n];
    }

    /** The parameter where the running length reaches s: 0 before the start, 1 past the end. */
    public static double tAtLength(double[] table, double s) {
        int n = table.length - 1;
        if (s <= 0) {
            return 0;
        }
        if (s >= table[n]) {
            return 1;
        }
        int lo = 0;
        int hi = n;
        while (hi - lo > 1) {
            int mid = (lo + hi) / 2;
            if (table[mid] <= s) {
                lo = mid;
            } else {
                hi = mid;
            }
        }
        double span = table[lo + 1] - table[lo];
        double frac = span > 0 ? (s - table[lo]) / span : 0;
        return (lo + frac) / n;
    }

    public static Tuple pointAtLength(Curve c, double s, int n) {
        return Curves.pointAt(c, tAtLength(arcLengthTable(c, n), s));
    }

    public static Curve[] splitAtLength(Curve c, double s, int n) {
        return Curves.splitAt(c, tAtLength(arcLengthTable(c, n), s));
    }
}
