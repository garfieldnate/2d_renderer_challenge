namespace Chapter01;

/// <summary>
/// A canvas of numbers instead of colors: one value per pixel, from 0 ("none
/// of this pixel is inside") to 1 ("all of it"). Starts at zero. Writes
/// outside the buffer are silently ignored, same as Canvas.
/// </summary>
public sealed class CoverageBuffer
{
    public int Width { get; }
    public int Height { get; }

    private readonly double[] _values;

    public CoverageBuffer(int width, int height)
    {
        Width = width;
        Height = height;
        _values = new double[width * height];
    }

    public void SetCoverage(int x, int y, double coverage)
    {
        if (x < 0 || x >= Width || y < 0 || y >= Height) return;
        _values[y * Width + x] = coverage;
    }

    public double CoverageAt(int x, int y) => _values[y * Width + x];

    /// <summary>The sum of every value: the area of the shape, in pixels, as the buffer sees it.</summary>
    public double Ink => _values.Sum();
}
