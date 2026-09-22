import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;

/**
 * Chapter 19: shaping, a field guide. The step between a string and a
 * list of glyph names to draw, built as a small pipeline over a buffer of
 * glyphs, with the cluster -- the character index a glyph traces back
 * to -- carried through every step.
 *
 * §19.1: script_of/itemize cut a string into runs of one script and one
 * direction; a common character (no script of its own) joins the run
 * before it, and leading common characters join the first run, which
 * defaults to latin/ltr when the whole string is common.
 *
 * §19.2: glyph_buffer(font, text) is the starting buffer, one entry per
 * character, cluster = character index. clusters(buffer) lists the
 * distinct clusters in order.
 *
 * §19.3: apply_ligatures walks the buffer from the left, trying the
 * font's rules (longest first) at each position; a match's result takes
 * the first part's cluster and the walk continues past it, never
 * re-matching the result.
 *
 * §19.4: arabic_forms answers every character's positional form from
 * Unicode's joining types, skipping transparent characters (marks) when
 * looking for a neighbour; apply_forms swaps each glyph for its form's
 * glyph where the font's forms table has one.
 *
 * §19.5: attach_marks finds each mark's nearest preceding non-mark (its
 * base), and if the base has an anchor of the mark's class, sets the
 * mark's offset to base anchor minus mark anchor and gives it the base's
 * cluster; otherwise the mark stays at offset (0, 0) with its own
 * cluster. shape(font, text) is the pipeline: buffer, forms if the font
 * has them, ligatures always, marks if the font has them.
 *
 * §19.6: position turns a shaped buffer into chapter 18's placements.
 * ltr walks the pen right from x; rtl starts at x plus the buffer's
 * advance and walks left, subtracting each glyph's own kern and advance
 * before placing it, so the run still occupies x to x + advance either
 * way. A mark never moves the pen -- it rides its base's placement plus
 * its offset, scaled to pixels with dy turned over (font y-up to canvas
 * y-down). caret_offsets/caret_positions give the cluster boundaries a
 * cursor may stand at, and where they land on the baseline.
 */
public final class Shaping {
    private Shaping() {}

    // ---- §19.1: itemizing --------------------------------------------------

    public static String scriptOf(int cp) {
        if (cp >= 0x600 && cp <= 0x6FF) {
            return "arabic";
        }
        if ((cp >= 'A' && cp <= 'Z') || (cp >= 'a' && cp <= 'z') || (cp >= 0xC0 && cp <= 0x24F)) {
            return "latin";
        }
        return "common";
    }

    public static List<Item> itemize(String text) {
        List<Item> items = new ArrayList<>();
        int n = text.length();
        if (n == 0) {
            return items;
        }
        int runStart = 0;
        String runScript = null;
        for (int i = 0; i < n; i++) {
            String sc = scriptOf(text.charAt(i));
            if (sc.equals("common")) {
                continue;
            }
            if (runScript == null) {
                runScript = sc;
            } else if (!sc.equals(runScript)) {
                items.add(makeItem(text, runStart, i, runScript));
                runStart = i;
                runScript = sc;
            }
        }
        items.add(makeItem(text, runStart, n, runScript != null ? runScript : "latin"));
        return items;
    }

    private static Item makeItem(String text, int start, int end, String script) {
        return new Item(start, end, text.substring(start, end), script,
                script.equals("arabic") ? "rtl" : "ltr");
    }

    // ---- §19.2: the glyph buffer and clusters -------------------------------

    public static List<GlyphEntry> glyphBuffer(Font font, String text) {
        List<GlyphEntry> out = new ArrayList<>();
        for (int i = 0; i < text.length(); i++) {
            out.add(new GlyphEntry(Fonts.glyphName(font, text.charAt(i)), i));
        }
        return out;
    }

    public static List<Integer> clusters(List<GlyphEntry> buffer) {
        LinkedHashSet<Integer> set = new LinkedHashSet<>();
        for (GlyphEntry e : buffer) {
            set.add(e.cluster());
        }
        List<Integer> out = new ArrayList<>(set);
        out.sort(Integer::compareTo);
        return out;
    }

