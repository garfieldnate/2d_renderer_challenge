import java.util.List;

/**
 * §20.10: render_svg(text, width, height) draws a document onto a width by
 * height canvas. It starts with a transparent chapter 9 layer, walks the
 * tree from the root with initial_style() as the root's parent style and
 * the root's view_box_matrix as the starting matrix, and flattens the
 * layer over white paper at the end.
 *
 * §21.2: render_svg_with(text, width, height, mode, st) is render_svg with
 * every fill and stroke counted one of three ways: "whole" (chapter 20, as
 * written), "bounded" (§21.3) or "tiled" (§21.4).
 */
public final class SvgWalker {
    private SvgWalker() {}

    public static Canvas renderSvg(String text, int width, int height) {
        return renderSvgWith(text, width, height, "whole", new Stats());
    }

    public static Canvas renderSvgWith(String text, int width, int height, String mode, Stats st) {
        SvgElement root = Xml.parseXml(text);
        Layer l = new Layer(width, height);
        Matrix vb = ViewBox.viewBoxMatrix(root.attribute("viewBox"), root.attribute("preserveAspectRatio"),
                width, height);
        renderElement(root, width, height, l, root, SvgStyle.initialStyle(), vb, mode, st, null);
        return Layers.flattenLayer(l, new Color(1, 1, 1));
    }

    /** §21.4's plate: how many of each tile's fills/strokes classified it partial and how many solid. */
    public static int[][][] tileWork(String text, int width, int height) {
        SvgElement root = Xml.parseXml(text);
        int tileRows = (height + Tiles.TILE - 1) / Tiles.TILE;
        int tileCols = (width + Tiles.TILE - 1) / Tiles.TILE;
        int[][][] work = new int[tileRows][tileCols][2];
        Layer l = new Layer(width, height);
        Matrix vb = ViewBox.viewBoxMatrix(root.attribute("viewBox"), root.attribute("preserveAspectRatio"),
                width, height);
        renderElement(root, width, height, l, root, SvgStyle.initialStyle(), vb, "tiled", new Stats(), work);
        return work;
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

    private static void fillAndPaint(Path devicePath, String rule, Layer l, Paint paint, double alpha,
            CoverageBuffer clip, int w, int h, String mode, Stats st, int[][][] tileWork) {
        switch (mode) {
            case "bounded" -> {
                if (clip != null) {
                    BoundedFill.FillWindow win = BoundedFill.fillPathBounded(devicePath, rule, w, h, st);
                    CoverageBuffer full = Clipping.multiplyCoverage(Coverage.fullCoverage(win, w, h), clip);
                    FillCounting.drawCoverageCounted(l, full, paint, alpha, st);
                } else {
                    BoundedFill.FillWindow win = BoundedFill.fillPathBounded(devicePath, rule, w, h, st);
                    BoundedFill.drawWindow(l, win, paint, alpha, st);
                }
            }
            case "tiled" -> {
                if (clip != null) {
                    TiledCoverage t = Tiles.fillPathTiled(devicePath, rule, w, h, st, tileWork);
                    CoverageBuffer full = Clipping.multiplyCoverage(Coverage.fullCoverage(t, w, h), clip);
                    FillCounting.drawCoverageCounted(l, full, paint, alpha, st);
                } else {
                    TiledCoverage t = Tiles.fillPathTiled(devicePath, rule, w, h, st, tileWork);
                    Tiles.drawTiled(l, t, paint, alpha, st);
                }
            }
            default -> { // "whole"
                CoverageBuffer cov = FillCounting.fillPathCounted(devicePath, rule, w, h, st);
                if (clip != null) {
                    cov = Clipping.multiplyCoverage(cov, clip);
                }
                FillCounting.drawCoverageCounted(l, cov, paint, alpha, st);
            }
        }
    }

    private static void drawShape(SvgElement root, Layer l, SvgElement el, SvgStyle.Style st, Matrix ctm,
            CoverageBuffer clip, int w, int h, String mode, Stats stats, int[][][] tileWork) {
        List<SvgCommand> cmds = SvgShapes.shapeCommands(el);
        if (cmds.isEmpty() || ctm.determinant() == 0) {
            return;
        }
        Path dev = SvgBuilder.buildPath(cmds, ctm, SvgClip.TOLERANCE);

        Paint fp = paintFor(root, st.fill, cmds, ctm);
        if (fp != null && st.fillOpacity > 0) {
            fillAndPaint(dev, st.fillRule, l, fp, st.fillOpacity, clip, w, h, mode, stats, tileWork);
        }

        Paint sp = paintFor(root, st.stroke, cmds, ctm);
        if (sp != null && st.strokeWidth > 0 && st.strokeOpacity > 0) {
            Path user = Paths.transformPath(dev, ctm.inverse());
            if (st.strokeDasharray != null) {
                user = Dash.dash(user, st.strokeDasharray, st.strokeDashoffset);
            }
            Path outline = Stroke.strokeToPath(
                    user, st.strokeWidth, st.strokeLinecap, st.strokeLinejoin, st.strokeMiterlimit);
            Path deviceOutline = Paths.transformPath(outline, ctm);
            fillAndPaint(deviceOutline, "nonzero", l, sp, st.strokeOpacity, clip, w, h, mode, stats, tileWork);
        }
    }

    private static void copyInto(Layer dst, Layer src) {
        for (int y = 0; y < dst.height; y++) {
            for (int x = 0; x < dst.width; x++) {
                dst.setPixel(x, y, src.pixelAt(x, y));
            }
        }
    }

    private static void renderElement(SvgElement root, int w, int h, Layer l, SvgElement el, SvgStyle.Style parent,
            Matrix ctm, String mode, Stats st, int[][][] tileWork) {
        boolean isShape = SvgShapes.SHAPES.contains(el.name);
        boolean isGroup = el.name.equals("svg") || el.name.equals("g");
        if (!isGroup && !isShape) {
            return;
        }
        SvgStyle.Style style = SvgStyle.computedStyle(el, parent);
        Matrix m = ctm.multiply(SvgTransform.parseTransform(el.attribute("transform")));
        CoverageBuffer clip = style.clipPath != null ? SvgClip.clipCoverage(root, style.clipPath, m, w, h) : null;
        boolean grouped = style.opacity < 1 || (clip != null && isGroup);
        Layer target = grouped ? new Layer(w, h) : l;

        if (isGroup) {
            for (SvgElement child : el.children) {
                renderElement(root, w, h, target, child, style, m, mode, st, tileWork);
            }
        } else {
            drawShape(root, target, el, style, m, grouped ? null : clip, w, h, mode, st, tileWork);
        }

        if (grouped) {
            if (clip != null) {
                Groups.maskLayer(target, clip);
            }
            Layer merged = Groups.popGroupWithOpacity(target, l, style.opacity);
            copyInto(l, merged);
        }
    }
}
