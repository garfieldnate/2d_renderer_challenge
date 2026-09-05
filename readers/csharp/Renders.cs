namespace Chapter01;

/// <summary>The chapter's five renders, wrapped in functions so tests can call them.</summary>
public static class Renders
{
    public static Canvas GrayMatch()
    {
        var c = new Canvas(300, 100);

        for (int y = 0; y <= 99; y++)
        {
            for (int x = 0; x <= 99; x++)
            {
                Color color = (x + y) % 2 == 0 ? new Color(1, 1, 1) : new Color(0, 0, 0);
                c.WritePixel(x, y, color);
            }
        }

        double g = Srgb.Decode(128.0 / 255.0);
        for (int y = 0; y <= 99; y++)
        {
            for (int x = 100; x <= 199; x++)
            {
                c.WritePixel(x, y, new Color(g, g, g));
            }
        }

        for (int y = 0; y <= 99; y++)
        {
            for (int x = 200; x <= 299; x++)
            {
                c.WritePixel(x, y, new Color(0.5, 0.5, 0.5));
            }
        }

        return c;
    }

    public static Canvas QuarterMatch()
    {
        var c = new Canvas(200, 100);

        for (int y = 0; y <= 99; y++)
        {
            for (int x = 0; x <= 99; x++)
            {
                Color color = (x + y) % 4 == 0 ? new Color(1, 1, 1) : new Color(0, 0, 0);
                c.WritePixel(x, y, color);
            }
        }

        for (int y = 0; y <= 99; y++)
        {
            for (int x = 100; x <= 199; x++)
            {
                c.WritePixel(x, y, new Color(0.25, 0.25, 0.25));
            }
        }

        return c;
    }

    public static Canvas Ramp()
    {
        var c = new Canvas(256, 32);

        for (int x = 0; x <= 255; x++)
        {
            double g = x / 255.0;
            for (int y = 0; y <= 31; y++)
            {
                c.WritePixel(x, y, new Color(g, g, g));
            }
        }

        return c;
    }

    public static Canvas ClampPair()
    {
        var c = new Canvas(200, 100);

        for (int y = 0; y <= 99; y++)
        {
            for (int x = 0; x <= 99; x++)
            {
                c.WritePixel(x, y, new Color(2, 0.5, 0.5));
            }
            for (int x = 100; x <= 199; x++)
            {
                c.WritePixel(x, y, new Color(1, 0.25, 0.25));
            }
        }

        return c;
    }

    private static void RampPair(Canvas c, int top, Color a, Color b)
    {
        for (int x = 0; x <= 399; x++)
        {
            double t = x / 399.0;

            Mix.LinearBlending = false;
            Color naive = Mix.Blend(a, b, t);
            Mix.LinearBlending = true;
            Color light = Mix.Blend(a, b, t);

            for (int y = top; y <= top + 39; y++) c.WritePixel(x, y, naive);
            for (int y = top + 45; y <= top + 84; y++) c.WritePixel(x, y, light);
        }
    }

    public static Canvas Plate01()
    {
        var c = new Canvas(400, 180);
        RampPair(c, 0, new Color(0, 0, 0), new Color(1, 1, 1));
        RampPair(c, 90, new Color(0.7, 0, 0), new Color(0, 0.3, 0.02));
        return c;
    }

    private static readonly Color Paper = new(0.02, 0.02, 0.025);
    private static readonly Color Ink = new(0.9, 0.55, 0.1);

    /// <summary>A 40-pixel disc, rasterized by centers, painted orange on gray, magnified 8x.</summary>
    public static Canvas DiscCenters()
    {
        var c = new Canvas(40, 40);
        c.Fill(Paper);
        var cov = Rasterizer.RasterizeCenters(new Circle(20, 20, 16), 40, 40);
        Paint.PaintThrough(c, cov, Ink);
        return Magnifier.Magnify(c, 8);
    }

    /// <summary>disc_centers with rasterize in place of rasterize_centers, nothing else changed.</summary>
    public static Canvas DiscCoverage()
    {
        var c = new Canvas(40, 40);
        c.Fill(Paper);
        var cov = Rasterizer.Rasterize(new Circle(20, 20, 16), 40, 40);
        Paint.PaintThrough(c, cov, Ink);
        return Magnifier.Magnify(c, 8);
    }

    /// <summary>The same disc's coverage painted once on the left half, twice on the right.</summary>
    public static Canvas PaintedTwice()
    {
        var c = new Canvas(80, 40);
        c.Fill(Paper);
        var cov = Rasterizer.Rasterize(new Circle(20, 20, 16), 40, 40);

        var once = new CoverageBuffer(80, 40);
        for (int y = 0; y <= 39; y++)
        {
            for (int x = 0; x <= 39; x++)
            {
                once.SetCoverage(x, y, cov.CoverageAt(x, y));
                once.SetCoverage(x + 40, y, cov.CoverageAt(x, y));
            }
        }
        Paint.PaintThrough(c, once, Ink);

        var twice = new CoverageBuffer(80, 40);
        for (int y = 0; y <= 39; y++)
        {
            for (int x = 0; x <= 39; x++)
            {
                twice.SetCoverage(x + 40, y, cov.CoverageAt(x, y));
            }
        }
        Paint.PaintThrough(c, twice, Ink);

        return Magnifier.Magnify(c, 6);
    }

    /// <summary>The same circle on the same grid, asked two different questions: centers on the left, coverage on the right.</summary>
    public static Canvas Plate02()
    {
        var c = new Canvas(80, 40);
        c.Fill(Paper);
        var shape = new Circle(20, 20, 16);
        var left = Rasterizer.RasterizeCenters(shape, 40, 40);
        var right = Rasterizer.Rasterize(shape, 40, 40);

        var both = new CoverageBuffer(80, 40);
        for (int y = 0; y <= 39; y++)
        {
            for (int x = 0; x <= 39; x++)
            {
                both.SetCoverage(x, y, left.CoverageAt(x, y));
                both.SetCoverage(x + 40, y, right.CoverageAt(x, y));
            }
        }
        Paint.PaintThrough(c, both, Ink);

        return Magnifier.Magnify(c, 6);
    }
}
