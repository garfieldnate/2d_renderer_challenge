import java.util.List;
import java.util.Map;

/**
 * §16.1: the whole font -- vertical metrics in font units, a codepoint to
 * glyph-name map, and the glyphs by name. Several sections are optional
 * and arrive in later chapters: kern (chapter 18, a (left, right) ->
 * font-unit table, missing pairs read as 0), ligatures (chapter 19, a
 * list of parts -> result), and, for the Arabic font only, joining
 * (Unicode's joining type per codepoint), forms (glyph -> form -> glyph,
 * GSUB's init/medi/fina) and marks/anchors (GPOS mark-to-base). A font
 * without a section reads it as empty.
 */
public final class Font {
    public final double unitsPerEm;
    public final double ascender;
    public final double descender;
    public final double lineGap;
    public final Map<String, String> cmap; // codepoint (as a string) -> glyph name
    public final Map<String, Glyph> glyphs;
    public final Map<List<String>, Double> kern; // [left, right] -> font units
    public final List<Ligature> ligatures;
    public final Map<Integer, String> joining; // codepoint -> joining type, missing = "none"
    public final Map<String, Map<String, String>> forms; // glyph -> form -> glyph
    public final Map<String, MarkAnchor> marks; // mark glyph -> its own anchor
    public final Map<String, Map<String, double[]>> anchors; // base glyph -> class -> [x, y]

    public Font(double unitsPerEm, double ascender, double descender, double lineGap,
                Map<String, String> cmap, Map<String, Glyph> glyphs,
                Map<List<String>, Double> kern, List<Ligature> ligatures,
                Map<Integer, String> joining, Map<String, Map<String, String>> forms,
                Map<String, MarkAnchor> marks, Map<String, Map<String, double[]>> anchors) {
        this.unitsPerEm = unitsPerEm;
        this.ascender = ascender;
        this.descender = descender;
        this.lineGap = lineGap;
        this.cmap = cmap;
        this.glyphs = glyphs;
        this.kern = kern;
        this.ligatures = ligatures;
        this.joining = joining;
        this.forms = forms;
        this.marks = marks;
        this.anchors = anchors;
    }
}
