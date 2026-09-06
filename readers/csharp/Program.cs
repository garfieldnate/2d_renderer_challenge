using Chapter01;

var runner = new TestRunner();

// ---------------------------------------------------------------------
// features/chapter01-equality.feature
// ---------------------------------------------------------------------
runner.Run("chapter01-equality", "Two numbers that differ by less than the tolerance are equal", () =>
{
    Check.Equal(1.0, 1.0000001, 0.00001);
});

runner.Run("chapter01-equality", "Two numbers that differ by more than the tolerance are not", () =>
{
    Check.NotEqual(1.0, 1.001, 0.00001);
});

runner.Run("chapter01-equality", "The default tolerance is 0.0001", () =>
{
    Check.Equal(0.1 + 0.2, 0.3);
    Check.Equal(1.0, 1.00009);
    Check.NotEqual(1.0, 1.0002);
});

// ---------------------------------------------------------------------
// features/chapter01-colors.feature
// ---------------------------------------------------------------------
runner.Run("chapter01-colors", "A color is a red, green, blue tuple", () =>
{
    var c = new Color(-0.5, 0.4, 1.7);
    Check.Equal(-0.5, c.Red);
    Check.Equal(0.4, c.Green);
    Check.Equal(1.7, c.Blue);
});

runner.Run("chapter01-colors", "Adding colors", () =>
{
    var c1 = new Color(0.9, 0.6, 0.75);
    var c2 = new Color(0.7, 0.1, 0.25);
    Check.ColorEqual(new Color(1.6, 0.7, 1.0), c1 + c2);
});

runner.Run("chapter01-colors", "Subtracting colors", () =>
{
    var c1 = new Color(0.9, 0.6, 0.75);
    var c2 = new Color(0.7, 0.1, 0.25);
    Check.ColorEqual(new Color(0.2, 0.5, 0.5), c1 - c2);
});

runner.Run("chapter01-colors", "Scaling a color by a number", () =>
{
    var c = new Color(0.2, 0.3, 0.4);
    Check.ColorEqual(new Color(0.4, 0.6, 0.8), c * 2);
    Check.ColorEqual(new Color(0.1, 0.15, 0.2), c * 0.5);
});

runner.Run("chapter01-colors", "Multiplying two colors filters one through the other", () =>
{
    var c1 = new Color(1, 0.2, 0.4);
    var c2 = new Color(0.9, 1, 0.1);
    Check.ColorEqual(new Color(0.9, 0.2, 0.04), c1 * c2);
});

runner.Run("chapter01-colors", "Colors compare component by component, with the usual tolerance", () =>
{
    var c1 = new Color(0.1, 0.5, 1);
    var c2 = new Color(0.2, 0, 0);
    Check.ColorEqual(new Color(0.3, 0.5, 1), c1 + c2);
    Check.ColorNotEqual(new Color(0.3, 0.5, 1.001), c1 + c2);
});

// ---------------------------------------------------------------------
// features/chapter01-canvas.feature
// ---------------------------------------------------------------------
runner.Run("chapter01-canvas", "A new canvas is black", () =>
{
    var c = new Canvas(10, 20);
    Check.IntEqual(10, c.Width);
    Check.IntEqual(20, c.Height);
    foreach (var p in c.AllPixels()) Check.ColorEqual(new Color(0, 0, 0), p);
});

runner.Run("chapter01-canvas", "Writing a pixel", () =>
{
    var c = new Canvas(10, 20);
    var red = new Color(1, 0, 0);
    c.WritePixel(2, 3, red);
    Check.ColorEqual(red, c.PixelAt(2, 3));
});

runner.Run("chapter01-canvas", "x is the column and y is the row", () =>
{
    var c = new Canvas(10, 20);
    c.WritePixel(2, 3, new Color(1, 0, 0));
    Check.ColorEqual(new Color(0, 0, 0), c.PixelAt(3, 2));
    Check.ColorEqual(new Color(1, 0, 0), c.PixelAt(2, 3));
});

runner.Run("chapter01-canvas", "Writing outside the canvas is ignored", () =>
{
    var c = new Canvas(10, 20);
    c.WritePixel(-1, 5, new Color(1, 0, 0));
    c.WritePixel(10, 5, new Color(1, 0, 0));
    c.WritePixel(5, -1, new Color(1, 0, 0));
    c.WritePixel(5, 20, new Color(1, 0, 0));
    foreach (var p in c.AllPixels()) Check.ColorEqual(new Color(0, 0, 0), p);
});

runner.Run("chapter01-canvas", "A pixel can be written more than once", () =>
{
    var c = new Canvas(10, 20);
    c.WritePixel(2, 3, new Color(1, 0, 0));
    c.WritePixel(2, 3, new Color(0, 1, 0));
    Check.ColorEqual(new Color(0, 1, 0), c.PixelAt(2, 3));
});

runner.Run("chapter01-canvas", "Filling a canvas", () =>
{
    var c = new Canvas(10, 20);
    c.Fill(new Color(0.1, 0.2, 0.3));
    foreach (var p in c.AllPixels()) Check.ColorEqual(new Color(0.1, 0.2, 0.3), p);
});

// ---------------------------------------------------------------------
// features/chapter01-srgb.feature
// ---------------------------------------------------------------------
(double Light, double Value)[] encodeExamples =
{
    (0.0, 0.0), (0.0025, 0.0323), (0.01, 0.0999), (0.1, 0.3492),
    (0.216, 0.5021), (0.25, 0.5371), (0.5, 0.7354), (0.75, 0.8808), (1.0, 1.0)
};
foreach (var (light, value) in encodeExamples)
{
    runner.Run("chapter01-srgb", $"Encoding light into a file value <{light}>", () =>
    {
        Check.Equal(value, Srgb.Encode(light));
    });
}

(double Value, double Light)[] decodeExamples =
{
    (0.0, 0.0), (0.04, 0.0031), (0.05, 0.0039), (0.1, 0.0100),
    (0.5, 0.2140), (0.75, 0.5225), (1.0, 1.0)
};
foreach (var (value, light) in decodeExamples)
{
    runner.Run("chapter01-srgb", $"Decoding a file value into light <{value}>", () =>
    {
        Check.Equal(light, Srgb.Decode(value));
    });
}

runner.Run("chapter01-srgb", "Decode undoes encode", () =>
{
    double l = 0.2;
    Check.Equal(0.2, Srgb.Decode(Srgb.Encode(l)), 0.000000001);
});

runner.Run("chapter01-srgb", "Encode undoes decode", () =>
{
    double v = 0.7;
    Check.Equal(0.7, Srgb.Encode(Srgb.Decode(v)), 0.000000001);
});

runner.Run("chapter01-srgb", "The half gray that isn't 128", () =>
{
    Check.IntEqual(188, (int)Math.Round(Srgb.Encode(0.5) * 255, MidpointRounding.AwayFromZero));
});

runner.Run("chapter01-srgb", "What 128 actually is", () =>
{
    Check.Equal(0.2159, Srgb.Decode(128.0 / 255.0));
});

// ---------------------------------------------------------------------
// features/chapter01-ppm.feature
// ---------------------------------------------------------------------
runner.Run("chapter01-ppm", "The PPM header", () =>
{
    var c = new Canvas(5, 3);
    var ppm = Ppm.CanvasToPpm(c);
    var lines = Ppm.LineRange(ppm, 1, 3);
    Check.StringEqual("P3", lines[0]);
    Check.StringEqual("5 3", lines[1]);
    Check.StringEqual("255", lines[2]);
});

runner.Run("chapter01-ppm", "Pixel values are encoded, not scaled", () =>
{
    var c = new Canvas(3, 1);
    c.WritePixel(0, 0, new Color(1, 0, 0));
    c.WritePixel(1, 0, new Color(0, 0.5, 0));
    c.WritePixel(2, 0, new Color(0, 0, 0.216));
    var ppm = Ppm.CanvasToPpm(c);
    Check.StringEqual("255 0 0 0 188 0 0 0 128", Ppm.Line(ppm, 4));
});

runner.Run("chapter01-ppm", "Colors out of range are clamped, not wrapped", () =>
{
    var c = new Canvas(2, 1);
    c.WritePixel(0, 0, new Color(1.5, 0, -0.5));
    var ppm = Ppm.CanvasToPpm(c);
    Check.StringEqual("255 0 0 0 0 0", Ppm.Line(ppm, 4));
});

runner.Run("chapter01-ppm", "Every row starts a new line, and no line exceeds 70 characters", () =>
{
    var c = new Canvas(10, 2);
    c.Fill(new Color(1, 0.8, 0.6));
    var ppm = Ppm.CanvasToPpm(c);
    var expected = new[]
    {
        "255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231",
        "203 255 231 203 255 231 203 255 231 203 255 231 203",
        "255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231",
        "203 255 231 203 255 231 203 255 231 203 255 231 203"
    };
    var actual = Ppm.LineRange(ppm, 4, 7);
    for (int i = 0; i < expected.Length; i++) Check.StringEqual(expected[i], actual[i], $"line {i + 4}");

    foreach (var line in Ppm.Lines(ppm))
    {
        Check.True(line.Length <= 70, $"line exceeds 70 characters: \"{line}\" ({line.Length})");
    }
});

runner.Run("chapter01-ppm", "A line of exactly 70 characters is allowed", () =>
{
    var c = new Canvas(8, 1);
    c.Fill(new Color(1, 0.1, 0));
    c.WritePixel(7, 0, new Color(1, 1, 1));
    var ppm = Ppm.CanvasToPpm(c);
    var expected = new[]
    {
        "255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 255",
        "255"
    };
    var actual = Ppm.LineRange(ppm, 4, 5);
    Check.True(actual[0].Length == 70, $"expected exactly 70 characters, got {actual[0].Length}");
    for (int i = 0; i < expected.Length; i++) Check.StringEqual(expected[i], actual[i], $"line {i + 4}");
});

runner.Run("chapter01-ppm", "The file ends with a newline", () =>
{
    var c = new Canvas(5, 3);
    var ppm = Ppm.CanvasToPpm(c);
    Check.True(ppm.EndsWith('\n'), "ppm does not end with a newline character");
});

runner.Run("chapter01-ppm", "Reading a pixel back out of the text", () =>
{
    var c = new Canvas(3, 2);
    c.WritePixel(2, 1, new Color(0, 0.5, 1));
    var ppm = Ppm.CanvasToPpm(c);
    Check.TripleEqual((0, 188, 255), Ppm.PpmPixel(ppm, 2, 1));
    Check.TripleEqual((0, 0, 0), Ppm.PpmPixel(ppm, 1, 1));
});

runner.Run("chapter01-ppm", "Counting the distinct values in a file", () =>
{
    var c = new Canvas(3, 1);
    c.WritePixel(0, 0, new Color(1, 0, 0));
    c.WritePixel(1, 0, new Color(0, 0.5, 0));
    c.WritePixel(2, 0, new Color(0, 0, 0.216));
    var ppm = Ppm.CanvasToPpm(c);
    Check.IntEqual(4, Ppm.DistinctValues(ppm));
});

runner.Run("chapter01-ppm", "Comparing two files", () =>
{
    var c1 = new Canvas(2, 1);
    var c2 = new Canvas(2, 1);
    c2.WritePixel(0, 0, new Color(0.5, 0, 0));
    var ppm1 = Ppm.CanvasToPpm(c1);
    var ppm2 = Ppm.CanvasToPpm(c2);
    Check.IntEqual(0, Ppm.MaxChannelDifference(ppm1, ppm1));
    Check.IntEqual(188, Ppm.MaxChannelDifference(ppm1, ppm2));
});

runner.Run("chapter01-ppm", "Files of different sizes are as different as it gets", () =>
{
    var c1 = new Canvas(5, 3);
    var c2 = new Canvas(3, 5);
    var ppm1 = Ppm.CanvasToPpm(c1);
    var ppm2 = Ppm.CanvasToPpm(c2);
    Check.IntEqual(255, Ppm.MaxChannelDifference(ppm1, ppm2));
});

