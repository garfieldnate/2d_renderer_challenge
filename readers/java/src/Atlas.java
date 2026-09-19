/**
 * §17.2: one big coverage buffer the bitmaps are packed into, shelf by
 * shelf -- the simplest packing rule that works. Bitmaps go left to right
 * along a shelf whose height is set by its first bitmap; when the next one
 * doesn't fit on the shelf, a new shelf opens below the tallest so far.
 * atlas_add copies a bitmap in and answers where, or none (null) when
 * there is no room -- either the bitmap is wider than the whole atlas, or
 * a freshly opened shelf still doesn't have the height to hold it.
 */
public final class Atlas {
    public final CoverageBuffer coverage;
    private int shelfY = 0;
    private int shelfHeight = 0; // 0 means "not yet fixed by a bitmap"
    private int currentX = 0;

    public Atlas(int width, int height) {
        this.coverage = new CoverageBuffer(width, height);
    }

    public AtlasSpot add(Bitmap bm) {
        if (bm.width > coverage.width) {
            return null; // never fits, on any shelf
        }
        if (currentX + bm.width <= coverage.width && (shelfHeight == 0 || bm.height <= shelfHeight)) {
            if (shelfHeight == 0) {
                shelfHeight = bm.height; // the shelf's height is set by its first bitmap
            }
            int x = currentX;
            int y = shelfY;
            blit(bm, x, y);
            currentX += bm.width;
            return new AtlasSpot(x, y);
        }
        // Open a new shelf below the tallest one so far.
        int newY = shelfY + shelfHeight;
        if (newY + bm.height > coverage.height) {
            shelfY = newY;
            shelfHeight = 0;
            currentX = 0;
            return null;
        }
        shelfY = newY;
        shelfHeight = bm.height;
        currentX = bm.width;
        blit(bm, 0, newY);
        return new AtlasSpot(0, newY);
    }

    private void blit(Bitmap bm, int x, int y) {
        for (int j = 0; j < bm.height; j++) {
            for (int i = 0; i < bm.width; i++) {
                coverage.setCoverage(x + i, y + j, bm.coverage.coverageAt(i, j));
            }
        }
    }
}
