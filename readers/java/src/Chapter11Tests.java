import java.io.IOException;
import java.nio.file.Files;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter11-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-11/*.ppm resolves.
 */
public final class Chapter11Tests {

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
        if (!actual.equals(expected)) {
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

    private static void assertPixelEq(String what, Pixel actual, Pixel expected) {
        if (!actual.approxEquals(expected)) {
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

    private static Image image2x2() {
        return Images.image(2, 2, List.of(
                Pixel.opaque(new Color(1, 0, 0)),
                Pixel.opaque(new Color(0, 1, 0)),
                Pixel.opaque(new Color(0, 0, 1)),
                Pixel.opaque(new Color(1, 1, 1))));
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerImage();
        registerSampling();
        registerPaint();
        registerMip();
        registerPlate();
    }

    // features/chapter11-image.feature
    private static void registerImage() {
        scenario("Image: a PPM reads back into the image it was written from", () -> {
            Canvas c = new Canvas(2, 2);
            c.writePixel(0, 0, new Color(1, 0, 0));
            c.writePixel(1, 0, new Color(0, 1, 0));
            c.writePixel(0, 1, new Color(0, 0, 1));
            c.writePixel(1, 1, new Color(1, 1, 1));
            Image img = Images.readImage(Ppm.canvasToP6(c));
            assertEquals("img.width", img.width, 2);
            assertEquals("img.height", img.height, 2);
            assertColorEq("pixel_color(image_texel(img, 0, 0))",
                    Images.imageTexel(img, 0, 0).pixelColor(), new Color(1, 0, 0));
            assertColorEq("pixel_color(image_texel(img, 1, 1))",
                    Images.imageTexel(img, 1, 1).pixelColor(), new Color(1, 1, 1));
            assertDoubleEq("pixel_alpha(image_texel(img, 0, 0))",
                    Images.imageTexel(img, 0, 0).pixelAlpha(), 1);
        });

        scenario("Image: clamp holds the edge texel", () -> {
            Image img = image2x2();
            assertColorEq("pixel_color(image_texel(img, -1, 0, \"clamp\"))",
                    Images.imageTexel(img, -1, 0, "clamp").pixelColor(), new Color(1, 0, 0));
            assertColorEq("pixel_color(image_texel(img, 2, 0, \"clamp\"))",
                    Images.imageTexel(img, 2, 0, "clamp").pixelColor(), new Color(0, 1, 0));
        });

        scenario("Image: repeat wraps and reflect bounces", () -> {
            Image img = image2x2();
            assertColorEq("pixel_color(image_texel(img, 2, 0, \"repeat\"))",
                    Images.imageTexel(img, 2, 0, "repeat").pixelColor(), new Color(1, 0, 0));
            assertColorEq("pixel_color(image_texel(img, -1, 0, \"repeat\"))",
                    Images.imageTexel(img, -1, 0, "repeat").pixelColor(), new Color(0, 1, 0));
            assertColorEq("pixel_color(image_texel(img, 2, 0, \"reflect\"))",
                    Images.imageTexel(img, 2, 0, "reflect").pixelColor(), new Color(0, 1, 0));
            assertColorEq("pixel_color(image_texel(img, -1, 0, \"reflect\"))",
                    Images.imageTexel(img, -1, 0, "reflect").pixelColor(), new Color(1, 0, 0));
        });
    }

    // features/chapter11-sampling.feature
    private static void registerSampling() {
        scenario("Sampling: every sampler returns the texel exactly at its center", () -> {
            Image img = image2x2();
            assertColorEq("sample_nearest(img, 0.5, 0.5)",
                    Sampling.sampleNearest(img, 0.5, 0.5).pixelColor(), new Color(1, 0, 0));
            assertColorEq("sample_bilinear(img, 0.5, 0.5)",
                    Sampling.sampleBilinear(img, 0.5, 0.5).pixelColor(), new Color(1, 0, 0));
            assertColorEq("sample_bicubic(img, 0.5, 0.5)",
                    Sampling.sampleBicubic(img, 0.5, 0.5).pixelColor(), new Color(1, 0, 0));
            assertColorEq("sample_bilinear(img, 1.5, 0.5)",
                    Sampling.sampleBilinear(img, 1.5, 0.5).pixelColor(), new Color(0, 1, 0));
            assertColorEq("sample_bilinear(img, 1.5, 1.5)",
                    Sampling.sampleBilinear(img, 1.5, 1.5).pixelColor(), new Color(1, 1, 1));
        });

        scenario("Sampling: nearest takes the texel the point falls in", () -> {
            Image img = image2x2();
            assertColorEq("sample_nearest(img, 0.9, 0.1)",
                    Sampling.sampleNearest(img, 0.9, 0.1).pixelColor(), new Color(1, 0, 0));
            assertColorEq("sample_nearest(img, 1.1, 0.1)",
                    Sampling.sampleNearest(img, 1.1, 0.1).pixelColor(), new Color(0, 1, 0));
        });

        scenario("Sampling: bilinear blends toward its neighbours", () -> {
            Image img = image2x2();
            assertColorEq("sample_bilinear(img, 1.0, 0.5)",
                    Sampling.sampleBilinear(img, 1.0, 0.5).pixelColor(), new Color(0.5, 0.5, 0));
            assertColorEq("sample_bilinear(img, 1.0, 1.0)",
                    Sampling.sampleBilinear(img, 1.0, 1.0).pixelColor(), new Color(0.5, 0.5, 0.5));
        });

        scenario("Sampling: the Catmull-Rom weights sum to one and pass through the samples", () -> {
            double[] w0 = Sampling.catmull(0);
            assertDoubleEq("catmull(0)[0]", w0[0], 0);
            assertDoubleEq("catmull(0)[1]", w0[1], 1);
            assertDoubleEq("catmull(0)[2]", w0[2], 0);
            assertDoubleEq("catmull(0)[3]", w0[3], 0);
            double[] wh = Sampling.catmull(0.5);
            assertDoubleEq("catmull(0.5)[0]", wh[0], -0.0625, 0.0001);
            assertDoubleEq("catmull(0.5)[1]", wh[1], 0.5625, 0.0001);
            assertDoubleEq("catmull(0.5)[2]", wh[2], 0.5625, 0.0001);
            assertDoubleEq("catmull(0.5)[3]", wh[3], -0.0625, 0.0001);
        });
    }

    // features/chapter11-paint.feature
    private static void registerPaint() {
        scenario("Paint: the identity transform is bit-exact under every filter", () -> {
            Image img = image2x2();
            ImagePaint nearest = new ImagePaint(img, Matrix.identity(), "nearest", "clamp");
            ImagePaint bilinear = new ImagePaint(img, Matrix.identity(), "bilinear", "clamp");
            ImagePaint bicubic = new ImagePaint(img, Matrix.identity(), "bicubic", "clamp");
            assertColorEq("paint_at(nearest, 0.5, 0.5)", nearest.paintAt(0.5, 0.5), new Color(1, 0, 0));
            assertColorEq("paint_at(bilinear, 0.5, 0.5)", bilinear.paintAt(0.5, 0.5), new Color(1, 0, 0));
            assertColorEq("paint_at(bicubic, 0.5, 0.5)", bicubic.paintAt(0.5, 0.5), new Color(1, 0, 0));
            assertColorEq("paint_at(bilinear, 1.5, 0.5)", bilinear.paintAt(1.5, 0.5), new Color(0, 1, 0));
            assertColorEq("paint_at(bilinear, 1.5, 1.5)", bilinear.paintAt(1.5, 1.5), new Color(1, 1, 1));
        });

        scenario("Paint: the transform places the image, and the inverse finds the texel", () -> {
            Image img = image2x2();
            ImagePaint p = new ImagePaint(img, Transforms.translation(10, 0), "nearest", "clamp");
            assertColorEq("paint_at(p, 10.5, 0.5)", p.paintAt(10.5, 0.5), new Color(1, 0, 0));
            assertColorEq("paint_at(p, 11.5, 0.5)", p.paintAt(11.5, 0.5), new Color(0, 1, 0));
        });

        scenario("Paint: a doubled image samples the same texel across two device pixels", () -> {
            Image img = image2x2();
            ImagePaint p = new ImagePaint(img, Transforms.scaling(2, 2), "nearest", "clamp");
            assertColorEq("paint_at(p, 0.5, 0.5)", p.paintAt(0.5, 0.5), new Color(1, 0, 0));
            assertColorEq("paint_at(p, 1.5, 0.5)", p.paintAt(1.5, 0.5), new Color(1, 0, 0));
            assertColorEq("paint_at(p, 2.5, 0.5)", p.paintAt(2.5, 0.5), new Color(0, 1, 0));
        });
    }

    // features/chapter11-mip.feature
    private static void registerMip() {
        scenario("Mip: downsample averages each 2x2 block", () -> {
            Image img = image2x2();
            Image d = Images.downsample(img);
            assertEquals("d.width", d.width, 1);
            assertEquals("d.height", d.height, 1);
            assertColorEq("pixel_color(image_texel(d, 0, 0))",
                    Images.imageTexel(d, 0, 0).pixelColor(), new Color(0.5, 0.5, 0.5));
        });

        scenario("Mip: downsample averages premultiplied, so a transparent texel adds nothing", () -> {
            Image img = Images.image(2, 2, List.of(
                    Pixel.opaque(new Color(1, 0, 0)), Pixel.CLEAR, Pixel.CLEAR, Pixel.CLEAR));
            Image d = Images.downsample(img);
            assertPixelEq("image_texel(d, 0, 0)", Images.imageTexel(d, 0, 0), new Pixel(0.25, 0, 0, 0.25));
            assertColorEq("pixel_color(image_texel(d, 0, 0))",
                    Images.imageTexel(d, 0, 0).pixelColor(), new Color(1, 0, 0));
        });

        scenario("Mip: a mip chain halves down to a single pixel", () -> {
            Image img = image2x2();
            List<Image> chain = Images.mipChain(img);
            assertEquals("length(chain)", chain.size(), 2);
            assertEquals("chain[0].width", chain.get(0).width, 2);
            assertEquals("chain[1].width", chain.get(1).width, 1);
            assertColorEq("pixel_color(image_texel(chain[1], 0, 0))",
                    Images.imageTexel(chain.get(1), 0, 0).pixelColor(), new Color(0.5, 0.5, 0.5));
        });

        scenario("Mip: the mip level follows the minification", () -> {
            assertEquals("mip_level_for(2.0)", Images.mipLevelFor(2.0), 0);
            assertEquals("mip_level_for(1.0)", Images.mipLevelFor(1.0), 0);
            assertEquals("mip_level_for(0.5)", Images.mipLevelFor(0.5), 1);
            assertEquals("mip_level_for(0.25)", Images.mipLevelFor(0.25), 2);
            assertEquals("mip_level_for(0.3)", Images.mipLevelFor(0.3), 1);
        });
    }

    // features/chapter11-plate.feature
    private static void registerPlate() {
        scenario("Plate 11: the sprite round-trips through a PPM", () -> {
            Image s = Figures.sprite();
            assertEquals("s.width", s.width, 8);
            assertEquals("s.height", s.height, 8);
            assertEquals("length(mip_chain(s))", Images.mipChain(s).size(), 4);
        });

        scenario("Plate 11: two filters, nearest against bilinear", () -> {
            Canvas c = Figures.twoFilters();
            byte[] ref = readReference("two-filters.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 160);
            assertTriple("ppm_pixel(p6, 50, 50)", Ppm.ppmPixel(p6, 50, 50), new int[] {249, 247, 237}, 1);
            assertTriple("ppm_pixel(p6, 10, 10)", Ppm.ppmPixel(p6, 10, 10), new int[] {69, 69, 80}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 11: Plate 11", () -> {
            Canvas c = Figures.plate11();
            byte[] ref = readReference("plate-11.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 160);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 11: three filters, adding bicubic", () -> {
            Canvas c = Figures.threeFilters();
            byte[] ref = readReference("three-filters.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 384);
            assertEquals("c.height", c.height, 128);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference/chapter-11", filename));
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
        writeOne("two-filters.ppm", Figures.twoFilters());
        writeOne("plate-11.ppm", Figures.plate11());
        writeOne("three-filters.ppm", Figures.threeFilters());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