    // ---- §19.3: ligatures ---------------------------------------------------

    public static List<GlyphEntry> applyLigatures(Font font, List<GlyphEntry> buffer) {
        List<Ligature> rules = new ArrayList<>(font.ligatures);
        rules.sort((a, b) -> b.parts().size() - a.parts().size());
        List<GlyphEntry> out = new ArrayList<>();
        int i = 0;
        while (i < buffer.size()) {
            Ligature matched = null;
            for (Ligature rule : rules) {
                int len = rule.parts().size();
                if (i + len > buffer.size()) {
                    continue;
                }
                boolean ok = true;
                for (int k = 0; k < len; k++) {
                    if (!buffer.get(i + k).glyph().equals(rule.parts().get(k))) {
                        ok = false;
                        break;
                    }
                }
                if (ok) {
                    matched = rule;
                    break;
                }
            }
            if (matched != null) {
                out.add(new GlyphEntry(matched.result(), buffer.get(i).cluster()));
                i += matched.parts().size();
            } else {
                out.add(buffer.get(i));
                i++;
            }
        }
        return out;
    }

    // ---- §19.4: arabic joining and forms -------------------------------------

    public static List<String> arabicForms(Font font, String text) {
        int n = text.length();
        String[] types = new String[n];
        for (int i = 0; i < n; i++) {
            types[i] = Fonts.joiningType(font, text.charAt(i));
        }
        List<String> out = new ArrayList<>(n);
        for (int i = 0; i < n; i++) {
            int j = i - 1;
            while (j >= 0 && types[j].equals("transparent")) {
                j--;
            }
            boolean back = (types[i].equals("dual") || types[i].equals("right"))
                    && j >= 0 && types[j].equals("dual");
            int k = i + 1;
            while (k < n && types[k].equals("transparent")) {
                k++;
            }
            boolean forward = types[i].equals("dual") && k < n
                    && (types[k].equals("dual") || types[k].equals("right"));
            out.add(back && forward ? "medi" : back ? "fina" : forward ? "init" : "isol");
        }
        return out;
    }

    public static List<GlyphEntry> applyForms(Font font, String text, List<GlyphEntry> buffer) {
        List<String> forms = arabicForms(font, text);
        List<GlyphEntry> out = new ArrayList<>(buffer.size());
        for (int i = 0; i < buffer.size(); i++) {
            GlyphEntry e = buffer.get(i);
            String form = e.cluster() < forms.size() ? forms.get(e.cluster()) : "isol";
            Map<String, String> table = font.forms.get(e.glyph());
            String newGlyph = (table != null && table.containsKey(form)) ? table.get(form) : e.glyph();
            out.add(new GlyphEntry(newGlyph, e.cluster(), e.dx(), e.dy()));
        }
        return out;
    }

    // ---- §19.5: marks ---------------------------------------------------------

    public static List<GlyphEntry> attachMarks(Font font, List<GlyphEntry> buffer) {
        List<GlyphEntry> out = new ArrayList<>(buffer);
        int lastBase = -1;
        for (int i = 0; i < out.size(); i++) {
            GlyphEntry e = out.get(i);
            if (!Fonts.isMark(font, e.glyph())) {
                lastBase = i;
                continue;
            }
            MarkAnchor ma = font.marks.get(e.glyph());
            double[] baseAnchor = null;
            if (lastBase >= 0 && ma != null) {
                Map<String, double[]> baseAnchors = font.anchors.get(out.get(lastBase).glyph());
                if (baseAnchors != null) {
                    baseAnchor = baseAnchors.get(ma.anchorClass());
                }
            }
            if (baseAnchor != null) {
                GlyphEntry base = out.get(lastBase);
                out.set(i, new GlyphEntry(e.glyph(), base.cluster(),
                        baseAnchor[0] - ma.x(), baseAnchor[1] - ma.y()));
            }
        }
        return out;
    }

