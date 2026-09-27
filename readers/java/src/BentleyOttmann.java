import java.math.BigInteger;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;

/**
 * §22.7: Bentley-Ottmann. Keep the active list in order left to right along
 * the sweep line (the status); events are points, handled once each in the
 * sweep's order. A crossing's exact point is a fraction (X/D, Y/D); events
 * are kept and ordered exactly, with BigInteger where a long isn't enough
 * (about 80 bits to test a segment against an event, about 100 to order two
 * events).
 */
final class BentleyOttmann {
    private BentleyOttmann() {}

    /** A live piece of an original segment, from its current start to its original end. */
    private static final class Piece {
        final Tuple lo;
        final Tuple hi;
        final int origIndex;

        Piece(Tuple lo, Tuple hi, int origIndex) {
            this.lo = lo;
            this.hi = hi;
            this.origIndex = origIndex;
        }
    }

    /** An exact event point (X/D, Y/D), D > 0. */
    private static final class REvent implements Comparable<REvent> {
        final long x, y, d;

        REvent(long x, long y, long d) {
            this.x = x;
            this.y = y;
            this.d = d;
        }

        static REvent ofGrid(Tuple p) {
            return new REvent((long) p.x, (long) p.y, 1);
        }

        boolean isGridPoint() {
            return x % d == 0 && y % d == 0;
        }

        Tuple toGrid() {
            long rx = Math.floorDiv(2 * x + d, 2 * d);
            long ry = Math.floorDiv(2 * y + d, 2 * d);
            return Tuple.point(rx, ry);
        }

        @Override
        public int compareTo(REvent o) {
            BigInteger y1 = BigInteger.valueOf(y).multiply(BigInteger.valueOf(o.d));
            BigInteger y2 = BigInteger.valueOf(o.y).multiply(BigInteger.valueOf(d));
            int cy = y1.compareTo(y2);
            if (cy != 0) {
                return cy;
            }
            BigInteger x1 = BigInteger.valueOf(x).multiply(BigInteger.valueOf(o.d));
            BigInteger x2 = BigInteger.valueOf(o.x).multiply(BigInteger.valueOf(d));
            return x1.compareTo(x2);
        }
    }

    private static REvent crossingEvent(Tuple a, Tuple b, Tuple c, Tuple d) {
        long ax = (long) a.x, ay = (long) a.y, bx = (long) b.x, by = (long) b.y;
        long cx = (long) c.x, cy = (long) c.y, dx = (long) d.x, dy = (long) d.y;
        long dcx = dx - cx, dcy = dy - cy;
        long beta = (bx - ax) * dcy - (by - ay) * dcx;
        long alpha = (cx - ax) * dcy - (cy - ay) * dcx;
        if (beta < 0) {
            beta = -beta;
            alpha = -alpha;
        }
        long nx = ax * beta + (bx - ax) * alpha;
        long ny = ay * beta + (by - ay) * alpha;
        return new REvent(nx, ny, beta);
    }

    /** Sign of orient(piece.lo, piece.hi, p), exact, p a possibly-fractional event. */
    private static int rawOrientSign(Piece piece, REvent p) {
        long dx = (long) (piece.hi.x - piece.lo.x);
        long dy = (long) (piece.hi.y - piece.lo.y);
        long loy = (long) piece.lo.y;
        long lox = (long) piece.lo.x;
        BigInteger t1 = BigInteger.valueOf(dx)
                .multiply(BigInteger.valueOf(p.y).subtract(BigInteger.valueOf(p.d).multiply(BigInteger.valueOf(loy))));
        BigInteger t2 = BigInteger.valueOf(dy)
                .multiply(BigInteger.valueOf(p.x).subtract(BigInteger.valueOf(p.d).multiply(BigInteger.valueOf(lox))));
        return t1.subtract(t2).signum();
    }

    /** p's sweep-order position against a grid point g: negative, zero or positive. */
    private static int compareToGrid(REvent p, Tuple g) {
        long gy = (long) g.y, gx = (long) g.x;
        long lhsY = p.y, rhsY = gy * p.d;
        if (lhsY != rhsY) {
            return Long.compare(lhsY, rhsY);
        }
        long lhsX = p.x, rhsX = gx * p.d;
        return Long.compare(lhsX, rhsX);
    }

    /**
     * A piece can be exactly collinear with a far-off event (a rounded cut can
     * leave a piece running along a grid line, e.g. horizontal) without P
     * actually lying within its range. Only a P genuinely between lo and hi
     * counts as passing through the piece; one collinear but before lo or
     * after hi is treated as ahead of / behind the piece instead.
     */
    private static int orientSign(Piece piece, REvent p) {
        int sign = rawOrientSign(piece, p);
        if (sign != 0) {
            return sign;
        }
        if (compareToGrid(p, piece.lo) < 0) {
            return 1;
        }
        if (compareToGrid(p, piece.hi) > 0) {
            return -1;
        }
        return 0;
    }

    static List<List<Tuple>> findSplits(List<Seg> segs, SweepStats st) {
        int n = segs.size();
        List<List<Tuple>> out = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            out.add(new ArrayList<>());
        }

