import java.util.List;

/**
 * §16.1/§19.2: one ligature rule from the font's optional ligatures
 * section -- a list of glyph names that combine into one result glyph.
 */
public record Ligature(List<String> parts, String result) {}
