/**
 * §16.1, §16.2: one point of a TrueType contour, in font units -- (x, y, on),
 * on true for a point that sits on the outline, false for a quadratic's
 * off-curve control point.
 */
public record ContourPoint(double x, double y, boolean on) {}
