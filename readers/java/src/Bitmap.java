/**
 * §17.1: a glyph rendered at a quarter is a bitmap -- its coverage in a
 * buffer of its own, no bigger than it needs, plus two integers (left, top)
 * saying where the buffer's top-left corner sits relative to the pen.
 * width and height are the coverage buffer's own dimensions.
 */
public final class Bitmap {
    public final CoverageBuffer coverage;
    public final int width;
    public final int height;
    public final int left;
    public final int top;

    public Bitmap(CoverageBuffer coverage, int left, int top) {
        this.coverage = coverage;
        this.width = coverage.width;
        this.height = coverage.height;
        this.left = left;
        this.top = top;
    }
}
