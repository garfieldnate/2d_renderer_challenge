import java.util.ArrayList;
import java.util.List;

/**
 * Chapter 14: offsetting curves. The offset of a curve at distance d isn't
 * a Bezier -- its tangent's length is the square root of a quartic -- so
 * this chapter fits one cubic per piece and admits how far off it is.
 *
 * §14.1: tangent_at(c, t) is the unit tangent (chapter 8's derivative,
 * normalized); normal_at(c, t) is that turned a quarter turn toward +y,
 * which on this y-down canvas is the right-hand side of travel, the same
 * +h side chapter 13's rectangles used. offset_point(c, t, d) steps d
 * along the normal. Where the derivative vanishes (a handle dropped on its
 * anchor), the direction is taken a hair further into the curve instead
 * (live_t).
 *
 * §14.2: second_derivative(c, t) is one degree further down de Casteljau's
 * ladder than chapter 8's derivative. curvature(c, t) = cross(v, a) / |v|^3,
 * signed like chapter 4's cross -- positive where the curve turns clockwise
 * on screen, the same side positive d points to. The offset moves at
 * (1 - curvature * d) times the curve's speed, so cusps(c, d) -- where that
 * factor changes sign -- are found by 64 evenly spaced samples, bisected 40
 * times wherever two neighbours disagree.
 *
 * §14.3: fit_offset(c, d) is the one cubic with the curve's own end
 * tangents whose midpoint lands on the true offset's midpoint, a 2x2
 * cross-product solve; parallel tangents fall back to a third of the
 * chord. offset_error(c, d, fitted) is the worst miss over 17 matched
 * parameters. distance_to_curve(c, p) is the honest measure: the nearest
 * of 65 samples, refined by 32 rounds of ternary search between its two
 * neighbours.
 *
 * §14.4: offset_curve(c, d, tolerance) splits the curve at its cusps, then
 * fits, halves and refits each piece (sub_curve is two splits) until
 * offset_error is within tolerance or sixteen halvings have passed.
 * offset_distance_error(c, d, tolerance) walks 100 points along the result
 * and asks how far each strays from the honest distance |d|.
 *
 * §14.5: stroke_curve_to_path(c, width, cap, tolerance) is one closed
 * subpath -- the +h offset flattened forward, the end cap, the -h offset
 * flattened backward, the start cap -- filled nonzero; the inner fold is a
 * loop the fill rule resolves, not an error. flatten_then_stroke is the way
 * you'd have done it yesterday: flatten first, then chapter 13.
 */
public final class Offset {
    private static final double LIVE_EPSILON = 1e-9;
    private static final double LIVE_T_STEP = 1e-4;
    private static final double PARALLEL_EPSILON = 1e-9;
    private static final int CUSP_SAMPLES = 64;
    private static final int CUSP_BISECTIONS = 40;
    private static final int MAX_HALVINGS = 16;
    private static final int DISTANCE_SAMPLES = 64;
    private static final int DISTANCE_TERNARY_ROUNDS = 32;
    private static final int WALK_POINTS = 100;

    private Offset() {}

    /** §14.1: where the derivative vanishes, nudge a hair further into the curve. */
    private static double liveT(Curve c, double t) {
        Tuple v = Curves.derivative(c, t);
        if (v.magnitude() < LIVE_EPSILON) {
            return t < 0.5 ? t + LIVE_T_STEP : t - LIVE_T_STEP;
        }
        return t;
    }

    public static Tuple tangentAt(Curve c, double t) {
        Tuple v = Curves.derivative(c, liveT(c, t));
        return v.normalize();
    }

    /** The tangent turned a quarter turn toward +y -- the right of travel on this y-down canvas. */
    public static Tuple normalAt(Curve c, double t) {
        Tuple tan = tangentAt(c, t);
        return Tuple.vector(-tan.y, tan.x);
    }

    public static Tuple offsetPoint(Curve c, double t, double d) {
        return Curves.pointAt(c, t).add(normalAt(c, t).scale(d));
    }

    /** §14.2: one degree further down de Casteljau's ladder than chapter 8's derivative. */
    public static Tuple secondDerivative(Curve c, double t) {
        List<Tuple> pts = c.points();
        if (c.degree() == 2) {
            Tuple p0 = pts.get(0);
            Tuple p1 = pts.get(1);
            Tuple p2 = pts.get(2);
            return p0.subtract(p1.scale(2)).add(p2).scale(2);
        }
        Tuple p0 = pts.get(0);
        Tuple p1 = pts.get(1);
        Tuple p2 = pts.get(2);
        Tuple p3 = pts.get(3);
        Tuple a = p0.subtract(p1.scale(2)).add(p2);
        Tuple b = p1.subtract(p2.scale(2)).add(p3);
        return a.scale(1 - t).add(b.scale(t)).scale(6);
    }

