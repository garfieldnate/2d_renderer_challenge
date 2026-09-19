import java.util.Map;

/**
 * §16.1: the whole font -- vertical metrics in font units, a codepoint to
 * glyph-name map, and the glyphs by name. Two sections are optional and
 * arrive in later chapters (kern, ligatures); this book doesn't need them
 * before chapter 18.
 */
public final class Font {
    public final double unitsPerEm;
    public final double ascender;
    public final double descender;
    public final double lineGap;
    public final Map<String, String> cmap; // codepoint (as a string) -> glyph name
    public final Map<String, Glyph> glyphs;

    public Font(double unitsPerEm, double ascender, double descender, double lineGap,
                Map<String, String> cmap, Map<String, Glyph> glyphs) {
        this.unitsPerEm = unitsPerEm;
        this.ascender = ascender;
        this.descender = descender;
        this.lineGap = lineGap;
        this.cmap = cmap;
        this.glyphs = glyphs;
    }
}
