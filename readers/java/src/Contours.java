import java.util.ArrayList;
import java.util.List;

/**
 * §16.2: implied_points(contour) makes every implied on-curve point
 * explicit -- two off-curve points in a row (the loop wraps, so the last
 * and first count as consecutive too) imply an on-curve point at their
 * midpoint that the file didn't bother to store -- and then rotates the
 * result to start on an on-curve point, since a loop may start off-curve.
 *
 * contour_curves(contour) turns the (still raw) contour into chapter 8's
 * quadratics: implied_points first, then walk the expanded loop from each
 * on-curve point through the off-curve point after it to the next on-curve
 * point. Two on-curve points in a row are a straight edge, written as a
 * quadratic whose control point sits at the edge's own midpoint -- a
 * Bezier with its control point on the chord is the chord -- so every
 * piece of every contour ends up the same shape.
 */
public final class Contours {
    private Contours() {}

    public static List<ContourPoint> impliedPoints(List<ContourPoint> contour) {
        List<ContourPoint> out = new ArrayList<>();
        int n = contour.size();
        for (int i = 0; i < n; i++) {
            ContourPoint cur = contour.get(i);
            ContourPoint nxt = contour.get((i + 1) % n);
            out.add(cur);
            if (!cur.on() && !nxt.on()) {
                out.add(new ContourPoint((cur.x() + nxt.x()) / 2.0, (cur.y() + nxt.y()) / 2.0, true));
            }
        }
        for (int k = 0; k < out.size(); k++) {
            if (out.get(k).on()) {
                List<ContourPoint> rotated = new ArrayList<>(out.subList(k, out.size()));
                rotated.addAll(out.subList(0, k));
                return rotated;
            }
        }
        // Every point off-curve -- can't happen in a real TrueType contour
        // (there's always at least one on-curve point once implied points
        // are added, since two off-curve points always produce one), but
        // returned unrotated rather than looping forever if it ever did.
        return out;
    }

    public static List<Curve> contourCurves(List<ContourPoint> contour) {
        List<ContourPoint> pts = impliedPoints(contour);
        List<Curve> curves = new ArrayList<>();
        int n = pts.size();
        int i = 0;
        while (i < n) {
            ContourPoint a = pts.get(i);
            ContourPoint b = pts.get((i + 1) % n);
            if (b.on()) {
                Tuple mid = Tuple.point((a.x() + b.x()) / 2.0, (a.y() + b.y()) / 2.0);
                curves.add(Curve.quadratic(Tuple.point(a.x(), a.y()), mid, Tuple.point(b.x(), b.y())));
                i += 1;
            } else {
                ContourPoint c = pts.get((i + 2) % n);
                curves.add(Curve.quadratic(
                        Tuple.point(a.x(), a.y()), Tuple.point(b.x(), b.y()), Tuple.point(c.x(), c.y())));
                i += 2;
            }
        }
        return curves;
    }
}