    public static List<GlyphEntry> shape(Font font, String text) {
        List<GlyphEntry> buffer = glyphBuffer(font, text);
        if (!font.forms.isEmpty()) {
            buffer = applyForms(font, text, buffer);
        }
        buffer = applyLigatures(font, buffer);
        if (!font.marks.isEmpty()) {
            buffer = attachMarks(font, buffer);
        }
        return buffer;
    }

    // ---- §19.6: positioning -----------------------------------------------

    public static double bufferAdvance(Font font, List<GlyphEntry> buffer, double size, boolean kerning) {
        double total = 0;
        String prev = null;
        for (GlyphEntry e : buffer) {
            if (Fonts.isMark(font, e.glyph())) {
                continue;
            }
            if (kerning && prev != null) {
                total += Fonts.kern(font, prev, e.glyph()) * size / font.unitsPerEm;
            }
            total += Glyphs.penAdvance(font, e.glyph(), size);
            prev = e.glyph();
        }
        return total;
    }

    public static List<Placement> position(Font font, List<GlyphEntry> buffer, double size, double x, double y,
                                            String direction, boolean kerning) {
        double scale = size / font.unitsPerEm;
        boolean rtl = direction.equals("rtl");
        Placement[] out = new Placement[buffer.size()];
        double pen = rtl ? x + bufferAdvance(font, buffer, size, kerning) : x;
        String prev = null;
        Placement lastBase = null;
        for (int i = 0; i < buffer.size(); i++) {
            GlyphEntry e = buffer.get(i);
            if (Fonts.isMark(font, e.glyph())) {
                double baseX = lastBase != null ? lastBase.x() : x;
                out[i] = new Placement(e.glyph(), baseX + e.dx() * scale, y - e.dy() * scale);
                continue;
            }
            Placement p;
            if (rtl) {
                if (kerning && prev != null) {
                    pen -= Fonts.kern(font, prev, e.glyph()) * scale;
                }
                pen -= Glyphs.penAdvance(font, e.glyph(), size);
                p = new Placement(e.glyph(), pen, y);
            } else {
                if (kerning && prev != null) {
                    pen += Fonts.kern(font, prev, e.glyph()) * scale;
                }
                p = new Placement(e.glyph(), pen, y);
                pen += Glyphs.penAdvance(font, e.glyph(), size);
            }
            out[i] = p;
            lastBase = p;
            prev = e.glyph();
        }
        return List.of(out);
    }

    public static List<Integer> caretOffsets(List<GlyphEntry> buffer, int length) {
        List<Integer> out = new ArrayList<>(clusters(buffer));
        out.add(length);
        return out;
    }

    /**
     * §19.6: caret_positions -- for each cluster, the pen where its first
     * non-mark glyph was placed (ltr) or that glyph's own right edge,
     * origin plus its own advance (rtl, independent of any kern pull from
     * the glyph after it); a cluster with no non-mark entry (an
     * unattached mark on its own) falls back to that entry's own
     * placement. Then the pen after the last glyph: x plus the buffer's
     * advance for ltr, x for rtl.
     */
    public static List<Double> caretPositions(Font font, List<GlyphEntry> buffer, int length, double size, double x,
                                               String direction, boolean kerning) {
        List<Placement> run = position(font, buffer, size, x, 0, direction, kerning);
        boolean ltr = direction.equals("ltr");
        List<Double> out = new ArrayList<>();
        for (int cluster : clusters(buffer)) {
            Double value = null;
            for (int i = 0; i < buffer.size(); i++) {
                GlyphEntry e = buffer.get(i);
                if (e.cluster() == cluster && !Fonts.isMark(font, e.glyph())) {
                    double px = run.get(i).x();
                    value = ltr ? px : px + Glyphs.penAdvance(font, e.glyph(), size);
                    break;
                }
            }
            if (value == null) {
                for (int j = 0; j < buffer.size(); j++) {
                    if (buffer.get(j).cluster() == cluster) {
                        value = run.get(j).x();
                        break;
                    }
                }
            }
            out.add(value);
        }
        double total = bufferAdvance(font, buffer, size, kerning);
        out.add(ltr ? x + total : x);
        return out;
    }
}
