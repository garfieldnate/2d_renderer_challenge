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
}
