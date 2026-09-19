import java.util.LinkedHashMap;
import java.util.Map;

/**
 * §17.2: glyph_cache() is a table keyed by (glyph, size, subpixel); a page
 * of text draws a few thousand glyphs from a few dozen shapes at one size,
 * so cached_bitmap renders on the first request and hands back the very
 * same bitmap on every request after.
 */
public final class GlyphCache {
    private final Map<String, Bitmap> entries = new LinkedHashMap<>();

    private static String key(String name, double size, int subpixel) {
        return name + "|" + size + "|" + subpixel;
    }

    public Bitmap cachedBitmap(Font font, String name, double size, int subpixel) {
        return entries.computeIfAbsent(
                key(name, size, subpixel), k -> Bitmaps.glyphBitmap(font, name, size, subpixel));
    }

    public int size() {
        return entries.size();
    }
}
