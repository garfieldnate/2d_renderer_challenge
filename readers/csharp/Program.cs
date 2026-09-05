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

// ---------------------------------------------------------------------
// features/chapter01-mix.feature
// ---------------------------------------------------------------------
runner.Run("chapter01-mix", "Linear blending is on by default", () =>
{
    Check.True(Mix.LinearBlending, "expected linear blending to be on by default");
});

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

runner.Run("chapter01-mix", "The browser's way can't see past 1", () =>
{
    Mix.LinearBlending = false;
    var a = new Color(1.5, 0.5, -0.2);
    var b = new Color(0, 0, 0);
    Check.ColorEqual(new Color(1, 0.5, 0), Mix.Blend(a, b, 0));
});

runner.Run("chapter01-mix", "The ends of a mix are its inputs either way", () =>
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
runner.Run("chapter01-plate", "The plate", () =>
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

runner.PrintSummary();

// ---------------------------------------------------------------------
// Write the five renders required by the assignment.
// ---------------------------------------------------------------------
Directory.CreateDirectory("out");
File.WriteAllText("out/gray-match.ppm", Ppm.CanvasToPpm(Renders.GrayMatch()));
File.WriteAllText("out/quarter-match.ppm", Ppm.CanvasToPpm(Renders.QuarterMatch()));
File.WriteAllText("out/ramp.ppm", Ppm.CanvasToPpm(Renders.Ramp()));
File.WriteAllText("out/clamp-pair.ppm", Ppm.CanvasToPpm(Renders.ClampPair()));
File.WriteAllText("out/plate-01.ppm", Ppm.CanvasToPpm(Renders.Plate01()));
Console.WriteLine();
Console.WriteLine("Wrote out/gray-match.ppm, out/quarter-match.ppm, out/ramp.ppm, out/clamp-pair.ppm, out/plate-01.ppm");

return runner.FailedCount == 0 ? 0 : 1;
