import java.util.List;

/**
 * §20.10: clip_coverage(root, ref, m, width, height) is the coverage of the
 * clipPath a url(#id) names: the union, starting from nothing, of the fill
 * of every shape child (other children are skipped), each built through m
 * times the clipPath's own transform times the child's, under the child's
 * clip-rule, computed from the clipPath's style, which starts from
 * initial_style(); m is the matrix of the element that uses the clip. A
 * clipPath with no shapes clips everything away; a reference to nothing, or
 * to something that isn't a clipPath, clips nothing.
 */
public final class SvgClip {
    private SvgClip() {}

    public static final double TOLERANCE = 0.1;

    public static CoverageBuffer clipCoverage(SvgElement root, String ref, Matrix ctm, int width, int height) {
        String id = ref.substring(5, ref.length() - 1);
        SvgElement el = Xml.findById(root, id);
        if (el == null || !el.name.equals("clipPath")) {
            return null;
        }
        Matrix m = ctm.multiply(SvgTransform.parseTransform(el.attribute("transform")));
        SvgStyle.Style base = SvgStyle.computedStyle(el, SvgStyle.initialStyle());
        CoverageBuffer cov = new CoverageBuffer(width, height);
        for (SvgElement child : el.children) {
            if (!SvgShapes.SHAPES.contains(child.name)) {
                continue;
            }
            SvgStyle.Style st = SvgStyle.computedStyle(child, base);
            Matrix cm = m.multiply(SvgTransform.parseTransform(child.attribute("transform")));
            List<SvgCommand> cmds = SvgShapes.shapeCommands(child);
            Path dev = SvgBuilder.buildPath(cmds, cm, TOLERANCE);
            CoverageBuffer childCov = Fill.fillPath(dev, st.clipRule, width, height);
            cov = Clipping.unionCoverage(cov, childCov);
        }
        return cov;
    }
}
