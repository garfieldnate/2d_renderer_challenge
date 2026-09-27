import java.util.Map;

/**
 * §20.8: view_box_matrix(view_box, aspect, width, height) is the matrix
 * that carries the viewBox rectangle onto a width by height viewport, per
 * preserveAspectRatio. No usable viewBox is the identity.
 */
public final class ViewBox {
    private ViewBox() {}

    private static final Map<String, Double> ALIGN =
            Map.of("xMin", 0.0, "xMid", 0.5, "xMax", 1.0, "YMin", 0.0, "YMid", 0.5, "YMax", 1.0);

    public static Matrix viewBoxMatrix(String vbs, String aspect, double width, double height) {
        if (vbs == null) {
            return Matrix.identity();
        }
        double[] vb = SvgNumbers.numberList(vbs);
        if (vb.length != 4 || vb[2] <= 0 || vb[3] <= 0) {
            return Matrix.identity();
        }
        double sx = width / vb[2];
        double sy = height / vb[3];
        String[] words = (aspect == null || aspect.isBlank() ? "xMidYMid meet" : aspect).trim().split("\\s+");
        String align = words.length > 0 && !words[0].isEmpty() ? words[0] : "xMidYMid";
        if (align.equals("none")) {
            return Transforms.scaling(sx, sy).multiply(Transforms.translation(-vb[0], -vb[1]));
        }
        boolean slice = words.length > 1 && words[1].equals("slice");
        double s = slice ? Math.max(sx, sy) : Math.min(sx, sy);
        String xPart = align.length() >= 4 ? align.substring(0, 4) : "xMid";
        String yPart = align.length() >= 8 ? align.substring(4, 8) : "YMid";
        double fx = ALIGN.getOrDefault(xPart, 0.5);
        double fy = ALIGN.getOrDefault(yPart, 0.5);
        double ox = (width - vb[2] * s) * fx;
        double oy = (height - vb[3] * s) * fy;
        return Transforms.translation(ox, oy)
                .multiply(Transforms.scaling(s, s))
                .multiply(Transforms.translation(-vb[0], -vb[1]));
    }
}
