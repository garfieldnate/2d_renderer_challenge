import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * §16.1: load_font(text) reads the book's JSON font schema: units_per_em,
 * ascender, descender, line_gap in font units; cmap, codepoint (as a string
 * key) to glyph name; glyphs, name to {advance, contours, components},
 * where contours is a list of loops of [x, y, on] points in font units with
 * y up, and components is a list of {glyph, transform}. glyph_name looks a
 * character up in the cmap and answers ".notdef" -- the box every font
 * draws for a character it doesn't have -- when the character isn't there.
 */
public final class Fonts {
    private Fonts() {}

    public static Font loadFont(String text) {
        Map<String, Object> root = Json.asObject(Json.parse(text));
        double unitsPerEm = Json.asNumber(root.get("units_per_em"));
        double ascender = Json.asNumber(root.get("ascender"));
        double descender = Json.asNumber(root.get("descender"));
        double lineGap = Json.asNumber(root.get("line_gap"));

        Map<String, String> cmap = new LinkedHashMap<>();
        for (Map.Entry<String, Object> e : Json.asObject(root.get("cmap")).entrySet()) {
            cmap.put(e.getKey(), Json.asString(e.getValue()));
        }

        Map<String, Glyph> glyphs = new LinkedHashMap<>();
        for (Map.Entry<String, Object> e : Json.asObject(root.get("glyphs")).entrySet()) {
            glyphs.put(e.getKey(), readGlyph(Json.asObject(e.getValue())));
        }

        return new Font(unitsPerEm, ascender, descender, lineGap, cmap, glyphs);
    }

    private static Glyph readGlyph(Map<String, Object> obj) {
        double advance = Json.asNumber(obj.get("advance"));

        List<List<ContourPoint>> contours = new ArrayList<>();
        for (Object rawContour : Json.asArray(obj.get("contours"))) {
            List<ContourPoint> contour = new ArrayList<>();
            for (Object rawPoint : Json.asArray(rawContour)) {
                List<Object> triple = Json.asArray(rawPoint);
                double x = Json.asNumber(triple.get(0));
                double y = Json.asNumber(triple.get(1));
                boolean on = Json.asBoolean(triple.get(2));
                contour.add(new ContourPoint(x, y, on));
            }
            contours.add(contour);
        }

        List<Component> components = new ArrayList<>();
        for (Object rawComponent : Json.asArray(obj.get("components"))) {
            Map<String, Object> comp = Json.asObject(rawComponent);
            String glyphName = Json.asString(comp.get("glyph"));
            List<Object> t = Json.asArray(comp.get("transform"));
            double[] transform = new double[6];
            for (int i = 0; i < 6; i++) {
                transform[i] = Json.asNumber(t.get(i));
            }
            components.add(new Component(glyphName, transform));
        }

        return new Glyph(advance, contours, components);
    }

    public static String glyphName(Font font, int codepoint) {
        String name = font.cmap.get(Integer.toString(codepoint));
        return name != null ? name : ".notdef";
    }

    public static double glyphAdvance(Font font, String name) {
        return font.glyphs.get(name).advance();
    }

    public static int glyphCount(Font font) {
        return font.glyphs.size();
    }
}
