import java.util.ArrayList;
import java.util.List;

/**
 * §24.5: encode_svg(text, width, height) is chapter 20's walker drawing
 * nothing. A shape's fill and then its stroke outline are Fills of device
 * paths built exactly as chapter 20 builds them; an element chapter 20
 * draws into a fresh layer (opacity below 1, or a group with a clip) is a
 * Push before its contents and a Pop after; a clip is the list of (device
 * path, clip rule) of the clipPath's shapes, on the Push of a grouped
 * element and on the Fill of a shape that isn't grouped.
 */
public final class Encoder {
    private Encoder() {}

    private static final double TOL = SvgClip.TOLERANCE;

    public static List<EncCmd> encodeSvg(String text, int width, int height) {
        SvgElement root = Xml.parseXml(text);
        List<EncCmd> out = new ArrayList<>();
        Matrix vb = ViewBox.viewBoxMatrix(
                root.attribute("viewBox"), root.attribute("preserveAspectRatio"), width, height);
        encodeElement(root, out, root, SvgStyle.initialStyle(), vb);
        return out;
    }

    private static void encodeElement(
            SvgElement root, List<EncCmd> out, SvgElement el, SvgStyle.Style parent, Matrix ctm) {
        boolean isShape = SvgShapes.SHAPES.contains(el.name);
        boolean isGroup = el.name.equals("svg") || el.name.equals("g");
        if (!isShape && !isGroup) {
            return;
        }
        SvgStyle.Style st = SvgStyle.computedStyle(el, parent);
        Matrix m = ctm.multiply(SvgTransform.parseTransform(el.attribute("transform")));
        List<ClipPart> clip = st.clipPath != null ? clipParts(root, st.clipPath, m) : null;
        boolean grouped = st.opacity < 1 || (clip != null && isGroup);
        if (grouped) {
            out.add(new EncPush(st.opacity, clip));
        }
        List<ClipPart> inner = grouped ? null : clip;

        if (isGroup) {
            for (SvgElement child : el.children) {
                encodeElement(root, out, child, st, m);
            }
        } else {
            List<SvgCommand> cmds = SvgShapes.shapeCommands(el);
            if (!cmds.isEmpty() && m.determinant() != 0) {
                Path dev = SvgBuilder.buildPath(cmds, m, TOL);

                Paint fp = paintFor(root, st.fill, cmds, m);
                if (fp != null && st.fillOpacity > 0) {
                    out.add(new EncFill(dev, st.fillRule, fp, st.fillOpacity, inner));
                }

                Paint sp = paintFor(root, st.stroke, cmds, m);
                if (sp != null && st.strokeWidth > 0 && st.strokeOpacity > 0) {
                    Path user = Paths.transformPath(dev, m.inverse());
                    if (st.strokeDasharray != null) {
                        user = Dash.dash(user, st.strokeDasharray, st.strokeDashoffset);
                    }
                    Path outline = Stroke.strokeToPath(
                            user, st.strokeWidth, st.strokeLinecap, st.strokeLinejoin, st.strokeMiterlimit);
                    Path deviceOutline = Paths.transformPath(outline, m);
                    out.add(new EncFill(deviceOutline, "nonzero", sp, st.strokeOpacity, inner));
                }
            }
        }

        if (grouped) {
            out.add(new EncPop());
        }
    }

    private static Paint paintFor(SvgElement root, Object value, List<SvgCommand> cmds, Matrix ctm) {
        if (value == null) {
            return null;
        }
        if (value instanceof String s) {
            return SvgPaint.paintServer(root, s, SvgBuilder.commandsBounds(cmds), ctm);
        }
        return Paint.solid((Color) value);
    }

    private static List<ClipPart> clipParts(SvgElement root, String ref, Matrix ctm) {
        String id = ref.substring(5, ref.length() - 1);
        SvgElement el = Xml.findById(root, id);
        if (el == null || !el.name.equals("clipPath")) {
            return null;
        }
        Matrix m = ctm.multiply(SvgTransform.parseTransform(el.attribute("transform")));
        SvgStyle.Style base = SvgStyle.computedStyle(el, SvgStyle.initialStyle());
        List<ClipPart> parts = new ArrayList<>();
        for (SvgElement child : el.children) {
            if (!SvgShapes.SHAPES.contains(child.name)) {
                continue;
            }
            SvgStyle.Style st = SvgStyle.computedStyle(child, base);
            Matrix cm = m.multiply(SvgTransform.parseTransform(child.attribute("transform")));
            Path dev = SvgBuilder.buildPath(SvgShapes.shapeCommands(child), cm, TOL);
            parts.add(new ClipPart(dev, st.clipRule));
        }
        return parts;
    }
}