runner.Run("chapter01-ppm", "The same width with a different height is still a different size", () =>
{
    var c1 = new Canvas(5, 3);
    var c2 = new Canvas(5, 4);
    var ppm1 = Ppm.CanvasToPpm(c1);
    var ppm2 = Ppm.CanvasToPpm(c2);
    Check.IntEqual(255, Ppm.MaxChannelDifference(ppm1, ppm2));
});

// ---------------------------------------------------------------------
// features/chapter01-mix.feature
// ---------------------------------------------------------------------
runner.Run("chapter01-mix", "Halfway between black and white", () =>
{
    var a = new Color(0, 0, 0);
    var b = new Color(1, 1, 1);
    Check.ColorEqual(new Color(0.5, 0.5, 0.5), Mix.Blend(a, b, 0.5));
});

runner.Run("chapter01-mix", "The ends of a mix are its inputs", () =>
{
    var a = new Color(0.7, 0, 0);
    var b = new Color(0, 0.3, 0.02);
    Check.ColorEqual(a, Mix.Blend(a, b, 0));
    Check.ColorEqual(b, Mix.Blend(a, b, 1));
});

runner.Run("chapter01-mix", "Red to green, in light", () =>
{
    var a = new Color(0.7, 0, 0);
    var b = new Color(0, 0.3, 0.02);
    Check.ColorEqual(new Color(0.35, 0.15, 0.01), Mix.Blend(a, b, 0.5));
    Check.ColorEqual(new Color(0.525, 0.075, 0.005), Mix.Blend(a, b, 0.25));
});

runner.Run("chapter01-mix", "Halfway between black and white, the way browsers do it", () =>
{
    Mix.LinearBlending = false;
    var a = new Color(0, 0, 0);
    var b = new Color(1, 1, 1);
    Check.ColorEqual(new Color(0.2140, 0.2140, 0.2140), Mix.Blend(a, b, 0.5));
});

runner.Run("chapter01-mix", "Red to green, the way browsers do it", () =>
{
    Mix.LinearBlending = false;
    var a = new Color(0.7, 0, 0);
    var b = new Color(0, 0.3, 0.02);
    Check.ColorEqual(new Color(0.1527, 0.0693, 0.0067), Mix.Blend(a, b, 0.5));
});

runner.Run("chapter01-mix", "The light's way never clamps", () =>
{
    var a = new Color(1.5, 0.5, -0.2);
    var b = new Color(0, 0, 0);
    Check.ColorEqual(new Color(1.5, 0.5, -0.2), Mix.Blend(a, b, 0));
    Check.ColorEqual(new Color(0.75, 0.25, -0.1), Mix.Blend(a, b, 0.5));
});

runner.Run("chapter01-mix", "The switch can be passed instead of set", () =>
{
    var a = new Color(0, 0, 0);
    var b = new Color(1, 1, 1);
    Check.ColorEqual(new Color(0.5, 0.5, 0.5), Mix.Blend(a, b, 0.5, true));
    Check.ColorEqual(new Color(0.2140, 0.2140, 0.2140), Mix.Blend(a, b, 0.5, false));
    Check.True(Mix.LinearBlending, "expected linear blending to still be on");
});

runner.Run("chapter01-mix", "The browser's way clamps each end before encoding it", () =>
{
    Mix.LinearBlending = false;
    var a = new Color(1.5, 0.5, -0.2);
    var b = new Color(0, 0, 0);
    Check.ColorEqual(new Color(1, 0.5, 0), Mix.Blend(a, b, 0));
    Check.ColorEqual(new Color(0.2140, 0.1113, 0.0000), Mix.Blend(a, b, 0.5));
});

runner.Run("chapter01-mix", "The ends of a mix are its inputs either way, when they're in range", () =>
{
    Mix.LinearBlending = false;
    var a = new Color(0.7, 0, 0);
    var b = new Color(0, 0.3, 0.02);
    Check.ColorEqual(a, Mix.Blend(a, b, 0));
    Check.ColorEqual(b, Mix.Blend(a, b, 1));
});

// ---------------------------------------------------------------------
// features/chapter01-gray-match.feature
// ---------------------------------------------------------------------
runner.Run("chapter01-gray-match", "The gray match", () =>
{
    var c = Renders.GrayMatch();
    Check.IntEqual(300, c.Width);
    Check.IntEqual(100, c.Height);
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(0, 0));
    Check.ColorEqual(new Color(0, 0, 0), c.PixelAt(1, 0));
    Check.ColorEqual(new Color(0, 0, 0), c.PixelAt(0, 1));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(1, 1));
    Check.ColorEqual(new Color(0.2159, 0.2159, 0.2159), c.PixelAt(150, 50));
    Check.ColorEqual(new Color(0.5, 0.5, 0.5), c.PixelAt(250, 50));

    int whiteCount = c.AllPixels().Count(p => Check.NumbersEqual(p.Red, 1) && Check.NumbersEqual(p.Green, 1) && Check.NumbersEqual(p.Blue, 1));
    Check.IntEqual(5000, whiteCount);
});

