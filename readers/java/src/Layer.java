/**
 * §9.6: layer(w, h) is a buffer of premultiplied pixels, every one starting
 * CLEAR -- the translucent sibling of chapter 1's Canvas.
 */
public final class Layer {
    public final int width;
    public final int height;
    private final Pixel[] pixels;

    public Layer(int width, int height) {
        this.width = width;
        this.height = height;
        this.pixels = new Pixel[width * height];
        java.util.Arrays.fill(pixels, Pixel.CLEAR);
    }

    public void setPixel(int x, int y, Pixel p) {
        if (x < 0 || x >= width || y < 0 || y >= height) {
            return;
        }
        pixels[y * width + x] = p;
    }

    public Pixel pixelAt(int x, int y) {
        if (x < 0 || x >= width || y < 0 || y >= height) {
            return Pixel.CLEAR;
        }
        return pixels[y * width + x];
    }
}
