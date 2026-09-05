namespace Chapter01;

/// <summary>
/// A shape answers exactly one question: is this point inside you? Boundary
/// is included in all three shapes below. Coordinates are real numbers, not
/// pixel indices.
/// </summary>
public interface IShape
{
    bool Inside(double x, double y);
}

/// <summary>A circle, given its center and radius. Inside means within the radius, boundary included.</summary>
public sealed class Circle : IShape
{
    public double Cx { get; }
    public double Cy { get; }
    public double R { get; }

    public Circle(double cx, double cy, double r)
    {
        Cx = cx;
        Cy = cy;
        R = r;
    }

    public bool Inside(double x, double y)
    {
        double dx = x - Cx;
        double dy = y - Cy;
        return dx * dx + dy * dy <= R * R;
    }
}

/// <summary>A rectangle given its left, top, right and bottom edges. Boundary included.</summary>
public sealed class Rectangle : IShape
{
    public double X0 { get; }
    public double Y0 { get; }
    public double X1 { get; }
    public double Y1 { get; }

    public Rectangle(double x0, double y0, double x1, double y1)
    {
        X0 = x0;
        Y0 = y0;
        X1 = x1;
        Y1 = y1;
    }

    public bool Inside(double x, double y) => x >= X0 && x <= X1 && y >= Y0 && y <= Y1;
}

/// <summary>
/// Everything on one side of a line: a point on the line, plus a normal
/// vector pointing into the half you want. Inside when the vector from
/// (px, py) to the point has a non-negative dot product with the normal.
/// The normal needn't have length 1.
/// </summary>
public sealed class HalfPlane : IShape
{
    public double Px { get; }
    public double Py { get; }
    public double Nx { get; }
    public double Ny { get; }

    public HalfPlane(double px, double py, double nx, double ny)
    {
        Px = px;
        Py = py;
        Nx = nx;
        Ny = ny;
    }

    public bool Inside(double x, double y)
    {
        double dx = x - Px;
        double dy = y - Py;
        return dx * Nx + dy * Ny >= 0;
    }
}

/// <summary>
/// A line, honestly: the rectangle of the given width centered on the
/// segment from the center of pixel (x0, y0) to the center of pixel
/// (x1, y1), with square ends. Four half-planes - through each end facing
/// outward along the segment, and along each side offset by half the width
/// facing inward - and inside means inside all four.
/// </summary>
public sealed class ThickLine : IShape
{
    private readonly HalfPlane[] _planes;

    public ThickLine(double x0, double y0, double x1, double y1, double width)
    {
        double ax = x0 + 0.5, ay = y0 + 0.5;
        double bx = x1 + 0.5, by = y1 + 0.5;
        double dx = bx - ax, dy = by - ay;
        double length = Math.Sqrt(dx * dx + dy * dy);
        if (length > 0)
        {
            dx /= length;
            dy /= length;
        }
        else
        {
            dx = 1;
            dy = 0;
        }
        double nx = -dy, ny = dx;
        double half = width / 2.0;

        _planes = new[]
        {
            new HalfPlane(ax, ay, dx, dy),
            new HalfPlane(bx, by, -dx, -dy),
            new HalfPlane(ax + nx * half, ay + ny * half, -nx, -ny),
            new HalfPlane(ax - nx * half, ay - ny * half, nx, ny),
        };
    }

    public bool Inside(double x, double y)
    {
        for (int i = 0; i < _planes.Length; i++)
        {
            if (!_planes[i].Inside(x, y)) return false;
        }
        return true;
    }
}
