import java.util.ArrayList;
import java.util.List;

/**
 * §23.2: fields for curves. solve_cubic is exact, by Cardano's formula or the
 * cosine formula; distance_to_quadratic uses it directly; distance_to_cubic
 * falls back to nine Newton seeds plus both ends, since a quintic has no
 * formula; brute_distance is the ground truth by search, refining around
 * every local minimum, not just the best sample, so it doesn't miss a curve
 * that loops back past the point.
 */
public final class CurveDistance {
    private CurveDistance() {}

    private static final double EPS = 1e-12;

    /** The real roots of a t^3 + b t^2 + c t + d = 0, in increasing order. */
    public static List<Double> solveCubic(double a, double b, double c, double d) {
        List<Double> roots = new ArrayList<>();
        if (Math.abs(a) < EPS) {
            if (Math.abs(b) < EPS) {
                if (Math.abs(c) < EPS) {
                    return roots;
                }
                roots.add(-d / c);
                return roots;
            }
            double disc = c * c - 4 * b * d;
            if (disc < 0) {
                return roots;
            }
            if (disc == 0) {
                roots.add(-c / (2 * b));
                return roots;
            }
            double sq = Math.sqrt(disc);
            double r1 = (-c - sq) / (2 * b);
            double r2 = (-c + sq) / (2 * b);
            roots.add(Math.min(r1, r2));
            roots.add(Math.max(r1, r2));
            return roots;
        }

        double bb = b / a, cc = c / a, dd = d / a;
        double p = cc - bb * bb / 3;
        double q = 2 * bb * bb * bb / 27 - bb * cc / 3 + dd;
        double shift = -bb / 3;
        double delta = (q / 2) * (q / 2) + (p / 3) * (p / 3) * (p / 3);

        if (delta > 0 || p >= -EPS) {
            double sq = Math.sqrt(Math.max(0, delta));
            double x = Math.cbrt(-q / 2 + sq) + Math.cbrt(-q / 2 - sq);
            roots.add(x + shift);
            return roots;
        }

        double u = 2 * Math.sqrt(-p / 3);
        double arg = (3 * q) / (p * u);
        arg = Math.max(-1, Math.min(1, arg));
        double theta = Math.acos(arg) / 3;
        for (int k = 0; k < 3; k++) {
            double x = u * Math.cos(theta - 2 * Math.PI * k / 3);
            roots.add(x + shift);
        }
        roots.sort(Double::compare);
        return roots;
    }

    public static double distanceToQuadratic(Tuple p, Curve c) {
        double t = nearestTQuadratic(p, c);
        return Curves.pointAt(c, t).subtract(p).magnitude();
    }

    /** The t in {0, 1} or a root of the cubic whose point is nearest p. */
    public static double nearestTQuadratic(Tuple p, Curve c) {
        List<Tuple> pts = c.points();
        Tuple p0 = pts.get(0), p1 = pts.get(1), p2 = pts.get(2);
        Tuple a0 = p0.subtract(p);
        Tuple a1 = p1.subtract(p0).scale(2);
        Tuple a2 = p0.subtract(p1.scale(2)).add(p2);
        List<Double> roots = solveCubic(
                2 * Tuple.dot(a2, a2),
                3 * Tuple.dot(a1, a2),
                Tuple.dot(a1, a1) + 2 * Tuple.dot(a0, a2),
                Tuple.dot(a0, a1));
        double bestT = 0;
        double bestD = p0.subtract(p).magnitude();
        double d1 = p2.subtract(p).magnitude();
        if (d1 < bestD) {
            bestD = d1;
            bestT = 1;
        }
        for (double t : roots) {
            if (t > 0 && t < 1) {
                double d = Curves.pointAt(c, t).subtract(p).magnitude();
                if (d < bestD) {
                    bestD = d;
                    bestT = t;
                }
            }
        }
        return bestT;
    }

    private static final int NEWTON_SEEDS = 9;
    private static final int NEWTON_STEPS = 8;

