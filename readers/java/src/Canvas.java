/**
 * §1.3: a rectangle of colors. Origin top left, x increases right, y increases
 * down. Every pixel starts black. Writes outside the canvas are silently
 * dropped -- not an error, not a wraparound, not a resize.
 */
public final class Canvas {
    public final int width;
    public final int height;
    private final Color[] pixels;

    public Canvas(int width, int height) {
        this.width = width;
        this.height = height;
        this.pixels = new Color[width * height];
        java.util.Arrays.fill(pixels, new Color(0, 0, 0));
    }

    public void writePixel(int x, int y, Color c) {
        if (x < 0 || x >= width || y < 0 || y >= height) {
            return;
        }
        pixels[y * width + x] = c;
    }

    public Color pixelAt(int x, int y) {
        return pixels[y * width + x];
    }

    public void fill(Color c) {
        java.util.Arrays.fill(pixels, c);
    }
}
