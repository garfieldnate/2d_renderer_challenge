import java.io.IOException;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter09-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-09/*.ppm resolves.
 */
public final class Chapter09Tests {

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

    private static void assertDoubleEq(String what, double actual, double expected) {
        assertDoubleEq(what, actual, expected, Numbers.DEFAULT_EPSILON);
    }

    private static void assertDoubleEq(String what, double actual, double expected, double eps) {
        if (!Numbers.approxEqual(actual, expected, eps)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual
                    + " (tolerance " + eps + ")");
        }
    }

    private static void assertEquals(String what, Object actual, Object expected) {
        if (!actual.equals(expected)) {
            throw new AssertionError(what + ": expected [" + expected + "] but got [" + actual + "]");
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

    private static void assertPixelEq(String what, Pixel actual, Pixel expected) {
        assertPixelEq(what, actual, expected, Numbers.DEFAULT_EPSILON);
    }

    private static void assertPixelEq(String what, Pixel actual, Pixel expected, double eps) {
        if (!actual.approxEquals(expected, eps)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
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

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerPixels();
        registerOver();
        registerPorterDuff();
        registerBlend();
        registerPlate();
    }

    // features/chapter09-pixels.feature
    private static void registerPixels() {
        scenario("Pixels: a colour and an alpha premultiply into a pixel", () -> {
            Pixel p = Pixel.fromColor(new Color(1, 0, 0), 0.5);
            assertPixelEq("p", p, new Pixel(0.5, 0, 0, 0.5));
            assertDoubleEq("pixel_alpha(p)", p.pixelAlpha(), 0.5);
            assertColorEq("pixel_color(p)", p.pixelColor(), new Color(1, 0, 0));
        });

        scenario("Pixels: opaque is alpha 1 and leaves the colour alone", () -> {
            Pixel p = Pixel.opaque(new Color(0.2, 0.4, 0.8));
            assertPixelEq("p", p, new Pixel(0.2, 0.4, 0.8, 1));
            assertColorEq("pixel_color(p)", p.pixelColor(), new Color(0.2, 0.4, 0.8));
        });

        scenario("Pixels: a transparent pixel has no colour", () -> {
            assertPixelEq("CLEAR", Pixel.CLEAR, new Pixel(0, 0, 0, 0));
            assertColorEq("pixel_color(CLEAR)", Pixel.CLEAR.pixelColor(), new Color(0, 0, 0));
        });

        scenario("Pixels: averaging premultiplied pixels stays clean", () -> {
            Pixel red = Pixel.opaque(new Color(1, 0, 0));
            Pixel half = Pixel.lerpPixel(red, Pixel.CLEAR, 0.5);
            assertPixelEq("half", half, new Pixel(0.5, 0, 0, 0.5));
            assertColorEq("pixel_color(half)", half.pixelColor(), new Color(1, 0, 0));
        });

        scenario("Pixels: a pixel halfway between opaque red and opaque blue", () -> {
            Pixel m = Pixel.lerpPixel(
                    Pixel.opaque(new Color(1, 0, 0)), Pixel.opaque(new Color(0, 0, 1)), 0.5);
            assertPixelEq("m", m, new Pixel(0.5, 0, 0.5, 1));
        });
    }

    // features/chapter09-over.feature
    private static void registerOver() {
        scenario("Over: a translucent source over an opaque destination", () -> {
            Pixel src = Pixel.fromColor(new Color(1, 0, 0), 0.5);
            Pixel dst = Pixel.opaque(new Color(0, 0, 1));
            assertPixelEq("over(src, dst)", Compositing.over(src, dst), new Pixel(0.5, 0, 0.5, 1));
        });

        scenario("Over: an opaque source hides the destination", () -> {
            Pixel src = Pixel.opaque(new Color(1, 0, 0));
            Pixel dst = Pixel.opaque(new Color(0, 0, 1));
            assertPixelEq("over(src, dst)", Compositing.over(src, dst), src);
        });

        scenario("Over: a transparent source changes nothing", () -> {
            Pixel dst = Pixel.fromColor(new Color(0, 0, 1), 0.4);
            assertPixelEq("over(CLEAR, dst)", Compositing.over(Pixel.CLEAR, dst), dst);
        });

        scenario("Over: over nothing leaves the source alone", () -> {
            Pixel src = Pixel.fromColor(new Color(1, 0, 0), 0.6);
            assertPixelEq("over(src, CLEAR)", Compositing.over(src, Pixel.CLEAR), src);
        });

        scenario("Over: two translucent pixels stack their alphas", () -> {
            Pixel src = Pixel.fromColor(new Color(1, 0, 0), 0.6);
            Pixel dst = Pixel.fromColor(new Color(0, 0, 1), 0.4);
            assertPixelEq("over(src, dst)", Compositing.over(src, dst), new Pixel(0.6, 0, 0.16, 0.76));
        });
    }

    // features/chapter09-porterduff.feature
    private static final Object[][] PORTER_DUFF_TABLE = {
        {"clear", 0.0, 0.0, 0.0, 0.0},
        {"src", 0.6, 0.0, 0.0, 0.6},
        {"dst", 0.0, 0.0, 0.4, 0.4},
        {"src-over", 0.6, 0.0, 0.16, 0.76},
        {"dst-over", 0.36, 0.0, 0.4, 0.76},
        {"src-in", 0.24, 0.0, 0.0, 0.24},
        {"dst-in", 0.0, 0.0, 0.24, 0.24},
        {"src-out", 0.36, 0.0, 0.0, 0.36},
        {"dst-out", 0.0, 0.0, 0.16, 0.16},
        {"src-atop", 0.24, 0.0, 0.16, 0.4},
        {"dst-atop", 0.36, 0.0, 0.24, 0.6},
        {"xor", 0.36, 0.0, 0.16, 0.52},
    };

    private static void registerPorterDuff() {
        for (Object[] row : PORTER_DUFF_TABLE) {
            String op = (String) row[0];
            Pixel expected = new Pixel((double) row[1], (double) row[2], (double) row[3], (double) row[4]);
            scenario("Porter-Duff: each operator is its two coefficients: op=" + op, () -> {
                Pixel src = Pixel.fromColor(new Color(1, 0, 0), 0.6);
                Pixel dst = Pixel.fromColor(new Color(0, 0, 1), 0.4);
                assertPixelEq("composite(\"" + op + "\", src, dst)",
                        Compositing.composite(op, src, dst), expected);
            });
        }

        scenario("Porter-Duff: src-over is over, and dst-over is over with the arguments swapped", () -> {
            Pixel src = Pixel.fromColor(new Color(1, 0, 0), 0.6);
            Pixel dst = Pixel.fromColor(new Color(0, 0, 1), 0.4);
            assertPixelEq("composite(\"src-over\", src, dst)",
                    Compositing.composite("src-over", src, dst), Compositing.over(src, dst));
            assertPixelEq("composite(\"dst-over\", src, dst)",
                    Compositing.composite("dst-over", src, dst), Compositing.over(dst, src));
        });

        scenario("Porter-Duff: clear empties the pixel and dst keeps it", () -> {
            Pixel src = Pixel.opaque(new Color(1, 0, 0));
            Pixel dst = Pixel.opaque(new Color(0, 0, 1));
            assertPixelEq("composite(\"clear\", src, dst)", Compositing.composite("clear", src, dst), Pixel.CLEAR);
            assertPixelEq("composite(\"dst\", src, dst)", Compositing.composite("dst", src, dst), dst);
            assertPixelEq("composite(\"src\", src, dst)", Compositing.composite("src", src, dst), src);
        });
    }

    // features/chapter09-blend.feature
    private static final Object[][] SEPARABLE_TABLE = {
        {"normal", 0.8}, {"multiply", 0.24}, {"screen", 0.86}, {"overlay", 0.48},
        {"darken", 0.3}, {"lighten", 0.8}, {"color-dodge", 1.0}, {"color-burn", 0.125},
        {"hard-light", 0.72}, {"soft-light", 0.448634}, {"difference", 0.5}, {"exclusion", 0.62},
    };

    private static void registerBlend() {
        scenario("Blend: normal is source-over", () -> {
            Pixel src = Pixel.fromColor(new Color(1, 0, 0), 0.6);
            Pixel dst = Pixel.fromColor(new Color(0, 0, 1), 0.4);
            assertPixelEq("blend(\"normal\", src, dst)", Blend.blend("normal", src, dst), Compositing.over(src, dst));
        });

        for (Object[] row : SEPARABLE_TABLE) {
            String mode = (String) row[0];
            double value = (double) row[1];
            scenario("Blend: the separable modes, opaque source 0.8 over opaque backdrop 0.3: mode=" + mode, () -> {
                Pixel src = Pixel.opaque(new Color(0.8, 0.8, 0.8));
                Pixel dst = Pixel.opaque(new Color(0.3, 0.3, 0.3));
                assertDoubleEq("blend(\"" + mode + "\", src, dst).r", Blend.blend(mode, src, dst).r, value);
            });
        }

        scenario("Blend: a blended pixel over an opaque backdrop stays opaque", () -> {
            Pixel src = Pixel.opaque(new Color(0.8, 0.8, 0.8));
            Pixel dst = Pixel.opaque(new Color(0.3, 0.3, 0.3));
            assertDoubleEq("blend(\"multiply\", src, dst).a", Blend.blend("multiply", src, dst).a, 1);
            assertDoubleEq("blend(\"screen\", src, dst).a", Blend.blend("screen", src, dst).a, 1);
        });

        scenario("Blend: the four non-separable modes mix a saturated red with a blue", () -> {
            Pixel src = Pixel.opaque(new Color(0.9, 0.2, 0.2));
            Pixel dst = Pixel.opaque(new Color(0.2, 0.4, 0.8));
            assertColorEq("pixel_color(blend(\"hue\", src, dst))",
                    Blend.blend("hue", src, dst).pixelColor(), new Color(0.804, 0.204, 0.204));
            assertColorEq("pixel_color(blend(\"saturation\", src, dst))",
                    Blend.blend("saturation", src, dst).pixelColor(), new Color(0.169333, 0.402667, 0.869333));
            assertColorEq("pixel_color(blend(\"color\", src, dst))",
                    Blend.blend("color", src, dst).pixelColor(), new Color(0.874, 0.174, 0.174));
            assertColorEq("pixel_color(blend(\"luminosity\", src, dst))",
                    Blend.blend("luminosity", src, dst).pixelColor(), new Color(0.226, 0.426, 0.826));
        });

        scenario("Blend: blend_color is the blend function on two straight colours", () -> {
            assertColorEq("blend_color(\"multiply\", ...)",
                    Blend.blendColor("multiply", new Color(0.8, 0.8, 0.8), new Color(0.5, 0.5, 0.5)),
                    new Color(0.4, 0.4, 0.4));
            assertColorEq("blend_color(\"color\", ...)",
                    Blend.blendColor("color", new Color(0.2, 0.4, 0.8), new Color(0.9, 0.2, 0.2)),
                    new Color(0.874, 0.174, 0.174));
        });
    }

    // features/chapter09-plate.feature
    private static void registerPlate() {
        scenario("Plate 9: the Porter-Duff table places each operator", () -> {
            Canvas c = Figures.porterDuffTable();
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 256);
            assertEquals("c.height", c.height, 192);
            assertTriple("ppm_pixel(p6, 20, 20)", Ppm.ppmPixel(p6, 20, 20), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 102, 38)", Ppm.ppmPixel(p6, 102, 38), new int[] {249, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 148, 20)", Ppm.ppmPixel(p6, 148, 20), new int[] {124, 188, 237}, 1);
            assertTriple("ppm_pixel(p6, 232, 38)", Ppm.ppmPixel(p6, 232, 38), new int[] {249, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 40, 102)", Ppm.ppmPixel(p6, 40, 102), new int[] {124, 188, 237}, 1);
            assertTriple("ppm_pixel(p6, 79, 79)", Ppm.ppmPixel(p6, 79, 79), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 102, 96)", Ppm.ppmPixel(p6, 102, 96), new int[] {249, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 230, 160)", Ppm.ppmPixel(p6, 230, 160), new int[] {39, 39, 44}, 1);
        });

        scenario("Plate 9: the conflation seam is 0.75, not 1.0", () -> {
            Pixel half = Pixel.fromColor(new Color(1, 1, 1), 0.5);
            Pixel black = Pixel.opaque(new Color(0, 0, 0));
            Pixel once = Compositing.composite("src-over", half, black);
            Pixel twice = Compositing.composite("src-over", half, once);
            assertPixelEq("once", once, new Pixel(0.5, 0.5, 0.5, 1));
            assertPixelEq("twice", twice, new Pixel(0.75, 0.75, 0.75, 1));
        });

        scenario("Plate 9: the seam shows in the render", () -> {
            Canvas c = Figures.seam();
            byte[] ref = readReference("seam.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 320);
            assertTriple("ppm_pixel(p6, 40, 160)", Ppm.ppmPixel(p6, 40, 160), new int[] {249, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 160, 160)", Ppm.ppmPixel(p6, 160, 160), new int[] {220, 173, 81}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 9: Plate 9", () -> {
            Canvas c = Figures.plate09();
            byte[] ref = readReference("plate-09.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 512);
            assertEquals("c.height", c.height, 384);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 9: the blend-mode strip", () -> {
            Canvas c = Figures.blendStrip();
            byte[] ref = readReference("blend-modes.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 256);
            assertEquals("c.height", c.height, 256);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference/chapter-09", filename));
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
        writeOne("porter-duff.ppm", Figures.porterDuffTable());
        writeOne("plate-09.ppm", Figures.plate09());
        writeOne("blend-modes.ppm", Figures.blendStrip());
        writeOne("seam.ppm", Figures.seam());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
