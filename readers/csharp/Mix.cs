namespace Chapter01;

/// <summary>
/// mix(a, b, t) blends two colors a fraction t of the way from a to b.
/// With linear blending on (the default) the arithmetic happens on light,
/// which is physically correct. With it off, the arithmetic happens on
/// encoded file values, which is what web browsers do. This is global
/// state, reset to "on" before every scenario by the test runner.
/// </summary>
public static class Mix
{
    // [ThreadStatic] would matter for a parallel runner; this suite runs serially.
    public static bool LinearBlending { get; set; } = true;

    /// <summary>
    /// The optional fourth argument overrides the global switch for this one
    /// call only, leaving LinearBlending untouched either way.
    /// </summary>
    public static Color Blend(Color a, Color b, double t, bool? linear = null)
    {
        bool useLinear = linear ?? LinearBlending;
        if (useLinear)
        {
            return a + (b - a) * t;
        }

        // The browser's way: clamp each end into 0..1 (encode is only
        // defined there), encode, interpolate the file values, decode back.
        Color ca = Srgb.ClampColor(a);
        Color cb = Srgb.ClampColor(b);
        Color ea = Srgb.EncodeColor(ca);
        Color eb = Srgb.EncodeColor(cb);
        Color interpolated = ea + (eb - ea) * t;
        return Srgb.DecodeColor(interpolated);
    }
}