    public static double nearestTCubic(Tuple p, Curve c) {
        double bestT = 0;
        double bestD = Curves.pointAt(c, 0).subtract(p).magnitude();
        double d1 = Curves.pointAt(c, 1).subtract(p).magnitude();
        if (d1 < bestD) {
            bestT = 1;
            bestD = d1;
        }
        for (int i = 0; i < NEWTON_SEEDS; i++) {
            double t = (double) i / (NEWTON_SEEDS - 1);
            for (int step = 0; step < NEWTON_STEPS; step++) {
                Tuple b = Curves.pointAt(c, t);
                Tuple bp = Curves.derivative(c, t);
                Tuple bpp = Offset.secondDerivative(c, t);
                double f = Tuple.dot(b.subtract(p), bp);
                double fp = Tuple.dot(bp, bp) + Tuple.dot(b.subtract(p), bpp);
                if (fp == 0) {
                    break;
                }
                t = t - f / fp;
                t = Math.max(0, Math.min(1, t));
            }
            double d = Curves.pointAt(c, t).subtract(p).magnitude();
            if (d < bestD) {
                bestD = d;
                bestT = t;
            }
        }
        return bestT;
    }

    public static double distanceToCubic(Tuple p, Curve c) {
        double t = nearestTCubic(p, c);
        return Curves.pointAt(c, t).subtract(p).magnitude();
    }

    private static final int BRUTE_SAMPLES = 128;
    private static final int BRUTE_TERNARY_ROUNDS = 40;

    public static double bruteDistance(Curve c, Tuple p) {
        double[] ts = new double[BRUTE_SAMPLES + 1];
        double[] ds = new double[BRUTE_SAMPLES + 1];
        for (int i = 0; i <= BRUTE_SAMPLES; i++) {
            ts[i] = (double) i / BRUTE_SAMPLES;
            ds[i] = Curves.pointAt(c, ts[i]).subtract(p).magnitude();
        }
        double best = Double.POSITIVE_INFINITY;
        for (int i = 0; i <= BRUTE_SAMPLES; i++) {
            boolean localMin;
            if (i == 0) {
                localMin = ds[i] <= ds[i + 1];
            } else if (i == BRUTE_SAMPLES) {
                localMin = ds[i] <= ds[i - 1];
            } else {
                localMin = ds[i] <= ds[i - 1] && ds[i] <= ds[i + 1];
            }
            if (!localMin) {
                continue;
            }
            double lo = ts[Math.max(0, i - 1)];
            double hi = ts[Math.min(BRUTE_SAMPLES, i + 1)];
            for (int k = 0; k < BRUTE_TERNARY_ROUNDS; k++) {
                double m1 = lo + (hi - lo) / 3;
                double m2 = hi - (hi - lo) / 3;
                double d1 = Curves.pointAt(c, m1).subtract(p).magnitude();
                double d2 = Curves.pointAt(c, m2).subtract(p).magnitude();
                if (d1 < d2) {
                    hi = m2;
                } else {
                    lo = m1;
                }
            }
            double tMid = (lo + hi) / 2;
            best = Math.min(best, Curves.pointAt(c, tMid).subtract(p).magnitude());
        }
        return best;
    }

    private static final double WEYL_A = 0.7548776662466927;
    private static final double WEYL_B = 0.5698402909980532;

    private static double frac(double v) {
        return v - Math.floor(v);
    }

    public static List<Tuple> weylPoints(int n, double x0, double y0, double w, double h) {
        List<Tuple> pts = new ArrayList<>();
        for (int k = 1; k <= n; k++) {
            pts.add(Tuple.point(x0 + w * frac(k * WEYL_A), y0 + h * frac(k * WEYL_B)));
        }
        return pts;
    }

    public static double maxCurveError(Curve c, List<Tuple> pts) {
        double worst = 0;
        boolean cubic = c.degree() == 3;
        for (Tuple p : pts) {
            double d = cubic ? distanceToCubic(p, c) : distanceToQuadratic(p, c);
            double brute = bruteDistance(c, p);
            worst = Math.max(worst, Math.abs(d - brute));
        }
        return worst;
    }
}
