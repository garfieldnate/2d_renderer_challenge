/**
 * §7.1: a grid of two numbers per cell, all zero to start. area_at(x, y) is
 * what a cell itself has collected -- the signed area an edge left inside
 * this one cell. cover_at(x, y) is the signed height that cell hands to
 * every cell on its right. add_cell(x, row, area, cover) is the one
 * primitive that writes to the buffer: it adds rather than overwrites,
 * because two edges can cross the same cell and both have a say.
 *
 * A deposit left of the buffer (x &lt; 0) doesn't vanish: everything in that
 * row is to the right of it, so it folds onto column 0 and counts as pure
 * cover -- the whole height carries in, and the area argument is discarded
 * in favor of the cover value. A deposit right of the buffer (x &gt;= width)
 * really does vanish, because there's nothing to its right to carry into.
 */
public final class Accumulator {
    public final int width;
    public final int height;
    private final double[] area;
    private final double[] cover;

    public Accumulator(int width, int height) {
        this.width = width;
        this.height = height;
        this.area = new double[width * height];
        this.cover = new double[width * height];
    }

    public double areaAt(int x, int y) {
        if (x < 0 || x >= width || y < 0 || y >= height) {
            return 0;
        }
        return area[y * width + x];
    }

    public double coverAt(int x, int y) {
        if (x < 0 || x >= width || y < 0 || y >= height) {
            return 0;
        }
        return cover[y * width + x];
    }

    public void addCell(int x, int row, double a, double c) {
        if (row < 0 || row >= height) {
            return;
        }
        if (x < 0) {
            x = 0;
            a = c; // folds onto column 0 as pure cover
        } else if (x >= width) {
            return; // nothing to its right to carry into
        }
        int idx = row * width + x;
        area[idx] += a;
        cover[idx] += c;
    }
}
