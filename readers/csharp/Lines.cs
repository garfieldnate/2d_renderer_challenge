namespace Chapter01;

/// <summary>
/// Two ways to draw a line of integer endpoints. Bresenham lights one pixel
/// per step along the longer axis, chosen with integer arithmetic. Wu lights
/// two, weighted by where the ideal line falls between them. Both walk the
/// longer axis left to right (the "steep" and left-to-right swaps), so the
/// pixels don't depend on which end you call the start.
/// </summary>
public static class Lines
{
    public static void LineBresenham(Canvas c, int x0, int y0, int x1, int y1, Color col)
    {
        bool steep = Math.Abs(y1 - y0) > Math.Abs(x1 - x0);
        if (steep)
        {
            (x0, y0) = (y0, x0);
            (x1, y1) = (y1, x1);
        }
        if (x0 > x1)
        {
            (x0, x1) = (x1, x0);
            (y0, y1) = (y1, y0);
        }

        int dx = x1 - x0;
        int dy = Math.Abs(y1 - y0);
        int ystep = y0 < y1 ? 1 : -1;
        int err = dx / 2; // integer division: the tie rule
        int y = y0;

        for (int x = x0; x <= x1; x++)
        {
            if (steep) c.WritePixel(y, x, col);
            else c.WritePixel(x, y, col);

            err -= dy;
            if (err < 0)
            {
                y += ystep;
                err += dx;
            }
        }
    }

    /// <summary>
    /// Paint one pixel toward col by weight, mix(pixel_at(c, x, y), col, weight)
    /// written back. Drops writes off the canvas and skips a weight of zero.
    /// </summary>
    public static void Plot(Canvas c, int x, int y, Color col, double weight)
    {
        if (weight <= 0) return;
        if (x < 0 || x >= c.Width || y < 0 || y >= c.Height) return;
        c.WritePixel(x, y, Mix.Blend(c.PixelAt(x, y), col, weight));
    }

    public static void LineWu(Canvas c, int x0, int y0, int x1, int y1, Color col)
    {
        bool steep = Math.Abs(y1 - y0) > Math.Abs(x1 - x0);
        if (steep)
        {
            (x0, y0) = (y0, x0);
            (x1, y1) = (y1, x1);
        }
        if (x0 > x1)
        {
            (x0, x1) = (x1, x0);
            (y0, y1) = (y1, y0);
        }

        int dx = x1 - x0;
        double slope = dx == 0 ? 0 : (double)(y1 - y0) / dx;

        for (int x = x0; x <= x1; x++)
        {
            double y = y0 + (x - x0) * slope;
            int yi = (int)Math.Floor(y);
            double f = y - yi;

            if (steep)
            {
                Plot(c, yi, x, col, 1 - f);
                Plot(c, yi + 1, x, col, f);
            }
            else
            {
                Plot(c, x, yi, col, 1 - f);
                Plot(c, x, yi + 1, col, f);
            }
        }
    }

    /// <summary>
    /// Test helper, not a renderer function: every pixel of the canvas that
    /// isn't black, as (x, y) pairs in reading order - top row first, left
    /// to right within a row.
    /// </summary>
    public static List<(int X, int Y)> LitPixels(Canvas c)
    {
        var result = new List<(int, int)>();
        for (int y = 0; y < c.Height; y++)
        {
            for (int x = 0; x < c.Width; x++)
            {
                var p = c.PixelAt(x, y);
                if (p.Red != 0 || p.Green != 0 || p.Blue != 0) result.Add((x, y));
            }
        }
        return result;
    }

    /// <summary>
    /// Test helper: the sum of every pixel's red channel - for a white line
    /// on black, exactly how much paint went down.
    /// </summary>
    public static double TotalInk(Canvas c) => c.AllPixels().Sum(p => p.Red);
}
