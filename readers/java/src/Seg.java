import java.util.Objects;

/**
 * §22.2: a segment between two grid points, stored lo before hi in the
 * sweep's order, plus how much it adds to the winding number of path A (wa)
 * and of path B (wb). seg(a, b, wa, wb) canonicalizes: if a comes after b
 * they're swapped and wa/wb change sign, so seg(a, b, 1, 0) and
 * seg(b, a, -1, 0) are the same segment. Two segments are equal when their
 * ends and both windings are.
 */
public final class Seg {
    public final Tuple lo;
    public final Tuple hi;
    public final int wa;
    public final int wb;

    private Seg(Tuple lo, Tuple hi, int wa, int wb) {
        this.lo = lo;
        this.hi = hi;
        this.wa = wa;
        this.wb = wb;
    }

    public static Seg seg(Tuple a, Tuple b, int wa, int wb) {
        if (Grid.lexLess(b, a)) {
            return new Seg(b, a, -wa, -wb);
        }
        return new Seg(a, b, wa, wb);
    }

    @Override
    public boolean equals(Object o) {
        if (!(o instanceof Seg)) {
            return false;
        }
        Seg s = (Seg) o;
        return Grid.samePoint(lo, s.lo) && Grid.samePoint(hi, s.hi) && wa == s.wa && wb == s.wb;
    }

    @Override
    public int hashCode() {
        return Objects.hash((long) lo.x, (long) lo.y, (long) hi.x, (long) hi.y, wa, wb);
    }

    @Override
    public String toString() {
        return "seg(" + lo + ", " + hi + ", " + wa + ", " + wb + ")";
    }
}
