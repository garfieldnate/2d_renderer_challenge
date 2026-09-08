/**
 * §10.5: ordered dithering. Before rounding a pixel down to a byte, nudge it
 * by a threshold that depends on its position, taken from the 4x4 Bayer
 * matrix: dither_threshold(x, y) = BAYER4[y % 4][x % 4] / 16, in [0, 1).
 * to_byte_dithered adds that threshold in place of the fixed 0.5 an ordinary
 * round uses, so a value that sits a fraction of the way between two bytes
 * rounds up in that fraction of the positions in the tile.
 */
public final class Dither {
    private Dither() {}

    public static final int[][] BAYER4 = {
        {0, 8, 2, 10},
        {12, 4, 14, 6},
        {3, 11, 1, 9},
        {15, 7, 13, 5}
    };

    public static double ditherThreshold(int x, int y) {
        int row = ((y % 4) + 4) % 4;
        int col = ((x % 4) + 4) % 4;
        return BAYER4[row][col] / 16.0;
    }

    public static int toByteDithered(double light, int x, int y) {
        double clamped = light < 0 ? 0 : light > 1 ? 1 : light;
        double encoded = Srgb.encode(clamped);
        return (int) Math.floor(encoded * 255.0 + ditherThreshold(x, y));
    }
}
