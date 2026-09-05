import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter01-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-01/*.ppm resolves.
 */
public final class Chapter01Tests {

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

    private static void assertColorEq(String what, Color actual, Color expected) {
        assertColorEq(what, actual, expected, Numbers.DEFAULT_EPSILON);
    }

    private static void assertColorEq(String what, Color actual, Color expected, double eps) {
        if (!actual.approxEquals(expected, eps)) {
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

    private static void assertEquals(String what, Object actual, Object expected) {
        if (!actual.equals(expected)) {
            throw new AssertionError(what + ": expected [" + expected + "] but got [" + actual + "]");
        }
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerEquality();
        registerColors();
        registerCanvas();
        registerSrgb();
        registerPpm();
        registerGrayMatch();
        registerLimits();
        registerMix();
        registerPlate();
    }

    // features/chapter01-equality.feature
    private static void registerEquality() {
        scenario("Comparing numbers: differ by less than tolerance are equal", () ->
                assertTrue("1.0 = 1.0000001 +/- 0.00001", Numbers.approxEqual(1.0, 1.0000001, 0.00001)));

        scenario("Comparing numbers: differ by more than tolerance are not", () ->
                assertTrue("1.0 != 1.001 +/- 0.00001", !Numbers.approxEqual(1.0, 1.001, 0.00001)));

        scenario("Comparing numbers: the default tolerance is 0.0001", () -> {
            assertTrue("0.1 + 0.2 = 0.3", Numbers.approxEqual(0.1 + 0.2, 0.3));
            assertTrue("1.0 = 1.00009", Numbers.approxEqual(1.0, 1.00009));
            assertTrue("1.0 != 1.0002", !Numbers.approxEqual(1.0, 1.0002));
        });
    }

    // features/chapter01-colors.feature
    private static void registerColors() {
        scenario("Colors: a color is a red, green, blue tuple", () -> {
            Color c = new Color(-0.5, 0.4, 1.7);
            assertDoubleEq("c.red", c.red, -0.5);
            assertDoubleEq("c.green", c.green, 0.4);
            assertDoubleEq("c.blue", c.blue, 1.7);
        });

        scenario("Colors: adding colors", () -> {
            Color c1 = new Color(0.9, 0.6, 0.75);
            Color c2 = new Color(0.7, 0.1, 0.25);
            assertColorEq("c1 + c2", c1.add(c2), new Color(1.6, 0.7, 1.0));
        });

        scenario("Colors: subtracting colors", () -> {
            Color c1 = new Color(0.9, 0.6, 0.75);
            Color c2 = new Color(0.7, 0.1, 0.25);
            assertColorEq("c1 - c2", c1.subtract(c2), new Color(0.2, 0.5, 0.5));
        });

        scenario("Colors: scaling a color by a number", () -> {
            Color c = new Color(0.2, 0.3, 0.4);
            assertColorEq("c * 2", c.scale(2), new Color(0.4, 0.6, 0.8));
            assertColorEq("c * 0.5", c.scale(0.5), new Color(0.1, 0.15, 0.2));
        });

        scenario("Colors: multiplying two colors filters one through the other", () -> {
            Color c1 = new Color(1, 0.2, 0.4);
            Color c2 = new Color(0.9, 1, 0.1);
            assertColorEq("c1 * c2", c1.multiply(c2), new Color(0.9, 0.2, 0.04));
        });

        scenario("Colors: compare component by component, with the usual tolerance", () -> {
            Color c1 = new Color(0.1, 0.5, 1);
            Color c2 = new Color(0.2, 0, 0);
            assertColorEq("c1 + c2", c1.add(c2), new Color(0.3, 0.5, 1));
            assertTrue("c1 + c2 != color(0.3, 0.5, 1.001)",
                    !c1.add(c2).approxEquals(new Color(0.3, 0.5, 1.001)));
        });
    }

    // features/chapter01-canvas.feature
    private static void registerCanvas() {
        scenario("Canvas: a new canvas is black", () -> {
            Canvas c = new Canvas(10, 20);
            assertEquals("c.width", c.width, 10);
            assertEquals("c.height", c.height, 20);
            for (int y = 0; y < c.height; y++) {
                for (int x = 0; x < c.width; x++) {
                    assertColorEq("pixel_at(c, " + x + ", " + y + ")", c.pixelAt(x, y), new Color(0, 0, 0));
                }
            }
        });

        scenario("Canvas: writing a pixel", () -> {
            Canvas c = new Canvas(10, 20);
            Color red = new Color(1, 0, 0);
            c.writePixel(2, 3, red);
            assertColorEq("pixel_at(c, 2, 3)", c.pixelAt(2, 3), red);
        });

        scenario("Canvas: x is the column and y is the row", () -> {
            Canvas c = new Canvas(10, 20);
            c.writePixel(2, 3, new Color(1, 0, 0));
            assertColorEq("pixel_at(c, 3, 2)", c.pixelAt(3, 2), new Color(0, 0, 0));
            assertColorEq("pixel_at(c, 2, 3)", c.pixelAt(2, 3), new Color(1, 0, 0));
        });

        scenario("Canvas: writing outside the canvas is ignored", () -> {
            Canvas c = new Canvas(10, 20);
            c.writePixel(-1, 5, new Color(1, 0, 0));
            c.writePixel(10, 5, new Color(1, 0, 0));
            c.writePixel(5, -1, new Color(1, 0, 0));
            c.writePixel(5, 20, new Color(1, 0, 0));
            for (int y = 0; y < c.height; y++) {
                for (int x = 0; x < c.width; x++) {
                    assertColorEq("pixel_at(c, " + x + ", " + y + ")", c.pixelAt(x, y), new Color(0, 0, 0));
                }
            }
        });

        scenario("Canvas: a pixel can be written more than once", () -> {
            Canvas c = new Canvas(10, 20);
            c.writePixel(2, 3, new Color(1, 0, 0));
            c.writePixel(2, 3, new Color(0, 1, 0));
            assertColorEq("pixel_at(c, 2, 3)", c.pixelAt(2, 3), new Color(0, 1, 0));
        });

        scenario("Canvas: filling a canvas", () -> {
            Canvas c = new Canvas(10, 20);
            c.fill(new Color(0.1, 0.2, 0.3));
            for (int y = 0; y < c.height; y++) {
                for (int x = 0; x < c.width; x++) {
                    assertColorEq("pixel_at(c, " + x + ", " + y + ")", c.pixelAt(x, y), new Color(0.1, 0.2, 0.3));
                }
            }
        });
    }

    // features/chapter01-srgb.feature
    private static final double[][] ENCODE_TABLE = {
        {0.0, 0.0}, {0.0025, 0.0323}, {0.0031308, 0.0405}, {0.01, 0.0999}, {0.1, 0.3492},
        {0.216, 0.5021}, {0.25, 0.5371}, {0.5, 0.7354}, {0.75, 0.8808}, {1.0, 1.0}
    };

    private static final double[][] DECODE_TABLE = {
        {0.0, 0.0}, {0.04, 0.0031}, {0.04045, 0.0031}, {0.05, 0.0039}, {0.1, 0.0100},
        {0.5, 0.2140}, {0.75, 0.5225}, {1.0, 1.0}
    };

    private static void registerSrgb() {
        for (double[] row : ENCODE_TABLE) {
            double light = row[0];
            double value = row[1];
            scenario("sRGB: encoding light into a file value: light=" + light, () ->
                    assertDoubleEq("encode(" + light + ")", Srgb.encode(light), value));
        }

        for (double[] row : DECODE_TABLE) {
            double value = row[0];
            double light = row[1];
            scenario("sRGB: decoding a file value into light: value=" + value, () ->
                    assertDoubleEq("decode(" + value + ")", Srgb.decode(value), light));
        }

        scenario("sRGB: decode undoes encode", () -> {
            double l = 0.2;
            assertDoubleEq("decode(encode(l))", Srgb.decode(Srgb.encode(l)), 0.2, 0.000000001);
        });

        scenario("sRGB: encode undoes decode", () -> {
            double v = 0.7;
            assertDoubleEq("encode(decode(v))", Srgb.encode(Srgb.decode(v)), 0.7, 0.000000001);
        });

        scenario("sRGB: the half gray that isn't 128", () ->
                assertEquals("round(encode(0.5) * 255)", Numbers.round(Srgb.encode(0.5) * 255), 188L));

        scenario("sRGB: what 128 actually is", () ->
                assertDoubleEq("decode(128 / 255)", Srgb.decode(128.0 / 255.0), 0.2159));
    }

    // features/chapter01-ppm.feature
    private static void registerPpm() {
        scenario("PPM: the PPM header", () -> {
            Canvas c = new Canvas(5, 3);
            String ppm = Ppm.canvasToPpm(c);
            String[] lines = Ppm.lines(ppm);
            assertEquals("line 1", lines[0], "P3");
            assertEquals("line 2", lines[1], "5 3");
            assertEquals("line 3", lines[2], "255");
        });

        scenario("PPM: pixel values are encoded, not scaled", () -> {
            Canvas c = new Canvas(3, 1);
            c.writePixel(0, 0, new Color(1, 0, 0));
            c.writePixel(1, 0, new Color(0, 0.5, 0));
            c.writePixel(2, 0, new Color(0, 0, 0.216));
            String ppm = Ppm.canvasToPpm(c);
            assertEquals("line 4", Ppm.lines(ppm)[3], "255 0 0 0 188 0 0 0 128");
        });

        scenario("PPM: colors out of range are clamped, not wrapped", () -> {
            Canvas c = new Canvas(2, 1);
            c.writePixel(0, 0, new Color(1.5, 0, -0.5));
            String ppm = Ppm.canvasToPpm(c);
            assertEquals("line 4", Ppm.lines(ppm)[3], "255 0 0 0 0 0");
        });

        scenario("PPM: every row starts a new line, and no line exceeds 70 characters", () -> {
            Canvas c = new Canvas(10, 2);
            c.fill(new Color(1, 0.8, 0.6));
            String ppm = Ppm.canvasToPpm(c);
            String[] lines = Ppm.lines(ppm);
            assertEquals("line 4", lines[3],
                    "255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231");
            assertEquals("line 5", lines[4], "203 255 231 203 255 231 203 255 231 203 255 231 203");
            assertEquals("line 6", lines[5],
                    "255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231");
            assertEquals("line 7", lines[6], "203 255 231 203 255 231 203 255 231 203 255 231 203");
            for (String line : lines) {
                assertTrue("line \"" + line + "\" is at most 70 characters", line.length() <= 70);
            }
        });

        scenario("PPM: the file ends with a newline", () -> {
            Canvas c = new Canvas(5, 3);
            String ppm = Ppm.canvasToPpm(c);
            assertTrue("ppm ends with a newline character", ppm.endsWith("\n"));
        });

        scenario("PPM: reading a pixel back out of the text", () -> {
            Canvas c = new Canvas(3, 2);
            c.writePixel(2, 1, new Color(0, 0.5, 1));
            String ppm = Ppm.canvasToPpm(c);
            assertTrue("ppm_pixel(ppm, 2, 1) = (0, 188, 255)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 2, 1), new int[] {0, 188, 255}));
            assertTrue("ppm_pixel(ppm, 1, 1) = (0, 0, 0)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 1, 1), new int[] {0, 0, 0}));
        });

        scenario("PPM: comparing two files", () -> {
            Canvas c1 = new Canvas(2, 1);
            Canvas c2 = new Canvas(2, 1);
            c2.writePixel(0, 0, new Color(0.5, 0, 0));
            String ppm1 = Ppm.canvasToPpm(c1);
            String ppm2 = Ppm.canvasToPpm(c2);
            assertEquals("max_channel_difference(ppm1, ppm1)", Ppm.maxChannelDifference(ppm1, ppm1), 0);
            assertEquals("max_channel_difference(ppm1, ppm2)", Ppm.maxChannelDifference(ppm1, ppm2), 188);
        });
    }

    // features/chapter01-gray-match.feature
    private static void registerGrayMatch() {
        scenario("Gray match: the gray match", () -> {
            Canvas c = Figures.grayMatch();
            assertEquals("c.width", c.width, 300);
            assertEquals("c.height", c.height, 100);
            assertColorEq("pixel_at(c, 0, 0)", c.pixelAt(0, 0), new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 1, 0)", c.pixelAt(1, 0), new Color(0, 0, 0));
            assertColorEq("pixel_at(c, 0, 1)", c.pixelAt(0, 1), new Color(0, 0, 0));
            assertColorEq("pixel_at(c, 1, 1)", c.pixelAt(1, 1), new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 150, 50)", c.pixelAt(150, 50), new Color(0.2159, 0.2159, 0.2159));
            assertColorEq("pixel_at(c, 250, 50)", c.pixelAt(250, 50), new Color(0.5, 0.5, 0.5));
            int whiteCount = 0;
            for (int y = 0; y < c.height; y++) {
                for (int x = 0; x < c.width; x++) {
                    if (c.pixelAt(x, y).approxEquals(new Color(1, 1, 1))) {
                        whiteCount++;
                    }
                }
            }
            assertEquals("count of white pixels", whiteCount, 5000);
        });

        scenario("Gray match: the gray match, as a file", () -> {
            Canvas c = Figures.grayMatch();
            String ppm = Ppm.canvasToPpm(c);
            assertTrue("ppm_pixel(ppm, 0, 0) = (255, 255, 255)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 0, 0), new int[] {255, 255, 255}));
            assertTrue("ppm_pixel(ppm, 1, 0) = (0, 0, 0)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 1, 0), new int[] {0, 0, 0}));
            assertTrue("ppm_pixel(ppm, 150, 50) = (128, 128, 128)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 150, 50), new int[] {128, 128, 128}));
            assertTrue("ppm_pixel(ppm, 250, 50) = (188, 188, 188)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 250, 50), new int[] {188, 188, 188}));
            String ref = readReference("gray-match.ppm");
            assertTrue("max_channel_difference(ppm, ref) <= 1", Ppm.maxChannelDifference(ppm, ref) <= 1);
        });

        scenario("Gray match: one pixel in four", () -> {
            Canvas c = Figures.quarterMatch();
            assertEquals("c.width", c.width, 200);
            assertEquals("c.height", c.height, 100);
            assertColorEq("pixel_at(c, 0, 0)", c.pixelAt(0, 0), new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 1, 0)", c.pixelAt(1, 0), new Color(0, 0, 0));
            assertColorEq("pixel_at(c, 2, 2)", c.pixelAt(2, 2), new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 3, 1)", c.pixelAt(3, 1), new Color(1, 1, 1));
            assertColorEq("pixel_at(c, 150, 50)", c.pixelAt(150, 50), new Color(0.25, 0.25, 0.25));
            int whiteCount = 0;
            for (int y = 0; y < c.height; y++) {
                for (int x = 0; x < c.width; x++) {
                    if (c.pixelAt(x, y).approxEquals(new Color(1, 1, 1))) {
                        whiteCount++;
                    }
                }
            }
            assertEquals("count of white pixels", whiteCount, 2500);
            String ppm = Ppm.canvasToPpm(c);
            assertTrue("ppm_pixel(ppm, 150, 50) = (137, 137, 137)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 150, 50), new int[] {137, 137, 137}));
            String ref = readReference("quarter-match.ppm");
            assertTrue("max_channel_difference(ppm, ref) <= 1", Ppm.maxChannelDifference(ppm, ref) <= 1);
        });
    }

    // features/chapter01-limits.feature
    private static void registerLimits() {
        scenario("Limits: a 256-step ramp", () -> {
            Canvas c = Figures.ramp();
            assertEquals("c.width", c.width, 256);
            assertEquals("c.height", c.height, 32);
            assertColorEq("pixel_at(c, 0, 0)", c.pixelAt(0, 0), new Color(0, 0, 0));
            assertColorEq("pixel_at(c, 128, 0)", c.pixelAt(128, 0), new Color(0.5020, 0.5020, 0.5020));
            assertColorEq("pixel_at(c, 255, 31)", c.pixelAt(255, 31), new Color(1, 1, 1));
        });

        scenario("Limits: encoding stretches the dark end and squeezes the bright end", () -> {
            Canvas c = Figures.ramp();
            String ppm = Ppm.canvasToPpm(c);
            assertEquals("line 4", Ppm.lines(ppm)[3],
                    "0 0 0 13 13 13 22 22 22 28 28 28 34 34 34 38 38 38 42 42 42 46 46 46");
            assertTrue("ppm_pixel(ppm, 75, 0) = (148, 148, 148)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 75, 0), new int[] {148, 148, 148}));
            assertTrue("ppm_pixel(ppm, 76, 0) = (148, 148, 148)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 76, 0), new int[] {148, 148, 148}));
            assertTrue("ppm_pixel(ppm, 254, 0) = (255, 255, 255)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 254, 0), new int[] {255, 255, 255}));
            assertEquals("distinct_values(ppm)", Ppm.distinctValues(ppm), 183);
            String ref = readReference("ramp.ppm");
            assertTrue("max_channel_difference(ppm, ref) <= 1", Ppm.maxChannelDifference(ppm, ref) <= 1);
        });

        scenario("Limits: clamping changes the color, not only the brightness", () -> {
            Canvas c = Figures.clampPair();
            assertEquals("c.width", c.width, 200);
            assertEquals("c.height", c.height, 100);
            assertColorEq("pixel_at(c, 50, 50)", c.pixelAt(50, 50), new Color(2, 0.5, 0.5));
            assertColorEq("pixel_at(c, 150, 50)", c.pixelAt(150, 50), new Color(1, 0.25, 0.25));
            String ppm = Ppm.canvasToPpm(c);
            assertTrue("ppm_pixel(ppm, 50, 50) = (255, 188, 188)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 50, 50), new int[] {255, 188, 188}));
            assertTrue("ppm_pixel(ppm, 150, 50) = (255, 137, 137)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 150, 50), new int[] {255, 137, 137}));
            String ref = readReference("clamp-pair.ppm");
            assertTrue("max_channel_difference(ppm, ref) <= 1", Ppm.maxChannelDifference(ppm, ref) <= 1);
        });
    }

    // features/chapter01-mix.feature
    private static void registerMix() {
        scenario("Mix: linear blending is on by default", () ->
                assertTrue("linear blending is on", Mixer.linearBlending));

        scenario("Mix: halfway between black and white", () -> {
            Color a = new Color(0, 0, 0);
            Color b = new Color(1, 1, 1);
            assertColorEq("mix(a, b, 0.5)", Mixer.mix(a, b, 0.5), new Color(0.5, 0.5, 0.5));
        });

        scenario("Mix: the ends of a mix are its inputs", () -> {
            Color a = new Color(0.7, 0, 0);
            Color b = new Color(0, 0.3, 0.02);
            assertColorEq("mix(a, b, 0)", Mixer.mix(a, b, 0), a);
            assertColorEq("mix(a, b, 1)", Mixer.mix(a, b, 1), b);
        });

        scenario("Mix: red to green, in light", () -> {
            Color a = new Color(0.7, 0, 0);
            Color b = new Color(0, 0.3, 0.02);
            assertColorEq("mix(a, b, 0.5)", Mixer.mix(a, b, 0.5), new Color(0.35, 0.15, 0.01));
            assertColorEq("mix(a, b, 0.25)", Mixer.mix(a, b, 0.25), new Color(0.525, 0.075, 0.005));
        });

        scenario("Mix: halfway between black and white, the way browsers do it", () -> {
            Mixer.linearBlending = false;
            Color a = new Color(0, 0, 0);
            Color b = new Color(1, 1, 1);
            assertColorEq("mix(a, b, 0.5)", Mixer.mix(a, b, 0.5), new Color(0.2140, 0.2140, 0.2140));
            Mixer.linearBlending = true;
        });

        scenario("Mix: red to green, the way browsers do it", () -> {
            Mixer.linearBlending = false;
            Color a = new Color(0.7, 0, 0);
            Color b = new Color(0, 0.3, 0.02);
            assertColorEq("mix(a, b, 0.5)", Mixer.mix(a, b, 0.5), new Color(0.1527, 0.0693, 0.0067));
            Mixer.linearBlending = true;
        });

        scenario("Mix: the ends of a mix are its inputs either way", () -> {
            Mixer.linearBlending = false;
            Color a = new Color(0.7, 0, 0);
            Color b = new Color(0, 0.3, 0.02);
            assertColorEq("mix(a, b, 0)", Mixer.mix(a, b, 0), a);
            assertColorEq("mix(a, b, 1)", Mixer.mix(a, b, 1), b);
            Mixer.linearBlending = true;
        });
    }

    // features/chapter01-plate.feature
    private static void registerPlate() {
        scenario("Plate 1: the plate", () -> {
            Canvas c = Figures.plate01();
            assertEquals("c.width", c.width, 400);
            assertEquals("c.height", c.height, 180);
            String ppm = Ppm.canvasToPpm(c);
            assertTrue("ppm_pixel(ppm, 0, 20) = (0, 0, 0)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 0, 20), new int[] {0, 0, 0}));
            assertTrue("ppm_pixel(ppm, 399, 20) = (255, 255, 255)",
                    Arrays.equals(Ppm.ppmPixel(ppm, 399, 20), new int[] {255, 255, 255}));
            assertTriple("ppm_pixel(ppm, 200, 20) = (128, 128, 128) +/- 1",
                    Ppm.ppmPixel(ppm, 200, 20), new int[] {128, 128, 128}, 1);
            assertTriple("ppm_pixel(ppm, 200, 65) = (188, 188, 188) +/- 1",
                    Ppm.ppmPixel(ppm, 200, 65), new int[] {188, 188, 188}, 1);
            assertTriple("ppm_pixel(ppm, 200, 42) = (0, 0, 0)",
                    Ppm.ppmPixel(ppm, 200, 42), new int[] {0, 0, 0}, 0);
            assertTriple("ppm_pixel(ppm, 0, 110) = (218, 0, 0)",
                    Ppm.ppmPixel(ppm, 0, 110), new int[] {218, 0, 0}, 0);
            assertTriple("ppm_pixel(ppm, 399, 110) = (0, 149, 39)",
                    Ppm.ppmPixel(ppm, 399, 110), new int[] {0, 149, 39}, 0);
            assertTriple("ppm_pixel(ppm, 200, 110) = (109, 75, 19) +/- 1",
                    Ppm.ppmPixel(ppm, 200, 110), new int[] {109, 75, 19}, 1);
            assertTriple("ppm_pixel(ppm, 200, 155) = (160, 108, 26) +/- 1",
                    Ppm.ppmPixel(ppm, 200, 155), new int[] {160, 108, 26}, 1);
            assertTriple("ppm_pixel(ppm, 200, 87) = (0, 0, 0)",
                    Ppm.ppmPixel(ppm, 200, 87), new int[] {0, 0, 0}, 0);
            String ref = readReference("plate-01.ppm");
            assertTrue("max_channel_difference(ppm, ref) <= 1", Ppm.maxChannelDifference(ppm, ref) <= 1);
        });

        scenario("Plate 1: the switch was left on", () -> {
            Figures.plate01();
            assertTrue("linear blending is on", Mixer.linearBlending);
        });
    }

    private static String readReference(String filename) throws IOException {
        return Files.readString(Path.of("reference/chapter-01", filename));
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
        Mixer.linearBlending = true;
        Files.createDirectories(Path.of("out"));
        writeOne("gray-match.ppm", Figures.grayMatch());
        writeOne("quarter-match.ppm", Figures.quarterMatch());
        writeOne("ramp.ppm", Figures.ramp());
        writeOne("clamp-pair.ppm", Figures.clampPair());
        writeOne("plate-01.ppm", Figures.plate01());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.writeString(Path.of("out", filename), Ppm.canvasToPpm(c));
    }
}