runner.Run("chapter01-gray-match", "The gray match, as a file", () =>
{
    var c = Renders.GrayMatch();
    var ppm = Ppm.CanvasToPpm(c);
    Check.TripleEqual((255, 255, 255), Ppm.PpmPixel(ppm, 0, 0), 1);
    Check.TripleEqual((0, 0, 0), Ppm.PpmPixel(ppm, 1, 0), 1);
    Check.TripleEqual((128, 128, 128), Ppm.PpmPixel(ppm, 150, 50), 1);
    Check.TripleEqual((188, 188, 188), Ppm.PpmPixel(ppm, 250, 50), 1);
    var ppmRef = File.ReadAllText("reference/chapter-01/gray-match.ppm");
    Check.True(Ppm.MaxChannelDifference(ppm, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

runner.Run("chapter01-gray-match", "One pixel in four", () =>
{
    var c = Renders.QuarterMatch();
    Check.IntEqual(200, c.Width);
    Check.IntEqual(100, c.Height);
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(0, 0));
    Check.ColorEqual(new Color(0, 0, 0), c.PixelAt(1, 0));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(2, 2));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(3, 1));
    Check.ColorEqual(new Color(0.25, 0.25, 0.25), c.PixelAt(150, 50));

    int whiteCount = c.AllPixels().Count(p => Check.NumbersEqual(p.Red, 1) && Check.NumbersEqual(p.Green, 1) && Check.NumbersEqual(p.Blue, 1));
    Check.IntEqual(2500, whiteCount);

    var ppm = Ppm.CanvasToPpm(c);
    Check.TripleEqual((137, 137, 137), Ppm.PpmPixel(ppm, 150, 50), 1);
    var ppmRef = File.ReadAllText("reference/chapter-01/quarter-match.ppm");
    Check.True(Ppm.MaxChannelDifference(ppm, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

// ---------------------------------------------------------------------
// features/chapter01-limits.feature
// ---------------------------------------------------------------------
runner.Run("chapter01-limits", "A 256-step ramp", () =>
{
    var c = Renders.Ramp();
    Check.IntEqual(256, c.Width);
    Check.IntEqual(32, c.Height);
    Check.ColorEqual(new Color(0, 0, 0), c.PixelAt(0, 0));
    Check.ColorEqual(new Color(0.5020, 0.5020, 0.5020), c.PixelAt(128, 0));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(255, 31));
});

runner.Run("chapter01-limits", "Encoding stretches the dark end and squeezes the bright end", () =>
{
    var c = Renders.Ramp();
    var ppm = Ppm.CanvasToPpm(c);
    Check.StringEqual("0 0 0 13 13 13 22 22 22 28 28 28 34 34 34 38 38 38 42 42 42 46 46 46", Ppm.Line(ppm, 4));
    Check.TripleEqual((148, 148, 148), Ppm.PpmPixel(ppm, 75, 0), 1);
    Check.TripleEqual((148, 148, 148), Ppm.PpmPixel(ppm, 76, 0), 1);
    Check.TripleEqual((255, 255, 255), Ppm.PpmPixel(ppm, 254, 0), 1);
    Check.IntEqual(183, Ppm.DistinctValues(ppm));
    var ppmRef = File.ReadAllText("reference/chapter-01/ramp.ppm");
    Check.True(Ppm.MaxChannelDifference(ppm, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

runner.Run("chapter01-limits", "Clamping changes the color, not only the brightness", () =>
{
    var c = Renders.ClampPair();
    Check.IntEqual(200, c.Width);
    Check.IntEqual(100, c.Height);
    Check.ColorEqual(new Color(2, 0.5, 0.5), c.PixelAt(50, 50));
    Check.ColorEqual(new Color(1, 0.25, 0.25), c.PixelAt(150, 50));

    var ppm = Ppm.CanvasToPpm(c);
    Check.TripleEqual((255, 188, 188), Ppm.PpmPixel(ppm, 50, 50), 1);
    Check.TripleEqual((255, 137, 137), Ppm.PpmPixel(ppm, 150, 50), 1);
    var ppmRef = File.ReadAllText("reference/chapter-01/clamp-pair.ppm");
    Check.True(Ppm.MaxChannelDifference(ppm, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

// ---------------------------------------------------------------------
// features/chapter01-plate.feature
// ---------------------------------------------------------------------
runner.Run("chapter01-plate", "Plate 1", () =>
{
    var c = Renders.Plate01();
    Check.IntEqual(400, c.Width);
    Check.IntEqual(180, c.Height);

    var ppm = Ppm.CanvasToPpm(c);
    Check.TripleEqual((0, 0, 0), Ppm.PpmPixel(ppm, 0, 20), 1);
    Check.TripleEqual((255, 255, 255), Ppm.PpmPixel(ppm, 399, 20), 1);
    Check.TripleEqual((128, 128, 128), Ppm.PpmPixel(ppm, 200, 20), 1);
    Check.TripleEqual((188, 188, 188), Ppm.PpmPixel(ppm, 200, 65), 1);
    Check.TripleEqual((0, 0, 0), Ppm.PpmPixel(ppm, 200, 42), 1);
    Check.TripleEqual((218, 0, 0), Ppm.PpmPixel(ppm, 0, 110), 1);
    Check.TripleEqual((0, 149, 39), Ppm.PpmPixel(ppm, 399, 110), 1);
    Check.TripleEqual((109, 75, 19), Ppm.PpmPixel(ppm, 200, 110), 1);
    Check.TripleEqual((160, 108, 26), Ppm.PpmPixel(ppm, 200, 155), 1);
    Check.TripleEqual((0, 0, 0), Ppm.PpmPixel(ppm, 200, 87), 1);
    Check.TripleEqual((0, 0, 0), Ppm.PpmPixel(ppm, 200, 132), 1);
    Check.TripleEqual((0, 0, 0), Ppm.PpmPixel(ppm, 200, 177), 1);
    var ppmRef = File.ReadAllText("reference/chapter-01/plate-01.ppm");
    Check.True(Ppm.MaxChannelDifference(ppm, ppmRef) <= 1, "max_channel_difference exceeds 1");
    Check.True(Mix.LinearBlending, "expected linear blending to be left on");
});

// ---------------------------------------------------------------------
// features/chapter02-shapes.feature
// ---------------------------------------------------------------------
runner.Run("chapter02-shapes", "A point inside a circle", () =>
{
    var s = new Circle(8, 8, 5);
    Check.True(s.Inside(8, 8), "expected (8, 8) inside");
    Check.True(s.Inside(12, 8), "expected (12, 8) inside");
    Check.True(s.Inside(13, 8), "expected (13, 8) inside (boundary included)");
    Check.True(!s.Inside(13.01, 8), "expected (13.01, 8) outside");
    Check.True(!s.Inside(11.6, 11.6), "expected (11.6, 11.6) outside");
});

runner.Run("chapter02-shapes", "A point inside a rectangle", () =>
{
    var s = new Rectangle(1.25, 2.0, 4.75, 5.0);
    Check.True(s.Inside(3, 3), "expected (3, 3) inside");
    Check.True(s.Inside(1.25, 2.0), "expected (1.25, 2.0) inside (boundary included)");
    Check.True(s.Inside(4.75, 5.0), "expected (4.75, 5.0) inside (boundary included)");
    Check.True(!s.Inside(1.2, 3), "expected (1.2, 3) outside");
    Check.True(!s.Inside(3, 5.1), "expected (3, 5.1) outside");
});

runner.Run("chapter02-shapes", "A point inside a half-plane", () =>
{
    var s = new HalfPlane(2.5, 0, 1, 0);
    Check.True(s.Inside(2.5, 7), "expected (2.5, 7) inside");
    Check.True(s.Inside(3, -4), "expected (3, -4) inside");
    Check.True(!s.Inside(2.4, 0), "expected (2.4, 0) outside");
});

runner.Run("chapter02-shapes", "The normal picks the side", () =>
{
    var s = new HalfPlane(2.5, 0, -1, 0);
    Check.True(s.Inside(2.4, 0), "expected (2.4, 0) inside");
    Check.True(!s.Inside(3, 0), "expected (3, 0) outside");
});

// ---------------------------------------------------------------------
// features/chapter02-p6.feature
// ---------------------------------------------------------------------
runner.Run("chapter02-p6", "The header, then the bytes", () =>
{
    var c = new Canvas(2, 1);
    c.WritePixel(0, 0, new Color(1, 0, 0));
    c.WritePixel(1, 0, new Color(0, 0.5, 0));
    var p6 = Ppm.CanvasToP6(c);
    Check.True(Ppm.BeginsWith(p6, "P6\n2 1\n255\n"), "p6 does not begin with the expected header");
    Check.IntEqual(17, p6.Length);
    Check.IntEqual(255, Ppm.Byte(p6, 12));
    Check.IntEqual(0, Ppm.Byte(p6, 13));
    Check.IntEqual(188, Ppm.Byte(p6, 16));
});

runner.Run("chapter02-p6", "Rows go top to bottom", () =>
{
    var c = new Canvas(1, 2);
    c.WritePixel(0, 0, new Color(1, 0, 0));
    c.WritePixel(0, 1, new Color(0, 0, 1));
    var p6 = Ppm.CanvasToP6(c);
    Check.IntEqual(255, Ppm.Byte(p6, 12));
    Check.IntEqual(255, Ppm.Byte(p6, 17));
    Check.TripleEqual((255, 0, 0), Ppm.PpmPixel(p6, 0, 0));
    Check.TripleEqual((0, 0, 255), Ppm.PpmPixel(p6, 0, 1));
});

runner.Run("chapter02-p6", "The binary writer clamps too", () =>
{
    var c = new Canvas(2, 1);
    c.WritePixel(0, 0, new Color(1.5, 0, -0.5));
    var p6 = Ppm.CanvasToP6(c);
    Check.IntEqual(255, Ppm.Byte(p6, 12));
    Check.IntEqual(0, Ppm.Byte(p6, 13));
    Check.IntEqual(0, Ppm.Byte(p6, 14));
    Check.TripleEqual((255, 0, 0), Ppm.PpmPixel(p6, 0, 0));
});

runner.Run("chapter02-p6", "Pixel bytes that look like whitespace are still pixel bytes", () =>
{
    var c = new Canvas(2, 1);
    c.WritePixel(0, 0, new Color(0.00304, 0.01444, 0.00304));
    c.WritePixel(1, 0, new Color(1, 1, 1));
    var p6 = Ppm.CanvasToP6(c);
    Check.IntEqual(17, p6.Length);
    Check.IntEqual(10, Ppm.Byte(p6, 12));
    Check.IntEqual(32, Ppm.Byte(p6, 13));
    Check.TripleEqual((10, 32, 10), Ppm.PpmPixel(p6, 0, 0));
    Check.TripleEqual((255, 255, 255), Ppm.PpmPixel(p6, 1, 0));
    Check.IntEqual(0, Ppm.MaxChannelDifference(Ppm.CanvasToPpm(c), p6));
});

runner.Run("chapter02-p6", "The same pixel comes back out of either format", () =>
{
    var c = new Canvas(2, 1);
    c.WritePixel(1, 0, new Color(0, 0.5, 0));
    var p3 = Ppm.CanvasToPpm(c);
    var p6 = Ppm.CanvasToP6(c);
    Check.TripleEqual((0, 188, 0), Ppm.PpmPixel(p6, 1, 0));
    Check.TripleEqual((0, 188, 0), Ppm.PpmPixel(p3, 1, 0));
    Check.IntEqual(0, Ppm.MaxChannelDifference(p3, p6));
    Check.IntEqual(2, Ppm.DistinctValues(p6));
});

runner.Run("chapter02-p6", "Sizes still have to match", () =>
{
    var c1 = new Canvas(2, 1);
    var c2 = new Canvas(1, 2);
    var p6a = Ppm.CanvasToP6(c1);
    var p6b = Ppm.CanvasToP6(c2);
    Check.IntEqual(255, Ppm.MaxChannelDifference(p6a, p6b));
});

// ---------------------------------------------------------------------
// features/chapter02-magnify.feature
// ---------------------------------------------------------------------
runner.Run("chapter02-magnify", "Every pixel becomes a block", () =>
{
    var c = new Canvas(2, 1);
    c.WritePixel(0, 0, new Color(1, 0, 0));
    c.WritePixel(1, 0, new Color(0, 0.5, 0));
    var m = Magnifier.Magnify(c, 3);
    Check.IntEqual(6, m.Width);
    Check.IntEqual(3, m.Height);
    Check.ColorEqual(new Color(1, 0, 0), m.PixelAt(0, 0));
    Check.ColorEqual(new Color(1, 0, 0), m.PixelAt(2, 2));
    Check.ColorEqual(new Color(0, 0.5, 0), m.PixelAt(3, 0));
    Check.ColorEqual(new Color(0, 0.5, 0), m.PixelAt(5, 2));

    int redCount = m.AllPixels().Count(p => Check.NumbersEqual(p.Red, 1) && Check.NumbersEqual(p.Green, 0) && Check.NumbersEqual(p.Blue, 0));
    Check.IntEqual(9, redCount);
});

runner.Run("chapter02-magnify", "Magnifying by one changes nothing", () =>
{
    var c = new Canvas(2, 1);
    c.WritePixel(1, 0, new Color(0, 0.5, 0));
    var m = Magnifier.Magnify(c, 1);
    Check.IntEqual(0, Ppm.MaxChannelDifference(Ppm.CanvasToP6(c), Ppm.CanvasToP6(m)));
});

// ---------------------------------------------------------------------
// features/chapter02-centers.feature
// ---------------------------------------------------------------------
runner.Run("chapter02-centers", "A new coverage buffer is empty", () =>
{
    var cov = new CoverageBuffer(4, 3);
    Check.IntEqual(4, cov.Width);
    Check.IntEqual(3, cov.Height);
    Check.Equal(0, cov.CoverageAt(2, 1));
    Check.Equal(0, cov.Ink);
});

runner.Run("chapter02-centers", "Setting coverage", () =>
{
    var cov = new CoverageBuffer(4, 3);
    cov.SetCoverage(2, 1, 0.75);
    Check.Equal(0.75, cov.CoverageAt(2, 1));
    Check.Equal(0, cov.CoverageAt(1, 2));
    Check.Equal(0.75, cov.Ink);
});

runner.Run("chapter02-centers", "Setting coverage outside the buffer is ignored, and reading it gives 0", () =>
{
    var cov = new CoverageBuffer(4, 3);
    cov.SetCoverage(-1, 1, 1);
    cov.SetCoverage(4, 1, 1);
    cov.SetCoverage(1, 3, 1);
    Check.Equal(0, cov.Ink);
    Check.Equal(0, cov.CoverageAt(-1, 1));
    Check.Equal(0, cov.CoverageAt(4, 1));
    Check.Equal(0, cov.CoverageAt(1, 3));
});

runner.Run("chapter02-centers", "The center of pixel (x, y) is (x + 0.5, y + 0.5)", () =>
{
    var s = new HalfPlane(2.5, 0, 1, 0);
    Check.IntEqual(1, Rasterizer.CenterInside(s, 2, 4));
    Check.IntEqual(0, Rasterizer.CenterInside(s, 1, 4));

    var t = new HalfPlane(2.6, 0, 1, 0);
    Check.IntEqual(0, Rasterizer.CenterInside(t, 2, 4));
});

runner.Run("chapter02-centers", "The center question is not \"at least half\"", () =>
{
    var s = new HalfPlane(2.55, 0, 1, 0);
    Check.IntEqual(0, Rasterizer.CenterInside(s, 2, 4));
    Check.Equal(0.5, Rasterizer.Coverage(s, 2, 4));
});

runner.Run("chapter02-centers", "A buffer need not be square", () =>
{
    var s = new Rectangle(0, 0, 2, 1);
    var cov = Rasterizer.RasterizeCenters(s, 4, 2);
    Check.IntEqual(4, cov.Width);
    Check.IntEqual(2, cov.Height);
    Check.Equal(1, cov.CoverageAt(1, 0));
    Check.Equal(0, cov.CoverageAt(0, 1));
    Check.Equal(2, cov.Ink);
});

runner.Run("chapter02-centers", "A rectangle, by asking each center", () =>
{
    var s = new Rectangle(1.25, 2.0, 4.75, 5.0);
    var cov = Rasterizer.RasterizeCenters(s, 8, 8);
    Check.Equal(1, cov.CoverageAt(1, 4));
    Check.Equal(0, cov.CoverageAt(4, 1));
    Check.Equal(1, cov.CoverageAt(4, 4));
    Check.Equal(0, cov.CoverageAt(0, 3));
    Check.Equal(0, cov.CoverageAt(5, 3));
    Check.Equal(0, cov.CoverageAt(2, 1));
    Check.Equal(0, cov.CoverageAt(2, 5));
    Check.Equal(12, cov.Ink);
});

runner.Run("chapter02-centers", "A disc, by asking each center", () =>
{
    var s = new Circle(8, 8, 5);
    var cov = Rasterizer.RasterizeCenters(s, 16, 16);
    Check.IntEqual(16, cov.Width);
    Check.IntEqual(16, cov.Height);
    Check.Equal(1, cov.CoverageAt(8, 8));
    Check.Equal(1, cov.CoverageAt(3, 8));
    Check.Equal(1, cov.CoverageAt(12, 8));
    Check.Equal(0, cov.CoverageAt(2, 8));
    Check.Equal(0, cov.CoverageAt(13, 8));
    Check.Equal(1, cov.CoverageAt(4, 4));
    Check.Equal(0, cov.CoverageAt(3, 4));
    Check.Equal(80, cov.Ink);
});

// ---------------------------------------------------------------------
// features/chapter02-paint.feature
// ---------------------------------------------------------------------
runner.Run("chapter02-paint", "Half coverage is half the paint", () =>
{
    var c = new Canvas(1, 1);
    var cov = new CoverageBuffer(1, 1);
    cov.SetCoverage(0, 0, 0.5);
    Paint.PaintThrough(c, cov, new Color(1, 1, 1));
    Check.ColorEqual(new Color(0.5, 0.5, 0.5), c.PixelAt(0, 0));
});

runner.Run("chapter02-paint", "Paint over something that isn't black", () =>
{
    var c = new Canvas(1, 1);
    var cov = new CoverageBuffer(1, 1);
    c.Fill(new Color(0.2, 0.2, 0.2));
    cov.SetCoverage(0, 0, 0.25);
    Paint.PaintThrough(c, cov, new Color(1, 0, 0));
    Check.ColorEqual(new Color(0.4, 0.15, 0.15), c.PixelAt(0, 0));
});

runner.Run("chapter02-paint", "Zero leaves it alone and one replaces it", () =>
{
    var c = new Canvas(2, 1);
    var cov = new CoverageBuffer(2, 1);
    c.Fill(new Color(0.2, 0.2, 0.2));
    cov.SetCoverage(1, 0, 1);
    Paint.PaintThrough(c, cov, new Color(1, 0, 0));
    Check.ColorEqual(new Color(0.2, 0.2, 0.2), c.PixelAt(0, 0));
    Check.ColorEqual(new Color(1, 0, 0), c.PixelAt(1, 0));
});

runner.Run("chapter02-paint", "The arithmetic is on light, whatever the switch says", () =>
{
    Mix.LinearBlending = false;
    var c = new Canvas(1, 1);
    var cov = new CoverageBuffer(1, 1);
    cov.SetCoverage(0, 0, 0.5);
    Paint.PaintThrough(c, cov, new Color(1, 1, 1));
    var ppm = Ppm.CanvasToPpm(c);
    Check.ColorEqual(new Color(0.5, 0.5, 0.5), c.PixelAt(0, 0));
    Check.TripleEqual((188, 188, 188), Ppm.PpmPixel(ppm, 0, 0));
});

runner.Run("chapter02-paint", "The disc by centers", () =>
{
    var c = Renders.DiscCenters();
    var ppmRef = File.ReadAllBytes("reference/chapter-02/disc-centers.ppm");
    var p6 = Ppm.CanvasToP6(c);
    Check.IntEqual(320, c.Width);
    Check.IntEqual(320, c.Height);
    Check.TripleEqual((243, 196, 89), Ppm.PpmPixel(p6, 160, 160), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 124, 36), 1);
    Check.TripleEqual((243, 196, 89), Ppm.PpmPixel(p6, 132, 36), 1);
    Check.IntEqual(5, Ppm.DistinctValues(p6));
    Check.True(Ppm.MaxChannelDifference(p6, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

// ---------------------------------------------------------------------
// features/chapter02-coverage.feature
// ---------------------------------------------------------------------
runner.Run("chapter02-coverage", "The sixty-four sample points", () =>
{
    var s = new HalfPlane(2.5, 0, 1, 0);
    Check.Equal(0.5, Rasterizer.Coverage(s, 2, 4));
    Check.Equal(0, Rasterizer.Coverage(s, 1, 4));
    Check.Equal(1, Rasterizer.Coverage(s, 3, 4));
});

runner.Run("chapter02-coverage", "A rectangle is covered exactly, when its edges land on sample boundaries", () =>
{
    var s = new Rectangle(1.25, 2.0, 4.75, 5.0);
    var cov = Rasterizer.Rasterize(s, 8, 8);
    Check.Equal(0, cov.CoverageAt(0, 2));
    Check.Equal(0.75, cov.CoverageAt(1, 2));
    Check.Equal(1, cov.CoverageAt(2, 2));
    Check.Equal(1, cov.CoverageAt(3, 2));
    Check.Equal(0.75, cov.CoverageAt(4, 2));
    Check.Equal(0, cov.CoverageAt(5, 2));
    Check.Equal(0, cov.CoverageAt(2, 1));
    Check.Equal(0, cov.CoverageAt(2, 5));
    Check.Equal(10.5, cov.Ink);
});

runner.Run("chapter02-coverage", "Neither need the buffer be square here", () =>
{
    var s = new Rectangle(0, 0, 2, 1);
    var cov = Rasterizer.Rasterize(s, 4, 2);
    Check.IntEqual(4, cov.Width);
    Check.IntEqual(2, cov.Height);
    Check.Equal(1, cov.CoverageAt(1, 0));
    Check.Equal(0, cov.CoverageAt(2, 0));
    Check.Equal(0, cov.CoverageAt(0, 1));
    Check.Equal(2, cov.Ink);
});

runner.Run("chapter02-coverage", "A half-plane through a pixel center covers half of it", () =>
{
    var s = new HalfPlane(2.5, 4.5, 0.6, 0.8);
    Check.Equal(0.5, Rasterizer.Coverage(s, 2, 4));
});

runner.Run("chapter02-coverage", "Except when the grid conspires", () =>
{
    var s = new HalfPlane(2.5, 4.5, 1, 1);
    Check.Equal(0.5625, Rasterizer.Coverage(s, 2, 4));
});

runner.Run("chapter02-coverage", "A disc is only ever approximately covered", () =>
{
    var s = new Circle(8, 8, 5);
    var cov = Rasterizer.Rasterize(s, 16, 16);
    Check.Equal(1, cov.CoverageAt(8, 8));
    Check.Equal(0.96875, cov.CoverageAt(3, 8));
    Check.Equal(0.96875, cov.CoverageAt(12, 8));
    Check.Equal(0.5625, cov.CoverageAt(4, 4));
    Check.Equal(0, cov.CoverageAt(3, 4));
    Check.Equal(78.5, cov.Ink);
    Check.Equal(78.5398, cov.Ink, 0.1);
});

runner.Run("chapter02-coverage", "The disc by coverage", () =>
{
    var c = Renders.DiscCoverage();
    var ppmRef = File.ReadAllBytes("reference/chapter-02/disc-coverage.ppm");
    var p6 = Ppm.CanvasToP6(c);
    Check.IntEqual(320, c.Width);
    Check.IntEqual(320, c.Height);
    Check.TripleEqual((243, 196, 89), Ppm.PpmPixel(p6, 160, 160), 1);
    Check.TripleEqual((157, 127, 64), Ppm.PpmPixel(p6, 124, 36), 1);
    Check.True(Ppm.MaxChannelDifference(p6, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

// ---------------------------------------------------------------------
// features/chapter02-twice.feature
// ---------------------------------------------------------------------
runner.Run("chapter02-twice", "Half coverage, painted twice, is three quarters", () =>
{
    var c = new Canvas(1, 1);
    var cov = new CoverageBuffer(1, 1);
    cov.SetCoverage(0, 0, 0.5);
    Paint.PaintThrough(c, cov, new Color(1, 1, 1));
    Paint.PaintThrough(c, cov, new Color(1, 1, 1));
    Check.ColorEqual(new Color(0.75, 0.75, 0.75), c.PixelAt(0, 0));
});

runner.Run("chapter02-twice", "The disc, once and twice", () =>
{
    var c = Renders.PaintedTwice();
    var ppmRef = File.ReadAllBytes("reference/chapter-02/painted-twice.ppm");
    var p6 = Ppm.CanvasToP6(c);
    Check.IntEqual(480, c.Width);
    Check.IntEqual(240, c.Height);
    Check.TripleEqual((243, 196, 89), Ppm.PpmPixel(p6, 120, 120), 1);
    Check.TripleEqual((243, 196, 89), Ppm.PpmPixel(p6, 360, 120), 1);
    Check.TripleEqual((157, 127, 64), Ppm.PpmPixel(p6, 93, 27), 1);
    Check.TripleEqual((194, 156, 74), Ppm.PpmPixel(p6, 333, 27), 1);
    Check.True(Ppm.MaxChannelDifference(p6, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

// ---------------------------------------------------------------------
// features/chapter02-plate.feature
// ---------------------------------------------------------------------
runner.Run("chapter02-plate", "Plate 2", () =>
{
    var c = Renders.Plate02();
    var ppmRef = File.ReadAllBytes("reference/chapter-02/plate-02.ppm");
    var p6 = Ppm.CanvasToP6(c);
    Check.IntEqual(480, c.Width);
    Check.IntEqual(240, c.Height);
    Check.TripleEqual((243, 196, 89), Ppm.PpmPixel(p6, 120, 120), 1);
    Check.TripleEqual((243, 196, 89), Ppm.PpmPixel(p6, 360, 120), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 93, 27), 1);
    Check.TripleEqual((157, 127, 64), Ppm.PpmPixel(p6, 333, 27), 1);
    Check.True(Ppm.MaxChannelDifference(p6, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

// ---------------------------------------------------------------------
// features/chapter03-bresenham.feature
// ---------------------------------------------------------------------
runner.Run("chapter03-bresenham", "lit_pixels reads like a page", () =>
{
    var c = new Canvas(10, 10);
    c.WritePixel(5, 0, new Color(1, 1, 1));
    c.WritePixel(0, 2, new Color(1, 1, 1));
    c.WritePixel(2, 2, new Color(0.5, 0, 0));
    Check.PixelListEqual(new (int, int)[] { (5, 0), (0, 2), (2, 2) }, Lines.LitPixels(c));
});

runner.Run("chapter03-bresenham", "A diagonal", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineBresenham(c, 0, 0, 5, 5, new Color(1, 1, 1));
    Check.PixelListEqual(new (int, int)[] { (0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5) }, Lines.LitPixels(c));
});

runner.Run("chapter03-bresenham", "A horizontal line lights one row and nothing else", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineBresenham(c, 0, 3, 7, 3, new Color(1, 1, 1));
    Check.PixelListEqual(new (int, int)[] { (0, 3), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3) }, Lines.LitPixels(c));
});

runner.Run("chapter03-bresenham", "A shallow line steps along x", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineBresenham(c, 0, 0, 7, 3, new Color(1, 1, 1));
    Check.PixelListEqual(new (int, int)[] { (0, 0), (1, 0), (2, 1), (3, 1), (4, 2), (5, 2), (6, 3), (7, 3) }, Lines.LitPixels(c));
});

runner.Run("chapter03-bresenham", "A steep line steps along y", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineBresenham(c, 1, 1, 3, 7, new Color(1, 1, 1));
    Check.PixelListEqual(new (int, int)[] { (1, 1), (1, 2), (2, 3), (2, 4), (2, 5), (3, 6), (3, 7) }, Lines.LitPixels(c));
});

runner.Run("chapter03-bresenham", "The pixels don't depend on which end you start from", () =>
{
    var c1 = new Canvas(10, 10);
    var c2 = new Canvas(10, 10);
    Lines.LineBresenham(c1, 1, 1, 3, 7, new Color(1, 1, 1));
    Lines.LineBresenham(c2, 3, 7, 1, 1, new Color(1, 1, 1));
    Check.PixelListEqual(Lines.LitPixels(c1), Lines.LitPixels(c2));
    Check.IntEqual(0, Ppm.MaxChannelDifference(Ppm.CanvasToP6(c1), Ppm.CanvasToP6(c2)));
});

runner.Run("chapter03-bresenham", "A line going up and to the right", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineBresenham(c, 0, 6, 7, 3, new Color(1, 1, 1));
    Check.PixelListEqual(new (int, int)[] { (6, 3), (7, 3), (4, 4), (5, 4), (2, 5), (3, 5), (0, 6), (1, 6) }, Lines.LitPixels(c));
});

runner.Run("chapter03-bresenham", "At an exact half the line stays on its row one step longer", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineBresenham(c, 0, 0, 4, 2, new Color(1, 1, 1));
    Check.PixelListEqual(new (int, int)[] { (0, 0), (1, 0), (2, 1), (3, 1), (4, 2) }, Lines.LitPixels(c));
});

runner.Run("chapter03-bresenham", "A line of one point", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineBresenham(c, 3, 3, 3, 3, new Color(1, 1, 1));
    Check.PixelListEqual(new (int, int)[] { (3, 3) }, Lines.LitPixels(c));
});

runner.Run("chapter03-bresenham", "A line may run off the canvas", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineBresenham(c, 0, 0, 12, 6, new Color(1, 1, 1));
    Check.IntEqual(10, Lines.LitPixels(c).Count);
});

// ---------------------------------------------------------------------
// features/chapter03-wu.feature
// ---------------------------------------------------------------------
runner.Run("chapter03-wu", "A half step lights two pixels equally", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineWu(c, 0, 0, 4, 2, new Color(1, 1, 1));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(0, 0));
    Check.ColorEqual(new Color(0.5, 0.5, 0.5), c.PixelAt(1, 0));
    Check.ColorEqual(new Color(0.5, 0.5, 0.5), c.PixelAt(1, 1));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(2, 1));
    Check.ColorEqual(new Color(0, 0, 0), c.PixelAt(2, 2));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(4, 2));
    Check.Equal(5, Lines.TotalInk(c));
});

runner.Run("chapter03-wu", "A diagonal has uniform weights", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineWu(c, 0, 0, 5, 5, new Color(1, 1, 1));
    Check.PixelListEqual(new (int, int)[] { (0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5) }, Lines.LitPixels(c));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(3, 3));
    Check.Equal(6, Lines.TotalInk(c));
});

runner.Run("chapter03-wu", "A horizontal line has weight 1 on its row and 0 on the neighbors", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineWu(c, 0, 3, 7, 3, new Color(1, 1, 1));
    Check.PixelListEqual(new (int, int)[] { (0, 3), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3) }, Lines.LitPixels(c));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(3, 3));
    Check.ColorEqual(new Color(0, 0, 0), c.PixelAt(3, 2));
    Check.ColorEqual(new Color(0, 0, 0), c.PixelAt(3, 4));
    Check.Equal(8, Lines.TotalInk(c));
});

runner.Run("chapter03-wu", "A steep line weights across columns", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineWu(c, 1, 1, 3, 7, new Color(1, 1, 1));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(1, 1));
    Check.ColorEqual(new Color(0.6667, 0.6667, 0.6667), c.PixelAt(1, 2));
    Check.ColorEqual(new Color(0.3333, 0.3333, 0.3333), c.PixelAt(2, 2));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(2, 4));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(3, 7));
    Check.Equal(7, Lines.TotalInk(c));
});

runner.Run("chapter03-wu", "The weights don't depend on which end you start from", () =>
{
    var c1 = new Canvas(10, 10);
    var c2 = new Canvas(10, 10);
    Lines.LineWu(c1, 1, 1, 3, 7, new Color(1, 1, 1));
    Lines.LineWu(c2, 3, 7, 1, 1, new Color(1, 1, 1));
    Check.IntEqual(0, Ppm.MaxChannelDifference(Ppm.CanvasToP6(c1), Ppm.CanvasToP6(c2)));
});

runner.Run("chapter03-wu", "A line that starts above the canvas", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineWu(c, 0, -1, 8, 3, new Color(1, 1, 1));
    Check.ColorEqual(new Color(0.5, 0.5, 0.5), c.PixelAt(1, 0));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(2, 0));
    Check.Equal(7.5, Lines.TotalInk(c));
});

runner.Run("chapter03-wu", "A Wu line of one point", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineWu(c, 3, 3, 3, 3, new Color(1, 1, 1));
    Check.PixelListEqual(new (int, int)[] { (3, 3) }, Lines.LitPixels(c));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(3, 3));
});

