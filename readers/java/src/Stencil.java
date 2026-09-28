/**
 * §24.1: a stencil is one whole number per pixel, all 0 at first, and a
 * count of fragments -- how many pixels a stencil_triangle actually changed
 * (a triangle_winding of 0 changes nothing and isn't a fragment).
 */
public final class Stencil {
    public final int width;
    public final int height;
    public final int[] values;
    public int fragments;

    public Stencil(int width, int height) {
        this.width = width;
        this.height = height;
        this.values = new int[width * height];
        this.fragments = 0;
    }

    /** add(x, y, delta): a fragment only when delta isn't 0, per stencil_triangle's own rule. */
    public void add(int x, int y, int delta) {
        if (delta == 0) {
            return;
        }
        if (x < 0 || x >= width || y < 0 || y >= height) {
            return;
        }
        values[y * width + x] += delta;
        fragments++;
    }
}