    public static double curvature(Curve c, double t) {
        double lt = liveT(c, t);
        Tuple v = Curves.derivative(c, lt);
        Tuple a = secondDerivative(c, lt);
        double s = v.magnitude();
        return Tuple.cross(v, a) / (s * s * s);
    }

    private static double stallFactor(Curve c, double t, double d) {
        return 1 - curvature(c, t) * d;
    }

    /**
     * §14.2: the parameters where 1 - curvature(t) * d changes sign: 64
     * evenly spaced samples, bisected 40 times between any pair that
     * disagree.
     */
    public static List<Double> cusps(Curve c, double d) {
        List<Double> out = new ArrayList<>();
        double prev = stallFactor(c, 0, d);
        for (int i = 1; i <= CUSP_SAMPLES; i++) {
            double t = (double) i / CUSP_SAMPLES;
            double cur = stallFactor(c, t, d);
            if ((prev < 0) != (cur < 0)) {
                double lo = (double) (i - 1) / CUSP_SAMPLES;
                double hi = t;
                double flo = prev;
                for (int k = 0; k < CUSP_BISECTIONS; k++) {
                    double mid = (lo + hi) / 2;
                    double fm = stallFactor(c, mid, d);
                    if ((fm < 0) == (flo < 0)) {
                        lo = mid;
                        flo = fm;
                    } else {
                        hi = mid;
                    }
                }
                out.add((lo + hi) / 2);
            }
            prev = cur;
        }
        return out;
    }

    /** §14.3: the one cubic through the curve's own end tangents and the true offset's midpoint. */
    public static Curve fitOffset(Curve c, double d) {
        Tuple p0 = offsetPoint(c, 0, d);
        Tuple p3 = offsetPoint(c, 1, d);
        Tuple t0 = tangentAt(c, 0);
        Tuple t1 = tangentAt(c, 1);
        Tuple m = offsetPoint(c, 0.5, d);
        Tuple r = m.scale(8).subtract(p0.scale(4)).subtract(p3.scale(4)).scale(1.0 / 3.0);
        double den = Tuple.cross(t0, t1);
        double a;
        double b;
        if (Math.abs(den) < PARALLEL_EPSILON) {
            a = b = p3.subtract(p0).magnitude() / 3.0;
        } else {
            a = Tuple.cross(r, t1) / den;
            b = Tuple.cross(r, t0) / den;
        }
        return Curve.cubic(p0, p0.add(t0.scale(a)), p3.subtract(t1.scale(b)), p3);
    }

    /** §14.3: the worst miss over 17 matched parameters t = i / 16. */
    public static double offsetError(Curve c, double d, Curve fitted) {
        double worst = 0;
        for (int i = 0; i <= 16; i++) {
            double t = i / 16.0;
            double miss = Curves.pointAt(fitted, t).subtract(offsetPoint(c, t, d)).magnitude();
            worst = Math.max(worst, miss);
        }
        return worst;
    }

