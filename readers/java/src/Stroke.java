import java.util.ArrayList;
import java.util.List;

/**
 * §13.1, §13.2: stroking is filling. stroke_to_path(path, width, cap, join,
 * miter_limit) turns a stroked path into a fillable outline -- one
 * rectangle per segment, one join wedge per interior vertex, one cap shape
 * per open end, all as subpaths of a single output path, meant to be filled
 * nonzero (chapter 7's fill_path). There is no new rasterizer.
 *
 * §13.3: miter_length(d_in, d_out, h) is the closed form for how far a
 * miter's tip sits from the vertex: h / sin(theta / 2), where theta is the
 * interior angle of the turn -- the angle between the reversed incoming
 * direction and the outgoing one. The stroker itself finds the same point
 * geometrically, by intersecting the two segments' outer edges, and falls
 * back to a bevel when that intersection sits farther than miter_limit * h
 * from the vertex.
 *
 * §13.4: the trap. A subpath's consecutive duplicate points are dropped
 * before anything else, so a doubled point never becomes a zero-length
 * segment to divide by. A subpath of one point (after dedup) is not an
 * error -- with a round cap it's a filled dot of radius h; with a square
 * cap it's a square of the same half-width; with a butt cap it's nothing.
 * A join whose turn is (numerically) zero -- a straight continuation, or an
 * exact hairpin reversal -- emits no join wedge at all: there's no gap to
 * fill either way.
 */
public final class Stroke {
    // Below this, two consecutive points are the same point -- a doubled
    // vertex from a sloppy export, dropped so it never becomes a
    // zero-length segment to divide by.
    private static final double DEDUPE_EPSILON = 1e-9;
    // Below this, a turn's cross product is treated as exactly zero: a
    // straight continuation or an exact hairpin reversal, either way no
    // join wedge to emit.
    private static final double CROSS_EPSILON = 1e-12;
    private static final int DOT_STEPS = 48;

    private Stroke() {}

    /** §13.3: the closed form, h / sin(theta / 2), theta the interior turn angle. */
    public static double miterLength(Tuple dIn, Tuple dOut, double h) {
        Tuple a = dIn.normalize();
        Tuple b = dOut.normalize();
        double dot = Tuple.dot(a.negate(), b);
        dot = Math.max(-1.0, Math.min(1.0, dot));
        double theta = Math.acos(dot);
        return h / Math.sin(theta / 2.0);
    }

    public static Path strokeToPath(Path path, double width, String cap, String join, double miterLimit) {
        double h = width / 2.0;
        Path out = new Path();
        for (Subpath sp : path.subpaths()) {
            List<Tuple> pts = dedupe(sp.points);
            for (List<Tuple> poly : strokeSubpath(pts, sp.closed, h, cap, join, miterLimit)) {
                appendClosedSubpath(out, poly);
            }
        }
        return out;
    }

    private static void appendClosedSubpath(Path out, List<Tuple> poly) {
        boolean first = true;
        for (Tuple p : poly) {
            if (first) {
                out.moveTo(p);
                first = false;
            } else {
                out.lineTo(p);
            }
        }
        out.close();
    }

    private static List<Tuple> dedupe(List<Tuple> pts) {
        List<Tuple> o = new ArrayList<>();
        if (pts.isEmpty()) {
            return o;
        }
        o.add(pts.get(0));
        for (int i = 1; i < pts.size(); i++) {
            Tuple candidate = pts.get(i);
            Tuple last = o.get(o.size() - 1);
            if (candidate.subtract(last).magnitude() > DEDUPE_EPSILON) {
                o.add(candidate);
            }
        }
        return o;
    }

