namespace Chapter01;

/// <summary>
/// A color: three floating point numbers measuring light. 0.0 is none, 1.0 is
/// full. Values may wander outside 0..1 in the middle of a calculation; they
/// are clamped once, on the way out to a file.
/// </summary>
public readonly struct Color
{
    public double Red { get; }
    public double Green { get; }
    public double Blue { get; }

    public Color(double red, double green, double blue)
    {
        Red = red;
        Green = green;
        Blue = blue;
    }

    public static Color operator +(Color a, Color b) =>
        new(a.Red + b.Red, a.Green + b.Green, a.Blue + b.Blue);

    public static Color operator -(Color a, Color b) =>
        new(a.Red - b.Red, a.Green - b.Green, a.Blue - b.Blue);

    public static Color operator *(Color c, double scalar) =>
        new(c.Red * scalar, c.Green * scalar, c.Blue * scalar);

    /// <summary>Hadamard product: component by component, red times red and so on.</summary>
    public static Color operator *(Color a, Color b) =>
        new(a.Red * b.Red, a.Green * b.Green, a.Blue * b.Blue);

    public override string ToString() => $"color({Red}, {Green}, {Blue})";
}
