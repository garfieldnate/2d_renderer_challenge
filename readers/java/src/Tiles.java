/**
 * §21.4: the canvas is cut into tiles 16 pixels square, starting at the top
 * left; a tile at the right or bottom edge is cut short by the canvas.
 * classify_tiles(p, rule, width, height) answers classes[ty][tx] for every
 * tile: "empty" outside fill_bounds; "partial" when a cell in it got a
 * deposit with a nonzero area or cover; otherwise look at the running sum
 * arriving at the tile's left edge in each of its rows: if every row is
 * within 0.000001 of the same whole number n, the tile is "solid" when
 * apply_rule(n, rule) is 1 and "empty" when it isn't, else "partial".
 * fill_path_tiled resolves the cells of the partial tiles only.
 *
 * §21.5: draw_tiled(l, t, paint, alpha, st) paints a tiled coverage tile by
 * tile, skipping empty tiles. A solid tile is a run of pixels of the same
 * coverage, 1: with a solid paint and alpha 1 it's a copy; otherwise it's
 * blended. A solid paint's colour is looked up once for the whole tile.
 */
public final class Tiles {
    private Tiles() {}

    public static final int TILE = 16;

    private static double[][] rowPrefixes(Accumulator acc, int width, int height) {
        double[][] prefix = new double[height][width + 1];
        for (int y = 0; y < height; y++) {
            double sum = 0;
            for (int x = 0; x < width; x++) {
                sum += acc.coverAt(x, y);
                prefix[y][x + 1] = sum;
            }
        }
        return prefix;
    }

    private static String[][] classify(Accumulator acc, double[][] prefix, String rule, int width, int height,
            BoundedFill.IntBounds bounds) {
        int tileRows = (height + TILE - 1) / TILE;
        int tileCols = (width + TILE - 1) / TILE;
        String[][] out = new String[tileRows][tileCols];
        boolean nothing = bounds.equals(BoundedFill.IntBounds.EMPTY);
        for (int ty = 0; ty < tileRows; ty++) {
            int y0 = ty * TILE;
            int y1 = Math.min(y0 + TILE, height);
            for (int tx = 0; tx < tileCols; tx++) {
                int x0 = tx * TILE;
                int x1 = Math.min(x0 + TILE, width);
                if (nothing || x1 <= bounds.x0() || x0 >= bounds.x1() || y1 <= bounds.y0() || y0 >= bounds.y1()) {
                    out[ty][tx] = "empty";
                    continue;
                }
                boolean touched = false;
                for (int y = y0; y < y1 && !touched; y++) {
                    for (int x = x0; x < x1; x++) {
                        if (acc.areaAt(x, y) != 0 || acc.coverAt(x, y) != 0) {
                            touched = true;
                            break;
                        }
                    }
                }
                if (touched) {
                    out[ty][tx] = "partial";
                    continue;
                }
                double first = prefix[y0][x0];
                double n = Math.round(first);
                boolean consistent = Math.abs(first - n) <= 1e-6;
                for (int y = y0 + 1; consistent && y < y1; y++) {
                    if (Math.abs(prefix[y][x0] - n) > 1e-6) {
                        consistent = false;
                    }
                }
                if (!consistent) {
                    out[ty][tx] = "partial";
                    continue;
                }
                out[ty][tx] = Fill.applyRule(n, rule) == 1.0 ? "solid" : "empty";
            }
        }
        return out;
    }

    public static String[][] classifyTiles(Path p, String rule, int width, int height) {
        Accumulator acc = new Accumulator(width, height);
        for (Edge e : p.edges()) {
            Fill.accumulate(acc, e.a(), e.b());
        }
        BoundedFill.IntBounds bounds = BoundedFill.fillBounds(p, width, height);
        double[][] prefix = rowPrefixes(acc, width, height);
        return classify(acc, prefix, rule, width, height, bounds);
    }

    public static long tileCount(String[][] classes, String kind) {
        long count = 0;
        for (String[] row : classes) {
            for (String s : row) {
                if (s.equals(kind)) {
                    count++;
                }
            }
        }
        return count;
    }

    public static TiledCoverage fillPathTiled(Path p, String rule, int width, int height, Stats st) {
        return fillPathTiled(p, rule, width, height, st, null);
    }

