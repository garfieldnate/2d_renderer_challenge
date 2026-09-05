using System.Globalization;
using System.Text;

namespace Chapter01;

/// <summary>
/// A PPM file's bytes, however they got here: as text (P3, e.g. straight
/// from CanvasToPpm or File.ReadAllText) or as raw bytes (P6, from
/// CanvasToP6 or File.ReadAllBytes). The implicit conversions mean every
/// reader below - PpmPixel, DistinctValues, MaxChannelDifference - accepts
/// either format, and the two can even be compared to one another.
/// </summary>
public readonly struct PpmData
{
    public byte[] Bytes { get; }

    private PpmData(byte[] bytes) => Bytes = bytes;

    public static implicit operator PpmData(string text) => new(Encoding.ASCII.GetBytes(text));
    public static implicit operator PpmData(byte[] bytes) => new(bytes);
}

/// <summary>
/// The PPM formats: P3 (plain text) and P6 (binary - same three header
/// lines, a 6 in place of the 3, one newline, then one byte per channel).
/// Plus a few helpers so tests can read files back: ppm_pixel,
/// distinct_values, max_channel_difference. None of these three are
/// renderer functions.
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
    /// P6: the same three header lines with a 6 in place of the 3, then
    /// exactly one newline, then the pixel data as raw bytes - one byte per
    /// channel, nothing in between. The bytes are the same numbers the P3
    /// writer computes: clamp, encode, scale, round.
    /// </summary>
    public static byte[] CanvasToP6(Canvas c)
    {
        var header = Encoding.ASCII.GetBytes($"P6\n{c.Width} {c.Height}\n255\n");
        var body = new byte[c.Width * c.Height * 3];
        int i = 0;
        for (int y = 0; y < c.Height; y++)
        {
            for (int x = 0; x < c.Width; x++)
            {
                Color pixel = c.PixelAt(x, y);
                body[i++] = (byte)ChannelToFileValue(pixel.Red);
                body[i++] = (byte)ChannelToFileValue(pixel.Green);
                body[i++] = (byte)ChannelToFileValue(pixel.Blue);
            }
        }

        var file = new byte[header.Length + body.Length];
        header.CopyTo(file, 0);
        body.CopyTo(file, header.Length);
        return file;
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

    /// <summary>True for space, newline, CR and tab - the only whitespace a PPM header uses.</summary>
    private static bool IsWhitespace(byte b) => b == ' ' || b == '\n' || b == '\r' || b == '\t';

    /// <summary>
    /// Reads the four header tokens (magic, width, height, maxval) directly
    /// off the bytes, then skips the single whitespace byte after maxval.
    /// Done byte-by-byte, not by splitting the whole buffer on whitespace,
    /// because in a P6 file a pixel byte can itself equal a whitespace
    /// character.
    /// </summary>
    private static (string Magic, int Width, int Height, int DataStart) ParseHeader(byte[] bytes)
    {
        int pos = 0;

        string ReadToken()
        {
            while (pos < bytes.Length && IsWhitespace(bytes[pos])) pos++;
            int start = pos;
            while (pos < bytes.Length && !IsWhitespace(bytes[pos])) pos++;
            return Encoding.ASCII.GetString(bytes, start, pos - start);
        }

        string magic = ReadToken();
        int width = int.Parse(ReadToken(), CultureInfo.InvariantCulture);
        int height = int.Parse(ReadToken(), CultureInfo.InvariantCulture);
        ReadToken(); // maxval, always 255 in this book
        pos++; // the single whitespace byte after maxval
        return (magic, width, height, pos);
    }

    private static (int Width, int Height, int[] Values) Parse(PpmData ppm)
    {
        byte[] bytes = ppm.Bytes;
        var (magic, width, height, dataStart) = ParseHeader(bytes);

        int[] values;
        if (magic == "P6")
        {
            // Raw bytes: one value per channel, nothing in between.
            values = new int[bytes.Length - dataStart];
            for (int i = 0; i < values.Length; i++) values[i] = bytes[dataStart + i];
        }
        else
        {
            // P3: the rest of the file is whitespace-separated ASCII numbers.
            string rest = Encoding.ASCII.GetString(bytes, dataStart, bytes.Length - dataStart);
            var tokens = rest.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
            values = new int[tokens.Length];
            for (int i = 0; i < tokens.Length; i++) values[i] = int.Parse(tokens[i], CultureInfo.InvariantCulture);
        }

        return (width, height, values);
    }

    public static (int R, int G, int B) PpmPixel(PpmData ppm, int x, int y)
    {
        var (width, _, values) = Parse(ppm);
        int index = (y * width + x) * 3;
        return (values[index], values[index + 1], values[index + 2]);
    }

    public static int DistinctValues(PpmData ppm)
    {
        var (_, _, values) = Parse(ppm);
        return values.Distinct().Count();
    }

    /// <summary>
    /// The largest difference between any pair of corresponding numbers in
    /// two files. If the files don't share a width and height, the answer
    /// is 255 — otherwise a transposed render could compare as a match.
    /// </summary>
    public static int MaxChannelDifference(PpmData ppmA, PpmData ppmB)
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

    /// <summary>1-based byte access, matching "byte N of p6" in the scenarios.</summary>
    public static byte Byte(byte[] data, int oneBasedNumber) => data[oneBasedNumber - 1];

    public static bool BeginsWith(byte[] data, string expectedAscii)
    {
        var expected = Encoding.ASCII.GetBytes(expectedAscii);
        if (data.Length < expected.Length) return false;
        for (int i = 0; i < expected.Length; i++)
        {
            if (data[i] != expected[i]) return false;
        }
        return true;
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
