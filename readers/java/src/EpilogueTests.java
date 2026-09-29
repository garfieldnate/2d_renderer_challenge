import java.io.IOException;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/epilogue-*.feature into a Java test. No JUnit, no network: run
 * from the project root so reference/epilogue and reference/chapter-16
 * resolve.
 */
public final class EpilogueTests {

    private interface Scenario {
        void run() throws Exception;
    }

    private static final List<String> names = new ArrayList<>();
    private static final List<Scenario> bodies = new ArrayList<>();

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

    private static String readText(String path) throws IOException {
        return Files.readString(java.nio.file.Path.of(path));
    }

    private static byte[] readBytes(String path) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of(path));
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerType();
        registerDocument();
        registerCover();
        registerGlow();
    }

    // ---- features/epilogue-type.feature -------------------------------------

    private static void registerType() {
        scenario("Type: the title breaks after \"Renderer\"", () -> {
            Font font = Fonts.loadFont(readText("reference/chapter-16/roboto.json"));
            assertEquals("break_lines(...)",
                    Layout.breakLines(font, "The 2D Renderer Challenge", 44, 400, true),
                    List.of("The 2D Renderer", "Challenge"));
            assertDoubleEq("run_advance(\"The 2D Renderer\")",
                    Layout.runAdvance(font, "The 2D Renderer", 44, true), 324.628906, 0.0001);
            assertDoubleEq("run_advance(\"The 2D Renderer Challenge\")",
                    Layout.runAdvance(font, "The 2D Renderer Challenge", 44, true), 529.267578, 0.0001);
            assertDoubleEq("line_height(font, 44)", Layout.lineHeight(font, 44), 51.5625);
        });

        scenario("Type: the second line starts at the margin, one line height down, "
                + "and the space it broke at isn't placed", () -> {
            Font font = Fonts.loadFont(readText("reference/chapter-16/roboto.json"));
            List<Placement> title = Layout.layoutParagraph(font, "The 2D Renderer Challenge", 44, 40, 530, 400,
                    "left", true);
            assertEquals("length(title)", title.size(), 24);
            assertEquals("title[14].name", title.get(14).name(), "r");
            assertDoubleEq("title[14].x", title.get(14).x(), 349.740234, 0.0001);
            assertDoubleEq("title[14].y", title.get(14).y(), 530);
            assertEquals("title[15].name", title.get(15).name(), "C");
            assertDoubleEq("title[15].x", title.get(15).x(), 40);
            assertDoubleEq("title[15].y", title.get(15).y(), 581.5625);
        });

        scenario("Type: the subtitle fits on one line", () -> {
            Font font = Fonts.loadFont(readText("reference/chapter-16/roboto.json"));
            List<Placement> sub = Layout.layoutRun(font,
                    "A test-driven guide to drawing every pixel yourself", 15, 40, 640, true);
            assertEquals("length(sub)", sub.size(), 51);
            assertDoubleEq("run_advance(sub)",
                    Layout.runAdvance(font, "A test-driven guide to drawing every pixel yourself", 15, true),
                    328.630371, 0.0001);
        });
    }

    // ---- features/epilogue-document.feature ----------------------------------

    private static void registerDocument() {
        scenario("Document: drawn by chapter 20 and nothing else", () -> {
            byte[] ref = readBytes("reference/epilogue/cover-art.ppm");
            Canvas c = SvgWalker.renderSvg(readText("reference/epilogue/cover.svg"), 480, 680);
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 480);
            assertEquals("c.height", c.height, 680);
            assertTriple("ppm_pixel(p6, 240, 8)", Ppm.ppmPixel(p6, 240, 8), new int[] {21, 19, 42}, 1);
            assertTriple("ppm_pixel(p6, 240, 670)", Ppm.ppmPixel(p6, 240, 670), new int[] {46, 22, 54}, 1);
            assertTriple("ppm_pixel(p6, 60, 60)", Ppm.ppmPixel(p6, 60, 60), new int[] {207, 121, 77}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Document: the clip rounds the panel's corner, and the rule is dashed", () -> {
            byte[] p6 = Ppm.canvasToP6(SvgWalker.renderSvg(readText("reference/epilogue/cover.svg"), 480, 680));
            assertTriple("ppm_pixel(p6, 41, 41)", Ppm.ppmPixel(p6, 41, 41), new int[] {23, 19, 43}, 1);
            assertTriple("ppm_pixel(p6, 47, 472)", Ppm.ppmPixel(p6, 47, 472), new int[] {255, 154, 82}, 1);
            assertTriple("ppm_pixel(p6, 58, 472)", Ppm.ppmPixel(p6, 58, 472), new int[] {40, 21, 51}, 1);
        });

        scenario("Document: the crop marks are one group, so where two arms cross is no brighter than one arm",
                () -> {
                    byte[] p6 = Ppm.canvasToP6(
                            SvgWalker.renderSvg(readText("reference/epilogue/cover.svg"), 480, 680));
                    assertTriple("ppm_pixel(p6, 24, 24)", Ppm.ppmPixel(p6, 24, 24), new int[] {180, 176, 171}, 1);
                    assertTriple("ppm_pixel(p6, 24, 20)", Ppm.ppmPixel(p6, 24, 20), new int[] {180, 176, 171}, 1);
                    assertTriple("ppm_pixel(p6, 20, 24)", Ppm.ppmPixel(p6, 20, 24), new int[] {180, 176, 171}, 1);
                    assertTriple("ppm_pixel(p6, 23, 20)", Ppm.ppmPixel(p6, 23, 20), new int[] {22, 19, 42}, 1);
                });
    }

    // ---- features/epilogue-cover.feature --------------------------------------

    private static void registerCover() {
        scenario("Cover: the cover", () -> {
            byte[] ref = readBytes("reference/epilogue/cover.ppm");
            Canvas c = Epilogue.bookCover();
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 480);
            assertEquals("c.height", c.height, 680);
            assertTriple("ppm_pixel(p6, 44, 499)", Ppm.ppmPixel(p6, 44, 499), new int[] {243, 239, 230}, 1);
            assertTriple("ppm_pixel(p6, 52, 551)", Ppm.ppmPixel(p6, 52, 551), new int[] {243, 239, 230}, 1);
            assertTriple("ppm_pixel(p6, 60, 540)", Ppm.ppmPixel(p6, 60, 540), new int[] {42, 21, 52}, 1);
            assertTriple("ppm_pixel(p6, 56, 639)", Ppm.ppmPixel(p6, 56, 639), new int[] {255, 155, 82}, 1);
            assertTriple("ppm_pixel(p6, 240, 8)", Ppm.ppmPixel(p6, 240, 8), new int[] {21, 19, 42}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Cover: chapter 21's tiled walker draws the cover's document byte for byte", () -> {
            Stats st = new Stats();
            String text = readText("reference/epilogue/cover.svg");
            Canvas c = SvgWalker.renderSvgWith(text, 480, 680, "tiled", st);
            assertEquals("st.cells", st.cells, 881792L);
            assertEquals("st.copies", st.copies, 205568L);
            assertTrue("byte for byte with chapter 20's whole walker",
                    Ppm.maxChannelDifference(Ppm.canvasToP6(c), Ppm.canvasToP6(SvgWalker.renderSvg(text, 480, 680)))
                            == 0);
            assertTrue("max_channel_difference(canvas_to_p6(c), cover-art.ppm) <= 1",
                    Ppm.maxChannelDifference(Ppm.canvasToP6(c), readBytes("reference/epilogue/cover-art.ppm")) <= 1);
        });
    }

    // ---- features/epilogue-glow.feature ---------------------------------------

    private static void registerGlow() {
        scenario("Glow: how the glow falls off", () -> {
            assertDoubleEq("glow_of(-3)", Epilogue.glowOf(-3), 0.45);
            assertDoubleEq("glow_of(0)", Epilogue.glowOf(0), 0.45);
            assertDoubleEq("glow_of(5)", Epilogue.glowOf(5), 0.1125);
            assertDoubleEq("glow_of(10)", Epilogue.glowOf(10), 0);
            assertDoubleEq("glow_of(12)", Epilogue.glowOf(12), 0);
        });

        scenario("Glow: at chapter 23's spread of 4 the clamp would glow, and at 8 it doesn't", () -> {
            assertDoubleEq("glow_of(4 * 44 / 32)", Epilogue.glowOf(4.0 * 44 / 32), 0.091125);
            assertDoubleEq("glow_of(8 * 44 / 32)", Epilogue.glowOf(8.0 * 44 / 32), 0);
        });

        scenario("Glow: the glow sits around the title's letters and nowhere else", () -> {
            byte[] ref = readBytes("reference/epilogue/cover-glow.ppm");
            Canvas c = Epilogue.bookCoverGlow();
            byte[] p6 = Ppm.canvasToP6(c);
            assertTriple("ppm_pixel(p6, 44, 499)", Ppm.ppmPixel(p6, 44, 499), new int[] {243, 239, 230}, 1);
            assertTriple("ppm_pixel(p6, 44, 494)", Ppm.ppmPixel(p6, 44, 494), new int[] {114, 67, 57}, 1);
            assertTriple("ppm_pixel(p6, 35, 499)", Ppm.ppmPixel(p6, 35, 499), new int[] {93, 54, 55}, 1);
            assertTriple("ppm_pixel(p6, 60, 540)", Ppm.ppmPixel(p6, 60, 540), new int[] {42, 21, 52}, 1);
            assertTriple("ppm_pixel(p6, 56, 639)", Ppm.ppmPixel(p6, 56, 639), new int[] {255, 155, 82}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    public static void main(String[] args) throws IOException {
        registerAll();

        int passed = 0;
        int failed = 0;
        long start = System.nanoTime();
        for (int i = 0; i < names.size(); i++) {
            Mixer.linearBlending = true;
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
        writeOne("cover-art.ppm", SvgWalker.renderSvg(readText("reference/epilogue/cover.svg"), 480, 680));
        writeOne("cover.ppm", Epilogue.bookCover());
        writeOne("cover-glow.ppm", Epilogue.bookCoverGlow());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