    public static TiledCoverage fillPathTiled(
            Path p, String rule, int width, int height, Stats st, int[][][] tileWork) {
        Accumulator acc = new Accumulator(width, height);
        for (Edge e : p.edges()) {
            Fill.accumulate(acc, e.a(), e.b());
        }
        BoundedFill.IntBounds bounds = BoundedFill.fillBounds(p, width, height);
        double[][] prefix = rowPrefixes(acc, width, height);
        String[][] classes = classify(acc, prefix, rule, width, height, bounds);
        int tileRows = classes.length;
        int tileCols = classes[0].length;
        CoverageBuffer[][] partials = new CoverageBuffer[tileRows][tileCols];
        for (int ty = 0; ty < tileRows; ty++) {
            int y0 = ty * TILE;
            int y1 = Math.min(y0 + TILE, height);
            for (int tx = 0; tx < tileCols; tx++) {
                String kind = classes[ty][tx];
                if (tileWork != null) {
                    if (kind.equals("partial")) {
                        tileWork[ty][tx][0]++;
                    } else if (kind.equals("solid")) {
                        tileWork[ty][tx][1]++;
                    }
                }
                if (!kind.equals("partial")) {
                    continue;
                }
                int x0 = tx * TILE;
                int x1 = Math.min(x0 + TILE, width);
                int tw = x1 - x0;
                int th = y1 - y0;
                CoverageBuffer buf = new CoverageBuffer(tw, th);
                for (int y = y0; y < y1; y++) {
                    double running = prefix[y][x0];
                    for (int x = x0; x < x1; x++) {
                        double winding = running + acc.areaAt(x, y);
                        buf.setCoverage(x - x0, y - y0, Fill.applyRule(winding, rule));
                        running += acc.coverAt(x, y);
                    }
                }
                partials[ty][tx] = buf;
                st.cells += (long) tw * th;
            }
        }
        return new TiledCoverage(width, height, classes, partials);
    }

    public static void drawTiled(Layer l, TiledCoverage t, Paint paint, double alpha, Stats st) {
        int tileRows = t.classes.length;
        int tileCols = t.classes[0].length;
        for (int ty = 0; ty < tileRows; ty++) {
            int y0 = ty * TILE;
            int y1 = Math.min(y0 + TILE, t.height);
            for (int tx = 0; tx < tileCols; tx++) {
                String kind = t.classes[ty][tx];
                if (kind.equals("empty")) {
                    continue;
                }
                int x0 = tx * TILE;
                int x1 = Math.min(x0 + TILE, t.width);
                if (kind.equals("solid")) {
                    if (paint instanceof Solid) {
                        Color c = paint.paintAt(x0 + 0.5, y0 + 0.5);
                        if (alpha == 1.0) {
                            Pixel px = Pixel.fromColor(c, 1.0);
                            for (int y = y0; y < y1; y++) {
                                for (int x = x0; x < x1; x++) {
                                    l.setPixel(x, y, px);
                                    st.copies++;
                                }
                            }
                        } else {
                            Pixel src = Pixel.fromColor(c, alpha);
                            for (int y = y0; y < y1; y++) {
                                for (int x = x0; x < x1; x++) {
                                    l.setPixel(x, y, Compositing.over(src, l.pixelAt(x, y)));
                                    st.blends++;
                                }
                            }
                        }
                    } else {
                        for (int y = y0; y < y1; y++) {
                            for (int x = x0; x < x1; x++) {
                                Color c = paint.paintAt(x + 0.5, y + 0.5);
                                l.setPixel(x, y, Compositing.over(Pixel.fromColor(c, alpha), l.pixelAt(x, y)));
                                st.blends++;
                            }
                        }
                    }
                } else { // partial
                    CoverageBuffer buf = t.partials[ty][tx];
                    for (int y = y0; y < y1; y++) {
                        for (int x = x0; x < x1; x++) {
                            double k = buf.coverageAt(x - x0, y - y0) * alpha;
                            if (k > 0) {
                                Color c = paint.paintAt(x + 0.5, y + 0.5);
                                l.setPixel(x, y, Compositing.over(Pixel.fromColor(c, k), l.pixelAt(x, y)));
                                st.blends++;
                            }
                        }
                    }
                }
            }
        }
    }
}
