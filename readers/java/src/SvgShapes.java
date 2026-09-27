import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * §20.7: shape_commands(el) is the list of commands a shape element stands
 * for, the equivalent paths the SVG specification gives, built so that
 * everything after this point only ever sees path commands.
 */
public final class SvgShapes {
    private SvgShapes() {}

    public static final Set<String> SHAPES =
            Set.of("path", "rect", "circle", "ellipse", "line", "polyline", "polygon");

    private static SvgCommand cmd(String op, double... args) {
        return new SvgCommand(op, args);
    }

    private static double numAttr(SvgElement el, String name) {
        String v = el.attribute(name);
        if (v == null) {
            return 0;
        }
        Double n = SvgStyle.numberValue(v);
        return n == null ? 0 : n;
    }

    public static List<SvgCommand> shapeCommands(SvgElement el) {
        String nm = el.name;
        List<SvgCommand> out = new ArrayList<>();
        switch (nm) {
            case "path" -> {
                String d = el.attribute("d");
                return SvgPathData.pathCommands(d == null ? "" : d);
            }
            case "rect" -> {
                double x = numAttr(el, "x");
                double y = numAttr(el, "y");
                double w = numAttr(el, "width");
                double h = numAttr(el, "height");
                if (w <= 0 || h <= 0) {
                    return out;
                }
                Double rxAttr = el.attribute("rx") != null ? SvgStyle.numberValue(el.attribute("rx")) : null;
                Double ryAttr = el.attribute("ry") != null ? SvgStyle.numberValue(el.attribute("ry")) : null;
                if (rxAttr != null && rxAttr < 0) {
                    rxAttr = null;
                }
                if (ryAttr != null && ryAttr < 0) {
                    ryAttr = null;
                }
                double rx;
                double ry;
                if (rxAttr == null && ryAttr == null) {
                    rx = 0;
                    ry = 0;
                } else if (rxAttr == null) {
                    rx = ryAttr;
                    ry = ryAttr;
                } else if (ryAttr == null) {
                    rx = rxAttr;
                    ry = rxAttr;
                } else {
                    rx = rxAttr;
                    ry = ryAttr;
                }
                rx = Math.min(rx, w / 2);
                ry = Math.min(ry, h / 2);
                if (rx == 0 || ry == 0) {
                    out.add(cmd("M", x, y));
                    out.add(cmd("L", x + w, y));
                    out.add(cmd("L", x + w, y + h));
                    out.add(cmd("L", x, y + h));
                    out.add(cmd("Z"));
                    return out;
                }
                out.add(cmd("M", x + rx, y));
                out.add(cmd("L", x + w - rx, y));
                out.add(cmd("A", rx, ry, 0, 0, 1, x + w, y + ry));
                out.add(cmd("L", x + w, y + h - ry));
                out.add(cmd("A", rx, ry, 0, 0, 1, x + w - rx, y + h));
                out.add(cmd("L", x + rx, y + h));
                out.add(cmd("A", rx, ry, 0, 0, 1, x, y + h - ry));
                out.add(cmd("L", x, y + ry));
                out.add(cmd("A", rx, ry, 0, 0, 1, x + rx, y));
                out.add(cmd("Z"));
                return out;
            }
            case "circle", "ellipse" -> {
                double cx = numAttr(el, "cx");
                double cy = numAttr(el, "cy");
                double erx;
                double ery;
                if (nm.equals("circle")) {
                    erx = ery = numAttr(el, "r");
                } else {
                    erx = numAttr(el, "rx");
                    ery = numAttr(el, "ry");
                }
                if (erx <= 0 || ery <= 0) {
                    return out;
                }
                out.add(cmd("M", cx + erx, cy));
                out.add(cmd("A", erx, ery, 0, 0, 1, cx, cy + ery));
                out.add(cmd("A", erx, ery, 0, 0, 1, cx - erx, cy));
                out.add(cmd("A", erx, ery, 0, 0, 1, cx, cy - ery));
                out.add(cmd("A", erx, ery, 0, 0, 1, cx + erx, cy));
                out.add(cmd("Z"));
                return out;
            }
            case "line" -> {
                out.add(cmd("M", numAttr(el, "x1"), numAttr(el, "y1")));
                out.add(cmd("L", numAttr(el, "x2"), numAttr(el, "y2")));
                return out;
            }
            case "polyline", "polygon" -> {
                String pts = el.attribute("points");
                double[] nums = SvgNumbers.numberList(pts == null ? "" : pts);
                for (int i = 0; i + 1 < nums.length; i += 2) {
                    out.add(cmd(out.isEmpty() ? "M" : "L", nums[i], nums[i + 1]));
                }
                if (!out.isEmpty() && nm.equals("polygon")) {
                    out.add(cmd("Z"));
                }
                return out;
            }
            default -> {
                return out;
            }
        }
    }
}
