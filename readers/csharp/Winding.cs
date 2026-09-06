namespace Chapter01;

/// <summary>
/// Two ways to ask whether a point is inside a path's edges: the raw
/// crossing count of the old ray-casting trick, and the signed winding
/// number that tells nonzero from even-odd. Both use the half-open rule -
/// an edge from a to b is crossed when the ray's height y satisfies
/// a.y &lt;= y &lt; b.y or b.y &lt;= y &lt; a.y - so a vertex the ray passes exactly
/// through counts on exactly one of its two edges, never both and never
/// neither. A horizontal edge (a.y == b.y) satisfies neither half of the
/// rule and is never crossed.
/// </summary>
public static class Winding
{
    /// <summary>How many edges a ray from (x, y) toward +x crosses.</summary>
    public static int Crossings(Path p, double x, double y)
    {
        int count = 0;
        foreach (var (a, b) in p.Edges())
        {
            bool spans = (a.Y <= y && y < b.Y) || (b.Y <= y && y < a.Y);
            if (!spans) continue;

            double t = (y - a.Y) / (b.Y - a.Y);
            double crossX = a.X + t * (b.X - a.X);
            if (crossX > x) count++;
        }
        return count;
    }

    /// <summary>
    /// The winding number: each crossed edge counts +1 heading down the
    /// canvas (toward larger y) or -1 heading up, using cross(b - a, q - a)
    /// to find which side of the edge q is on instead of dividing for x.
    /// Positive is clockwise on the screen, because the canvas's y points
    /// down.
    /// </summary>
    public static int WindingAt(Path p, double x, double y)
    {
        var q = Tuple2.Point(x, y);
        int w = 0;
        foreach (var (a, b) in p.Edges())
        {
            if (a.Y <= y)
            {
                if (b.Y > y && Tuple2.Cross(b - a, q - a) > 0) w++;
            }
            else
            {
                if (b.Y <= y && Tuple2.Cross(b - a, q - a) < 0) w--;
            }
        }
        return w;
    }

    /// <summary>Nonzero rule: inside when the winding number isn't zero.</summary>
    public static bool InsideNonzero(Path p, double x, double y) => WindingAt(p, x, y) != 0;

    /// <summary>Even-odd rule: inside when the winding number is odd.</summary>
    public static bool InsideEvenOdd(Path p, double x, double y) => WindingAt(p, x, y) % 2 != 0;
}
