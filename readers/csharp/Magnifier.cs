namespace Chapter01;

/// <summary>
/// magnify(canvas, k) returns a canvas k times wider and taller, every pixel
/// repeated into a k-by-k block. No smoothing, no averaging, no cleverness.
/// </summary>
public static class Magnifier
{
    public static Canvas Magnify(Canvas c, int k)
    {
        var m = new Canvas(c.Width * k, c.Height * k);
        for (int y = 0; y < c.Height; y++)
        {
            for (int x = 0; x < c.Width; x++)
            {
                Color color = c.PixelAt(x, y);
                for (int dy = 0; dy < k; dy++)
                {
                    for (int dx = 0; dx < k; dx++)
                    {
                        m.WritePixel(x * k + dx, y * k + dy, color);
                    }
                }
            }
        }
        return m;
    }
}