runner.Run("chapter03-wu", "Sevenths", () =>
{
    var c = new Canvas(10, 10);
    Lines.LineWu(c, 0, 0, 7, 3, new Color(1, 1, 1));
    Check.ColorEqual(new Color(0.5714, 0.5714, 0.5714), c.PixelAt(1, 0));
    Check.ColorEqual(new Color(0.4286, 0.4286, 0.4286), c.PixelAt(1, 1));
    Check.ColorEqual(new Color(0.1429, 0.1429, 0.1429), c.PixelAt(2, 0));
    Check.ColorEqual(new Color(0.8571, 0.8571, 0.8571), c.PixelAt(2, 1));
    Check.Equal(8, Lines.TotalInk(c));
});

(int X1, int Y1, double Ink)[] wuAngleExamples =
{
    (12, 2, 11), (10, 8, 9), (8, 10, 9), (2, 12, 11)
};
foreach (var (x1, y1, ink) in wuAngleExamples)
{
    runner.Run("chapter03-wu", $"The ink depends on the angle <{x1}, {y1}>", () =>
    {
        var c = new Canvas(20, 20);
        Lines.LineWu(c, 2, 2, x1, y1, new Color(1, 1, 1));
        Check.Equal(ink, Lines.TotalInk(c));
    });
}

