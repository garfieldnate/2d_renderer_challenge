/**
 * §21.4: the tiled coverage of a fill_path_tiled: 1 in a solid tile, 0 in an
 * empty one, the resolved value in a partial one.
 */
public final class TiledCoverage {
    public static final int TILE = Tiles.TILE;

    final int width;
    final int height;
    final String[][] classes; // [ty][tx], one of "empty"/"solid"/"partial"
    final CoverageBuffer[][] partials; // same shape, non-null only where classes is "partial"

    TiledCoverage(int width, int height, String[][] classes, CoverageBuffer[][] partials) {
        this.width = width;
        this.height = height;
        this.classes = classes;
        this.partials = partials;
    }

    public double coverageAt(int x, int y) {
        if (x < 0 || y < 0 || x >= width || y >= height) {
            return 0;
        }
        int tx = x / TILE;
        int ty = y / TILE;
        String kind = classes[ty][tx];
        if (kind.equals("empty")) {
            return 0;
        }
        if (kind.equals("solid")) {
            return 1;
        }
        return partials[ty][tx].coverageAt(x - tx * TILE, y - ty * TILE);
    }
}
