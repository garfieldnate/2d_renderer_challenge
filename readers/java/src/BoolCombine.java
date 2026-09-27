import java.util.ArrayList;
import java.util.List;

/**
 * §22.9: combine(a, rule_a, b, rule_b, op) is the whole pipeline --
 * path_segments of a as "a" and b as "b", split_segments, keep_edges,
 * stitch, and a path with one closed subpath per contour, every coordinate
 * divided by 256. simplify(p, rule) is combine(p, rule, path(), "nonzero",
 * "union"); point_lists(p) is the list of each subpath's points.
 */
public final class BoolCombine {
    private BoolCombine() {}

    public static Path combine(Path a, String ruleA, Path b, String ruleB, String op) {
        List<Seg> segs = new ArrayList<>();
        segs.addAll(Splitting.pathSegments(a, "a"));
        segs.addAll(Splitting.pathSegments(b, "b"));
        segs = Splitting.splitSegments(segs, "sweep", new SweepStats());
        List<KeptEdge> kept = Inside.keepEdges(segs, ruleA, ruleB, op);
        List<List<Tuple>> contours = Stitching.stitch(kept);
        Path result = new Path();
        for (List<Tuple> contour : contours) {
            boolean first = true;
            for (Tuple q : contour) {
                Tuple scaled = Tuple.point(q.x / 256.0, q.y / 256.0);
                if (first) {
                    result.moveTo(scaled);
                    first = false;
                } else {
                    result.lineTo(scaled);
                }
            }
            result.close();
        }
        return result;
    }

    public static Path simplify(Path p, String rule) {
        return combine(p, rule, new Path(), "nonzero", "union");
    }

    public static List<List<Tuple>> pointLists(Path p) {
        List<List<Tuple>> out = new ArrayList<>();
        for (Subpath sp : p.subpaths()) {
            out.add(new ArrayList<>(sp.points));
        }
        return out;
    }
}
