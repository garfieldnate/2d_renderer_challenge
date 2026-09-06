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

    // -----------------------------------------------------------------
    // Chapter 3 - the fan: twelve rays from the center of a 160x160
    // canvas to points 72 pixels out, every 30 degrees.
    // -----------------------------------------------------------------

    private static readonly Color FanPaper = new(0.02, 0.02, 0.025);
    private static readonly Color FanInk = new(0.92, 0.92, 0.88);

    public static List<(int X, int Y)> RayEnds()
    {
        var ends = new List<(int, int)>();
        for (int k = 0; k < 12; k++)
        {
            double a = k * 30.0 * Math.PI / 180.0;
            int x = (int)Math.Round(80 + 72 * Math.Cos(a), MidpointRounding.AwayFromZero);
            int y = (int)Math.Round(80 + 72 * Math.Sin(a), MidpointRounding.AwayFromZero);
            ends.Add((x, y));
        }
        return ends;
    }

    public static Canvas FanBresenham()
    {
        var c = new Canvas(160, 160);
        c.Fill(FanPaper);
        foreach (var (x, y) in RayEnds())
        {
            Lines.LineBresenham(c, 80, 80, x, y, FanInk);
        }
        return c;
    }

    public static Canvas FanWu()
    {
        var c = new Canvas(160, 160);
        c.Fill(FanPaper);
        foreach (var (x, y) in RayEnds())
        {
            Lines.LineWu(c, 80, 80, x, y, FanInk);
        }
        return c;
    }

    /// <summary>Each ray a thick_line of width 1, rasterized and painted through in turn, then magnified 2x.</summary>
    public static Canvas FanCoverage()
    {
        var c = new Canvas(160, 160);
        c.Fill(FanPaper);
        foreach (var (x, y) in RayEnds())
        {
            var cov = Rasterizer.Rasterize(new ThickLine(80, 80, x, y, 1), 160, 160);
            Paint.PaintThrough(c, cov, FanInk);
        }
        return Magnifier.Magnify(c, 2);
    }

    /// <summary>Bresenham's fan, then Wu's, side by side, magnified 2x.</summary>
    public static Canvas Plate03()
    {
        var both = new Canvas(320, 160);
        var a = FanBresenham();
        var b = FanWu();
        for (int y = 0; y < 160; y++)
        {
            for (int x = 0; x < 160; x++)
            {
                both.WritePixel(x, y, a.PixelAt(x, y));
                both.WritePixel(x + 160, y, b.PixelAt(x, y));
            }
        }
        return Magnifier.Magnify(both, 2);
    }

    // -----------------------------------------------------------------
    // Chapter 4 - the same fan, described as points around the origin and
    // pushed through matrices instead of drawn in pixels; and a letter F,
    // which unlike the fan has no symmetry to hide a wrong transform.
    // -----------------------------------------------------------------

    /// <summary>The center, then twelve points at radius 36, every 30 degrees.</summary>
    public static List<Tuple2> FanPoints()
    {
        var pts = new List<Tuple2> { Tuple2.Point(0, 0) };
        for (int k = 0; k < 12; k++)
        {
            double a = k * 30.0 * Math.PI / 180.0;
            pts.Add(Tuple2.Point(36 * Math.Cos(a), 36 * Math.Sin(a)));
        }
        return pts;
    }

    /// <summary>The fan's points through m, drawn as one union of segments.</summary>
    public static Canvas FanTransformed(Matrix3 m)
    {
        var c = new Canvas(160, 160);
        c.Fill(FanPaper);
        var pts = Matrix3.TransformPoints(FanPoints(), m);
        var rays = new IShape[12];
        for (int k = 1; k <= 12; k++) rays[k - 1] = new Segment(pts[0], pts[k], 1);
        var cov = Rasterizer.Rasterize(new Union(rays), 160, 160);
        Paint.PaintThrough(c, cov, FanInk);
        return c;
    }

    /// <summary>The fan drawn through rotation(pi/6) then translation, and through the same two matrices the other order, side by side.</summary>
    public static Canvas FanBothOrders()
    {
        var turn = Matrix3.Rotation(Math.PI / 6);
        var move = Matrix3.Translation(104.5, 76.5);
        return SideBySide(FanTransformed(move * turn), FanTransformed(turn * move));
    }

    /// <summary>Ten corners, clockwise from the top left, in a 40-by-60 box centered on the origin.</summary>
    public static List<Tuple2> LetterF() => new()
    {
        Tuple2.Point(-20, -30), Tuple2.Point(20, -30), Tuple2.Point(20, -20), Tuple2.Point(-10, -20),
        Tuple2.Point(-10, -5), Tuple2.Point(12, -5), Tuple2.Point(12, 5), Tuple2.Point(-10, 5),
        Tuple2.Point(-10, 30), Tuple2.Point(-20, 30),
    };

    private static readonly Color GhostInk = new(0.16, 0.16, 0.17);

    /// <summary>
    /// A dim, untransformed F for reference, copied into two canvases, then
    /// the F drawn through move * turn on one and turn * move on the other.
    /// </summary>
    public static Canvas FBothOrders()
    {
        var turn = Matrix3.Rotation(Math.PI / 6);
        var move = Matrix3.Translation(104.5, 76.5);
        var home = Matrix3.Translation(44.5, 44.5);

        var ghost = new Canvas(160, 160);
        ghost.Fill(FanPaper);
        Paint.PaintThrough(ghost, Rasterizer.Rasterize(Outline.Build(LetterF(), home, 1), 160, 160), GhostInk);

        var a = CopyCanvas(ghost);
        var b = CopyCanvas(ghost);
        Paint.PaintThrough(a, Rasterizer.Rasterize(Outline.Build(LetterF(), move * turn, 1), 160, 160), FanInk);
        Paint.PaintThrough(b, Rasterizer.Rasterize(Outline.Build(LetterF(), turn * move, 1), 160, 160), FanInk);

        return SideBySide(a, b);
    }

    public static Canvas Plate04() => Magnifier.Magnify(FBothOrders(), 2);

    /// <summary>Copies a into the left half of a canvas twice as wide, b into the right half.</summary>
    private static Canvas SideBySide(Canvas a, Canvas b)
    {
        var both = new Canvas(a.Width + b.Width, Math.Max(a.Height, b.Height));
        for (int y = 0; y < a.Height; y++)
            for (int x = 0; x < a.Width; x++)
                both.WritePixel(x, y, a.PixelAt(x, y));
        for (int y = 0; y < b.Height; y++)
            for (int x = 0; x < b.Width; x++)
                both.WritePixel(x + a.Width, y, b.PixelAt(x, y));
        return both;
    }

    private static Canvas CopyCanvas(Canvas c)
    {
        var copy = new Canvas(c.Width, c.Height);
        for (int y = 0; y < c.Height; y++)
            for (int x = 0; x < c.Width; x++)
                copy.WritePixel(x, y, c.PixelAt(x, y));
        return copy;
    }
}