// ---------------------------------------------------------------------
// features/chapter03-quad.feature
// ---------------------------------------------------------------------
runner.Run("chapter03-quad", "Inside a thick line", () =>
{
    var s = new ThickLine(0, 0, 4, 0, 1);
    Check.True(s.Inside(2.5, 0.5), "expected (2.5, 0.5) inside");
    Check.True(s.Inside(2.5, 1.0), "expected (2.5, 1.0) inside (boundary included)");
    Check.True(!s.Inside(2.5, 1.01), "expected (2.5, 1.01) outside");
    Check.True(s.Inside(0.5, 0.5), "expected (0.5, 0.5) inside (boundary included)");
    Check.True(!s.Inside(0.4, 0.5), "expected (0.4, 0.5) outside");
    Check.True(s.Inside(4.5, 0.5), "expected (4.5, 0.5) inside (boundary included)");
    Check.True(!s.Inside(4.6, 0.5), "expected (4.6, 0.5) outside");
});

runner.Run("chapter03-quad", "A horizontal thick line covers its row, with half pixels at the ends", () =>
{
    var s = new ThickLine(0, 3, 7, 3, 1);
    var cov = Rasterizer.Rasterize(s, 10, 10);
    Check.Equal(0.5, cov.CoverageAt(0, 3));
    Check.Equal(1, cov.CoverageAt(1, 3));
    Check.Equal(1, cov.CoverageAt(6, 3));
    Check.Equal(0.5, cov.CoverageAt(7, 3));
    Check.Equal(0, cov.CoverageAt(8, 3));
    Check.Equal(0, cov.CoverageAt(3, 2));
    Check.Equal(0, cov.CoverageAt(3, 4));
    Check.Equal(7, cov.Ink);
});

runner.Run("chapter03-quad", "A line of no length is a square", () =>
{
    var s = new ThickLine(3, 3, 3, 3, 1);
    var cov = Rasterizer.Rasterize(s, 8, 8);
    Check.Equal(1, cov.CoverageAt(3, 3));
    Check.Equal(1, cov.Ink);
});

runner.Run("chapter03-quad", "A wider line", () =>
{
    var s = new ThickLine(0, 3, 7, 3, 3);
    var cov = Rasterizer.Rasterize(s, 10, 10);
    Check.Equal(1, cov.CoverageAt(3, 2));
    Check.Equal(1, cov.CoverageAt(3, 3));
    Check.Equal(1, cov.CoverageAt(3, 4));
    Check.Equal(0, cov.CoverageAt(3, 1));
    Check.Equal(0, cov.CoverageAt(3, 5));
    Check.Equal(0.5, cov.CoverageAt(0, 3));
    Check.Equal(21, cov.Ink);
});

runner.Run("chapter03-quad", "An off-axis line runs through pixel centers, not corners", () =>
{
    var s = new ThickLine(2, 2, 11, 5, 1);
    var cov = Rasterizer.Rasterize(s, 16, 10);
    Check.Equal(0.484375, cov.CoverageAt(2, 2));
    Check.Equal(0.484375, cov.CoverageAt(11, 5));
    Check.Equal(0.6875, cov.CoverageAt(6, 3));
    Check.Equal(0.359375, cov.CoverageAt(7, 3));
    Check.Equal(0, cov.CoverageAt(2, 1));
    Check.Equal(9.4063, cov.Ink);
});

(int X1, int Y1)[] thickLineAngleExamples =
{
    (12, 2), (10, 8), (8, 10), (2, 12)
};
foreach (var (x1, y1) in thickLineAngleExamples)
{
    runner.Run("chapter03-quad", $"The ink is the length, whatever the angle <{x1}, {y1}>", () =>
    {
        var s = new ThickLine(2, 2, x1, y1, 1);
        var cov = Rasterizer.Rasterize(s, 20, 20);
        Check.Equal(10, cov.Ink);
    });
}

runner.Run("chapter03-quad", "Except that the grid is blind along the diagonal", () =>
{
    var s = new ThickLine(2, 2, 9, 9, 1);
    var cov = Rasterizer.Rasterize(s, 20, 20);
    Check.Equal(9.71875, cov.Ink);
    Check.Equal(9.8995, cov.Ink, 0.25);
});

// ---------------------------------------------------------------------
// features/chapter03-plate.feature
// ---------------------------------------------------------------------
runner.Run("chapter03-plate", "The ray endpoints", () =>
{
    var expected = new (int, int)[]
    {
        (152, 80), (142, 116), (116, 142), (80, 152), (44, 142), (18, 116),
        (8, 80), (18, 44), (44, 18), (80, 8), (116, 18), (142, 44)
    };
    Check.PixelListEqual(expected, Renders.RayEnds());
});