    private static List<List<Tuple>> strokeSubpath(
            List<Tuple> pts, boolean closed, double h, String cap, String join, double ml) {
        List<List<Tuple>> subs = new ArrayList<>();
        if (pts.size() < 2) {
            if (pts.isEmpty()) {
                return subs;
            }
            Tuple c = pts.get(0);
            if (cap.equals("round")) {
                emit(subs, arcPoints(c, 0, 2 * Math.PI, h, DOT_STEPS));
            } else if (cap.equals("square")) {
                emit(subs, List.of(
                        Tuple.point(c.x - h, c.y - h), Tuple.point(c.x + h, c.y - h),
                        Tuple.point(c.x + h, c.y + h), Tuple.point(c.x - h, c.y + h)));
            }
            // butt: nothing at all.
            return subs;
        }

        List<Tuple[]> segs = new ArrayList<>();
        for (int i = 0; i < pts.size() - 1; i++) {
            segs.add(new Tuple[] {pts.get(i), pts.get(i + 1)});
        }
        if (closed) {
            segs.add(new Tuple[] {pts.get(pts.size() - 1), pts.get(0)});
        }

        for (Tuple[] s : segs) {
            emit(subs, segRect(s[0], s[1], h));
        }

        List<Tuple> dirs = new ArrayList<>();
        for (Tuple[] s : segs) {
            dirs.add(unitDir(s[0], s[1]));
        }

        int nj = closed ? segs.size() : segs.size() - 1;
        for (int k = 0; k < nj; k++) {
            Tuple v = segs.get((k + 1) % segs.size())[0];
            List<Tuple> j = joinShape(v, dirs.get(k), dirs.get((k + 1) % segs.size()), h, join, ml);
            if (j != null) {
                emit(subs, j);
            }
        }

        if (!closed) {
            List<Tuple> startCap = capShape(pts.get(0), dirs.get(0).negate(), h, cap);
            if (startCap != null) {
                emit(subs, startCap);
            }
            List<Tuple> endCap = capShape(pts.get(pts.size() - 1), dirs.get(dirs.size() - 1), h, cap);
            if (endCap != null) {
                emit(subs, endCap);
            }
        }
        return subs;
    }

    /**
     * §13.2: every piece has to wind the same way -- counterclockwise on
     * screen, i.e. a negative signed area -- so that overlapping pieces add
     * under nonzero instead of cancelling. A piece that comes out the other
     * way gets its points reversed before it's kept.
     */
    private static void emit(List<List<Tuple>> subs, List<Tuple> piece) {
        List<Tuple> p = new ArrayList<>(piece);
        if (signedArea(p) > 0) {
            java.util.Collections.reverse(p);
        }
        subs.add(p);
    }

    private static double signedArea(List<Tuple> pts) {
        double sum = 0;
        int n = pts.size();
        for (int i = 0; i < n; i++) {
            Tuple a = pts.get(i);
            Tuple b = pts.get((i + 1) % n);
            sum += a.x * b.y - b.x * a.y;
        }
        return sum / 2.0;
    }

    private static Tuple unitDir(Tuple a, Tuple b) {
        return b.subtract(a).normalize();
    }

    private static Tuple perp(Tuple v) {
        return Tuple.vector(-v.y, v.x);
    }

    /** §13.1: the rectangle of half-width h on a..b: the ends offset by ±h along the perpendicular. */
    private static List<Tuple> segRect(Tuple a, Tuple b, double h) {
        Tuple d = unitDir(a, b);
        Tuple n = perp(d);
        return new ArrayList<>(List.of(
                a.add(n.scale(h)), b.add(n.scale(h)),
                b.add(n.scale(-h)), a.add(n.scale(-h))));
    }

    private static Tuple intersectLines(Tuple p1, Tuple d1, Tuple p2, Tuple d2) {
        double den = Tuple.cross(d1, d2);
        if (Math.abs(den) < CROSS_EPSILON) {
            return null;
        }
        double t = Tuple.cross(p2.subtract(p1), d2) / den;
        return p1.add(d1.scale(t));
    }

    /** The signed shortest angular difference from a0 to a1, wrapped to (-pi, pi]. */
    private static double angBetween(double a0, double a1) {
        double d = (a1 - a0) % (2 * Math.PI);
        if (d > Math.PI) {
            d -= 2 * Math.PI;
        }
        if (d <= -Math.PI) {
            d += 2 * Math.PI;
        }
        return d;
    }

