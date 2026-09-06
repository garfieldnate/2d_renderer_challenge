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
/// segment from point a to point b, with square ends. Four half-planes -
/// through each end facing outward along the segment, and along each side
/// offset by half the width facing inward - and inside means inside all
/// four. §4.5 calls this segment; chapter 3's thick_line, below, is the
/// same shape given pixel indices instead of points.
/// </summary>
public sealed class Segment : IShape
{
    private readonly HalfPlane[] _planes;

    public Segment(Tuple2 a, Tuple2 b, double width)
    {
        double ax = a.X, ay = a.Y;
        double bx = b.X, by = b.Y;
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

        // A zero-length segment has no direction to be flush against, so
        // its caps get pushed out by half the width too, same as its
        // sides: the result is a width-by-width square, not a degenerate
        // sliver.
        double capOffset = length > 0 ? 0 : half;
        double sx = ax - capOffset * dx, sy = ay - capOffset * dy;
        double ex = bx + capOffset * dx, ey = by + capOffset * dy;

        _planes = new[]
        {
            new HalfPlane(sx, sy, dx, dy),
            new HalfPlane(ex, ey, -dx, -dy),
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

/// <summary>
/// segment(point(x0 + 0.5, y0 + 0.5), point(x1 + 0.5, y1 + 0.5), width) -
/// the segment between the centers of pixels (x0, y0) and (x1, y1). Exactly
/// the one-liner §4.5 promises; every chapter 3 scenario still passes.
/// </summary>
public sealed class ThickLine : IShape
{
    private readonly Segment _segment;

    public ThickLine(double x0, double y0, double x1, double y1, double width) :
        this(new Segment(Tuple2.Point(x0 + 0.5, y0 + 0.5), Tuple2.Point(x1 + 0.5, y1 + 0.5), width))
    {
    }

    private ThickLine(Segment segment) => _segment = segment;

    public bool Inside(double x, double y) => _segment.Inside(x, y);
}

/// <summary>A shape that's inside when any of its parts is - a loop with an early exit.</summary>
public sealed class Union : IShape
{
    private readonly IShape[] _shapes;

    public Union(IEnumerable<IShape> shapes) => _shapes = shapes.ToArray();

    public bool Inside(double x, double y)
    {
        foreach (var shape in _shapes)
        {
            if (shape.Inside(x, y)) return true;
        }
        return false;
    }
}

/// <summary>
/// A shape seen through a matrix. To decide whether a device point is
/// inside the transformed shape, run the point backwards through the
/// inverse and ask the original shape about the result - the shape never
/// learns it's been transformed. A matrix with no inverse flattens
/// everything to nothing: nothing can be inside it.
/// </summary>
public sealed class Transformed : IShape
{
    private readonly IShape _shape;
    private readonly Matrix3? _inverse;

    public Transformed(IShape shape, Matrix3 m)
    {
        _shape = shape;
        _inverse = m.IsInvertible() ? m.Inverse() : (Matrix3?)null;
    }

    public bool Inside(double x, double y)
    {
        if (_inverse is null) return false;
        var p = _inverse.Value * Tuple2.Point(x, y);
        return _shape.Inside(p.X, p.Y);
    }
}

/// <summary>
/// A path, filled: inside is the rule ("nonzero" or "evenodd") applied to
/// the path's winding number at the point. One more IShape, so any path -
/// self-intersecting, nested subpaths and all - goes through the same
/// supersampler as every shape before it.
/// </summary>
public sealed class Filled : IShape
{
    private readonly Path _path;
    private readonly string _rule;

    public Filled(Path path, string rule)
    {
        _path = path;
        _rule = rule;
    }

    public bool Inside(double x, double y) => _rule switch
    {
        "nonzero" => Winding.InsideNonzero(_path, x, y),
        "evenodd" => Winding.InsideEvenOdd(_path, x, y),
        _ => throw new ArgumentException($"unknown fill rule: {_rule}"),
    };
}

/// <summary>
/// The closed polygon through points, after m: every edge a segment of
/// that width in device space, last point back to first, built as one
/// shape. That's what makes a shared corner's coverage the coverage of the
/// union - painted once - rather than the sum of two edges painted
/// separately.
/// </summary>
public static class Outline
{
    public static IShape Build(IReadOnlyList<Tuple2> points, Matrix3 m, double width)
    {
        var transformed = points.Select(p => m * p).ToArray();
        var segments = new IShape[transformed.Length];
        for (int i = 0; i < transformed.Length; i++)
        {
            var a = transformed[i];
            var b = transformed[(i + 1) % transformed.Length];
            segments[i] = new Segment(a, b, width);
        }
        return new Union(segments);
    }
}