runner.Run("chapter03-plate", "Bresenham's fan", () =>
{
    var c = Renders.FanBresenham();
    var ppmRef = File.ReadAllBytes("reference/chapter-03/fan-bresenham.ppm");
    var p6 = Ppm.CanvasToP6(c);
    Check.IntEqual(160, c.Width);
    Check.IntEqual(160, c.Height);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 80, 80), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 120, 80), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 10, 10), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 100, 91), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 100, 92), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 103, 120), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 102, 120), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 104, 120), 1);
    Check.True(Ppm.MaxChannelDifference(p6, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

runner.Run("chapter03-plate", "Wu's fan", () =>
{
    var c = Renders.FanWu();
    var ppmRef = File.ReadAllBytes("reference/chapter-03/fan-wu.ppm");
    var p6 = Ppm.CanvasToP6(c);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 80, 80), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 120, 80), 1);
    Check.TripleEqual((163, 163, 161), Ppm.PpmPixel(p6, 100, 91), 1);
    Check.TripleEqual((199, 199, 196), Ppm.PpmPixel(p6, 100, 92), 1);
    Check.TripleEqual((220, 220, 216), Ppm.PpmPixel(p6, 103, 120), 1);
    Check.TripleEqual((130, 130, 129), Ppm.PpmPixel(p6, 104, 120), 1);
    Check.True(Ppm.MaxChannelDifference(p6, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

runner.Run("chapter03-plate", "The fan as twelve thin rectangles", () =>
{
    var c = Renders.FanCoverage();
    var ppmRef = File.ReadAllBytes("reference/chapter-03/fan-coverage.ppm");
    var p6 = Ppm.CanvasToP6(c);
    Check.IntEqual(320, c.Width);
    Check.IntEqual(320, c.Height);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 160, 160), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 10, 10), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 240, 160), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 240, 158), 1);
    Check.TripleEqual((177, 177, 174), Ppm.PpmPixel(p6, 200, 183), 1);
    Check.TripleEqual((209, 209, 205), Ppm.PpmPixel(p6, 200, 185), 1);
    Check.True(Ppm.MaxChannelDifference(p6, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

runner.Run("chapter03-plate", "Plate 3", () =>
{
    var c = Renders.Plate03();
    var ppmRef = File.ReadAllBytes("reference/chapter-03/plate-03.ppm");
    var p6 = Ppm.CanvasToP6(c);
    Check.IntEqual(640, c.Width);
    Check.IntEqual(320, c.Height);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 160, 160), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 480, 160), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 10, 10), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 200, 183), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 200, 185), 1);
    Check.TripleEqual((163, 163, 161), Ppm.PpmPixel(p6, 520, 183), 1);
    Check.TripleEqual((199, 199, 196), Ppm.PpmPixel(p6, 520, 185), 1);
    Check.True(Ppm.MaxChannelDifference(p6, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

// ---------------------------------------------------------------------
// features/chapter04-tuples.feature
// ---------------------------------------------------------------------
runner.Run("chapter04-tuples", "A point has w = 1", () =>
{
    var p = Tuple2.Point(4, -4);
    Check.Equal(4, p.X);
    Check.Equal(-4, p.Y);
    Check.Equal(1, p.W);
});

runner.Run("chapter04-tuples", "A vector has w = 0", () =>
{
    var v = Tuple2.Vector(4, -4);
    Check.Equal(4, v.X);
    Check.Equal(-4, v.Y);
    Check.Equal(0, v.W);
});

runner.Run("chapter04-tuples", "The difference of two points is the vector between them", () =>
{
    var a = Tuple2.Point(3, 2);
    var b = Tuple2.Point(5, 6);
    Check.TupleEqual(Tuple2.Vector(2, 4), b - a);
    Check.TupleEqual(Tuple2.Vector(-2, -4), a - b);
});

runner.Run("chapter04-tuples", "A point plus a vector is a point", () =>
{
    var p = Tuple2.Point(3, -2);
    var v = Tuple2.Vector(-2, 3);
    Check.TupleEqual(Tuple2.Point(1, 1), p + v);
    Check.TupleEqual(Tuple2.Point(5, -5), p - v);
});

runner.Run("chapter04-tuples", "A vector plus a vector is a vector", () =>
{
    var a = Tuple2.Vector(3, -2);
    var b = Tuple2.Vector(-2, 3);
    Check.TupleEqual(Tuple2.Vector(1, 1), a + b);
    Check.TupleEqual(Tuple2.Vector(5, -5), a - b);
});

runner.Run("chapter04-tuples", "Negating, scaling and dividing a vector", () =>
{
    var v = Tuple2.Vector(1, -2);
    Check.TupleEqual(Tuple2.Vector(-1, 2), -v);
    Check.TupleEqual(Tuple2.Vector(3.5, -7), v * 3.5);
    Check.TupleEqual(Tuple2.Vector(0.5, -1), v * 0.5);
    Check.TupleEqual(Tuple2.Vector(0.5, -1), v / 2);
});

runner.Run("chapter04-tuples", "The magnitude of a vector", () =>
{
    Check.Equal(1, Tuple2.Vector(1, 0).Magnitude());
    Check.Equal(1, Tuple2.Vector(0, 1).Magnitude());
    Check.Equal(5, Tuple2.Vector(3, 4).Magnitude());
    Check.Equal(5, Tuple2.Vector(-3, -4).Magnitude());
    Check.Equal(2.2361, Tuple2.Vector(-1, -2).Magnitude());
});

runner.Run("chapter04-tuples", "Normalizing a vector", () =>
{
    Check.TupleEqual(Tuple2.Vector(1, 0), Tuple2.Vector(4, 0).Normalize());
    Check.TupleEqual(Tuple2.Vector(0.4472, 0.8944), Tuple2.Vector(1, 2).Normalize());
    Check.Equal(1, Tuple2.Vector(1, 2).Normalize().Magnitude());
});

runner.Run("chapter04-tuples", "The dot product of two vectors", () =>
{
    var a = Tuple2.Vector(1, 2);
    var b = Tuple2.Vector(2, 3);
    Check.Equal(8, Tuple2.Dot(a, b));
    Check.Equal(0, Tuple2.Dot(a, Tuple2.Vector(-2, 1)));
});

runner.Run("chapter04-tuples", "The cross product of two vectors is a number", () =>
{
    var a = Tuple2.Vector(1, 0);
    var b = Tuple2.Vector(0, 1);
    Check.Equal(1, Tuple2.Cross(a, b));
    Check.Equal(-1, Tuple2.Cross(b, a));
    Check.Equal(0, Tuple2.Cross(a, a));
    Check.Equal(-2, Tuple2.Cross(Tuple2.Vector(2, 3), Tuple2.Vector(4, 5)));
});

runner.Run("chapter04-tuples", "The sign of the cross product says which side of a line a point is on", () =>
{
    var a = Tuple2.Point(0, 0);
    var b = Tuple2.Point(10, 0);
    Check.Equal(30, Tuple2.Cross(b - a, Tuple2.Point(5, 3) - a));
    Check.Equal(-30, Tuple2.Cross(b - a, Tuple2.Point(5, -3) - a));
    Check.Equal(0, Tuple2.Cross(b - a, Tuple2.Point(20, 0) - a));
});

// ---------------------------------------------------------------------
// features/chapter04-matrices.feature
// ---------------------------------------------------------------------
runner.Run("chapter04-matrices", "Constructing and inspecting a matrix", () =>
{
    var M = new Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
    Check.Equal(1, M[0, 0]);
    Check.Equal(3, M[0, 2]);
    Check.Equal(4, M[1, 0]);
    Check.Equal(5, M[1, 1]);
    Check.Equal(7, M[2, 0]);
    Check.Equal(9, M[2, 2]);
    Check.MatrixEqual(new Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9), M);
});

runner.Run("chapter04-matrices", "Matrix equality with identical matrices", () =>
{
    var A = new Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
    var B = new Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
    Check.MatrixEqual(A, B);
});

runner.Run("chapter04-matrices", "Matrix equality with different matrices", () =>
{
    var A = new Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
    var B = new Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 8);
    Check.MatrixNotEqual(A, B);
});

runner.Run("chapter04-matrices", "Multiplying two matrices", () =>
{
    var A = new Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
    var B = new Matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
    Check.MatrixEqual(new Matrix3(4, 8, 8, 13, 17, 17, 22, 26, 26), A * B);
});

runner.Run("chapter04-matrices", "Matrix multiplication is not commutative", () =>
{
    var A = new Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
    var B = new Matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
    Check.MatrixNotEqual(A * B, B * A);
});

runner.Run("chapter04-matrices", "A matrix multiplied by a point", () =>
{
    var A = new Matrix3(1, 2, 3, 4, 5, 6, 0, 0, 1);
    var p = Tuple2.Point(1, 2);
    Check.TupleEqual(Tuple2.Point(8, 20), A * p);
});

runner.Run("chapter04-matrices", "A matrix multiplied by a vector ignores the last column", () =>
{
    var A = new Matrix3(1, 2, 3, 4, 5, 6, 0, 0, 1);
    var v = Tuple2.Vector(1, 2);
    Check.TupleEqual(Tuple2.Vector(5, 14), A * v);
});

runner.Run("chapter04-matrices", "Multiplying by the identity matrix changes nothing", () =>
{
    var A = new Matrix3(0, 1, 2, 1, 2, 4, 2, 4, 8);
    var p = Tuple2.Point(1, 2);
    Check.MatrixEqual(A, A * Matrix3.Identity());
    Check.MatrixEqual(A, Matrix3.Identity() * A);
    Check.TupleEqual(p, Matrix3.Identity() * p);
});

runner.Run("chapter04-matrices", "Transposing a matrix", () =>
{
    var A = new Matrix3(0, 9, 3, 9, 8, 0, 1, 8, 5);
    Check.MatrixEqual(new Matrix3(0, 9, 1, 9, 8, 8, 3, 0, 5), A.Transpose());
});

runner.Run("chapter04-matrices", "Transposing the identity matrix", () =>
{
    Check.MatrixEqual(Matrix3.Identity(), Matrix3.Identity().Transpose());
});

runner.Run("chapter04-matrices", "The determinant of a 3 by 3 matrix", () =>
{
    var A = new Matrix3(1, 2, 6, -5, 8, -4, 2, 6, 4);
    Check.Equal(-196, A.Determinant());
});

runner.Run("chapter04-matrices", "The determinant of a transform is the area factor", () =>
{
    Check.Equal(1, Matrix3.Identity().Determinant());
    Check.Equal(6, Matrix3.Scaling(2, 3).Determinant());
    Check.Equal(1, Matrix3.Rotation(0.7).Determinant());
    Check.Equal(1, Matrix3.Translation(4, 9).Determinant());
    Check.Equal(-1, Matrix3.Scaling(-1, 1).Determinant());
});

runner.Run("chapter04-matrices", "Testing an invertible matrix for invertibility", () =>
{
    var A = new Matrix3(3, 0, 2, 2, 0, -2, 0, 1, 1);
    Check.Equal(10, A.Determinant());
    Check.True(A.IsInvertible(), "expected A to be invertible");
});

runner.Run("chapter04-matrices", "Testing a non-invertible matrix for invertibility", () =>
{
    var A = new Matrix3(1, 2, 3, 2, 4, 6, 0, 0, 1);
    Check.Equal(0, A.Determinant());
    Check.True(!A.IsInvertible(), "expected A not to be invertible");
});

runner.Run("chapter04-matrices", "Calculating the inverse of a matrix", () =>
{
    var A = new Matrix3(3, 0, 2, 2, 0, -2, 0, 1, 1);
    var B = A.Inverse();
    Check.Equal(0.2, B[0, 0]);
    Check.Equal(1, B[1, 2]);
    Check.Equal(-0.3, B[2, 1]);
    Check.MatrixEqual(new Matrix3(0.2, 0.2, 0, -0.2, 0.3, 1, 0.2, -0.3, 0), B);
    Check.MatrixEqual(Matrix3.Identity(), A * B);
});

runner.Run("chapter04-matrices", "Multiplying a product by its inverse", () =>
{
    var A = new Matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
    var B = new Matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
    var C = A * B;
    Check.MatrixEqual(A, C * B.Inverse());
});

runner.Run("chapter04-matrices", "The inverse of a transform is a transform", () =>
{
    var A = Matrix3.Translation(5, -3) * Matrix3.Rotation(Math.PI / 6) * Matrix3.Scaling(2, 3);
    var B = A.Inverse();
    Check.Equal(0, B[2, 0]);
    Check.Equal(0, B[2, 1]);
    Check.Equal(1, B[2, 2]);
    Check.Equal(0.4330, B[0, 0]);
    Check.Equal(-1.4151, B[0, 2]);
    Check.Equal(1.6994, B[1, 2]);
    Check.MatrixEqual(Matrix3.Identity(), B * A);
});

// ---------------------------------------------------------------------
// features/chapter04-transforms.feature
// ---------------------------------------------------------------------
runner.Run("chapter04-transforms", "Multiplying by a translation matrix", () =>
{
    var t = Matrix3.Translation(5, -3);
    var p = Tuple2.Point(-3, 4);
    Check.TupleEqual(Tuple2.Point(2, 1), t * p);
});

runner.Run("chapter04-transforms", "The inverse of a translation moves the other way", () =>
{
    var t = Matrix3.Translation(5, -3);
    var p = Tuple2.Point(-3, 4);
    Check.TupleEqual(Tuple2.Point(-8, 7), t.Inverse() * p);
});

runner.Run("chapter04-transforms", "Translation does not affect vectors", () =>
{
    var t = Matrix3.Translation(5, -3);
    var v = Tuple2.Vector(-3, 4);
    Check.TupleEqual(v, t * v);
});

runner.Run("chapter04-transforms", "A scaling matrix applied to a point", () =>
{
    var s = Matrix3.Scaling(2, 3);
    var p = Tuple2.Point(-4, 6);
    Check.TupleEqual(Tuple2.Point(-8, 18), s * p);
});

runner.Run("chapter04-transforms", "A scaling matrix applied to a vector", () =>
{
    var s = Matrix3.Scaling(2, 3);
    var v = Tuple2.Vector(-4, 6);
    Check.TupleEqual(Tuple2.Vector(-8, 18), s * v);
});

runner.Run("chapter04-transforms", "The inverse of a scaling shrinks", () =>
{
    var s = Matrix3.Scaling(2, 3);
    var v = Tuple2.Vector(-4, 6);
    Check.TupleEqual(Tuple2.Vector(-2, 2), s.Inverse() * v);
});

runner.Run("chapter04-transforms", "Reflection is scaling by a negative value", () =>
{
    var s = Matrix3.Scaling(-1, 1);
    var p = Tuple2.Point(2, 3);
    Check.TupleEqual(Tuple2.Point(-2, 3), s * p);
});

runner.Run("chapter04-transforms", "A positive rotation turns x toward y", () =>
{
    var p = Tuple2.Point(1, 0);
    Check.TupleEqual(Tuple2.Point(0.7071, 0.7071), Matrix3.Rotation(Math.PI / 4) * p);
    Check.TupleEqual(Tuple2.Point(0, 1), Matrix3.Rotation(Math.PI / 2) * p);
    Check.TupleEqual(Tuple2.Point(-1, 0), Matrix3.Rotation(Math.PI) * p);
});

