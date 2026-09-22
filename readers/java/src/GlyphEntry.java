/**
 * §19.2: one entry of a glyph buffer -- a glyph name, the cluster (the
 * index of the character it came from, or the smallest of several once
 * things merge), and a mark's offset from its base, in font units
 * (0, 0) until §19.5 attaches it.
 */
public record GlyphEntry(String glyph, int cluster, double dx, double dy) {
    public GlyphEntry(String glyph, int cluster) {
        this(glyph, cluster, 0, 0);
    }
}
