namespace Chapter01;

/// <summary>
/// The scanline fill: crossings on one row, the spans they imply under a
/// rule, painting a span into a coverage buffer, and the sweep that ties
/// it all together with an active edge list instead of checking every edge
/// on every row. fill_path_aliased's result is exactly chapter 5's
/// rasterize_centers(filled(p, rule), w, h), pixel for pixel, and
/// max_coverage_difference is how the scenarios say so.
/// </summary>
public static class Sweep
{
    /// <summary>
    /// (x, direction) for every edge of the table that spans height y under
    /// the half-open rule y_top &lt;= y &lt; y_bottom, sorted by x.
    /// </summary>
    public static List<(double X, int Direction)> CrossingsOnRow(List<Edge> table, double y)
    {
        var result = new List<(double X, int Direction)>();
        foreach (var e in table)
        {
            if (e.YTop <= y && y < e.YBottom)
            {
                result.Add((EdgeTable.XAt(e, y), e.Direction));
            }
        }
        result.Sort((a, b) => a.X.CompareTo(b.X));
        return result;
    }

    /// <summary>
    /// Walks sorted crossings left to right, accumulating the winding
    /// number, and returns the maximal intervals where the rule says
    /// inside. Two inside stretches that touch are one span, because the
    /// rule never turned false between them.
    /// </summary>
    public static List<(double Start, double End)> SpansFromCrossings(IReadOnlyList<(double X, int Direction)> xs, string rule)
    {
        var result = new List<(double, double)>();
        int w = 0;
        double? start = null;
        foreach (var (x, d) in xs)
        {
            w += d;
            bool inside = rule == "nonzero" ? w != 0 : w % 2 != 0;
            if (inside && start is null) start = x;
            if (!inside && start is not null)
            {
                result.Add((start.Value, x));
                start = null;
            }
        }
        return result;
    }

    /// <summary>Crossings and spans together for one pixel row, sampled at height row + 0.5.</summary>
    public static List<(double Start, double End)> Spans(Path p, string rule, int row)
    {
        double y = row + 0.5;
        var xs = CrossingsOnRow(EdgeTable.Build(p), y);
        return SpansFromCrossings(xs, rule);
    }

    /// <summary>
    /// Sets to 1 every pixel of the row whose center lies in [x0, x1):
    /// the first is ceil(x0 - 0.5), the last is ceil(x1 - 0.5) - 1, clipped
    /// to the buffer. If the first is past the last there's nothing to do.
    /// </summary>
    public static void FillSpan(CoverageBuffer cov, int row, double x0, double x1)
    {
        int first = (int)Math.Ceiling(x0 - 0.5);
        int last = (int)Math.Ceiling(x1 - 0.5) - 1;
        int from = Math.Max(first, 0);
        int to = Math.Min(last, cov.Width - 1);
        for (int x = from; x <= to; x++)
        {
            cov.SetCoverage(x, row, 1);
        }
    }

    /// <summary>
    /// The scanline fill with an active edge list: the table is read once,
    /// front to back, and each row keeps only the edges that span its
    /// sample height - an edge whose y_top has been reached joins, one
    /// whose y_bottom has been passed leaves, half-open both ways.
    /// </summary>
    public static CoverageBuffer FillPathAliased(Path p, string rule, int width, int height)
    {
        var cov = new CoverageBuffer(width, height);
        var table = EdgeTable.Build(p); // sorted by y_top
        var active = new List<Edge>();
        int next = 0;

        for (int row = 0; row < height; row++)
        {
            double y = row + 0.5;

            while (next < table.Count && table[next].YTop <= y)
            {
                active.Add(table[next]);
                next++;
            }

            active.RemoveAll(e => e.YBottom <= y); // half-open: out once y reaches the bottom

            var xs = active
                .Select(e => (X: EdgeTable.XAt(e, y), e.Direction))
                .OrderBy(c => c.X)
                .ToList();

            foreach (var (x0, x1) in SpansFromCrossings(xs, rule))
            {
                FillSpan(cov, row, x0, x1);
            }
        }

        return cov;
    }

    /// <summary>
    /// The largest difference between corresponding entries of two
    /// coverage buffers, or 1 when the sizes differ - the coverage-buffer
    /// twin of chapter 1's max_channel_difference, for the same reason: a
    /// transposed sweep shouldn't compare equal to anything.
    /// </summary>
    public static double MaxCoverageDifference(CoverageBuffer a, CoverageBuffer b)
    {
        if (a.Width != b.Width || a.Height != b.Height) return 1;

        double max = 0;
        for (int y = 0; y < a.Height; y++)
        {
            for (int x = 0; x < a.Width; x++)
            {
                double diff = Math.Abs(a.CoverageAt(x, y) - b.CoverageAt(x, y));
                if (diff > max) max = diff;
            }
        }
        return max;
    }
}
