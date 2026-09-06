/**
 * §4.5: segment(a, b, width) -- chapter 3's thick_line with real endpoints
 * instead of pixel indices. The rectangle of the given width, centered on
 * the segment from point a to point b, square ends: one half-plane through
 * each endpoint facing outward along the segment's direction, one along
 * each side offset by half the width along the normal, facing back inward.
 * Inside means inside all four. A segment of no length has no direction,
 * so it gets (1, 0) and its two ends are pushed apart by half the width
 * each, which makes it a width-by-width square.
 */
public final class Segment implements Shape {
    private final HalfPlane startCap;
    private final HalfPlane endCap;
    private final HalfPlane side1;
    private final HalfPlane side2;

    public Segment(Tuple a, Tuple b, double width) {
        double sx = a.x;
        double sy = a.y;
        double ex = b.x;
        double ey = b.y;
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