runner.Run("chapter04-transforms", "The inverse of a rotation turns the other way", () =>
{
    var p = Tuple2.Point(1, 0);
    Check.TupleEqual(Tuple2.Point(0.7071, -0.7071), Matrix3.Rotation(Math.PI / 4).Inverse() * p);
    Check.TupleEqual(Tuple2.Point(0.7071, -0.7071), Matrix3.Rotation(-Math.PI / 4) * p);
});

runner.Run("chapter04-transforms", "A rotation preserves length", () =>
{
    var v = Tuple2.Vector(3, 4);
    Check.Equal(5, (Matrix3.Rotation(1.2) * v).Magnitude());
    Check.Equal(5, (Matrix3.Rotation(-2.8) * v).Magnitude());
});

runner.Run("chapter04-transforms", "Shearing moves x in proportion to y", () =>
{
    var s = Matrix3.Shearing(1, 0);
    var p = Tuple2.Point(2, 3);
    Check.TupleEqual(Tuple2.Point(5, 3), s * p);
});

runner.Run("chapter04-transforms", "Shearing moves y in proportion to x", () =>
{
    var s = Matrix3.Shearing(0, 1);
    var p = Tuple2.Point(2, 3);
    Check.TupleEqual(Tuple2.Point(2, 5), s * p);
});

runner.Run("chapter04-transforms", "Individual transformations are applied in sequence", () =>
{
    var p = Tuple2.Point(1, 0);
    var A = Matrix3.Rotation(Math.PI / 2);
    var B = Matrix3.Scaling(5, 5);
    var C = Matrix3.Translation(10, 5);
    var p2 = A * p;
    var p3 = B * p2;
    var p4 = C * p3;
    Check.TupleEqual(Tuple2.Point(0, 1), p2);
    Check.TupleEqual(Tuple2.Point(0, 5), p3);
    Check.TupleEqual(Tuple2.Point(10, 10), p4);
});

runner.Run("chapter04-transforms", "Chained transformations must be applied in reverse order", () =>
{
    var p = Tuple2.Point(1, 0);
    var A = Matrix3.Rotation(Math.PI / 2);
    var B = Matrix3.Scaling(5, 5);
    var C = Matrix3.Translation(10, 5);
    var T = C * B * A;
    Check.TupleEqual(Tuple2.Point(10, 10), T * p);
});

runner.Run("chapter04-transforms", "The other order is a different transform", () =>
{
    var p = Tuple2.Point(1, 0);
    var A = Matrix3.Rotation(Math.PI / 2);
    var B = Matrix3.Scaling(5, 5);
    var C = Matrix3.Translation(10, 5);
    var T = A * B * C;
    Check.TupleEqual(Tuple2.Point(-25, 55), T * p);
});

runner.Run("chapter04-transforms", "Rotating about a point that isn't the origin", () =>
{
    var T = Matrix3.Translation(4, 4) * Matrix3.Rotation(Math.PI / 2) * Matrix3.Translation(-4, -4);
    Check.TupleEqual(Tuple2.Point(4, 6), T * Tuple2.Point(6, 4));
    Check.TupleEqual(Tuple2.Point(4, 4), T * Tuple2.Point(4, 4));
});

// ---------------------------------------------------------------------
// features/chapter04-scale.feature
// ---------------------------------------------------------------------
runner.Run("chapter04-scale", "The identity, a translation and a rotation don't stretch", () =>
{
    Check.Equal(1, Matrix3.Identity().ApproxScale());
    Check.Equal(1, Matrix3.Translation(7, 9).ApproxScale());
    Check.Equal(1, Matrix3.Rotation(1.1).ApproxScale());
});

runner.Run("chapter04-scale", "A uniform scale is reported exactly", () =>
{
    Check.Equal(2, Matrix3.Scaling(2, 2).ApproxScale());
    Check.Equal(0.5, Matrix3.Scaling(0.5, 0.5).ApproxScale());
    Check.Equal(3, (Matrix3.Scaling(3, 3) * Matrix3.Rotation(0.7)).ApproxScale());
    Check.Equal(3, (Matrix3.Translation(5, 5) * Matrix3.Scaling(3, 3)).ApproxScale());
});

runner.Run("chapter04-scale", "A reflection is not a negative scale", () =>
{
    Check.Equal(2, Matrix3.Scaling(-2, 2).ApproxScale());
});

runner.Run("chapter04-scale", "A non-uniform scale is reported as the geometric mean", () =>
{
    Check.Equal(2, Matrix3.Scaling(4, 1).ApproxScale());
    Check.Equal(2, (Matrix3.Scaling(4, 1) * Matrix3.Rotation(0.4)).ApproxScale());
    Check.Equal(3, Matrix3.Scaling(9, 1).ApproxScale());
});

runner.Run("chapter04-scale", "A shear that preserves area reports 1", () =>
{
    Check.Equal(1, Matrix3.Shearing(1, 0).ApproxScale());
    Check.Equal(0.8660, Matrix3.Shearing(0.5, 0.5).ApproxScale());
});

runner.Run("chapter04-scale", "A collapsed transform reports 0", () =>
{
    Check.Equal(0, Matrix3.Scaling(0, 1).ApproxScale());
    Check.Equal(0, new Matrix3(1, 2, 0, 2, 4, 0, 0, 0, 1).ApproxScale());
});

// ---------------------------------------------------------------------
// features/chapter04-shapes.feature
// ---------------------------------------------------------------------
runner.Run("chapter04-shapes", "A segment between pixel centers is a thick line", () =>
{
    var s = new Segment(Tuple2.Point(2.5, 2.5), Tuple2.Point(11.5, 5.5), 1);
    var cov = Rasterizer.Rasterize(s, 16, 10);
    Check.Equal(0.484375, cov.CoverageAt(2, 2));
    Check.Equal(0.6875, cov.CoverageAt(6, 3));
    Check.Equal(0.359375, cov.CoverageAt(7, 3));
    Check.Equal(9.4063, cov.Ink);
});

runner.Run("chapter04-shapes", "A segment need not start on a pixel center", () =>
{
    var s = new Segment(Tuple2.Point(1, 3.5), Tuple2.Point(7, 3.5), 1);
    var cov = Rasterizer.Rasterize(s, 10, 10);
    Check.Equal(0, cov.CoverageAt(0, 3));
    Check.Equal(1, cov.CoverageAt(1, 3));
    Check.Equal(1, cov.CoverageAt(6, 3));
    Check.Equal(0, cov.CoverageAt(7, 3));
    Check.Equal(0, cov.CoverageAt(3, 2));
    Check.Equal(6, cov.Ink);
});

runner.Run("chapter04-shapes", "A segment of no length is a square", () =>
{
    var s = new Segment(Tuple2.Point(3.5, 3.5), Tuple2.Point(3.5, 3.5), 1);
    var cov = Rasterizer.Rasterize(s, 8, 8);
    Check.Equal(1, cov.CoverageAt(3, 3));
    Check.Equal(1, cov.Ink);
});

runner.Run("chapter04-shapes", "A union is inside when any of its parts is", () =>
{
    var s = new Union(new IShape[] { new Circle(2, 2, 1), new Rectangle(5, 0, 7, 4) });
    Check.True(s.Inside(2, 2), "expected (2, 2) inside");
    Check.True(s.Inside(6, 1), "expected (6, 1) inside");
    Check.True(!s.Inside(4, 2), "expected (4, 2) outside");
    Check.Equal(11.25, Rasterizer.Rasterize(s, 8, 8).Ink);
});

runner.Run("chapter04-shapes", "A circle seen through a scale is an ellipse", () =>
{
    var s = new Transformed(new Circle(0, 0, 4), Matrix3.Scaling(2, 1));
    Check.True(s.Inside(7.9, 0), "expected (7.9, 0) inside");
    Check.True(!s.Inside(8.1, 0), "expected (8.1, 0) outside");
    Check.True(s.Inside(0, 3.9), "expected (0, 3.9) inside");
    Check.True(!s.Inside(0, 4.1), "expected (0, 4.1) outside");
    Check.True(s.Inside(5.6, 1.4), "expected (5.6, 1.4) inside");
    Check.True(!s.Inside(5.6, 2.9), "expected (5.6, 2.9) outside");
});

runner.Run("chapter04-shapes", "The transform is applied in the order the matrix says", () =>
{
    var s = new Transformed(new Circle(0, 0, 4), Matrix3.Translation(10, 10) * Matrix3.Scaling(2, 1));
    Check.True(s.Inside(10, 10), "expected (10, 10) inside");
    Check.True(s.Inside(17.9, 10), "expected (17.9, 10) inside");
    Check.True(!s.Inside(18.1, 10), "expected (18.1, 10) outside");
    Check.True(s.Inside(10, 13.9), "expected (10, 13.9) inside");
    Check.True(!s.Inside(10, 14.1), "expected (10, 14.1) outside");
});

runner.Run("chapter04-shapes", "A shape seen through a collapsed transform is empty", () =>
{
    var s = new Transformed(new Circle(0, 0, 4), Matrix3.Scaling(0, 1));
    Check.True(!s.Inside(0, 0), "expected (0, 0) outside");
    Check.Equal(0, Rasterizer.Rasterize(s, 10, 10).Ink);
});

runner.Run("chapter04-shapes", "A pen in shape space scales with the shape", () =>
{
    var s = new Transformed(new ThickLine(5, 0, 5, 9, 1), Matrix3.Scaling(3, 1));
    var cov = Rasterizer.Rasterize(s, 24, 10);
    Check.Equal(0, cov.CoverageAt(14, 4));
    Check.Equal(1, cov.CoverageAt(15, 4));
    Check.Equal(1, cov.CoverageAt(16, 4));
    Check.Equal(1, cov.CoverageAt(17, 4));
    Check.Equal(0, cov.CoverageAt(18, 4));
    Check.Equal(27, cov.Ink);
});

runner.Run("chapter04-shapes", "A pen in device space does not", () =>
{
    var m = Matrix3.Scaling(3, 1);
    var s = new Segment(m * Tuple2.Point(5.5, 0.5), m * Tuple2.Point(5.5, 9.5), 1);
    var cov = Rasterizer.Rasterize(s, 24, 10);
    Check.Equal(0, cov.CoverageAt(15, 4));
    Check.Equal(1, cov.CoverageAt(16, 4));
    Check.Equal(0, cov.CoverageAt(17, 4));
    Check.Equal(9, cov.Ink);
});

runner.Run("chapter04-shapes", "Dividing the width by approx_scale makes the two pens agree", () =>
{
    var m = Matrix3.Scaling(2, 2);
    var s = new Transformed(new Segment(Tuple2.Point(5.5, 0.5), Tuple2.Point(5.5, 9.5), 1 / m.ApproxScale()), m);
    var cov = Rasterizer.Rasterize(s, 24, 20);
    Check.Equal(0, cov.CoverageAt(9, 5));
    Check.Equal(0.5, cov.CoverageAt(10, 5));
    Check.Equal(0.5, cov.CoverageAt(11, 5));
    Check.Equal(0, cov.CoverageAt(12, 5));
    Check.Equal(18, cov.Ink);
});

runner.Run("chapter04-shapes", "Under a non-uniform scale the compromise shows", () =>
{
    var m = Matrix3.Scaling(4, 1);
    var w = 1 / m.ApproxScale();
    var v = new Transformed(new Segment(Tuple2.Point(2.5, 0.5), Tuple2.Point(2.5, 9.5), w), m);
    var h = new Transformed(new Segment(Tuple2.Point(0.5, 5.5), Tuple2.Point(4.5, 5.5), w), m);
    var cv = Rasterizer.Rasterize(v, 24, 12);
    var ch = Rasterizer.Rasterize(h, 24, 12);
    Check.Equal(0, cv.CoverageAt(8, 5));
    Check.Equal(1, cv.CoverageAt(9, 5));
    Check.Equal(1, cv.CoverageAt(10, 5));
    Check.Equal(0, cv.CoverageAt(11, 5));
    Check.Equal(18, cv.Ink);
    Check.Equal(0, ch.CoverageAt(10, 4));
    Check.Equal(0.5, ch.CoverageAt(10, 5));
    Check.Equal(0, ch.CoverageAt(10, 6));
    Check.Equal(8, ch.Ink);
});

