import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * §22.2-22.3, 22.6-22.7: path_segments snaps a path's edges onto the grid;
 * find_splits(segs, method, st) is the pairwise "brute" search, the active
 * list "sweep", or "bentley-ottmann"; split_segments(segs, method, st) loops
 * find_splits and cuts until a pass finds nothing; merge_segments folds
 * identical segments together and drops the ones that carry no winding.
 */
public final class Splitting {
    private Splitting() {}

    public static List<Seg> pathSegments(Path p, String operand) {
        int wa = operand.equals("a") ? 1 : 0;
        int wb = operand.equals("a") ? 0 : 1;
        List<Seg> out = new ArrayList<>();
        for (Edge e : p.edges()) {
            Tuple a = Grid.snapPoint(e.a());
            Tuple b = Grid.snapPoint(e.b());
            if (Grid.samePoint(a, b)) {
                continue;
            }
            out.add(Seg.seg(a, b, wa, wb));
        }
        return out;
    }

    static int compareLex(Tuple p, Tuple q) {
        if (p.y != q.y) {
            return Double.compare(p.y, q.y);
        }
        return Double.compare(p.x, q.x);
    }

    static int compareSweepOrder(Seg s, Seg t) {
        int c = compareLex(s.lo, t.lo);
        if (c != 0) {
            return c;
        }
        return compareLex(s.hi, t.hi);
    }

    public static List<Seg> mergeSegments(List<Seg> segs) {
        Map<String, Seg> acc = new LinkedHashMap<>();
        for (Seg s : segs) {
            String key = Grid.key(s.lo) + "|" + Grid.key(s.hi);
            Seg cur = acc.get(key);
            if (cur == null) {
                acc.put(key, s);
            } else {
                acc.put(key, Seg.seg(s.lo, s.hi, cur.wa + s.wa, cur.wb + s.wb));
            }
        }
        List<Seg> out = new ArrayList<>();
        for (Seg s : acc.values()) {
            if (s.wa != 0 || s.wb != 0) {
                out.add(s);
            }
        }
        out.sort(Splitting::compareSweepOrder);
        return out;
    }

    /** Order the cut points along a segment, from lo to hi, deduplicated. */
    static List<Tuple> along(Seg s, List<Tuple> pts) {
        List<Tuple> uniq = new ArrayList<>();
        for (Tuple q : pts) {
            boolean dup = false;
            for (Tuple e : uniq) {
                if (Grid.samePoint(e, q)) {
                    dup = true;
                    break;
                }
            }
            if (!dup) {
                uniq.add(q);
            }
        }
        Tuple lo = s.lo, hi = s.hi;
        double dx = hi.x - lo.x, dy = hi.y - lo.y;
        uniq.sort((p, q) -> {
            double dp = (p.x - lo.x) * dx + (p.y - lo.y) * dy;
            double dq = (q.x - lo.x) * dx + (q.y - lo.y) * dy;
            int c = Double.compare(dp, dq);
            if (c != 0) {
                return c;
            }
            return compareLex(p, q);
        });
        return uniq;
    }

    public static List<List<Tuple>> findSplits(List<Seg> segs, String method, SweepStats st) {
        switch (method) {
            case "brute":
                return bruteFindSplits(segs, st);
            case "sweep":
                return sweepFindSplits(segs, st);
            case "bentley-ottmann":
                return BentleyOttmann.findSplits(segs, st);
            default:
                throw new IllegalArgumentException("unknown method: " + method);
        }
    }

    private static List<List<Tuple>> bruteFindSplits(List<Seg> segs, SweepStats st) {
        int n = segs.size();
        List<List<Tuple>> raw = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            raw.add(new ArrayList<>());
        }
        for (int i = 0; i < n; i++) {
            for (int j = i + 1; j < n; j++) {
                MeetResult m = BoolMeet.meet(segs.get(i), segs.get(j));
                st.tests++;
                raw.get(i).addAll(m.onS());
                raw.get(j).addAll(m.onT());
            }
        }
        List<List<Tuple>> out = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            out.add(along(segs.get(i), raw.get(i)));
        }
        return out;
    }

    private static List<List<Tuple>> sweepFindSplits(List<Seg> segs, SweepStats st) {
        int n = segs.size();
        Integer[] order = new Integer[n];
        for (int i = 0; i < n; i++) {
            order[i] = i;
        }
        Arrays.sort(order, (i, j) -> compareSweepOrder(segs.get(i), segs.get(j)));
        List<List<Tuple>> raw = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            raw.add(new ArrayList<>());
        }
        List<Integer> active = new ArrayList<>();
        for (int idx : order) {
            Seg s = segs.get(idx);
            active.removeIf(j -> !Grid.lexLess(s.lo, segs.get(j).hi));
            for (int j : active) {
                MeetResult m = BoolMeet.meet(s, segs.get(j));
                st.tests++;
                raw.get(idx).addAll(m.onS());
                raw.get(j).addAll(m.onT());
            }
            active.add(idx);
        }
        List<List<Tuple>> out = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            out.add(along(segs.get(i), raw.get(i)));
        }
        return out;
    }

    public static List<Seg> splitSegments(List<Seg> segs, String method, SweepStats st) {
        List<Seg> cur = mergeSegments(segs);
        while (true) {
            st.passes++;
            List<List<Tuple>> splits = findSplits(cur, method, st);
            boolean any = false;
            for (List<Tuple> l : splits) {
                if (!l.isEmpty()) {
                    any = true;
                    break;
                }
            }
            if (!any) {
                return cur;
            }
            List<Seg> out = new ArrayList<>();
            for (int i = 0; i < cur.size(); i++) {
                Seg s = cur.get(i);
                List<Tuple> sp = splits.get(i);
                if (sp.isEmpty()) {
                    out.add(s);
                    continue;
                }
                List<Tuple> chain = new ArrayList<>();
                chain.add(s.lo);
                chain.addAll(sp);
                chain.add(s.hi);
                for (int k = 0; k + 1 < chain.size(); k++) {
                    if (!Grid.samePoint(chain.get(k), chain.get(k + 1))) {
                        out.add(Seg.seg(chain.get(k), chain.get(k + 1), s.wa, s.wb));
                    }
                }
            }
            cur = mergeSegments(out);
        }
    }
}
