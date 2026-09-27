/** §23.7: a baked glyph -- a box (left, top, width, height) and one field per channel. */
public final class Baked {
    public final int left;
    public final int top;
    public final int width;
    public final int height;
    public final Field[] channels;

    public Baked(int left, int top, int width, int height, Field[] channels) {
        this.left = left;
        this.top = top;
        this.width = width;
        this.height = height;
        this.channels = channels;
    }
}