        TreeSet<REvent> queue = new TreeSet<>();
        Map<String, List<Piece>> startsAt = new HashMap<>();
        for (int i = 0; i < n; i++) {
            Seg s = segs.get(i);
            queue.add(REvent.ofGrid(s.lo));
            queue.add(REvent.ofGrid(s.hi));
            startsAt.computeIfAbsent(Grid.key(s.lo), k -> new ArrayList<>())
                    .add(new Piece(s.lo, s.hi, i));
        }

        List<Piece> status = new ArrayList<>();

        while (!queue.isEmpty()) {
            REvent p = queue.pollFirst();
            st.events++;

            int lo = 0, hi = status.size() - 1, zeroIdx = -1;
            while (lo <= hi) {
                int mid = (lo + hi) / 2;
                int sgn = orientSign(status.get(mid), p);
                if (sgn == 0) {
                    zeroIdx = mid;
                    break;
                } else if (sgn < 0) {
                    lo = mid + 1;
                } else {
                    hi = mid - 1;
                }
            }
            int blockStart, blockEnd;
            if (zeroIdx < 0) {
                blockStart = blockEnd = lo;
            } else {
                int a = zeroIdx, b = zeroIdx;
                while (a > 0 && orientSign(status.get(a - 1), p) == 0) {
                    a--;
                }
                while (b < status.size() - 1 && orientSign(status.get(b + 1), p) == 0) {
                    b++;
                }
                blockStart = a;
                blockEnd = b + 1;
            }

            List<Piece> block = new ArrayList<>(status.subList(blockStart, blockEnd));
            Tuple roundedP = p.toGrid();
            List<Piece> cutRemainders = new ArrayList<>();
            for (Piece pc : block) {
                if (sameEventAsGrid(p, pc.hi)) {
                    // L: this piece's hi is exactly P -- it ends here, no continuation.
                    continue;
                }
                Seg orig = segs.get(pc.origIndex);
                if (!Grid.samePoint(roundedP, orig.lo) && !Grid.samePoint(roundedP, orig.hi)) {
                    out.get(pc.origIndex).add(roundedP);
                }
                // Rounding can push the cut point off the piece's true line by up
                // to half a unit; a remainder that would run backward (the
                // rounded point landing lex-after the piece's own hi) has
                // nothing left to track -- drop it rather than splice in a
                // malformed, direction-reversed piece.
                if (!Grid.samePoint(roundedP, pc.hi) && !Grid.lexLess(pc.hi, roundedP)) {
                    Tuple newLo = Grid.lexLess(roundedP, pc.lo) ? pc.lo : roundedP;
                    cutRemainders.add(new Piece(newLo, pc.hi, pc.origIndex));
                }
            }

            List<Piece> u = new ArrayList<>();
            if (p.isGridPoint()) {
                List<Piece> starters = startsAt.get(p.x / p.d + "," + p.y / p.d);
                if (starters != null) {
                    u.addAll(starters);
                }
            }

            List<Piece> newBlock = new ArrayList<>(u);
            newBlock.addAll(cutRemainders);
            newBlock.sort((s, t) -> {
                double ds = s.hi.x - s.lo.x, dsY = s.hi.y - s.lo.y;
                double dt = t.hi.x - t.lo.x, dtY = t.hi.y - t.lo.y;
                double c = dt * dsY - dtY * ds;
                if (c > 0) {
                    return -1;
                }
                if (c < 0) {
                    return 1;
                }
                return Integer.compare(s.origIndex, t.origIndex);
            });

            List<Piece> tail = new ArrayList<>(status.subList(blockEnd, status.size()));
            List<Piece> head = new ArrayList<>(status.subList(0, blockStart));
            status.clear();
            status.addAll(head);
            status.addAll(newBlock);
            status.addAll(tail);

            int newBlockStart = blockStart;
            int newBlockEnd = blockStart + newBlock.size();
            if (newBlock.isEmpty()) {
                test(status, newBlockStart - 1, newBlockStart, p, segs, queue, st);
            } else {
                test(status, newBlockStart - 1, newBlockStart, p, segs, queue, st);
                test(status, newBlockEnd - 1, newBlockEnd, p, segs, queue, st);
            }
        }

        return out;
    }

    private static boolean sameEventAsGrid(REvent p, Tuple grid) {
        // p is exact; grid is a whole number. p equals grid exactly iff p is a
        // grid point and its coordinates match.
        return p.isGridPoint() && p.x / p.d == (long) grid.x && p.y / p.d == (long) grid.y;
    }

    private static void test(List<Piece> status, int i, int j, REvent p, List<Seg> segs,
            TreeSet<REvent> queue, SweepStats st) {
        if (i < 0 || j >= status.size() || i == j) {
            return;
        }
        Piece s = status.get(i);
        Piece t = status.get(j);
        st.tests++;
        MeetResult m = BoolMeet.meet(Seg.seg(s.lo, s.hi, 0, 0), Seg.seg(t.lo, t.hi, 0, 0));
        if (!m.kind().equals("cross")) {
            return;
        }
        REvent x = crossingEvent(s.lo, s.hi, t.lo, t.hi);
        if (x.compareTo(p) > 0) {
            queue.add(x);
        }
    }
}
