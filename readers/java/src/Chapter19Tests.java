import java.io.IOException;
import java.nio.file.Files;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter19-*.feature into a Java test. No JUnit, no network: run
 * from the project root so reference/chapter-16, reference/chapter-19
 * resolve.
 */
public final class Chapter19Tests {

    private interface Scenario {
        void run() throws Exception;
    }

    private static final List<String> names = new java.util.ArrayList<>();
    private static final List<Scenario> bodies = new java.util.ArrayList<>();

    private static void scenario(String name, Scenario body) {
        names.add(name);
        bodies.add(body);
    }

    // ---- assertion helpers -------------------------------------------------

    private static void assertTrue(String what, boolean condition) {
        if (!condition) {
            throw new AssertionError(what);
        }
    }

    private static void assertEquals(String what, Object actual, Object expected) {
        if (!java.util.Objects.equals(actual, expected)) {
            throw new AssertionError(what + ": expected [" + expected + "] but got [" + actual + "]");
        }
    }

    private static void assertDoubleEq(String what, double actual, double expected) {
        assertDoubleEq(what, actual, expected, Numbers.DEFAULT_EPSILON);
    }

    private static void assertDoubleEq(String what, double actual, double expected, double eps) {
        if (!Numbers.approxEqual(actual, expected, eps)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual
                    + " (tolerance " + eps + ")");
        }
    }

    private static void assertTriple(String what, int[] actual, int[] expected, int tolerance) {
        for (int i = 0; i < 3; i++) {
            if (Math.abs(actual[i] - expected[i]) > tolerance) {
                throw new AssertionError(what + ": expected " + Arrays.toString(expected)
                        + " but got " + Arrays.toString(actual) + " (tolerance " + tolerance + ")");
            }
        }
    }

    private static Font roboto;
    private static Font arabic;

    private static Font roboto() throws IOException {
        if (roboto == null) {
            roboto = Fonts.loadFont(Files.readString(java.nio.file.Path.of("reference/chapter-16/roboto.json")));
        }
        return roboto;
    }

    private static Font arabic() throws IOException {
        if (arabic == null) {
            arabic = Fonts.loadFont(
                    Files.readString(java.nio.file.Path.of("reference/chapter-19/dejavu-arabic.json")));
        }
        return arabic;
    }

    // A hand-written font with two ligature rules of different lengths (and one whose
    // parts include another rule's result, "a_b" + "a" -> "a_b_a", to prove a result is
    // never fed back into the rules), a kern pair, and a mark with an anchor.
    private static final String TOY_FONT_JSON = "{\"units_per_em\": 1000, \"ascender\": 800, "
            + "\"descender\": -200, \"line_gap\": 0, "
            + "\"cmap\": {\"97\": \"a\", \"98\": \"b\", \"99\": \"c\", \"42\": \"dot\"}, "
            + "\"glyphs\": {\".notdef\": {\"advance\": 500, \"contours\": [], \"components\": []}, "
            + "\"a\": {\"advance\": 600, \"contours\": [], \"components\": []}, "
            + "\"b\": {\"advance\": 600, \"contours\": [], \"components\": []}, "
            + "\"c\": {\"advance\": 600, \"contours\": [], \"components\": []}, "
            + "\"a_b\": {\"advance\": 900, \"contours\": [], \"components\": []}, "
            + "\"a_b_c\": {\"advance\": 1200, \"contours\": [], \"components\": []}, "
            + "\"a_b_a\": {\"advance\": 1500, \"contours\": [], \"components\": []}, "
            + "\"dot\": {\"advance\": 0, \"contours\": [], \"components\": []}}, "
            + "\"kern\": [[\"a\", \"b\", -100]], "
            + "\"ligatures\": [[[\"a\", \"b\"], \"a_b\"], [[\"a\", \"b\", \"c\"], \"a_b_c\"], "
            + "[[\"a_b\", \"a\"], \"a_b_a\"]], "
            + "\"marks\": {\"dot\": [\"above\", 0, 0]}, "
            + "\"anchors\": {\"a\": {\"above\": [300, 700]}}}";

    private static Font toy;

    private static Font toyFont() {
        if (toy == null) {
            toy = Fonts.loadFont(TOY_FONT_JSON);
        }
        return toy;
    }

    // codepoints, spelled out so the source stays readable without relying on the terminal's encoding
    private static final String KAF = "ك";
    private static final String KASRA = "ِ";
    private static final String TEH = "ت";
    private static final String ALEF = "ا";
    private static final String BEH = "ب";
    private static final String FATHA = "َ";
    private static final String SHADDA = "ّ";
    private static final String SEEN = "س";
    private static final String LAM = "ل";
    private static final String MEEM = "م";
    private static final String KITAB = KAF + KASRA + TEH + ALEF + BEH; // kitab, "book"
    private static final String SALAAM = SEEN + LAM + ALEF + MEEM;

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerItemize();
        registerBuffer();
        registerLigatures();
        registerArabic();
        registerMarks();
        registerPosition();
        registerPlate();
    }

    // features/chapter19-itemize.feature
    private static void registerItemize() {
        scenario("Itemize: letters have a script; spaces and punctuation don't", () -> {
            assertEquals("script_of(65)", Shaping.scriptOf(65), "latin");
            assertEquals("script_of(233)", Shaping.scriptOf(233), "latin");
            assertEquals("script_of(1603)", Shaping.scriptOf(1603), "arabic");
            assertEquals("script_of(32)", Shaping.scriptOf(32), "common");
            assertEquals("script_of(44)", Shaping.scriptOf(44), "common");
            assertEquals("script_of(51)", Shaping.scriptOf(51), "common");
        });

        scenario("Itemize: a Latin run and an Arabic run, the punctuation going with the run before it", () -> {
            List<Item> items = Shaping.itemize("Book: " + KITAB + ".");
            assertEquals("length(items)", items.size(), 2);
            assertEquals("items[0].start", items.get(0).start(), 0);
            assertEquals("items[0].end", items.get(0).end(), 6);
            assertEquals("items[0].text", items.get(0).text(), "Book: ");
            assertEquals("items[0].script", items.get(0).script(), "latin");
            assertEquals("items[0].direction", items.get(0).direction(), "ltr");
            assertEquals("items[1].start", items.get(1).start(), 6);
            assertEquals("items[1].end", items.get(1).end(), 12);
            assertEquals("items[1].text", items.get(1).text(), KITAB + ".");
            assertEquals("items[1].script", items.get(1).script(), "arabic");
            assertEquals("items[1].direction", items.get(1).direction(), "rtl");
        });

        scenario("Itemize: one script is one item, and common characters alone are Latin", () -> {
            assertEquals("length(itemize(kitab))", Shaping.itemize(KITAB).size(), 1);
            assertEquals("itemize(kitab)[0].direction", Shaping.itemize(KITAB).get(0).direction(), "rtl");
            assertEquals("length(itemize(\"  12 \"))", Shaping.itemize("  12 ").size(), 1);
            assertEquals("itemize(\"  12 \")[0].script", Shaping.itemize("  12 ").get(0).script(), "latin");
            assertEquals("itemize(\"  12 \")[0].end", Shaping.itemize("  12 ").get(0).end(), 5);
            assertEquals("length(itemize(\"\"))", Shaping.itemize("").size(), 0);
            assertEquals("length(itemize(\"a\" + kitab + \"b\"))", Shaping.itemize("a" + KITAB + "b").size(), 3);
            assertEquals("itemize(\"a\" + kitab + \"b\")[2].text",
                    Shaping.itemize("a" + KITAB + "b").get(2).text(), "b");
            assertEquals("itemize(\"a\" + kitab + \"b\")[2].start",
                    Shaping.itemize("a" + KITAB + "b").get(2).start(), 6);
        });
    }

    // features/chapter19-buffer.feature
    private static void registerBuffer() {
        scenario("Buffer: one entry per character, each its own cluster", () -> {
            Font f = roboto();
            List<GlyphEntry> b = Shaping.glyphBuffer(f, "office");
            assertEquals("length(b)", b.size(), 6);
            assertEquals("b[0].glyph", b.get(0).glyph(), "o");
            assertEquals("b[0].cluster", b.get(0).cluster(), 0);
            assertEquals("b[3].glyph", b.get(3).glyph(), "i");
            assertEquals("b[3].cluster", b.get(3).cluster(), 3);
            assertEquals("clusters(b)", Shaping.clusters(b), List.of(0, 1, 2, 3, 4, 5));
            assertEquals("glyph_buffer(font, \"a\\u2603\")[1].glyph",
                    Shaping.glyphBuffer(f, "a☃").get(1).glyph(), ".notdef");
            assertEquals("length(glyph_buffer(font, \"\"))", Shaping.glyphBuffer(f, "").size(), 0);
        });
    }

    // features/chapter19-ligatures.feature
    private static void registerLigatures() {
        scenario("Ligatures: f + i produces one glyph with a two-character cluster", () -> {
            Font f = roboto();
            List<GlyphEntry> b = Shaping.applyLigatures(f, Shaping.glyphBuffer(f, "office"));
            assertEquals("length(b)", b.size(), 5);
            assertEquals("b[1].glyph", b.get(1).glyph(), "f");
            assertEquals("b[1].cluster", b.get(1).cluster(), 1);
            assertEquals("b[2].glyph", b.get(2).glyph(), "f_i");
            assertEquals("b[2].cluster", b.get(2).cluster(), 2);
            assertEquals("b[3].glyph", b.get(3).glyph(), "c");
            assertEquals("b[3].cluster", b.get(3).cluster(), 4);
            assertEquals("clusters(b)", Shaping.clusters(b), List.of(0, 1, 2, 4, 5));
        });

        scenario("Ligatures: the walk is greedy from the left and a result is not fed back in", () -> {
            Font f = roboto();
            List<GlyphEntry> waffle = Shaping.applyLigatures(f, Shaping.glyphBuffer(f, "waffle"));
            assertEquals("waffle[3].glyph", waffle.get(3).glyph(), "f_l");
            assertEquals("waffle[3].cluster", waffle.get(3).cluster(), 3);
            assertEquals("clusters(waffle)", Shaping.clusters(waffle), List.of(0, 1, 2, 3, 5));
            List<GlyphEntry> fig = Shaping.applyLigatures(f, Shaping.glyphBuffer(f, "fig"));
            assertEquals("fig[0].glyph", fig.get(0).glyph(), "f_i");
            assertEquals("fig[0].cluster", fig.get(0).cluster(), 0);
            assertEquals("fig[1].cluster", fig.get(1).cluster(), 2);
            assertEquals("length(apply_ligatures(font, glyph_buffer(font, \"off\")))",
                    Shaping.applyLigatures(f, Shaping.glyphBuffer(f, "off")).size(), 3);
        });

        scenario("Ligatures: a ligature is narrower than its parts", () -> {
            Font f = roboto();
            assertDoubleEq("glyph_advance(font, \"f_i\")", Fonts.glyphAdvance(f, "f_i"), 1134);
            assertDoubleEq("glyph_advance(font, \"f\") + glyph_advance(font, \"i\")",
                    Fonts.glyphAdvance(f, "f") + Fonts.glyphAdvance(f, "i"), 1208);
        });

        scenario("Ligatures: the longest rule that matches wins, on a font written by hand to have two", () -> {
            Font f = toyFont();
            List<GlyphEntry> abc = Shaping.applyLigatures(f, Shaping.glyphBuffer(f, "abc"));
            assertEquals("length(apply_ligatures(toy, glyph_buffer(toy, \"abc\")))", abc.size(), 1);
            assertEquals("abc[0].glyph", abc.get(0).glyph(), "a_b_c");
            assertEquals("abc[0].cluster", abc.get(0).cluster(), 0);
            List<GlyphEntry> abcab = Shaping.applyLigatures(f, Shaping.glyphBuffer(f, "abcab"));
            assertEquals("abcab[1].glyph", abcab.get(1).glyph(), "a_b");
            assertEquals("abcab[1].cluster", abcab.get(1).cluster(), 3);
            assertEquals("length(apply_ligatures(toy, glyph_buffer(toy, \"acb\")))",
                    Shaping.applyLigatures(f, Shaping.glyphBuffer(f, "acb")).size(), 3);
        });

        scenario("Ligatures: a result is never fed back into the rules", () -> {
            Font f = toyFont();
            List<GlyphEntry> b = Shaping.applyLigatures(f, Shaping.glyphBuffer(f, "aba"));
            assertEquals("length(b)", b.size(), 2);
            assertEquals("b[0].glyph", b.get(0).glyph(), "a_b");
            assertEquals("b[1].glyph", b.get(1).glyph(), "a");
            assertEquals("b[1].cluster", b.get(1).cluster(), 2);
        });
    }

    // features/chapter19-arabic.feature
    private static void registerArabic() {
        scenario("Arabic: the joining types", () -> {
            Font f = arabic();
            assertEquals("joining_type(font, 1603)", Fonts.joiningType(f, 1603), "dual");
            assertEquals("joining_type(font, 1575)", Fonts.joiningType(f, 1575), "right");
            assertEquals("joining_type(font, 1616)", Fonts.joiningType(f, 1616), "transparent");
            assertEquals("joining_type(font, 1569)", Fonts.joiningType(f, 1569), "none");
            assertEquals("joining_type(font, 1600)", Fonts.joiningType(f, 1600), "dual");
            assertEquals("joining_type(font, 32)", Fonts.joiningType(f, 32), "none");
            assertEquals("joining_type(font, 65)", Fonts.joiningType(f, 65), "none");
        });

        scenario("Arabic: an Arabic letter selects its form by its neighbours", () -> {
            Font f = arabic();
            assertEquals("arabic_forms(font, beh)", Shaping.arabicForms(f, BEH), List.of("isol"));
            assertEquals("arabic_forms(font, beh+beh)", Shaping.arabicForms(f, BEH + BEH), List.of("init", "fina"));
            assertEquals("arabic_forms(font, beh x3)", Shaping.arabicForms(f, BEH + BEH + BEH),
                    List.of("init", "medi", "fina"));
            assertEquals("arabic_forms(font, beh+alef+beh)", Shaping.arabicForms(f, BEH + ALEF + BEH),
                    List.of("init", "fina", "isol"));
            assertEquals("arabic_forms(font, beh+space+beh)", Shaping.arabicForms(f, BEH + " " + BEH),
                    List.of("isol", "isol", "isol"));
            assertEquals("arabic_forms(font, salaam)", Shaping.arabicForms(f, SALAAM),
                    List.of("init", "medi", "fina", "isol"));
        });

        scenario("Arabic: a vowel mark is transparent: the letters join across it", () -> {
            Font f = arabic();
            assertEquals("arabic_forms(font, kitab)", Shaping.arabicForms(f, KITAB),
                    List.of("init", "isol", "medi", "fina", "isol"));
            assertEquals("arabic_forms(font, kaf+teh+alef+beh)",
                    Shaping.arabicForms(f, KAF + TEH + ALEF + BEH), List.of("init", "medi", "fina", "isol"));
        });

        scenario("Arabic: the forms table swaps glyphs, and leaves alone what it has no form for", () -> {
            Font f = arabic();
            List<GlyphEntry> b = Shaping.applyForms(f, KITAB, Shaping.glyphBuffer(f, KITAB));
            assertEquals("b[0].glyph", b.get(0).glyph(), "kaf.init");
            assertEquals("b[1].glyph", b.get(1).glyph(), "kasra");
            assertEquals("b[2].glyph", b.get(2).glyph(), "teh.medi");
            assertEquals("b[3].glyph", b.get(3).glyph(), "alef.fina");
            assertEquals("b[4].glyph", b.get(4).glyph(), "beh");
            assertEquals("b[4].cluster", b.get(4).cluster(), 4);
            assertEquals("font.forms[\"kaf\"][\"medi\"]", f.forms.get("kaf").get("medi"), "kaf.medi");
            assertEquals("font.forms[\"alef\"][\"fina\"]", f.forms.get("alef").get("fina"), "alef.fina");
            assertDoubleEq("glyph_advance(font, \"kaf\")", Fonts.glyphAdvance(f, "kaf"), 1688);
            assertDoubleEq("glyph_advance(font, \"kaf.init\")", Fonts.glyphAdvance(f, "kaf.init"), 975);
        });

        scenario("Arabic: lam and alef ligate after their forms are chosen", () -> {
            Font f = arabic();
            List<GlyphEntry> b = Shaping.applyLigatures(f, Shaping.applyForms(f, SALAAM, Shaping.glyphBuffer(f, SALAAM)));
            assertEquals("length(b)", b.size(), 3);
            assertEquals("b[0].glyph", b.get(0).glyph(), "seen.init");
            assertEquals("b[1].glyph", b.get(1).glyph(), "lam_alef.fina");
            assertEquals("b[1].cluster", b.get(1).cluster(), 1);
            assertEquals("b[2].glyph", b.get(2).glyph(), "meem");
            assertEquals("b[2].cluster", b.get(2).cluster(), 3);
            Ligature rule = f.ligatures.get(1);
            assertEquals("font.ligatures[1].parts", rule.parts(), List.of("lam.medi", "alef.fina"));
            assertEquals("font.ligatures[1].result", rule.result(), "lam_alef.fina");
        });
    }

    // features/chapter19-marks.feature
    private static void registerMarks() {
        scenario("Marks: the anchors, in font units", () -> {
            Font f = arabic();
            assertEquals("font.marks[\"kasra\"].anchorClass", f.marks.get("kasra").anchorClass(), "below");
            assertDoubleEq("font.marks[\"kasra\"].x", f.marks.get("kasra").x(), 512);
            assertDoubleEq("font.marks[\"kasra\"].y", f.marks.get("kasra").y(), 0);
            assertEquals("font.marks[\"fatha\"].anchorClass", f.marks.get("fatha").anchorClass(), "above");
            assertDoubleEq("font.marks[\"fatha\"].x", f.marks.get("fatha").x(), 512);
            assertDoubleEq("font.marks[\"fatha\"].y", f.marks.get("fatha").y(), 1200);
            assertTrue("font.anchors[\"kaf.init\"][\"below\"] = (300, -150)",
                    Arrays.equals(f.anchors.get("kaf.init").get("below"), new double[] {300, -150}));
            assertTrue("font.anchors[\"kaf.init\"][\"above\"] = (250, 1550)",
                    Arrays.equals(f.anchors.get("kaf.init").get("above"), new double[] {250, 1550}));
            assertTrue("font.anchors[\"beh\"][\"above\"] = (900, 1000)",
                    Arrays.equals(f.anchors.get("beh").get("above"), new double[] {900, 1000}));
            assertDoubleEq("glyph_advance(font, \"kasra\")", Fonts.glyphAdvance(f, "kasra"), 0);
            assertTrue("is_mark(font, \"kasra\")", Fonts.isMark(f, "kasra"));
            assertTrue("!is_mark(font, \"kaf\")", !Fonts.isMark(f, "kaf"));
        });

        scenario("Marks: a mark's anchor lands on its base's, and it joins the base's cluster", () -> {
            Font f = arabic();
            List<GlyphEntry> b = Shaping.shape(f, KITAB);
            assertEquals("length(b)", b.size(), 5);
            assertEquals("b[0].glyph", b.get(0).glyph(), "kaf.init");
            assertEquals("b[0].cluster", b.get(0).cluster(), 0);
            assertEquals("b[1].glyph", b.get(1).glyph(), "kasra");
            assertEquals("b[1].cluster", b.get(1).cluster(), 0);
            assertDoubleEq("b[1].dx", b.get(1).dx(), -212);
            assertDoubleEq("b[1].dy", b.get(1).dy(), -150);
            assertEquals("b[2].glyph", b.get(2).glyph(), "teh.medi");
            assertEquals("b[2].cluster", b.get(2).cluster(), 2);
            assertDoubleEq("b[2].dx", b.get(2).dx(), 0);
            assertEquals("clusters(b)", Shaping.clusters(b), List.of(0, 2, 3, 4));
        });

        scenario("Marks: two marks on one base both take its anchor; a mark with no base stays put", () -> {
            Font f = arabic();
            List<GlyphEntry> b = Shaping.shape(f, BEH + FATHA + SHADDA);
            assertEquals("length(b)", b.size(), 3);
            assertEquals("b[1].glyph", b.get(1).glyph(), "fatha");
            assertDoubleEq("b[1].dx", b.get(1).dx(), 388);
            assertDoubleEq("b[1].dy", b.get(1).dy(), -200);
            assertEquals("b[2].glyph", b.get(2).glyph(), "shadda");
            assertDoubleEq("b[2].dx", b.get(2).dx(), 388);
            assertDoubleEq("b[2].dy", b.get(2).dy(), -200);
            assertEquals("b[2].cluster", b.get(2).cluster(), 0);

            List<GlyphEntry> kb = Shaping.shape(f, KASRA + BEH);
            assertEquals("shape(kasra+beh)[0].glyph", kb.get(0).glyph(), "kasra");
            assertEquals("shape(kasra+beh)[0].cluster", kb.get(0).cluster(), 0);
            assertDoubleEq("shape(kasra+beh)[0].dx", kb.get(0).dx(), 0);
            assertEquals("shape(kasra+beh)[1].cluster", kb.get(1).cluster(), 1);
        });

        scenario("Marks: shaping Latin is ligatures alone", () -> {
            Font f = roboto();
            List<GlyphEntry> b = Shaping.shape(f, "office");
            assertEquals("length(b)", b.size(), 5);
            assertEquals("b[2].glyph", b.get(2).glyph(), "f_i");
            assertEquals("b[2].cluster", b.get(2).cluster(), 2);
            assertTrue("!is_mark(font, \"f_i\")", !Fonts.isMark(f, "f_i"));
        });

        scenario("Marks: shape chooses the forms before it looks for ligatures", () -> {
            Font f = arabic();
            List<GlyphEntry> b = Shaping.shape(f, SALAAM);
            assertEquals("length(b)", b.size(), 3);
            assertEquals("b[0].glyph", b.get(0).glyph(), "seen.init");
            assertEquals("b[1].glyph", b.get(1).glyph(), "lam_alef.fina");
            assertEquals("b[1].cluster", b.get(1).cluster(), 1);
            assertEquals("b[2].glyph", b.get(2).glyph(), "meem");
            assertEquals("clusters(b)", Shaping.clusters(b), List.of(0, 1, 3));
        });
    }

    // features/chapter19-position.feature
    private static void registerPosition() {
        scenario("Position: a buffer straight from the cmap positions exactly as layout_run lays it out", () -> {
            Font f = roboto();
            List<Placement> run = Shaping.position(f, Shaping.glyphBuffer(f, "TAVERN"), 64, 12, 70, "ltr", true);
            assertEquals("length(run)", run.size(), 6);
            assertEquals("run[1].name", run.get(1).name(), "A");
            assertDoubleEq("run[1].x", run.get(1).x(), Layout.layoutRun(f, "TAVERN", 64, 12, 70, true).get(1).x());
            assertDoubleEq("run[5].x", run.get(5).x(), 203.25);
            assertDoubleEq("buffer_advance(font, glyph_buffer(font, \"TAVERN\"), 64, true)",
                    Shaping.bufferAdvance(f, Shaping.glyphBuffer(f, "TAVERN"), 64, true),
                    Layout.runAdvance(f, "TAVERN", 64, true));
        });

        scenario("Position: a shaped Latin run is narrower by the ligature", () -> {
            Font f = roboto();
            List<GlyphEntry> b = Shaping.shape(f, "office");
            List<Placement> run = Shaping.position(f, b, 64, 20, 70, "ltr", true);
            assertDoubleEq("buffer_advance(font, b, 64, true)", Shaping.bufferAdvance(f, b, 64, true), 161.5625);
            assertDoubleEq("run_advance(font, \"office\", 64, true)", Layout.runAdvance(f, "office", 64, true),
                    163.875);
            assertEquals("run[2].name", run.get(2).name(), "f_i");
            assertDoubleEq("run[2].x", run.get(2).x(), 78.7188, 0.0001);
            assertDoubleEq("run[4].x", run.get(4).x(), 147.6563, 0.0001);
        });

        scenario("Position: right to left, the first glyph lands at the right end", () -> {
            Font f = arabic();
            List<GlyphEntry> b = Shaping.shape(f, KITAB);
            List<Placement> run = Shaping.position(f, b, 64, 20, 64, "rtl", false);
            assertDoubleEq("buffer_advance(font, b, 64, false)", Shaping.bufferAdvance(f, b, 64, false),
                    129.5313, 0.0001);
            assertEquals("run[0].name", run.get(0).name(), "kaf.init");
            assertDoubleEq("run[0].x", run.get(0).x(), 119.0625);
            assertDoubleEq("run[0].y", run.get(0).y(), 64);
            assertEquals("run[2].name", run.get(2).name(), "teh.medi");
            assertDoubleEq("run[2].x", run.get(2).x(), 99.75);
            assertDoubleEq("run[3].x", run.get(3).x(), 80.25);
            assertEquals("run[4].name", run.get(4).name(), "beh");
            assertDoubleEq("run[4].x", run.get(4).x(), 20);
            assertDoubleEq("run[0].x + pen_advance(font, \"kaf.init\", 64)",
                    run.get(0).x() + Glyphs.penAdvance(f, "kaf.init", 64),
                    20 + Shaping.bufferAdvance(f, b, 64, false));
        });

        scenario("Position: a mark sits at its base's origin plus its offset, whichever way the pen walks", () -> {
            Font f = arabic();
            List<GlyphEntry> b = Shaping.shape(f, KITAB);
            List<Placement> rtl = Shaping.position(f, b, 64, 20, 64, "rtl", false);
            List<Placement> ltr = Shaping.position(f, b, 64, 20, 64, "ltr", false);
            assertEquals("rtl[1].name", rtl.get(1).name(), "kasra");
            assertDoubleEq("rtl[1].x", rtl.get(1).x(), 112.4375);
            assertDoubleEq("rtl[1].y", rtl.get(1).y(), 68.6875);
            assertDoubleEq("rtl[1].x = rtl[0].x - 212 * 64 / 2048", rtl.get(1).x(),
                    rtl.get(0).x() - 212.0 * 64 / 2048);
            assertDoubleEq("ltr[0].x", ltr.get(0).x(), 20);
            assertDoubleEq("ltr[1].x", ltr.get(1).x(), 13.375);
            assertDoubleEq("ltr[1].y", ltr.get(1).y(), 68.6875);
            assertDoubleEq("ltr[2].x", ltr.get(2).x(), 50.4688, 0.0001);
            assertDoubleEq("ltr[4].x", ltr.get(4).x(), 89.2813, 0.0001);
        });

        scenario("Position: the cursor may stand at cluster boundaries and nowhere else", () -> {
            Font f = roboto();
            List<GlyphEntry> b = Shaping.shape(f, "office");
            assertEquals("caret_offsets(b, 6)", Shaping.caretOffsets(b, 6), List.of(0, 1, 2, 4, 5, 6));
            List<Double> positions = Shaping.caretPositions(f, b, 6, 64, 20, "ltr", true);
            double[] expected = {20, 56.5, 78.7188, 114.1563, 147.6563, 181.5625};
            assertEquals("length(caret_positions)", positions.size(), expected.length);
            for (int i = 0; i < expected.length; i++) {
                assertDoubleEq("caret_positions[" + i + "]", positions.get(i), expected[i], 0.0001);
            }
        });

        scenario("Position: cursor positions in a right-to-left run run from right to left", () -> {
            Font f = arabic();
            List<GlyphEntry> b = Shaping.shape(f, KITAB);
            assertEquals("caret_offsets(b, 5)", Shaping.caretOffsets(b, 5), List.of(0, 2, 3, 4, 5));
            List<Double> positions = Shaping.caretPositions(f, b, 5, 64, 20, "rtl", false);
            double[] expected = {149.5313, 119.0625, 99.75, 80.25, 20};
            assertEquals("length(caret_positions)", positions.size(), expected.length);
            for (int i = 0; i < expected.length; i++) {
                assertDoubleEq("caret_positions[" + i + "]", positions.get(i), expected[i], 0.0001);
            }
            assertDoubleEq("caret_positions[0] = 20 + buffer_advance(font, b, 64, false)", positions.get(0),
                    20 + Shaping.bufferAdvance(f, b, 64, false));
        });

        scenario("Position: a mark between two glyphs neither moves the pen nor breaks their kern pair", () -> {
            Font f = toyFont();
            List<GlyphEntry> b = Shaping.shape(f, "a*b");
            List<Placement> run = Shaping.position(f, b, 10, 10, 50, "ltr", true);
            assertEquals("length(b)", b.size(), 3);
            assertEquals("b[1].glyph", b.get(1).glyph(), "dot");
            assertEquals("b[1].cluster", b.get(1).cluster(), 0);
            assertDoubleEq("b[1].dx", b.get(1).dx(), 300);
            assertDoubleEq("b[1].dy", b.get(1).dy(), 700);
            assertEquals("b[2].glyph", b.get(2).glyph(), "b");
            assertDoubleEq("buffer_advance(toy, b, 10, true)", Shaping.bufferAdvance(f, b, 10, true), 11);
            assertDoubleEq("buffer_advance(toy, b, 10, false)", Shaping.bufferAdvance(f, b, 10, false), 12);
            assertDoubleEq("run[1].x", run.get(1).x(), 13);
            assertDoubleEq("run[1].y", run.get(1).y(), 43);
            assertDoubleEq("run[2].x", run.get(2).x(), 15);
            assertDoubleEq("run[2].y", run.get(2).y(), 50);
            assertDoubleList("caret_positions(toy, b, 3, 10, 10, \"ltr\", true)",
                    Shaping.caretPositions(f, b, 3, 10, 10, "ltr", true), new double[] {10, 15, 21});
            assertDoubleList("caret_positions(toy, b, 3, 10, 10, \"rtl\", true)",
                    Shaping.caretPositions(f, b, 3, 10, 10, "rtl", true), new double[] {21, 16, 10});
            assertDoubleList("caret_positions(toy, b, 3, 10, 10, \"rtl\", false)",
                    Shaping.caretPositions(f, b, 3, 10, 10, "rtl", false), new double[] {22, 16, 10});
        });
    }

    private static void assertDoubleList(String what, List<Double> actual, double[] expected) {
        assertEquals(what + ": length", actual.size(), expected.length);
        for (int i = 0; i < expected.length; i++) {
            assertDoubleEq(what + "[" + i + "]", actual.get(i), expected[i]);
        }
    }

    // features/chapter19-plate.feature
    private static void registerPlate() {
        scenario("Plate 19: the ligature and where the cursor may stand", () -> {
            Canvas c = Figures.ligatureDemo();
            byte[] ref = readReference("ligature.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 260);
            assertEquals("c.height", c.height, 100);
            assertTriple("ppm_pixel(p6, 106, 50)", Ppm.ppmPixel(p6, 106, 50), new int[] {237, 124, 196}, 1);
            assertTriple("ppm_pixel(p6, 120, 50)", Ppm.ppmPixel(p6, 120, 50), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 56, 80)", Ppm.ppmPixel(p6, 56, 80), new int[] {124, 225, 243}, 1);
            assertTriple("ppm_pixel(p6, 5, 5)", Ppm.ppmPixel(p6, 5, 5), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 19: one letter, four forms", () -> {
            Canvas c = Figures.formsDemo();
            byte[] ref = readReference("forms.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 110);
            assertTriple("ppm_pixel(p6, 50, 55)", Ppm.ppmPixel(p6, 50, 55), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 180, 55)", Ppm.ppmPixel(p6, 180, 55), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 5, 5)", Ppm.ppmPixel(p6, 5, 5), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 19: a word, right to left, with its mark attached", () -> {
            Canvas c = Figures.wordDemo();
            byte[] ref = readReference("word.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 260);
            assertEquals("c.height", c.height, 100);
            assertTriple("ppm_pixel(p6, 88, 50)", Ppm.ppmPixel(p6, 88, 50), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 133, 72)", Ppm.ppmPixel(p6, 133, 72), new int[] {237, 124, 196}, 1);
            assertTriple("ppm_pixel(p6, 5, 5)", Ppm.ppmPixel(p6, 5, 5), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 19: two scripts on one line, and the comma that jumped", () -> {
            Canvas c = Figures.mixedDemo();
            byte[] ref = readReference("mixed.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 300);
            assertEquals("c.height", c.height, 60);
            assertTriple("ppm_pixel(p6, 24, 30)", Ppm.ppmPixel(p6, 24, 30), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 155, 30)", Ppm.ppmPixel(p6, 155, 30), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 191, 30)", Ppm.ppmPixel(p6, 191, 30), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 5, 5)", Ppm.ppmPixel(p6, 5, 5), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 19: Plate 19", () -> {
            Canvas c = Figures.plate19();
            byte[] ref = readReference("plate-19.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 540);
            assertEquals("c.height", c.height, 210);
            assertTriple("ppm_pixel(p6, 24, 165)", Ppm.ppmPixel(p6, 24, 165), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 75, 165)", Ppm.ppmPixel(p6, 75, 165), new int[] {237, 124, 196}, 1);
            assertTriple("ppm_pixel(p6, 296, 165)", Ppm.ppmPixel(p6, 296, 165), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 345, 165)", Ppm.ppmPixel(p6, 345, 165), new int[] {237, 124, 196}, 1);
            assertTriple("ppm_pixel(p6, 5, 5)", Ppm.ppmPixel(p6, 5, 5), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference/chapter-19", filename));
    }

    // ---- runner ---------------------------------------------------------

    public static void main(String[] args) throws IOException {
        registerAll();

        int passed = 0;
        int failed = 0;
        long start = System.nanoTime();
        for (int i = 0; i < names.size(); i++) {
            Mixer.linearBlending = true; // reset before each scenario, per §1.7
            String name = names.get(i);
            try {
                bodies.get(i).run();
                passed++;
                System.out.println("PASS  " + name);
            } catch (Throwable t) {
                failed++;
                System.out.println("FAIL  " + name + " -- " + t.getMessage());
            }
        }
        long elapsedMs = (System.nanoTime() - start) / 1_000_000;

        System.out.println();
        System.out.println("Total: " + names.size() + "  Passed: " + passed + "  Failed: " + failed
                + "  (" + elapsedMs + " ms)");

        writeRenders();
    }

    private static void writeRenders() throws IOException {
        Files.createDirectories(java.nio.file.Path.of("out"));
        writeOne("ligature.ppm", Figures.ligatureDemo());
        writeOne("forms.ppm", Figures.formsDemo());
        writeOne("word.ppm", Figures.wordDemo());
        writeOne("mixed.ppm", Figures.mixedDemo());
        writeOne("plate-19.ppm", Figures.plate19());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
