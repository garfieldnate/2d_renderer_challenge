import java.util.ArrayList;
import java.util.List;

/**
 * §22.4: once nothing crosses, a segment has one winding number of A and one
 * of B on each of its sides, so ask once, at its midpoint. winding_beside is
 * chapter 5's winding_at with the half-open rule in the sweep's order and
 * the two cases folded into one. inside_rule/op_inside classify; keep_edges
 * decides which segments bound the result, pointed with the inside on the
 * right.
 */
public final class Inside {
    private Inside() {}

    /** {{wa, wb} on the side that doesn't count, {wa, wb} on the side that does}. */
    public static int[][] windingBeside(List<Seg> segs, int i) {
        Seg e = segs.get(i);
        double mx = e.lo.x + e.hi.x;
        double my = e.lo.y + e.hi.y;
        int wa = 0, wb = 0;
        for (int j = 0; j < segs.size(); j++) {
            if (j == i) {
                continue;
            }
            Seg f = segs.get(j);
            double flx = 2 * f.lo.x, fly = 2 * f.lo.y;
            double fhx = 2 * f.hi.x, fhy = 2 * f.hi.y;
            boolean loBeforeOrEqual = (fly < my) || (fly == my && flx <= mx);
            boolean midBeforeHi = (my < fhy) || (my == fhy && mx < fhx);
            if (loBeforeOrEqual && midBeforeHi) {
                double o = Grid.orient(Tuple.point(flx, fly), Tuple.point(fhx, fhy), Tuple.point(mx, my));
                if (o > 0) {
                    wa += f.wa;
                    wb += f.wb;
                }
            }
        }
        return new int[][] {{wa, wb}, {wa + e.wa, wb + e.wb}};
    }

    public static boolean insideRule(int w, String rule) {
        if (rule.equals("nonzero")) {
            return w != 0;
        }
        return ((w % 2) + 2) % 2 == 1;
    }

    public static boolean opInside(String op, boolean a, boolean b) {
        switch (op) {
            case "union":
                return a || b;
            case "intersection":
                return a && b;
            case "difference":
                return a && !b;
            case "xor":
                return a != b;
            default:
                throw new IllegalArgumentException("unknown op: " + op);
        }
    }

    public static List<KeptEdge> keepEdges(List<Seg> segs, String ruleA, String ruleB, String op) {
        List<KeptEdge> kept = new ArrayList<>();
        for (int i = 0; i < segs.size(); i++) {
            Seg e = segs.get(i);
            int[][] w = windingBeside(segs, i);
            boolean out = opInside(op, insideRule(w[0][0], ruleA), insideRule(w[0][1], ruleB));
            boolean in = opInside(op, insideRule(w[1][0], ruleA), insideRule(w[1][1], ruleB));
            if (out != in) {
                kept.add(in ? new KeptEdge(e.lo, e.hi) : new KeptEdge(e.hi, e.lo));
            }
        }
        return kept;
    }
}
