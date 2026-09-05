namespace Chapter01;

/// <summary>
/// The sRGB transfer function. decode turns a file value (0..1) into light
/// (0..1); encode turns light back into a file value. Both are defined only
/// on 0..1 — callers must clamp first.
/// </summary>
public static class Srgb
{
    public static double Decode(double v) =>
        v <= 0.04045 ? v / 12.92 : Math.Pow((v + 0.055) / 1.055, 2.4);

    public static double Encode(double l) =>
        l <= 0.0031308 ? l * 12.92 : 1.055 * Math.Pow(l, 1.0 / 2.4) - 0.055;

    public static Color DecodeColor(Color c) =>
        new(Decode(c.Red), Decode(c.Green), Decode(c.Blue));

    public static Color EncodeColor(Color c) =>
        new(Encode(c.Red), Encode(c.Green), Encode(c.Blue));

    public static double Clamp01(double v) => v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);

    public static Color ClampColor(Color c) =>
        new(Clamp01(c.Red), Clamp01(c.Green), Clamp01(c.Blue));
}
