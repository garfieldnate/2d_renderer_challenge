namespace Chapter01;

/// <summary>
/// A small hand-rolled test runner and assertion library, since NuGet (and
/// therefore xUnit/NUnit) is unavailable offline. One assertion failure
/// throws AssertionException; the runner catches it per-scenario.
/// </summary>
public sealed class AssertionException : Exception
{
    public AssertionException(string message) : base(message) { }
}

public static class Check
{
    public const double DefaultTolerance = 0.0001;

    /// <summary>a = b within tolerance, per §1.1: |a - b| ≤ tolerance.</summary>
    public static bool NumbersEqual(double a, double b, double tolerance = DefaultTolerance) =>
        Math.Abs(a - b) <= tolerance;

    public static void Equal(double expected, double actual, double tolerance = DefaultTolerance, string? label = null)
    {
        if (!NumbersEqual(expected, actual, tolerance))
        {
            throw new AssertionException(
                $"{Prefix(label)}expected {expected} = {actual} within ± {tolerance}, differed by {Math.Abs(expected - actual)}");
        }
    }

    public static void NotEqual(double a, double b, double tolerance = DefaultTolerance, string? label = null)
    {
        if (NumbersEqual(a, b, tolerance))
        {
            throw new AssertionException($"{Prefix(label)}expected {a} ≠ {b} within ± {tolerance}, but they were equal");
        }
    }

    public static void ColorEqual(Color expected, Color actual, double tolerance = DefaultTolerance, string? label = null)
    {
        if (!NumbersEqual(expected.Red, actual.Red, tolerance) ||
            !NumbersEqual(expected.Green, actual.Green, tolerance) ||
            !NumbersEqual(expected.Blue, actual.Blue, tolerance))
        {
            throw new AssertionException($"{Prefix(label)}expected {expected} = {actual} within ± {tolerance}");
        }
    }

    public static void ColorNotEqual(Color a, Color b, double tolerance = DefaultTolerance, string? label = null)
    {
        bool equal = NumbersEqual(a.Red, b.Red, tolerance) &&
                     NumbersEqual(a.Green, b.Green, tolerance) &&
                     NumbersEqual(a.Blue, b.Blue, tolerance);
        if (equal)
        {
            throw new AssertionException($"{Prefix(label)}expected {a} ≠ {b}, but they were equal");
        }
    }

    /// <summary>A triple of whole numbers, as it appears in a file. Exact unless tolerance says otherwise.</summary>
    public static void TripleEqual((int R, int G, int B) expected, (int R, int G, int B) actual, int tolerance = 0, string? label = null)
    {
        if (Math.Abs(expected.R - actual.R) > tolerance ||
            Math.Abs(expected.G - actual.G) > tolerance ||
            Math.Abs(expected.B - actual.B) > tolerance)
        {
            throw new AssertionException(
                $"{Prefix(label)}expected ({expected.R}, {expected.G}, {expected.B}) = ({actual.R}, {actual.G}, {actual.B}) within ± {tolerance}");
        }
    }

    public static void IntEqual(int expected, int actual, string? label = null)
    {
        if (expected != actual)
        {
            throw new AssertionException($"{Prefix(label)}expected {expected}, got {actual}");
        }
    }

    public static void True(bool condition, string message)
    {
        if (!condition) throw new AssertionException(message);
    }

    public static void StringEqual(string expected, string actual, string? label = null)
    {
        if (expected != actual)
        {
            throw new AssertionException($"{Prefix(label)}expected {Quote(expected)}, got {Quote(actual)}");
        }
    }

    /// <summary>An ordered list of (x, y) pixel coordinates, as lit_pixels returns.</summary>
    public static void PixelListEqual(IReadOnlyList<(int X, int Y)> expected, IReadOnlyList<(int X, int Y)> actual, string? label = null)
    {
        bool equal = expected.Count == actual.Count;
        for (int i = 0; equal && i < expected.Count; i++)
        {
            if (expected[i] != actual[i]) equal = false;
        }
        if (!equal)
        {
            throw new AssertionException($"{Prefix(label)}expected [{FormatPixels(expected)}] = [{FormatPixels(actual)}]");
        }
    }

    private static string FormatPixels(IReadOnlyList<(int X, int Y)> pixels) =>
        string.Join(", ", pixels.Select(p => $"({p.X}, {p.Y})"));

    private static string Quote(string s) => "\"" + s.Replace("\n", "\\n") + "\"";
    private static string Prefix(string? label) => label is null ? "" : $"{label}: ";
}

public sealed class TestRunner
{
    private int _total;
    private int _passed;
    private readonly List<(string Feature, string Scenario, string Message)> _failures = new();
    private readonly Dictionary<string, (int Total, int Passed)> _byFeature = new();

    public void Run(string feature, string scenario, Action test)
    {
        // Every scenario that doesn't say otherwise expects linear blending on.
        Mix.LinearBlending = true;

        _total++;
        var (ft, fp) = _byFeature.TryGetValue(feature, out var existing) ? existing : (0, 0);
        ft++;
        try
        {
            test();
            _passed++;
            fp++;
        }
        catch (Exception ex)
        {
            _failures.Add((feature, scenario, ex.Message));
        }
        finally
        {
            _byFeature[feature] = (ft, fp);
        }
    }

    public void PrintSummary()
    {
        Console.WriteLine();
        Console.WriteLine("=== Results by feature ===");
        foreach (var (feature, (ft, fp)) in _byFeature)
        {
            Console.WriteLine($"{feature}: {fp}/{ft} passed");
        }

        Console.WriteLine();
        if (_failures.Count > 0)
        {
            Console.WriteLine("=== Failures ===");
            foreach (var (feature, scenario, message) in _failures)
            {
                Console.WriteLine($"[{feature}] {scenario}");
                Console.WriteLine($"    {message}");
            }
            Console.WriteLine();
        }

        Console.WriteLine($"TOTAL: {_passed}/{_total} passed, {_total - _passed} failed");
    }

    public int FailedCount => _total - _passed;
}