    /**
     * §14.3: the honest measure -- nearest of 65 samples, refined by 32
     * rounds of ternary search between its two neighbours.
     */
    public static double distanceToCurve(Curve c, Tuple p) {
        double[] ts = new double[DISTANCE_SAMPLES + 1];
        double best = Double.POSITIVE_INFINITY;
        int bestI = 0;
        for (int i = 0; i <= DISTANCE_SAMPLES; i++) {
            ts[i] = (double) i / DISTANCE_SAMPLES;
            double dd = Curves.pointAt(c, ts[i]).subtract(p).magnitude();
            if (dd < best) {
                best = dd;
                bestI = i;
            }
        }
        double lo = ts[Math.max(0, bestI - 1)];
        double hi = ts[Math.min(DISTANCE_SAMPLES, bestI + 1)];
        for (int k = 0; k < DISTANCE_TERNARY_ROUNDS; k++) {
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
        return Curves.pointAt(c, tMid).subtract(p).magnitude();
    }

    /** §14.4: the piece of a curve between two parameters, by splitting twice. */
    public static Curve subCurve(Curve c, double t0, double t1) {
        Curve right = t0 > 0 ? Curves.splitAt(c, t0)[1] : c;
        if (t1 < 1) {
            return Curves.splitAt(right, (t1 - t0) / (1 - t0))[0];
        }
        return right;
    }

    private static void offsetInto(Curve c, double d, double tolerance, List<Curve> out, int depth) {
        Curve fitted = fitOffset(c, d);
        if (offsetError(c, d, fitted) <= tolerance || depth >= MAX_HALVINGS) {
            out.add(fitted);
            return;
        }
        Curve[] halves = Curves.splitAt(c, 0.5);
        offsetInto(halves[0], d, tolerance, out, depth + 1);
        offsetInto(halves[1], d, tolerance, out, depth + 1);
    }

    /** §14.4: split at the cusps, then fit-halve-refit each piece, capped at sixteen halvings. */
    public static List<Curve> offsetCurve(Curve c, double d, double tolerance) {
        List<Double> ts = new ArrayList<>();
        ts.add(0.0);
        for (double t : cusps(c, d)) {
            if (t - ts.get(ts.size() - 1) > 1e-9 && 1 - t > 1e-9) {
                ts.add(t);
            }
        }
        ts.add(1.0);
        List<Curve> out = new ArrayList<>();
        for (int i = 0; i < ts.size() - 1; i++) {
            offsetInto(subCurve(c, ts.get(i), ts.get(i + 1)), d, tolerance, out, 0);
        }
        return out;
    }

    /** §14.4: how far 100 points spread along the result stray from distance |d| to the curve. */
    public static double offsetDistanceError(Curve c, double d, double tolerance) {
        List<Curve> pieces = offsetCurve(c, d, tolerance);
        int n = pieces.size();
        double worst = 0;
        for (int i = 0; i < WALK_POINTS; i++) {
            double s = (double) i / (WALK_POINTS - 1) * n;
            int idx = Math.min((int) Math.floor(s), n - 1);
            double localT = Math.min(1.0, s - idx);
            Tuple p = Curves.pointAt(pieces.get(idx), localT);
            double miss = Math.abs(distanceToCurve(c, p) - Math.abs(d));
            worst = Math.max(worst, miss);
        }
        return worst;
    }

    /** Flattens every piece of an offset_curve into one chained list of points. */
    public static List<Tuple> offsetPath(Curve c, double d, double tolerance) {
        List<Tuple> pts = new ArrayList<>();
        for (Curve piece : offsetCurve(c, d, tolerance)) {
            List<Tuple> f = Curves.flatten(piece, tolerance);
            if (!pts.isEmpty() && !f.isEmpty() && pts.get(pts.size() - 1).approxEquals(f.get(0))) {
                f = f.subList(1, f.size());
            }
            pts.addAll(f);
        }
        return pts;
    }

    private static List<Tuple> capPoints(Tuple p, Tuple dout, double h, String cap) {
        List<Tuple> s = Stroke.capShapePublic(p, dout, h, cap);
        return s != null ? s : new ArrayList<>();
    }

    /**
     * §14.5: one closed subpath -- the +h offset flattened forward, the
     * end cap, the -h offset flattened backward, the start cap -- meant to
     * be filled nonzero. The inner fold is a loop the fill rule resolves.
     */
    public static Path strokeCurveToPath(Curve c, double width, String cap, double tolerance) {
        double h = width / 2.0;
        List<Tuple> pts = new ArrayList<>();
        for (Curve piece : offsetCurve(c, h, tolerance)) {
            pts.addAll(Curves.flatten(piece, tolerance));
        }
        pts.addAll(capPoints(Curves.pointAt(c, 1), tangentAt(c, 1), h, cap));
        List<Curve> negPieces = offsetCurve(c, -h, tolerance);
        for (int i = negPieces.size() - 1; i >= 0; i--) {
            List<Tuple> f = new ArrayList<>(Curves.flatten(negPieces.get(i), tolerance));
            java.util.Collections.reverse(f);
            pts.addAll(f);
        }
        Tuple t0 = tangentAt(c, 0);
        pts.addAll(capPoints(Curves.pointAt(c, 0), t0.negate(), h, cap));

        List<Tuple> deduped = Stroke.dedupePublic(pts);
        if (deduped.size() > 1
                && deduped.get(deduped.size() - 1).subtract(deduped.get(0)).magnitude() < 1e-9) {
            deduped.remove(deduped.size() - 1);
        }

        Path out = new Path();
        boolean first = true;
        for (Tuple p : deduped) {
            if (first) {
                out.moveTo(p);
                first = false;
            } else {
                out.lineTo(p);
            }
        }
        out.close();
        return out;
    }

    /** §14.5: yesterday's way -- flatten first, then chapter 13, with round joins. */
    public static Path flattenThenStroke(Curve c, double width, String cap, double tolerance) {
        Path flat = new Path();
        List<Tuple> pts = Curves.flatten(c, tolerance);
        boolean first = true;
        for (Tuple p : pts) {
            if (first) {
                flat.moveTo(p);
                first = false;
            } else {
                flat.lineTo(p);
            }
        }
        return Stroke.strokeToPath(flat, width, cap, "round", 4.0);
    }

    /** A test helper: how many points a path holds across all its subpaths. */
    public static int pointCount(Path p) {
        int total = 0;
        for (Subpath sp : p.subpaths()) {
            total += sp.points.size();
        }
        return total;
    }
}
