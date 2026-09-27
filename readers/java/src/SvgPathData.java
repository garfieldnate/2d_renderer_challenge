import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * §20.3: path_commands(d) turns a d attribute into a list of commands, each
 * with an op and its args, in absolute coordinates and in six ops only: M,
 * L, C, Q, A and Z. See the feature's own prose for the full rules (S/T
 * reflection, H/V folded to L, repeated argument groups, the first command
 * must be M, stop at the first thing that can't be read).
 */
public final class SvgPathData {
    private SvgPathData() {}

    private static final Map<Character, Integer> ARITY = Map.of(
            'M', 2, 'L', 2, 'H', 1, 'V', 1, 'C', 6, 'S', 4, 'Q', 4, 'T', 2, 'A', 7, 'Z', 0);

    public static List<SvgCommand> pathCommands(String d) {
        List<SvgCommand> out = new ArrayList<>();
        int i = SvgNumbers.skipSep(d, 0);
        int n = d.length();
        double cx = 0, cy = 0, sx = 0, sy = 0;
        double[] prevCtrl = null;
        String prevOp = null;
        Character cmd = null;

        while (i < n) {
            char ch = d.charAt(i);
            if (Character.isLetter(ch)) {
                char up = Character.toUpperCase(ch);
                if (!ARITY.containsKey(up)) {
                    break;
                }
                if (cmd == null && up != 'M') {
                    break;
                }
                cmd = ch;
                i = SvgNumbers.skipSep(d, i + 1);
                if (up == 'Z') {
                    out.add(new SvgCommand("Z", new double[0]));
                    cx = sx;
                    cy = sy;
                    prevOp = "Z";
                    prevCtrl = null;
                    continue;
                }
            } else if (cmd == null || Character.toUpperCase(cmd) == 'Z') {
                break;
            }

            char op = Character.toUpperCase(cmd);
            boolean rel = cmd != op;
            int arity = ARITY.get(op);
            double[] vals = new double[arity];
            int j = i;
            boolean ok = true;
            for (int k = 0; k < arity; k++) {
                j = SvgNumbers.skipSep(d, j);
                if (op == 'A' && (k == 3 || k == 4)) {
                    SvgNumbers.FlagResult r = SvgNumbers.readFlag(d, j);
                    if (r.value() == null) {
                        ok = false;
                        break;
                    }
                    vals[k] = r.value();
                    j = r.index();
                } else {
                    SvgNumbers.NumberResult r = SvgNumbers.readNumber(d, j);
                    if (r.value() == null) {
                        ok = false;
                        break;
                    }
                    vals[k] = r.value();
                    j = r.index();
                }
            }
            if (!ok) {
                break;
            }
            i = SvgNumbers.skipSep(d, j);
            double ox = rel ? cx : 0;
            double oy = rel ? cy : 0;

            if (op == 'M') {
                cx = vals[0] + ox;
                cy = vals[1] + oy;
                sx = cx;
                sy = cy;
                out.add(new SvgCommand("M", new double[] {cx, cy}));
                cmd = rel ? 'l' : 'L';
                prevCtrl = null;
            } else if (op == 'L' || op == 'H' || op == 'V') {
                double x;
                double y;
                if (op == 'H') {
                    x = vals[0] + ox;
                    y = cy;
                } else if (op == 'V') {
                    x = cx;
                    y = vals[0] + oy;
                } else {
                    x = vals[0] + ox;
                    y = vals[1] + oy;
                }
                cx = x;
                cy = y;
                out.add(new SvgCommand("L", new double[] {x, y}));
                prevCtrl = null;
            } else if (op == 'C' || op == 'S') {
                double x1;
                double y1;
                double x2;
                double y2;
                double x;
                double y;
                if (op == 'C') {
                    x1 = vals[0] + ox;
                    y1 = vals[1] + oy;
                    x2 = vals[2] + ox;
                    y2 = vals[3] + oy;
                    x = vals[4] + ox;
                    y = vals[5] + oy;
                } else {
                    if (("C".equals(prevOp) || "S".equals(prevOp)) && prevCtrl != null) {
                        x1 = 2 * cx - prevCtrl[0];
                        y1 = 2 * cy - prevCtrl[1];
                    } else {
                        x1 = cx;
                        y1 = cy;
                    }
                    x2 = vals[0] + ox;
                    y2 = vals[1] + oy;
                    x = vals[2] + ox;
                    y = vals[3] + oy;
                }
                out.add(new SvgCommand("C", new double[] {x1, y1, x2, y2, x, y}));
                prevCtrl = new double[] {x2, y2};
                cx = x;
                cy = y;
            } else if (op == 'Q' || op == 'T') {
                double qx;
                double qy;
                double x;
                double y;
                if (op == 'Q') {
                    qx = vals[0] + ox;
                    qy = vals[1] + oy;
                    x = vals[2] + ox;
                    y = vals[3] + oy;
                } else {
                    if (("Q".equals(prevOp) || "T".equals(prevOp)) && prevCtrl != null) {
                        qx = 2 * cx - prevCtrl[0];
                        qy = 2 * cy - prevCtrl[1];
                    } else {
                        qx = cx;
                        qy = cy;
                    }
                    x = vals[0] + ox;
                    y = vals[1] + oy;
                }
                out.add(new SvgCommand("Q", new double[] {qx, qy, x, y}));
                prevCtrl = new double[] {qx, qy};
                cx = x;
                cy = y;
            } else { // A
                double x = vals[5] + ox;
                double y = vals[6] + oy;
                out.add(new SvgCommand(
                        "A", new double[] {Math.abs(vals[0]), Math.abs(vals[1]), vals[2], vals[3], vals[4], x, y}));
                cx = x;
                cy = y;
                prevCtrl = null;
            }
            prevOp = String.valueOf(op);
        }
        return out;
    }
}
