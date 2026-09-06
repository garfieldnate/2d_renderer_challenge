namespace Chapter01;

/// <summary>
/// One subpath: the points the pen visited since the last move_to, in
/// order, and whether close() was called on it. A subpath of one point has
/// no edges and draws nothing; it's still legal (two move_tos in a row).
/// </summary>
public sealed class Subpath
{
    private readonly List<Tuple2> _points = new();

    public IReadOnlyList<Tuple2> Points => _points;
    public bool Closed { get; internal set; }

    internal Subpath(Tuple2 first) => _points.Add(first);

    internal void Add(Tuple2 p) => _points.Add(p);
}

/// <summary>
/// A path: a list of subpaths, one for each time the pen went down.
/// move_to lifts the pen and starts a new subpath. line_to draws to the
/// current subpath's end - or, if the pen has never been put down, behaves
/// like move_to; and if the last subpath was already closed, starts a new
/// one at the point the closed subpath began, the way PostScript and SVG
/// do. close() marks the current subpath closed; closing nothing, or
/// closing twice, does nothing extra.
///
/// For filling, edges() treats every subpath as closed whether or not
/// close() was called, so a triangle left open still has three edges - the
/// last one from its final point back to its first.
/// </summary>
public sealed class Path
{
    private readonly List<Subpath> _subpaths = new();

    public IReadOnlyList<Subpath> Subpaths => _subpaths;

    public void MoveTo(Tuple2 p) => _subpaths.Add(new Subpath(p));

    public void LineTo(Tuple2 p)
    {
        if (_subpaths.Count == 0)
        {
            _subpaths.Add(new Subpath(p));
            return;
        }

        var last = _subpaths[^1];
        if (last.Closed)
        {
            var fresh = new Subpath(last.Points[0]);
            fresh.Add(p);
            _subpaths.Add(fresh);
        }
        else
        {
            last.Add(p);
        }
    }

    public void Close()
    {
        if (_subpaths.Count == 0) return;
        _subpaths[^1].Closed = true;
    }

    /// <summary>
    /// Every edge of every subpath as (a, b) pairs, closing every subpath
    /// whether or not close() was called. A subpath of one point
    /// contributes no edges; a subpath of n &gt;= 2 points contributes n,
    /// the last one from its final point back to its first.
    /// </summary>
    public List<(Tuple2 A, Tuple2 B)> Edges()
    {
        var result = new List<(Tuple2, Tuple2)>();
        foreach (var sp in _subpaths)
        {
            int n = sp.Points.Count;
            if (n < 2) continue;
            for (int i = 0; i < n; i++)
            {
                result.Add((sp.Points[i], sp.Points[(i + 1) % n]));
            }
        }
        return result;
    }

    /// <summary>The smallest axis-aligned box around every point of every subpath. (0, 0, 0, 0) if the path is empty.</summary>
    public (double MinX, double MinY, double MaxX, double MaxY) Bounds()
    {
        bool any = false;
        double minX = 0, minY = 0, maxX = 0, maxY = 0;
        foreach (var sp in _subpaths)
        {
            foreach (var p in sp.Points)
            {
                if (!any)
                {
                    minX = maxX = p.X;
                    minY = maxY = p.Y;
                    any = true;
                }
                else
                {
                    minX = Math.Min(minX, p.X);
                    minY = Math.Min(minY, p.Y);
                    maxX = Math.Max(maxX, p.X);
                    maxY = Math.Max(maxY, p.Y);
                }
            }
        }
        return (minX, minY, maxX, maxY);
    }

    /// <summary>A single closed subpath through the given points.</summary>
    public static Path Polygon(params Tuple2[] points)
    {
        var p = new Path();
        if (points.Length == 0) return p;
        p.MoveTo(points[0]);
        for (int i = 1; i < points.Length; i++) p.LineTo(points[i]);
        p.Close();
        return p;
    }

    /// <summary>
    /// A regular n-gon standing in for a circle of radius r about (cx, cy):
    /// its first point at angle 0, on the right, going clockwise on the
    /// screen (increasing angle, since y points down).
    /// </summary>
    public static Path CirclePath(double cx, double cy, double r, int n)
    {
        var pts = new Tuple2[n];
        for (int k = 0; k < n; k++)
        {
            double a = 2 * Math.PI * k / n;
            pts[k] = Tuple2.Point(cx + r * Math.Cos(a), cy + r * Math.Sin(a));
        }
        return Polygon(pts);
    }

    /// <summary>
    /// A new path with every point of every subpath of p taken through m,
    /// closed flags and all. p itself is untouched, so a path described
    /// once can be drawn again, transformed differently, without the first
    /// draw leaking into the second.
    /// </summary>
    public static Path TransformPath(Path p, Matrix3 m)
    {
        var result = new Path();
        foreach (var sp in p.Subpaths)
        {
            if (sp.Points.Count == 0) continue;

            result.MoveTo(m * sp.Points[0]);
            for (int i = 1; i < sp.Points.Count; i++) result.LineTo(m * sp.Points[i]);
            if (sp.Closed) result.Close();
        }
        return result;
    }
}