runner.Run("chapter04-shapes", "An outline is one shape, so its corners are painted once", () =>
{
    var pts = new[] { Tuple2.Point(1.5, 1.5), Tuple2.Point(6.5, 1.5), Tuple2.Point(6.5, 6.5), Tuple2.Point(1.5, 6.5) };
    var c = new Canvas(8, 8);
    Paint.PaintThrough(c, Rasterizer.Rasterize(Outline.Build(pts, Matrix3.Identity(), 1), 8, 8), new Color(1, 1, 1));
    Check.IntEqual(20, Lines.LitPixels(c).Count);
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(3, 1));
    Check.ColorEqual(new Color(1, 1, 1), c.PixelAt(1, 3));
    Check.ColorEqual(new Color(0.75, 0.75, 0.75), c.PixelAt(1, 1));
    Check.ColorEqual(new Color(0, 0, 0), c.PixelAt(3, 3));
    Check.ColorEqual(new Color(0, 0, 0), c.PixelAt(0, 1));
    Check.Equal(19, Lines.TotalInk(c));
});

runner.Run("chapter04-shapes", "An outline takes its points through the matrix first", () =>
{
    var pts = new[] { Tuple2.Point(1.5, 1.5), Tuple2.Point(6.5, 1.5), Tuple2.Point(6.5, 6.5), Tuple2.Point(1.5, 6.5) };
    var c = new Canvas(16, 16);
    Paint.PaintThrough(c, Rasterizer.Rasterize(Outline.Build(pts, Matrix3.Scaling(2, 2), 1), 16, 16), new Color(1, 1, 1));
    Check.IntEqual(76, Lines.LitPixels(c).Count);
    Check.ColorEqual(new Color(0.75, 0.75, 0.75), c.PixelAt(3, 3));
    Check.ColorEqual(new Color(0.5, 0.5, 0.5), c.PixelAt(8, 2));
    Check.ColorEqual(new Color(0.5, 0.5, 0.5), c.PixelAt(8, 3));
    Check.ColorEqual(new Color(0, 0, 0), c.PixelAt(8, 4));
});

// ---------------------------------------------------------------------
// features/chapter04-plate.feature
// ---------------------------------------------------------------------
runner.Run("chapter04-plate", "The fan as points", () =>
{
    var pts = Renders.FanPoints();
    Check.IntEqual(13, pts.Count);
    Check.TupleEqual(Tuple2.Point(0, 0), pts[0]);
    Check.TupleEqual(Tuple2.Point(36, 0), pts[1]);
    Check.TupleEqual(Tuple2.Point(0, 36), pts[4]);
    Check.TupleEqual(Tuple2.Point(-36, 0), pts[7]);
    Check.TupleEqual(Tuple2.Point(31.1769, 18), pts[2]);
});

runner.Run("chapter04-plate", "Rotate, then translate: the fan turns about its own center", () =>
{
    var m = Matrix3.Translation(104.5, 76.5) * Matrix3.Rotation(Math.PI / 6);
    var pts = Matrix3.TransformPoints(Renders.FanPoints(), m);
    Check.TupleEqual(Tuple2.Point(104.5, 76.5), pts[0]);
    Check.TupleEqual(Tuple2.Point(135.6769, 94.5), pts[1]);
    Check.TupleEqual(Tuple2.Point(86.5, 107.6769), pts[4]);
});

runner.Run("chapter04-plate", "Translate, then rotate: the fan swings about the canvas corner", () =>
{
    var m = Matrix3.Rotation(Math.PI / 6) * Matrix3.Translation(104.5, 76.5);
    var pts = Matrix3.TransformPoints(Renders.FanPoints(), m);
    Check.TupleEqual(Tuple2.Point(52.2497, 118.5009), pts[0]);
    Check.TupleEqual(Tuple2.Point(83.4266, 136.5009), pts[1]);
});

runner.Run("chapter04-plate", "The letter F", () =>
{
    var f = Renders.LetterF();
    Check.IntEqual(10, f.Count);
    Check.TupleEqual(Tuple2.Point(-20, -30), f[0]);
    Check.TupleEqual(Tuple2.Point(20, -30), f[1]);
    Check.TupleEqual(Tuple2.Point(12, -5), f[5]);
    Check.TupleEqual(Tuple2.Point(-20, 30), f[9]);
});

runner.Run("chapter04-plate", "The F at home", () =>
{
    var f = Matrix3.TransformPoints(Renders.LetterF(), Matrix3.Translation(44.5, 44.5));
    Check.TupleEqual(Tuple2.Point(24.5, 14.5), f[0]);
    Check.TupleEqual(Tuple2.Point(64.5, 14.5), f[1]);
    Check.TupleEqual(Tuple2.Point(24.5, 74.5), f[9]);
});

runner.Run("chapter04-plate", "The F, rotated then translated", () =>
{
    var m = Matrix3.Translation(104.5, 76.5) * Matrix3.Rotation(Math.PI / 6);
    var f = Matrix3.TransformPoints(Renders.LetterF(), m);
    Check.TupleEqual(Tuple2.Point(102.1795, 40.5192), f[0]);
    Check.TupleEqual(Tuple2.Point(136.8205, 60.5192), f[1]);
    Check.TupleEqual(Tuple2.Point(117.3923, 78.1699), f[5]);
    Check.TupleEqual(Tuple2.Point(72.1795, 92.4808), f[9]);
});

runner.Run("chapter04-plate", "The F, translated then rotated", () =>
{
    var m = Matrix3.Rotation(Math.PI / 6) * Matrix3.Translation(104.5, 76.5);
    var f = Matrix3.TransformPoints(Renders.LetterF(), m);
    Check.TupleEqual(Tuple2.Point(49.9291, 82.5202), f[0]);
    Check.TupleEqual(Tuple2.Point(84.5702, 102.5202), f[1]);
    Check.TupleEqual(Tuple2.Point(65.142, 120.1708), f[5]);
    Check.TupleEqual(Tuple2.Point(19.9291, 134.4817), f[9]);
});

runner.Run("chapter04-plate", "The fan, both orders", () =>
{
    var c = Renders.FanBothOrders();
    var ppmRef = File.ReadAllBytes("reference/chapter-04/fan-both-orders.ppm");
    var p6 = Ppm.CanvasToP6(c);
    Check.IntEqual(320, c.Width);
    Check.IntEqual(160, c.Height);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 104, 76), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 124, 76), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 104, 56), 1);
    Check.TripleEqual((236, 236, 231), Ppm.PpmPixel(p6, 125, 88), 1);
    Check.TripleEqual((236, 236, 231), Ppm.PpmPixel(p6, 116, 97), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 141, 76), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 10, 10), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 212, 118), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 232, 118), 1);
    Check.TripleEqual((223, 223, 219), Ppm.PpmPixel(p6, 233, 130), 1);
    Check.TripleEqual((236, 236, 231), Ppm.PpmPixel(p6, 224, 139), 1);
    Check.TripleEqual((211, 211, 207), Ppm.PpmPixel(p6, 200, 139), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 310, 10), 1);
    Check.True(Ppm.MaxChannelDifference(p6, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

runner.Run("chapter04-plate", "Plate 4", () =>
{
    var c = Renders.Plate04();
    var ppmRef = File.ReadAllBytes("reference/chapter-04/plate-04.ppm");
    var p6 = Ppm.CanvasToP6(c);
    Check.IntEqual(640, c.Width);
    Check.IntEqual(320, c.Height);
    Check.TripleEqual((99, 99, 102), Ppm.PpmPixel(p6, 48, 28), 1);
    Check.TripleEqual((111, 111, 115), Ppm.PpmPixel(p6, 80, 28), 1);
    Check.TripleEqual((111, 111, 115), Ppm.PpmPixel(p6, 48, 100), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 10, 10), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 200, 150), 1);
    Check.TripleEqual((237, 237, 233), Ppm.PpmPixel(p6, 268, 129), 1);
    Check.TripleEqual((237, 237, 233), Ppm.PpmPixel(p6, 215, 145), 1);
    Check.TripleEqual((237, 237, 233), Ppm.PpmPixel(p6, 239, 101), 1);
    Check.TripleEqual((217, 217, 213), Ppm.PpmPixel(p6, 174, 173), 1);
    Check.TripleEqual((99, 99, 102), Ppm.PpmPixel(p6, 368, 28), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 500, 60), 1);
    Check.TripleEqual((236, 236, 231), Ppm.PpmPixel(p6, 453, 207), 1);
    Check.TripleEqual((234, 234, 229), Ppm.PpmPixel(p6, 431, 229), 1);
    Check.TripleEqual((234, 234, 229), Ppm.PpmPixel(p6, 445, 249), 1);
    Check.TripleEqual((177, 177, 174), Ppm.PpmPixel(p6, 368, 273), 1);
    Check.True(Ppm.MaxChannelDifference(p6, ppmRef) <= 1, "max_channel_difference exceeds 1");
});

runner.PrintSummary();

// ---------------------------------------------------------------------
// Write the renders required by the assignment.
// ---------------------------------------------------------------------
Directory.CreateDirectory("out");
File.WriteAllText("out/gray-match.ppm", Ppm.CanvasToPpm(Renders.GrayMatch()));
File.WriteAllText("out/quarter-match.ppm", Ppm.CanvasToPpm(Renders.QuarterMatch()));
File.WriteAllText("out/ramp.ppm", Ppm.CanvasToPpm(Renders.Ramp()));
File.WriteAllText("out/clamp-pair.ppm", Ppm.CanvasToPpm(Renders.ClampPair()));
File.WriteAllText("out/plate-01.ppm", Ppm.CanvasToPpm(Renders.Plate01()));
File.WriteAllBytes("out/disc-centers.ppm", Ppm.CanvasToP6(Renders.DiscCenters()));
File.WriteAllBytes("out/disc-coverage.ppm", Ppm.CanvasToP6(Renders.DiscCoverage()));
File.WriteAllBytes("out/painted-twice.ppm", Ppm.CanvasToP6(Renders.PaintedTwice()));
File.WriteAllBytes("out/plate-02.ppm", Ppm.CanvasToP6(Renders.Plate02()));
File.WriteAllBytes("out/fan-bresenham.ppm", Ppm.CanvasToP6(Renders.FanBresenham()));
File.WriteAllBytes("out/fan-wu.ppm", Ppm.CanvasToP6(Renders.FanWu()));
File.WriteAllBytes("out/fan-coverage.ppm", Ppm.CanvasToP6(Renders.FanCoverage()));
File.WriteAllBytes("out/plate-03.ppm", Ppm.CanvasToP6(Renders.Plate03()));
File.WriteAllBytes("out/fan-both-orders.ppm", Ppm.CanvasToP6(Renders.FanBothOrders()));
File.WriteAllBytes("out/plate-04.ppm", Ppm.CanvasToP6(Renders.Plate04()));
Console.WriteLine();
Console.WriteLine("Wrote out/gray-match.ppm, out/quarter-match.ppm, out/ramp.ppm, out/clamp-pair.ppm, out/plate-01.ppm,");
Console.WriteLine("      out/disc-centers.ppm, out/disc-coverage.ppm, out/painted-twice.ppm, out/plate-02.ppm,");
Console.WriteLine("      out/fan-bresenham.ppm, out/fan-wu.ppm, out/fan-coverage.ppm, out/plate-03.ppm,");
Console.WriteLine("      out/fan-both-orders.ppm, out/plate-04.ppm");

return runner.FailedCount == 0 ? 0 : 1;
