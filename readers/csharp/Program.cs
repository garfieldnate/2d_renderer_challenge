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

runner.Run("chapter02-centers", "Setting coverage outside the buffer is ignored", () =>
{
    var cov = new CoverageBuffer(4, 3);
    cov.SetCoverage(-1, 1, 1);
    cov.SetCoverage(4, 1, 1);
    cov.SetCoverage(1, 3, 1);
    Check.Equal(0, cov.Ink);
});

runner.Run("chapter02-centers", "The center of pixel (x, y) is (x + 0.5, y + 0.5)", () =>
{
    var s = new HalfPlane(2.5, 0, 1, 0);
    Check.IntEqual(1, Rasterizer.CenterInside(s, 2, 4));
    Check.IntEqual(0, Rasterizer.CenterInside(s, 1, 4));

    var t = new HalfPlane(2.6, 0, 1, 0);
    Check.IntEqual(0, Rasterizer.CenterInside(t, 2, 4));
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

runner.Run("chapter02-paint", "The arithmetic is on light", () =>
{
    var c = new Canvas(1, 1);
    var cov = new CoverageBuffer(1, 1);
    cov.SetCoverage(0, 0, 0.5);
    Paint.PaintThrough(c, cov, new Color(1, 1, 1));
    var ppm = Ppm.CanvasToPpm(c);
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
runner.Run("chapter02-plate", "The plate", () =>
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
    Check.Equal(9.7188, cov.Ink);
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
    var p6 = Ppm.CanvasToP6(c);
    Check.IntEqual(160, c.Width);
    Check.IntEqual(160, c.Height);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 80, 80), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 120, 80), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 10, 10), 1);
    Check.TripleEqual((39, 39, 44), Ppm.PpmPixel(p6, 100, 91), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 100, 92), 1);
});

runner.Run("chapter03-plate", "Wu's fan", () =>
{
    var c = Renders.FanWu();
    var p6 = Ppm.CanvasToP6(c);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 80, 80), 1);
    Check.TripleEqual((246, 246, 241), Ppm.PpmPixel(p6, 120, 80), 1);
    Check.TripleEqual((163, 163, 161), Ppm.PpmPixel(p6, 100, 91), 1);
    Check.TripleEqual((199, 199, 196), Ppm.PpmPixel(p6, 100, 92), 1);
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
File.WriteAllBytes("out/fan-coverage.ppm", Ppm.CanvasToP6(Renders.FanCoverage()));
File.WriteAllBytes("out/plate-03.ppm", Ppm.CanvasToP6(Renders.Plate03()));
Console.WriteLine();
Console.WriteLine("Wrote out/gray-match.ppm, out/quarter-match.ppm, out/ramp.ppm, out/clamp-pair.ppm, out/plate-01.ppm,");
Console.WriteLine("      out/disc-centers.ppm, out/disc-coverage.ppm, out/painted-twice.ppm, out/plate-02.ppm,");
Console.WriteLine("      out/fan-coverage.ppm, out/plate-03.ppm");

return runner.FailedCount == 0 ? 0 : 1;