    private static int arcSteps(double a0, double a1) {
        return (int) Math.max(2, Math.ceil(Math.abs(a1 - a0) / (Math.PI / 16)));
    }

    private static List<Tuple> arcPoints(Tuple c, double a0, double a1, double r, int steps) {
        List<Tuple> pts = new ArrayList<>();
        for (int k = 0; k <= steps; k++) {
            double a = a0 + (a1 - a0) * k / steps;
            pts.add(Tuple.point(c.x + r * Math.cos(a), c.y + r * Math.sin(a)));
        }
        return pts;
    }

    /**
     * §13.1, §13.3: the wedge that fills the outer gap at an interior
     * vertex. Which side is "outer" depends on which way the path turns
     * (the sign of the cross product of the two directions); a turn of
     * (numerically) zero -- straight ahead, or an exact hairpin reversal --
     * has no defined outer side and gets no wedge at all.
     */
    private static List<Tuple> joinShape(Tuple v, Tuple din, Tuple dout, double h, String join, double ml) {
        double turn = Tuple.cross(din, dout);
        if (Math.abs(turn) < CROSS_EPSILON) {
            return null;
        }
        double s = turn > 0 ? -1 : 1;
        Tuple nin = perp(din).scale(s);
        Tuple nout = perp(dout).scale(s);
        Tuple a = v.add(nin.scale(h));
        Tuple b = v.add(nout.scale(h));

        if (join.equals("bevel")) {
            return List.of(v, a, b);
        }
        if (join.equals("round")) {
            // §13.1: the arc has to go the short way round -- the long way
            // sweeps through the inside of the turn and leaves a notch.
            // angBetween wraps the raw angle difference to (-pi, pi], the
            // signed shortest turn from a0 to a1.
            double a0 = Math.atan2(a.y - v.y, a.x - v.x);
            double a1raw = Math.atan2(b.y - v.y, b.x - v.x);
            double a1 = a0 + angBetween(a0, a1raw);
            List<Tuple> p = new ArrayList<>();
            p.add(v);
            p.addAll(arcPoints(v, a0, a1, h, arcSteps(a0, a1)));
            return p;
        }
        // miter: extend the two outer edges until they meet, falling back
        // to a bevel when the tip sits farther than miter_limit * h away.
        Tuple m = intersectLines(a, din, b, dout);
        if (m != null && m.subtract(v).magnitude() <= ml * h) {
            return List.of(v, a, m, b);
        }
        return List.of(v, a, b);
    }

    /**
     * §14.5 reuses chapter 13's cap shapes, walked as points instead of
     * emitted as separate pieces.
     */
    public static List<Tuple> capShapePublic(Tuple p, Tuple dout, double h, String cap) {
        return capShape(p, dout, h, cap);
    }

    /** §14.5 reuses chapter 13's dedupe rule for the curve stroker's point list. */
    public static List<Tuple> dedupePublic(List<Tuple> pts) {
        return dedupe(pts);
    }

    /** §13.1, §13.4: the shape that closes an open end. dout points away from the path, out of the endpoint. */
    private static List<Tuple> capShape(Tuple p, Tuple dout, double h, String cap) {
        Tuple n = perp(dout);
        if (cap.equals("butt")) {
            return null;
        }
        if (cap.equals("square")) {
            Tuple l = p.add(n.scale(h));
            Tuple r = p.add(n.scale(-h));
            return List.of(l, l.add(dout.scale(h)), r.add(dout.scale(h)), r);
        }
        // round: a semicircle from n's angle to -n's angle, swept through dout.
        double a0 = Math.atan2(n.y, n.x);
        double outw = Math.atan2(dout.y, dout.x);
        double d = ((outw - a0) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI);
        if (d > Math.PI) {
            d -= 2 * Math.PI;
        }
        double a1 = a0 + (d > 0 ? Math.PI : -Math.PI);
        return arcPoints(p, a0, a1, h, arcSteps(a0, a1));
    }
}
