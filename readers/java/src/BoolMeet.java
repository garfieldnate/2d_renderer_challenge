import java.util.ArrayList;
import java.util.List;

/**
 * §22.2: meet(s, t) says how two segments meet and where each has to be cut,
 * and crossing_point(s, t) is the exact crossing of two segments' lines,
 * rounded to the nearest grid point, halves up. Every test is orient, exact
 * on grid points; the crossing itself needs 64-bit integers (N reaches about
 * 2^59), the one place in the chapter that does.
 */
public final class BoolMeet {
    private BoolMeet() {}

    /**
     * With a = s.lo, b = s.hi, c = t.lo, d = t.hi, β = cross(b-a, d-c) and
     * α = cross(c-a, d-c) (both negated if β < 0). The crossing is
     * a + (b-a) × α / β, and each coordinate is (2N + β) div 2β, N the
     * whole-number numerator, div rounding down toward -∞.
     */
    public static Tuple crossingPoint(Seg s, Seg t) {
        long ax = (long) s.lo.x, ay = (long) s.lo.y;
        long bx = (long) s.hi.x, by = (long) s.hi.y;
        long cx = (long) t.lo.x, cy = (long) t.lo.y;
        long dx = (long) t.hi.x, dy = (long) t.hi.y;
        long dcx = dx - cx, dcy = dy - cy;
        long beta = (bx - ax) * dcy - (by - ay) * dcx;
        long alpha = (cx - ax) * dcy - (cy - ay) * dcx;
        if (beta < 0) {
            beta = -beta;
            alpha = -alpha;
        }
        long nx = ax * beta + (bx - ax) * alpha;
        long ny = ay * beta + (by - ay) * alpha;
        long rx = Math.floorDiv(2 * nx + beta, 2 * beta);
        long ry = Math.floorDiv(2 * ny + beta, 2 * beta);
        return Tuple.point(rx, ry);
    }

    public static MeetResult meet(Seg s, Seg t) {
        Tuple a = s.lo, b = s.hi, c = t.lo, d = t.hi;
        double o1 = Grid.orient(a, b, c);
        double o2 = Grid.orient(a, b, d);
        double o3 = Grid.orient(c, d, a);
        double o4 = Grid.orient(c, d, b);

        if (o1 == 0 && o2 == 0) {
            // collinear: share more than a point, exactly one point, or nothing.
            List<Tuple> onS = new ArrayList<>();
            List<Tuple> onT = new ArrayList<>();
            if (Grid.between(c, a, b)) {
                onS.add(c);
            }
            if (Grid.between(d, a, b)) {
                onS.add(d);
            }
            if (Grid.between(a, c, d)) {
                onT.add(a);
            }
            if (Grid.between(b, c, d)) {
                onT.add(b);
            }
            boolean disjoint = Grid.lexLess(b, c) || Grid.lexLess(d, a);
            String kind;
            if (disjoint) {
                kind = "none";
            } else if (Grid.samePoint(b, c) || Grid.samePoint(d, a)) {
                kind = "end";
            } else {
                kind = "overlap";
            }
            return new MeetResult(kind, onS, onT);
        }

        if (o1 * o2 < 0 && o3 * o4 < 0) {
            Tuple p = crossingPoint(s, t);
            List<Tuple> onS = (Grid.samePoint(p, a) || Grid.samePoint(p, b))
                    ? List.of() : List.of(p);
            List<Tuple> onT = (Grid.samePoint(p, c) || Grid.samePoint(p, d))
                    ? List.of() : List.of(p);
            return new MeetResult("cross", onS, onT);
        }

        List<Tuple> onS = new ArrayList<>();
        List<Tuple> onT = new ArrayList<>();
        if (o1 == 0 && Grid.between(c, a, b)) {
            onS.add(c);
        }
        if (o2 == 0 && Grid.between(d, a, b)) {
            onS.add(d);
        }
        if (o3 == 0 && Grid.between(a, c, d)) {
            onT.add(a);
        }
        if (o4 == 0 && Grid.between(b, c, d)) {
            onT.add(b);
        }
        if (!onS.isEmpty() || !onT.isEmpty()) {
            return new MeetResult("touch", onS, onT);
        }
        boolean sharesEnd = Grid.samePoint(a, c) || Grid.samePoint(a, d)
                || Grid.samePoint(b, c) || Grid.samePoint(b, d);
        return new MeetResult(sharesEnd ? "end" : "none", onS, onT);
    }
}
