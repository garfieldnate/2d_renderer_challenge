using System.Globalization;
using System.Text;

namespace Chapter01;

/// <summary>
/// The plain-text P3 PPM format, and a few helpers so tests can read files
/// back: ppm_pixel, distinct_values, max_channel_difference. None of these
/// three are renderer functions.
/// </summary>
public static class Ppm
{
    private const int MaxLineLength = 70;

    public static string CanvasToPpm(Canvas c)
    {
        var lines = new List<string> { "P3", $"{c.Width} {c.Height}", "255" };

        for (int y = 0; y < c.Height; y++)
        {
            var rowTokens = new List<string>(c.Width * 3);
            for (int x = 0; x < c.Width; x++)
            {
                Color pixel = c.PixelAt(x, y);
                rowTokens.Add(ChannelToFileValue(pixel.Red).ToString(CultureInfo.InvariantCulture));
                rowTokens.Add(ChannelToFileValue(pixel.Green).ToString(CultureInfo.InvariantCulture));
                rowTokens.Add(ChannelToFileValue(pixel.Blue).ToString(CultureInfo.InvariantCulture));
            }
            lines.AddRange(PackLine(rowTokens));
        }

        return string.Join("\n", lines) + "\n";
    }

    /// <summary>
    /// Clamp to 0..1, encode, multiply by 255, round to the nearest whole
    /// number — in that order. Clamp before encode: encode is only defined
    /// on 0..1.
    /// </summary>
    private static int ChannelToFileValue(double lightValue)
    {
        double clamped = Srgb.Clamp01(lightValue);
        double encoded = Srgb.Encode(clamped);
        double scaled = encoded * 255.0;
        return (int)Math.Round(scaled, MidpointRounding.AwayFromZero);
    }

    /// <summary>
    /// Greedy word packing: add tokens separated by single spaces; before
    /// adding a token, if the line would end up longer than 70 characters,
    /// start a new line instead. Exactly 70 is fine.
    /// </summary>
    private static List<string> PackLine(List<string> tokens)
    {
        var lines = new List<string>();
        var current = new StringBuilder();

        foreach (var token in tokens)
        {
            int candidateLength = current.Length == 0 ? token.Length : current.Length + 1 + token.Length;
            if (candidateLength > MaxLineLength)
            {
                lines.Add(current.ToString());
                current.Clear();
                current.Append(token);
            }
            else
            {
                if (current.Length > 0) current.Append(' ');
                current.Append(token);
            }
        }

        if (current.Length > 0) lines.Add(current.ToString());
        return lines;
    }

    private static (int Width, int Height, int[] Values) Parse(string ppm)
    {
        // Split on any whitespace: magic, width, height, maxval, then pixel data.
        var tokens = ppm.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        int width = int.Parse(tokens[1], CultureInfo.InvariantCulture);
        int height = int.Parse(tokens[2], CultureInfo.InvariantCulture);
        var values = new int[tokens.Length - 4];
        for (int i = 4; i < tokens.Length; i++)
        {
            values[i - 4] = int.Parse(tokens[i], CultureInfo.InvariantCulture);
        }
        return (width, height, values);
    }

    public static (int R, int G, int B) PpmPixel(string ppm, int x, int y)
    {
        var (width, _, values) = Parse(ppm);
        int index = (y * width + x) * 3;
        return (values[index], values[index + 1], values[index + 2]);
    }

    public static int DistinctValues(string ppm)
    {
        var (_, _, values) = Parse(ppm);
        return values.Distinct().Count();
    }

    /// <summary>
    /// The largest difference between any pair of corresponding numbers in
    /// two files. If the files don't share a width and height, the answer
    /// is 255 — otherwise a transposed render could compare as a match.
    /// </summary>
    public static int MaxChannelDifference(string ppmA, string ppmB)
    {
        var (widthA, heightA, valuesA) = Parse(ppmA);
        var (widthB, heightB, valuesB) = Parse(ppmB);
        if (widthA != widthB || heightA != heightB) return 255;

        int max = 0;
        for (int i = 0; i < valuesA.Length; i++)
        {
            int diff = Math.Abs(valuesA[i] - valuesB[i]);
            if (diff > max) max = diff;
        }
        return max;
    }

    /// <summary>1-based line access, matching "line N of ppm" in the scenarios.</summary>
    public static string[] Lines(string ppm) => ppm.Split('\n');

    public static string Line(string ppm, int oneBasedNumber) => Lines(ppm)[oneBasedNumber - 1];

    public static string[] LineRange(string ppm, int oneBasedStart, int oneBasedEndInclusive)
    {
        var all = Lines(ppm);
        int count = oneBasedEndInclusive - oneBasedStart + 1;
        var slice = new string[count];
        Array.Copy(all, oneBasedStart - 1, slice, 0, count);
        return slice;
    }
}
