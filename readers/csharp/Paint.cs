namespace Chapter01;

/// <summary>
/// The one place the renderer touches the canvas. paint_through moves every
/// pixel of the canvas toward a color by that pixel's coverage: zero leaves
/// it alone, one replaces it, and in between it's mix(pixel, color,
/// coverage) in light, the same mix as chapter 1. This always happens in
/// light, regardless of the global linear-blending switch - coverage is a
/// rendering quantity, not a browser color to imitate.
/// </summary>
public static class Paint
{
    public static void PaintThrough(Canvas canvas, CoverageBuffer coverage, Color color)
    {
        for (int y = 0; y < canvas.Height; y++)
        {
            for (int x = 0; x < canvas.Width; x++)
            {
                double t = coverage.CoverageAt(x, y);
                Color current = canvas.PixelAt(x, y);
                canvas.WritePixel(x, y, Mix.Blend(current, color, t, linear: true));
            }
        }
    }
}
