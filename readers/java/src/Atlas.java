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

    // Matches chapter-17.html section 17.2's pseudo-code exactly: a bitmap
    // that fits width-wise stays on the current shelf even if it is taller
    // than what has been placed there so far (the shelf just grows), and
    // the "no room on this shelf" shift happens unconditionally before the
    // height check, so a shelf can be committed even when the bitmap that
    // triggered it then turns out not to fit.
    public AtlasSpot add(Bitmap bm) {
        if (bm.width > coverage.width || bm.height > coverage.height) {
            return null;
        }
        if (currentX + bm.width > coverage.width) {
            shelfY = shelfY + shelfHeight;
            currentX = 0;
            shelfHeight = 0;
        }
        if (shelfY + Math.max(bm.height, shelfHeight) > coverage.height) {
            return null;
        }
        blit(bm, currentX, shelfY);
        int x = currentX;
        int y = shelfY;
        currentX += bm.width;
        shelfHeight = Math.max(shelfHeight, bm.height);
        return new AtlasSpot(x, y);
    }

    private void blit(Bitmap bm, int x, int y) {
        for (int j = 0; j < bm.height; j++) {
            for (int i = 0; i < bm.width; i++) {
                coverage.setCoverage(x + i, y + j, bm.coverage.coverageAt(i, j));
            }
        }
    }
}
