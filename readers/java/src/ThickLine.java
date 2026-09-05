/**
 * §3.3: a line as a shape -- the rectangle of the given width, centered on
 * the segment between the centers of pixel (x0, y0) and pixel (x1, y1), with
 * square ends. Four half-planes: one through each endpoint, facing outward
 * along the segment's direction; one along each side, offset by half the
 * width along the segment's normal, facing back inward. Inside means inside
 * all four. A line of no length has no direction, so it gets (1, 0) and its
 * two ends are pushed apart by half the width each, which makes it a
 * width-by-width square.
 */
public final class ThickLine implements Shape {
    private final HalfPlane startCap;
    private final HalfPlane endCap;
    private final HalfPlane side1;
    private final HalfPlane side2;

    public ThickLine(double x0, double y0, double x1, double y1, double width) {
        double sx = x0 + 0.5;
        double sy = y0 + 0.5;
        double ex = x1 + 0.5;
        double ey = y1 + 0.5;
        double half = width / 2.0;
        double dx = ex - sx;
        double dy = ey - sy;
        double len = Math.hypot(dx, dy);
        double ux;
        double uy;
        if (len == 0) {
            ux = 1;
            uy = 0;
            sx = sx - half;
            ex = ex + half;
        } else {
            ux = dx / len;
            uy = dy / len;
        }
        double nx = -uy;
        double ny = ux;

        startCap = new HalfPlane(sx, sy, ux, uy);
        endCap = new HalfPlane(ex, ey, -ux, -uy);
        side1 = new HalfPlane(sx + half * nx, sy + half * ny, -nx, -ny);
        side2 = new HalfPlane(sx - half * nx, sy - half * ny, nx, ny);
    }

    @Override
    public boolean inside(double x, double y) {
        return startCap.inside(x, y) && endCap.inside(x, y)
                && side1.inside(x, y) && side2.inside(x, y);
    }
}
