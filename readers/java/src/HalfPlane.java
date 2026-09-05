/**
 * §2.1: everything on one side of a line, described by a point on the line
 * and a normal vector pointing into the half you want: half_plane(px, py, nx, ny).
 * A point is inside when the vector from (px, py) to it has a non-negative
 * dot product with the normal. The normal needn't have length 1.
 */
public final class HalfPlane implements Shape {
    public final double px;
    public final double py;
    public final double nx;
    public final double ny;

    public HalfPlane(double px, double py, double nx, double ny) {
        this.px = px;
        this.py = py;
        this.nx = nx;
        this.ny = ny;
    }

    @Override
    public boolean inside(double x, double y) {
        return (x - px) * nx + (y - py) * ny >= 0;
    }
}
