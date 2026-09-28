import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

/**
 * §24.5: cull_groups(cmds) drops each push whose pop has no fill (or
 * anything else that isn't a push/pop) between them in the list,
 * innermost first, since an empty layer composites to nothing. Generic
 * over any command type that can say whether it's a push or a pop, so the
 * same algorithm serves the pipeline's real per-tile commands and the
 * chapter's own worked example.
 */
public interface CullOp {
    boolean isPush();

    boolean isPop();

    static <T extends CullOp> List<T> cullGroups(List<T> cmds) {
        List<T> out = new ArrayList<>();
        Deque<int[]> marks = new ArrayDeque<>(); // [indexInOut, fillCountSincePush]
        for (T c : cmds) {
            if (c.isPush()) {
                marks.push(new int[] {out.size(), 0});
                out.add(c);
            } else if (c.isPop()) {
                int[] m = marks.pop();
                if (m[1] == 0) {
                    while (out.size() > m[0]) {
                        out.remove(out.size() - 1);
                    }
                } else {
                    out.add(c);
                    if (!marks.isEmpty()) {
                        marks.peek()[1] += m[1];
                    }
                }
            } else {
                out.add(c);
                if (!marks.isEmpty()) {
                    marks.peek()[1]++;
                }
            }
        }
        return out;
    }
}
