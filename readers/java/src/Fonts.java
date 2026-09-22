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

        Map<List<String>, Double> kern = new LinkedHashMap<>();
        if (root.containsKey("kern")) {
            for (Object rawTriple : Json.asArray(root.get("kern"))) {
                List<Object> triple = Json.asArray(rawTriple);
                String left = Json.asString(triple.get(0));
                String right = Json.asString(triple.get(1));
                double value = Json.asNumber(triple.get(2));
                kern.put(List.of(left, right), value);
            }
        }

        List<Ligature> ligatures = new ArrayList<>();
        if (root.containsKey("ligatures")) {
            for (Object rawRule : Json.asArray(root.get("ligatures"))) {
                List<Object> rule = Json.asArray(rawRule);
                List<String> parts = new ArrayList<>();
                for (Object part : Json.asArray(rule.get(0))) {
                    parts.add(Json.asString(part));
                }
                String result = Json.asString(rule.get(1));
                ligatures.add(new Ligature(parts, result));
            }
        }

        Map<Integer, String> joining = new LinkedHashMap<>();
        if (root.containsKey("joining")) {
            for (Map.Entry<String, Object> e : Json.asObject(root.get("joining")).entrySet()) {
                joining.put(Integer.valueOf(e.getKey()), Json.asString(e.getValue()));
            }
        }

        Map<String, Map<String, String>> forms = new LinkedHashMap<>();
        if (root.containsKey("forms")) {
            for (Map.Entry<String, Object> e : Json.asObject(root.get("forms")).entrySet()) {
                Map<String, String> perGlyph = new LinkedHashMap<>();
                for (Map.Entry<String, Object> f : Json.asObject(e.getValue()).entrySet()) {
                    perGlyph.put(f.getKey(), Json.asString(f.getValue()));
                }
                forms.put(e.getKey(), perGlyph);
            }
        }

        Map<String, MarkAnchor> marks = new LinkedHashMap<>();
        if (root.containsKey("marks")) {
            for (Map.Entry<String, Object> e : Json.asObject(root.get("marks")).entrySet()) {
                List<Object> triple = Json.asArray(e.getValue());
                String anchorClass = Json.asString(triple.get(0));
                double ax = Json.asNumber(triple.get(1));
                double ay = Json.asNumber(triple.get(2));
                marks.put(e.getKey(), new MarkAnchor(anchorClass, ax, ay));
            }
        }

        Map<String, Map<String, double[]>> anchors = new LinkedHashMap<>();
        if (root.containsKey("anchors")) {
            for (Map.Entry<String, Object> e : Json.asObject(root.get("anchors")).entrySet()) {
                Map<String, double[]> perGlyph = new LinkedHashMap<>();
                for (Map.Entry<String, Object> a : Json.asObject(e.getValue()).entrySet()) {
                    List<Object> pair = Json.asArray(a.getValue());
                    perGlyph.put(a.getKey(), new double[] {Json.asNumber(pair.get(0)), Json.asNumber(pair.get(1))});
                }
                anchors.put(e.getKey(), perGlyph);
            }
        }

        return new Font(unitsPerEm, ascender, descender, lineGap, cmap, glyphs, kern, ligatures,
                joining, forms, marks, anchors);
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

    /** §18.2: kern(font, left, right) -- font units to pull the pair together, 0 for pairs the font doesn't list. */
    public static double kern(Font font, String left, String right) {
        Double v = font.kern.get(List.of(left, right));
        return v != null ? v : 0.0;
    }

    /** §19.4: joining_type(font, codepoint) -- Unicode's joining type, "none" for a character not listed. */
    public static String joiningType(Font font, int codepoint) {
        String t = font.joining.get(codepoint);
        return t != null ? t : "none";
    }

    /** §19.5: is_mark(font, name) -- whether a glyph is in the font's marks table. */
    public static boolean isMark(Font font, String name) {
        return font.marks.containsKey(name);
    }
}
