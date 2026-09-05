namespace Chapter01;

/// <summary>
/// A rectangle of colors. The origin is the top left corner: x increases to
/// the right (the column), y increases downward (the row). Every pixel
/// starts black. Writes outside the canvas are silently ignored.
/// </summary>
public sealed class Canvas
{
    public int Width { get; }
    public int Height { get; }

    private readonly Color[] _pixels;

    public Canvas(int width, int height)
    {
        Width = width;
        Height = height;
        _pixels = new Color[width * height];
        // Color default(struct) is (0,0,0), i.e. black, already.
    }

    public void WritePixel(int x, int y, Color c)
    {
        if (x < 0 || x >= Width || y < 0 || y >= Height) return;
        _pixels[y * Width + x] = c;
    }

    public Color PixelAt(int x, int y) => _pixels[y * Width + x];

    public void Fill(Color c)
    {
        for (int i = 0; i < _pixels.Length; i++) _pixels[i] = c;
    }

    public IEnumerable<Color> AllPixels() => _pixels;
}
