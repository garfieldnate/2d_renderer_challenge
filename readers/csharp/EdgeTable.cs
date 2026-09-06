namespace Chapter01;

/// <summary>
/// One non-horizontal edge, ready for the sweep: which end is higher on
/// the canvas (y_top, x_top), which is lower (y_bottom), how far x moves
/// per unit of y (slope), and which way the path went along it - +1
/// heading down the canvas (increasing y), -1 heading up. The same sign
/// chapter 5's winding number gave a crossing.
/// </summary>
public readonly struct Edge
{
    public double YTop { get; }
    public double YBottom { get; }
    public double XTop { get; }
    public double Slope { get; }
    public int Direction { get; }

    public Edge(double yTop, double yBottom, double xTop, double slope, int direction)
    {
        YTop = yTop;
        YBottom = yBottom;
        XTop = xTop;
        Slope = slope;
        Direction = direction;
    }
}

/// <summary>
/// Takes a path apart for the sweep. Every edge that isn't horizontal
/// (a.y == b.y exactly - not clamped, not special-cased, dropped) becomes
/// an Edge; the result is sorted by y_top, then by x_top.
/// </summary>
public static class EdgeTable
{
    public static List<Edge> Build(Path p)
    {
        var edges = new List<Edge>();
        foreach (var (a, b) in p.Edges())
        {
            if (a.Y == b.Y) continue; // horizontal: dropped, not clamped

            Tuple2 top, bottom;
            int direction;
            if (a.Y < b.Y)
            {
                top = a;
                bottom = b;
                direction = 1;
            }
            else
            {
                top = b;
                bottom = a;
                direction = -1;
            }

            double slope = (bottom.X - top.X) / (bottom.Y - top.Y);
            edges.Add(new Edge(top.Y, bottom.Y, top.X, slope, direction));
        }

        edges.Sort((x, y) => x.YTop != y.YTop ? x.YTop.CompareTo(y.YTop) : x.XTop.CompareTo(y.XTop));
        return edges;
    }

    /// <summary>Where the edge is at height y: x_top + (y - y_top) * slope.</summary>
    public static double XAt(Edge e, double y) => e.XTop + (y - e.YTop) * e.Slope;
}
