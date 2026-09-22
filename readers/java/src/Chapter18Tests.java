import java.io.IOException;
import java.nio.file.Files;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter18-*.feature into a Java test. No JUnit, no network: run
 * from the project root so reference/chapter-16 and reference/chapter-18
 * resolve.
 */
public final class Chapter18Tests {

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

    private static void assertColorEq(String what, Color actual, Color expected) {
        assertColorEq(what, actual, expected, Numbers.DEFAULT_EPSILON);
    }

    private static void assertColorEq(String what, Color actual, Color expected, double eps) {
        if (!actual.approxEquals(expected, eps)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
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

    private static Font font;

    private static Font font() throws IOException {
        if (font == null) {
            font = Fonts.loadFont(Files.readString(java.nio.file.Path.of("reference/chapter-16/roboto.json")));
        }
        return font;
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerMetrics();
        registerKerning();
        registerBreaking();
        registerAligning();
        registerPlate();
    }

    // features/chapter18-metrics.feature
    private static void registerMetrics() {
        scenario("Metrics: the vertical metrics in pixels", () -> {
            Font f = font();
            assertDoubleEq("ascent(font, 16)", Layout.ascent(f, 16), 14.8438, 0.0001);
            assertDoubleEq("descent(font, 16)", Layout.descent(f, 16), 3.9063, 0.0001);
            assertDoubleEq("line_height(font, 16)", Layout.lineHeight(f, 16), 18.75);
            assertDoubleEq("line_height(font, 14)", Layout.lineHeight(f, 14), 16.4063, 0.0001);
            assertDoubleEq("line_height(font, 16) = ascent(font, 16) + descent(font, 16)",
                    Layout.lineHeight(f, 16), Layout.ascent(f, 16) + Layout.descent(f, 16));
        });

        scenario("Metrics: a run is one placement per character, each an advance further along", () -> {
            Font f = font();
            List<Placement> run = Layout.layoutRun(f, "Ha", 11, 2, 11, false);
            assertEquals("length(run)", run.size(), 2);
            assertEquals("run[0].name", run.get(0).name(), "H");
            assertDoubleEq("run[0].x", run.get(0).x(), 2);
            assertDoubleEq("run[0].y", run.get(0).y(), 11);
            assertEquals("run[1].name", run.get(1).name(), "a");
            assertDoubleEq("run[1].x = 2 + pen_advance(font, \"H\", 11)", run.get(1).x(),
                    2 + Glyphs.penAdvance(f, "H", 11));
            assertDoubleEq("run[1].x", run.get(1).x(), 9.8418, 0.0001);
            assertDoubleEq("run[1].y", run.get(1).y(), 11);
            assertDoubleEq("run_advance(font, \"Ha\", 11, false)", Layout.runAdvance(f, "Ha", 11, false),
                    13.8252, 0.0001);
            assertDoubleEq("run_advance = pen_advance(H) + pen_advance(a)",
                    Layout.runAdvance(f, "Ha", 11, false),
                    Glyphs.penAdvance(f, "H", 11) + Glyphs.penAdvance(f, "a", 11));
        });

        scenario("Metrics: spaces are placed, and so is a character the font doesn't have", () -> {
            Font f = font();
            List<Placement> run = Layout.layoutRun(f, "a☃b", 11, 0, 0, false);
            assertEquals("length(run)", run.size(), 3);
            assertEquals("run[1].name", run.get(1).name(), ".notdef");
            assertDoubleEq("run[1].x", run.get(1).x(), 5.9834, 0.0001);
            assertEquals("run[2].name", run.get(2).name(), "b");
            assertDoubleEq("run[2].x", run.get(2).x(), 10.8604, 0.0001);
            assertEquals("layout_run(font, \"a b\", 11, 0, 0, false)[1].name",
                    Layout.layoutRun(f, "a b", 11, 0, 0, false).get(1).name(), "space");
            assertDoubleEq("layout_run(font, \"a b\", 11, 0, 0, false)[2].x",
                    Layout.layoutRun(f, "a b", 11, 0, 0, false).get(2).x(),
                    5.9834 + Glyphs.penAdvance(f, "space", 11), 0.0001);
            assertEquals("length(layout_run(font, \"\", 11, 0, 0, false))",
                    Layout.layoutRun(f, "", 11, 0, 0, false).size(), 0);
            assertDoubleEq("run_advance(font, \"\", 11, false)", Layout.runAdvance(f, "", 11, false), 0);
        });

        scenario("Metrics: without kerning the run's advance is the sum of the glyph advances", () -> {
            Font f = font();
            assertDoubleEq("run_advance(font, \"TAVERN\", 64, false)",
                    Layout.runAdvance(f, "TAVERN", 64, false), 242.0625);
            assertDoubleEq("layout_run(font, \"TAVERN\", 64, 12, 70, false)[5].x",
                    Layout.layoutRun(f, "TAVERN", 64, 12, 70, false).get(5).x(), 208.4375);
        });
    }

    // features/chapter18-kerning.feature
    private static void registerKerning() {
        scenario("Kerning: the font's kern pairs, in font units", () -> {
            Font f = font();
            assertDoubleEq("kern(font, \"T\", \"A\")", Fonts.kern(f, "T", "A"), -79);
            assertDoubleEq("kern(font, \"A\", \"V\")", Fonts.kern(f, "A", "V"), -87);
            assertDoubleEq("kern(font, \"A\", \"T\")", Fonts.kern(f, "A", "T"), -129);
            assertDoubleEq("kern(font, \"V\", \"E\")", Fonts.kern(f, "V", "E"), 0);
            assertDoubleEq("kern(font, \"H\", \"a\")", Fonts.kern(f, "H", "a"), 0);
            assertDoubleEq("kern(font, \"space\", \"T\")", Fonts.kern(f, "space", "T"), -40);
        });

        scenario("Kerning: a kerned pair is narrower than the unkerned sum by exactly the kern", () -> {
            Font f = font();
            assertDoubleEq("run_advance(font, \"Wa\", 11, false)", Layout.runAdvance(f, "Wa", 11, false),
                    15.7427, 0.0001);
            assertDoubleEq("run_advance(font, \"Wa\", 11, true)", Layout.runAdvance(f, "Wa", 11, true),
                    15.5654, 0.0001);
            assertDoubleEq("run_advance(font, \"Wa\", 11, true) = ... + kern * 11 / 2048",
                    Layout.runAdvance(f, "Wa", 11, true),
                    Layout.runAdvance(f, "Wa", 11, false) + Fonts.kern(f, "W", "a") * 11 / 2048);
            assertDoubleEq("run_advance(font, \"Ha\", 11, true) = run_advance(font, \"Ha\", 11, false)",
                    Layout.runAdvance(f, "Ha", 11, true), Layout.runAdvance(f, "Ha", 11, false));
        });

        scenario("Kerning: the pen moves by the pair before the second glyph is placed", () -> {
            Font f = font();
            List<Placement> kerned = Layout.layoutRun(f, "TAVERN", 64, 12, 70, true);
            List<Placement> plain = Layout.layoutRun(f, "TAVERN", 64, 12, 70, false);
            assertDoubleEq("kerned[0].x", kerned.get(0).x(), 12);
            assertDoubleEq("kerned[1].x", kerned.get(1).x(), 47.7188, 0.0001);
            assertDoubleEq("kerned[1].x = plain[1].x + kern(font, \"T\", \"A\") * 64 / 2048",
                    kerned.get(1).x(), plain.get(1).x() + Fonts.kern(f, "T", "A") * 64 / 2048);
            assertDoubleEq("kerned[2].x", kerned.get(2).x(), 86.75);
            assertDoubleEq("kerned[3].x", kerned.get(3).x(), 127.4688, 0.0001);
            assertDoubleEq("kerned[5].x", kerned.get(5).x(), 203.25);
            assertDoubleEq("plain[5].x", plain.get(5).x(), 208.4375);
            assertDoubleEq("run_advance(font, \"TAVERN\", 64, true)",
                    Layout.runAdvance(f, "TAVERN", 64, true), 236.875);
            assertDoubleEq("run_advance(false) - run_advance(true)",
                    Layout.runAdvance(f, "TAVERN", 64, false) - Layout.runAdvance(f, "TAVERN", 64, true),
                    5.1875);
        });
    }

    // features/chapter18-breaking.feature
    private static void registerBreaking() {
        scenario("Breaking: greedy breaking at three measures", () -> {
            Font f = font();
            String text = "the quick brown fox jumps over the lazy dog";
            assertEquals("break_lines(..., 100, true)", Layout.breakLines(f, text, 11, 100, true),
                    List.of("the quick brown fox", "jumps over the lazy", "dog"));
            assertEquals("break_lines(..., 60, true)", Layout.breakLines(f, text, 11, 60, true),
                    List.of("the quick", "brown fox", "jumps over", "the lazy dog"));
            assertEquals("break_lines(..., 150, true)", Layout.breakLines(f, text, 11, 150, true),
                    List.of("the quick brown fox jumps", "over the lazy dog"));
            assertTrue("run_advance(\"the quick brown fox\") <= 100",
                    Layout.runAdvance(f, "the quick brown fox", 11, true) <= 100);
            assertTrue("100 <= run_advance(\"the quick brown fox jumps\")",
                    100 <= Layout.runAdvance(f, "the quick brown fox jumps", 11, true));
        });

        scenario("Breaking: a line exactly as wide as the measure fits", () -> {
            Font f = font();
            String text = "the quick brown fox jumps over the lazy dog";
            double measure = Layout.runAdvance(f, "the quick", 11, true);
            assertDoubleEq("measure", measure, 44.521, 0.0001);
            assertEquals("break_lines(text, 11, measure, true)[0]",
                    Layout.breakLines(f, text, 11, measure, true).get(0), "the quick");
            assertEquals("length(break_lines(text, 11, measure, true))",
                    Layout.breakLines(f, text, 11, measure, true).size(), 6);
            assertEquals("break_lines(text, 11, measure - 0.01, true)[0]",
                    Layout.breakLines(f, text, 11, measure - 0.01, true).get(0), "the");
            assertEquals("length(break_lines(text, 11, measure - 0.01, true))",
                    Layout.breakLines(f, text, 11, measure - 0.01, true).size(), 7);
        });

        scenario("Breaking: a word wider than the measure sits alone and overflows", () -> {
            Font f = font();
            assertEquals("break_lines(\"a supercalifragilistic word\", 11, 40, true)",
                    Layout.breakLines(f, "a supercalifragilistic word", 11, 40, true),
                    List.of("a", "supercalifragilistic", "word"));
            assertTrue("40 <= run_advance(\"supercalifragilistic\")",
                    40 <= Layout.runAdvance(f, "supercalifragilistic", 11, true));
        });

        scenario("Breaking: no text is no lines, and runs of spaces are one break", () -> {
            Font f = font();
            assertEquals("length(break_lines(\"\", 11, 100, true))",
                    Layout.breakLines(f, "", 11, 100, true).size(), 0);
            assertEquals("break_lines(\"  two  spaces \", 11, 100, true)",
                    Layout.breakLines(f, "  two  spaces ", 11, 100, true), List.of("two spaces"));
            assertEquals("break_lines(\"one\", 11, 1, true)",
                    Layout.breakLines(f, "one", 11, 1, true), List.of("one"));
        });
    }

    // features/chapter18-aligning.feature
    private static void registerAligning() {
        scenario("Aligning: four alignments of one short line", () -> {
            Font f = font();
            assertDoubleEq("run_advance(font, \"to be\", 11, true)", Layout.runAdvance(f, "to be", 11, true),
                    24.4814, 0.0001);
            assertDoubleEq("left[0].x", Layout.layoutLine(f, "to be", 11, 10, 20, 60, "left", true).get(0).x(), 10);
            assertDoubleEq("left[4].x", Layout.layoutLine(f, "to be", 11, 10, 20, 60, "left", true).get(4).x(),
                    28.6538, 0.0001);
            assertDoubleEq("right[0].x", Layout.layoutLine(f, "to be", 11, 10, 20, 60, "right", true).get(0).x(),
                    45.5186, 0.0001);
            assertDoubleEq("right[4].x", Layout.layoutLine(f, "to be", 11, 10, 20, 60, "right", true).get(4).x(),
                    64.1724, 0.0001);
            assertDoubleEq("center[0].x", Layout.layoutLine(f, "to be", 11, 10, 20, 60, "center", true).get(0).x(),
                    27.7593, 0.0001);
            assertDoubleEq("center[4].x", Layout.layoutLine(f, "to be", 11, 10, 20, 60, "center", true).get(4).x(),
                    46.4131, 0.0001);
            assertDoubleEq("right[4].x + pen_advance(font, \"e\", 11)",
                    Layout.layoutLine(f, "to be", 11, 10, 20, 60, "right", true).get(4).x()
                            + Glyphs.penAdvance(f, "e", 11),
                    70, 0.0001);
        });

        scenario("Aligning: justify stretches the spaces, not the letters", () -> {
            Font f = font();
            List<Placement> run = Layout.layoutLine(f, "to be", 11, 10, 20, 60, "justify", true);
            assertDoubleEq("run[0].x", run.get(0).x(), 10);
            assertDoubleEq("run[1].x", run.get(1).x(), 13.4858, 0.0001);
            assertEquals("run[2].name", run.get(2).name(), "space");
            assertDoubleEq("run[2].x", run.get(2).x(), 19.7593, 0.0001);
            assertDoubleEq("run[3].x", run.get(3).x(), 58.001, 0.0001);
            assertDoubleEq("run[4].x", run.get(4).x(), 64.1724, 0.0001);
            assertDoubleEq("run[4].x + pen_advance(font, \"e\", 11)", run.get(4).x() + Glyphs.penAdvance(f, "e", 11),
                    70, 0.0001);
            assertDoubleEq("layout_line(font, \"to\", ...justify...)[1].x",
                    Layout.layoutLine(f, "to", 11, 10, 20, 60, "justify", true).get(1).x(), 13.4858, 0.0001);
        });

        scenario("Aligning: a paragraph stacks its lines by line_height and leaves the last line ragged", () -> {
            Font f = font();
            List<Placement> run = Layout.layoutParagraph(f, "the quick brown fox jumps over the lazy dog", 11, 10,
                    20, 100, "justify", true);
            assertEquals("length(run)", run.size(), 41);
            assertEquals("run[0].name", run.get(0).name(), "t");
            assertDoubleEq("run[0].x", run.get(0).x(), 10);
            assertDoubleEq("run[0].y", run.get(0).y(), 20);
            assertEquals("run[18].name", run.get(18).name(), "x");
            assertDoubleEq("run[18].x + pen_advance(font, \"x\", 11)",
                    run.get(18).x() + Glyphs.penAdvance(f, "x", 11), 110, 0.0001);
            assertEquals("run[19].name", run.get(19).name(), "j");
            assertDoubleEq("run[19].x", run.get(19).x(), 10);
            assertDoubleEq("run[19].y", run.get(19).y(), 20 + Layout.lineHeight(f, 11));
            assertDoubleEq("run[19].y", run.get(19).y(), 32.8906, 0.0001);
            assertEquals("run[38].name", run.get(38).name(), "d");
            assertDoubleEq("run[38].x", run.get(38).x(), 10);
            assertDoubleEq("run[38].y", run.get(38).y(), 45.7813, 0.0001);
            assertEquals("run[40].name", run.get(40).name(), "g");
            assertDoubleEq("run[40].x", run.get(40).x(), 22.4771, 0.0001);
        });
    }

    // features/chapter18-plate.feature
    private static void registerPlate() {
        scenario("Plate 18: a run at whole pixels draws what chapter 17 drew", () -> {
            Font f = font();
            Canvas a = new Canvas(30, 14);
            Canvas b = new Canvas(30, 14);
            a.fill(new Color(1, 1, 1));
            b.fill(new Color(1, 1, 1));
            Layout.drawRun(a, f, Layout.layoutRun(f, "Ha", 11, 2, 11, false), 11, new Color(0, 0, 0), true);
            Figures.drawText(b, f, "Ha", 11, 2, 11, new Color(0, 0, 0), true);
            assertEquals("max_channel_difference(canvas_to_p6(a), canvas_to_p6(b))",
                    Ppm.maxChannelDifference(Ppm.canvasToP6(a), Ppm.canvasToP6(b)), 0);
            assertColorEq("pixel_at(a, 3, 6)", a.pixelAt(3, 6), new Color(0.0331, 0.0331, 0.0331));
        });

        scenario("Plate 18: the baseline rounds to a pixel row, halves up", () -> {
            Font f = font();
            Canvas a = new Canvas(30, 14);
            Canvas b = new Canvas(30, 14);
            a.fill(new Color(1, 1, 1));
            b.fill(new Color(1, 1, 1));
            Layout.drawRun(a, f, Layout.layoutRun(f, "Ha", 11, 2.4, 11.5, false), 11, new Color(0, 0, 0), true);
            Layout.drawRun(b, f, Layout.layoutRun(f, "Ha", 11, 2.4, 11.4, false), 11, new Color(0, 0, 0), true);
            assertEquals("subpixel_of(2.4)", Bitmaps.subpixelOf(2.4), new Subpixel(2, 2));
            assertColorEq("pixel_at(a, 3, 11)", a.pixelAt(3, 11), new Color(0.4077, 0.4077, 0.4077));
            assertColorEq("pixel_at(a, 3, 12)", a.pixelAt(3, 12), new Color(1, 1, 1));
            assertColorEq("pixel_at(b, 3, 11)", b.pixelAt(3, 11), new Color(1, 1, 1));
            assertColorEq("pixel_at(b, 3, 10)", b.pixelAt(3, 10), new Color(0.4077, 0.4077, 0.4077));
        });

        scenario("Plate 18: the kern pair the font asks for", () -> {
            Canvas c = Figures.kernDemo();
            byte[] ref = readReference("kerning.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 190);
            assertTriple("ppm_pixel(p6, 135, 40)", Ppm.ppmPixel(p6, 135, 40), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 135, 130)", Ppm.ppmPixel(p6, 135, 130), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 141, 130)", Ppm.ppmPixel(p6, 141, 130), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 141, 40)", Ppm.ppmPixel(p6, 141, 40), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 251, 180)", Ppm.ppmPixel(p6, 251, 180), new int[] {176, 93, 146}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 18: greedy breaking inside a measure", () -> {
            Canvas c = Figures.breakDemo();
            byte[] ref = readReference("breaking.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 340);
            assertEquals("c.height", c.height, 150);
            assertTriple("ppm_pixel(p6, 20, 60)", Ppm.ppmPixel(p6, 20, 60), new int[] {93, 167, 181}, 1);
            assertTriple("ppm_pixel(p6, 31, 28)", Ppm.ppmPixel(p6, 31, 28), new int[] {206, 206, 212}, 1);
            assertTriple("ppm_pixel(p6, 200, 140)", Ppm.ppmPixel(p6, 200, 140), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 18: a rounded pen drifts", () -> {
            Font f = font();
            Canvas c = Figures.driftDemo();
            byte[] ref = readReference("drift.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertDoubleEq("pen_advance(font, \"i\", 11)", Glyphs.penAdvance(f, "i", 11), 2.6694, 0.0001);
            assertDoubleEq("20 * round(pen_advance(font, \"i\", 11)) - run_advance(20 i's, false)",
                    20 * Numbers.round(Glyphs.penAdvance(f, "i", 11))
                            - Layout.runAdvance(f, "iiiiiiiiiiiiiiiiiiii", 11, false),
                    6.6113, 0.0001);
            assertEquals("c.width", c.width, 780);
            assertEquals("c.height", c.height, 132);
            assertTriple("ppm_pixel(p6, 571, 30)", Ppm.ppmPixel(p6, 571, 30), new int[] {124, 225, 243}, 1);
            assertTriple("ppm_pixel(p6, 616, 90)", Ppm.ppmPixel(p6, 616, 90), new int[] {237, 124, 196}, 1);
            assertTriple("ppm_pixel(p6, 600, 120)", Ppm.ppmPixel(p6, 600, 120), new int[] {237, 124, 196}, 1);
            assertTriple("ppm_pixel(p6, 600, 60)", Ppm.ppmPixel(p6, 600, 60), new int[] {255, 255, 255}, 0);
            assertTriple("ppm_pixel(p6, 21, 40)", Ppm.ppmPixel(p6, 21, 40), new int[] {114, 114, 114}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 18: Plate 18", () -> {
            Canvas c = Figures.plate18();
            byte[] ref = readReference("plate-18.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 660);
            assertEquals("c.height", c.height, 236);
            assertTriple("ppm_pixel(p6, 340, 130)", Ppm.ppmPixel(p6, 340, 130), new int[] {72, 124, 135}, 1);
            assertTriple("ppm_pixel(p6, 24, 20)", Ppm.ppmPixel(p6, 24, 20), new int[] {55, 55, 59}, 1);
            assertTriple("ppm_pixel(p6, 5, 5)", Ppm.ppmPixel(p6, 5, 5), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference/chapter-18", filename));
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
        writeOne("kerning.ppm", Figures.kernDemo());
        writeOne("breaking.ppm", Figures.breakDemo());
        writeOne("drift.ppm", Figures.driftDemo());
        writeOne("plate-18.ppm", Figures.plate18());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
