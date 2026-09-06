namespace Chapter01;

/// <summary>
/// Turns a shape into a coverage buffer, two ways: the fast, wrong way
/// (ask only the pixel's center) and the slow, honest way (ask 64 sample
/// points per pixel and count).
/// </summary>
public static class Rasterizer
{
    private const int Grid = 8;

    /// <summary>The center of pixel (x, y) is (x + 0.5, y + 0.5).</summary>
    public static int CenterInside(IShape shape, int x, int y) =>
        shape.Inside(x + 0.5, y + 0.5) ? 1 : 0;

    public static CoverageBuffer RasterizeCenters(IShape shape, int width, int height)
    {
        var cov = new CoverageBuffer(width, height);
        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                cov.SetCoverage(x, y, CenterInside(shape, x, y));
            }
        }
        return cov;
    }

    /// <summary>
    /// Divide the pixel into an 8-by-8 grid, one sample at the center of
    /// each cell: the sample in row j, column i is at
    /// (x + (i + 0.5) / 8, y + (j + 0.5) / 8). Coverage is the count inside,
    /// divided by 64.
    /// </summary>
    public static double Coverage(IShape shape, int x, int y)
    {
        int count = 0;
        for (int j = 0; j < Grid; j++)
        {
            for (int i = 0; i < Grid; i++)
            {
                double sx = x + (i + 0.5) / Grid;
                double sy = y + (j + 0.5) / Grid;
                if (shape.Inside(sx, sy)) count++;
            }
        }
        return count / (double)(Grid * Grid);
    }

    public static CoverageBuffer Rasterize(IShape shape, int width, int height)
    {
        var cov = new CoverageBuffer(width, height);
        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                cov.SetCoverage(x, y, Coverage(shape, x, y));
            }
        }
        return cov;
    }

    /// <summary>
    /// Rasterize restricted to the pixels box touches: columns from
    /// floor(min x) up to but not including ceil(max x), rows likewise,
    /// clipped to the buffer. Everything else is left at zero, same
    /// coverage as Rasterize, less work.
    /// </summary>
    public static CoverageBuffer RasterizeWithin(IShape shape, (double MinX, double MinY, double MaxX, double MaxY) box, int width, int height)
    {
        var cov = new CoverageBuffer(width, height);

        int x0 = Math.Max(0, (int)Math.Floor(box.MinX));
        int x1 = Math.Min(width, (int)Math.Ceiling(box.MaxX));
        int y0 = Math.Max(0, (int)Math.Floor(box.MinY));
        int y1 = Math.Min(height, (int)Math.Ceiling(box.MaxY));

        for (int y = y0; y < y1; y++)
        {
            for (int x = x0; x < x1; x++)
            {
                cov.SetCoverage(x, y, Coverage(shape, x, y));
            }
        }
        return cov;
    }
}
