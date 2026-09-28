import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter24-*.feature into a Java test. No JUnit, no network: run
 * from the project root so reference/chapter-16, reference/chapter-20,
 * reference/chapter-24 resolve.
 */
public final class Chapter24Tests {

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

    private static void assertTupleEq(String what, Tuple actual, Tuple expected) {
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertColorEq(String what, Color actual, Color expected) {
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertColorListEq(String what, List<Color> a, List<Color> b) {
        if (a.size() != b.size()) {
            throw new AssertionError(what + ": size mismatch " + a.size() + " vs " + b.size());
        }
        for (int i = 0; i < a.size(); i++) {
            if (!a.get(i).approxEquals(b.get(i))) {
                throw new AssertionError(what + " at " + i + ": " + a.get(i) + " vs " + b.get(i));
            }
        }
    }

    private static void assertUvEq(String what, LoopBlinn.UV actual, double u, double v, double s) {
        assertTrue(what + ": was none", actual != null);
        assertDoubleEq(what + ".u", actual.u(), u);
        assertDoubleEq(what + ".v", actual.v(), v);
        assertDoubleEq(what + ".s", actual.s(), s);
    }

    private static void assertArrayEq(String what, int[] actual, int[] expected) {
        if (!java.util.Arrays.equals(actual, expected)) {
            throw new AssertionError(what + ": expected " + java.util.Arrays.toString(expected)
                    + " but got " + java.util.Arrays.toString(actual));
        }
    }

    private static void assertTriple(String what, int[] actual, int[] expected) {
        for (int i = 0; i < 3; i++) {
            if (Math.abs(actual[i] - expected[i]) > 1) {
                throw new AssertionError(what + ": expected " + java.util.Arrays.toString(expected)
                        + " but got " + java.util.Arrays.toString(actual));
            }
        }
    }

    private static String readText(String path) throws IOException {
        return java.nio.file.Files.readString(java.nio.file.Path.of(path));
    }

    private static byte[] readBytes(String path) throws IOException {
        return java.nio.file.Files.readAllBytes(java.nio.file.Path.of(path));
    }

    private static Tuple pt(double x, double y) {
        return Tuple.point(x, y);
    }

    private static void checkRender(Canvas c, String refPath, int w, int h) throws IOException {
        byte[] ref = readBytes(refPath);
        byte[] p6 = Ppm.canvasToP6(c);
        assertEquals("width", c.width, w);
        assertEquals("height", c.height, h);
        assertTrue("max_channel_difference <= 1 (" + refPath + ")", Ppm.maxChannelDifference(p6, ref) <= 1);
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerStencil();
        registerLoopBlinn();
        registerMsaa();
        registerShader();
        registerPipeline();
        registerUnhappy();
        registerPlate();
    }

    // ---- §24.1: filling without sorting ---------------------------------------

    private static void registerStencil() {
        scenario("Stencil: one triangle, either way round", () -> {
            assertEquals("cw", Stencils.triangleWinding(pt(0, 0), pt(4, 0), pt(0, 4), 1, 1), 1);
            assertEquals("ccw", Stencils.triangleWinding(pt(0, 0), pt(0, 4), pt(4, 0), 1, 1), -1);
            assertEquals("outside", Stencils.triangleWinding(pt(0, 0), pt(4, 0), pt(0, 4), 3, 3), 0);
        });

        scenario("Stencil: a square as four signed triangles", () -> {
            Path sq = Paths.polygon(pt(1, 1), pt(5, 1), pt(5, 5), pt(1, 5));
            Stencil s = Stencils.stencilBuffer(sq, 6, 6);
            assertTupleEq("fan_anchor(sq)", Stencils.fanAnchor(sq), pt(1, 1));
            int[] expected = {
                0, 0, 0, 0, 0, 0,
                0, 1, 1, 1, 1, 0,
                0, 1, 1, 1, 1, 0,
                0, 1, 1, 1, 1, 0,
                0, 1, 1, 1, 1, 0,
                0, 0, 0, 0, 0, 0,
            };
            assertArrayEq("s.values", s.values, expected);
            assertEquals("s.fragments", s.fragments, 16);
        });

        scenario("Stencil: matches chapter 5's winding number everywhere", () -> {
            Path star = Figures.star();
            Path glyph = Figures.plateGlyph();
            Stencil s = Stencils.stencilBuffer(star, 160, 160);
            Stencil g = Stencils.stencilBuffer(glyph, 200, 200);
            assertEquals("winding_mismatches(s, star)", Stencils.windingMismatches(s, star), 0);
            assertEquals("winding_mismatches(g, plate_glyph)", Stencils.windingMismatches(g, glyph), 0);
            assertEquals("stencil_at(s,80,80)", Stencils.stencilAt(s, 80, 80), 2);
            assertEquals("stencil_at(s,80,30)", Stencils.stencilAt(s, 80, 30), 1);
            assertEquals("stencil_at(s,5,5)", Stencils.stencilAt(s, 5, 5), 0);
            assertEquals("s.fragments", s.fragments, 13660);
            assertEquals("g.fragments", g.fragments, 22639);
        });

        scenario("Stencil: cover keeps what the rule fills", () -> {
            Stencil s = Stencils.stencilBuffer(Figures.star(), 160, 160);
            assertDoubleEq("cover(nonzero)@80,80", Stencils.cover(s, "nonzero").coverageAt(80, 80), 1);
            assertDoubleEq("cover(evenodd)@80,80", Stencils.cover(s, "evenodd").coverageAt(80, 80), 0);
            assertDoubleEq("cover(evenodd)@80,30", Stencils.cover(s, "evenodd").coverageAt(80, 30), 1);
        });
    }

    // ---- §24.2: curves without flattening --------------------------------------

    private static void registerLoopBlinn() {
        scenario("Loop-Blinn: the control points carry (0,0), (1/2,0), (1,1)", () -> {
            Curve c = Curve.quadratic(pt(0, 0), pt(10, 0), pt(10, 10));
            assertUvEq("uv(0,0)", LoopBlinn.loopBlinnUv(c, pt(0, 0)), 0, 0, 0);
            assertUvEq("uv(10,0)", LoopBlinn.loopBlinnUv(c, pt(10, 0)), 0.5, 0, 1);
            assertUvEq("uv(10,10)", LoopBlinn.loopBlinnUv(c, pt(10, 10)), 1, 1, 0);
            assertUvEq("uv(7,3)", LoopBlinn.loopBlinnUv(c, pt(7, 3)), 0.5, 0.3, 0.4);
            Curve degenerate = Curve.quadratic(pt(0, 0), pt(5, 0), pt(10, 0));
            assertTrue("degenerate curve has no uv", LoopBlinn.loopBlinnUv(degenerate, pt(3, 1)) == null);
        });

        scenario("Loop-Blinn: u^2 - v < 0 is the sliver between the curve and its chord", () -> {
            Curve c = Curve.quadratic(pt(0, 0), pt(10, 0), pt(10, 10));
            assertEquals("(7,3)", LoopBlinn.insideCurve(c, pt(7, 3)), true);
            assertEquals("(9,1)", LoopBlinn.insideCurve(c, pt(9, 1)), false);
            assertEquals("(4,4)", LoopBlinn.insideCurve(c, pt(4, 4)), false);
            assertEquals("(7.5,2.4)", LoopBlinn.insideCurve(c, pt(7.5, 2.4)), false);
            assertEquals("(7.5,2.6)", LoopBlinn.insideCurve(c, pt(7.5, 2.6)), true);
            assertEquals("curve_sign(c)", LoopBlinn.curveSign(c), 1);
            assertEquals("curve_sign(reversed)",
                    LoopBlinn.curveSign(Curve.quadratic(pt(10, 10), pt(10, 0), pt(0, 0))), -1);
        });

        scenario("Loop-Blinn: a glyph without flattening agrees with one flattened tight", () -> {
            Font f = Figures.robotoFont();
            Matrix m = Glyphs.textMatrix(f, 200, 40, 140);
            Stencil lb = LoopBlinn.glyphStencil(f, "g", m, 200, 200);
            assertEquals("winding_mismatches(lb, glyph_path g)",
                    Stencils.windingMismatches(lb, Glyphs.glyphPath(f, "g", m, 0.001)), 0);
            assertEquals("lb.fragments", lb.fragments, 22813);
            Stencil amp = LoopBlinn.glyphStencil(f, "ampersand", m, 200, 200);
            assertEquals("winding_mismatches(amp, glyph_path ampersand)",
                    Stencils.windingMismatches(amp, Glyphs.glyphPath(f, "ampersand", m, 0.001)), 0);
        });
    }

    // ---- §24.3: sampling instead of area ----------------------------------------

    private static void registerMsaa() {
        scenario("MSAA: the patterns", () -> {
            assertEquals("length(sample_pattern(16))", Msaa.samplePattern(16).size(), 16);
            assertTupleEq("sample_pattern(16)[0]", Msaa.samplePattern(16).get(0), pt(0.03125, 0.21875));
            assertTupleEq("sample_pattern(16)[1]", Msaa.samplePattern(16).get(1), pt(0.09375, 0.53125));
            assertTupleEq("sample_pattern(4)[2]", Msaa.samplePattern(4).get(2), pt(0.125, 0.625));
            assertEquals("length(sample_pattern(64))", Msaa.samplePattern(64).size(), 64);
        });

        scenario("MSAA: more samples come closer to chapter 7", () -> {
            Path sliver = Msaa.sliver();
            CoverageBuffer exact = Fill.fillPath(sliver, "nonzero", 80, 40);
            assertDoubleEq("n=1",
                    CoverageBuffer.maxCoverageDifference(Msaa.msaaCoverage(sliver, "nonzero", 80, 40, 1), exact),
                    0.4875);
            assertDoubleEq("n=4",
                    CoverageBuffer.maxCoverageDifference(Msaa.msaaCoverage(sliver, "nonzero", 80, 40, 4), exact),
                    0.1125);
            assertDoubleEq("n=16",
                    CoverageBuffer.maxCoverageDifference(Msaa.msaaCoverage(sliver, "nonzero", 80, 40, 16), exact),
                    0.0375);
            assertDoubleEq("n=64",
                    CoverageBuffer.maxCoverageDifference(Msaa.msaaCoverage(sliver, "nonzero", 80, 40, 64), exact),
                    0.0375);
        });
    }

    // ---- §24.4: paint as a shader ------------------------------------------------

    private static void registerShader() {
        scenario("Shader: a gradient asked in any order is the same gradient", () -> {
            RadialGradient g = new RadialGradient(pt(20, 20), 0, pt(40, 30), 50,
                    List.of(Stop.stop(0, new Color(1, 0, 0)), Stop.stop(1, new Color(0, 0, 1))), "pad");
            List<Color> a = Shader.shadeTile(g, 1, 2, null);
            List<Color> b = Shader.shadeTile(g, 1, 2, 5);
            assertColorListEq("a = b", a, b);
            assertColorEq("a[0]", a.get(0), new Color(0.735942, 0, 0.264058));
            assertColorEq("a[255]", a.get(255), new Color(0.539754, 0, 0.460246));
        });
    }

    // ---- §24.5: the compute pipeline ---------------------------------------------

    private record Tag(String kind, double val) implements CullOp {
        @Override
        public boolean isPush() {
            return kind.equals("push");
        }

        @Override
        public boolean isPop() {
            return kind.equals("pop");
        }
    }

    private static void registerPipeline() {
        scenario("Pipeline: the same shuffle everywhere", () -> {
            assertArrayEq("lcg_shuffle(10,1)", Lcg.lcgShuffle(10, 1), new int[] {1, 2, 8, 9, 5, 6, 7, 4, 3, 0});
            assertArrayEq("lcg_shuffle(5,7)", Lcg.lcgShuffle(5, 7), new int[] {0, 2, 3, 4, 1});
        });

        scenario("Pipeline: an empty group costs a tile nothing", () -> {
            List<Tag> input = List.of(
                    new Tag("push", 1), new Tag("pop", 0), new Tag("fill", 1),
                    new Tag("push", 0.5), new Tag("push", 1), new Tag("pop", 0),
                    new Tag("fill", 2), new Tag("pop", 0));
            List<Tag> expected = List.of(
                    new Tag("fill", 1), new Tag("push", 0.5), new Tag("fill", 2), new Tag("pop", 0));
            assertEquals("cull_groups", CullOp.cullGroups(input), expected);
        });

        scenario("Pipeline: the tiger's scene, stage by stage", () -> {
            String text = readText("reference/chapter-20/tiger.svg");
            Scene sc = new Scene(Encoder.encodeSvg(text, 450, 450), 450, 450);
            List<Pipeline.Segment> segs = Pipeline.flattenStage(sc);
            Map<Pipeline.TileKey, List<Pipeline.Deposit>> bins = Pipeline.binStage(sc, segs);
            Map<Pipeline.TileKey, List<TileCommand>> lists = Pipeline.coarseStage(sc, bins);
            assertEquals("length(sc.commands)", sc.commands.size(), 305);
            assertEquals("length(sc.draws)", sc.draws.size(), 305);
            assertEquals("length(segs)", segs.size(), 37051);
            assertEquals("deposit_count(bins)", Pipeline.depositCount(bins), 119876L);
            assertEquals("command_count(lists)", Pipeline.commandCount(lists), 4004L);
        });

        scenario("Pipeline: every document, drawn tile by tile in any order, is chapter 20's", () -> {
            Object[][] cases = {
                {"reference/chapter-20/tiger.svg", "reference/chapter-20/tiger.ppm", 450, 450},
                {"reference/chapter-20/harbor.svg", "reference/chapter-20/harbor.ppm", 480, 320},
                {"reference/chapter-20/rose.svg", "reference/chapter-20/rose.ppm", 400, 400},
            };
            for (Object[] c : cases) {
                String text = readText((String) c[0]);
                int w = (int) c[2];
                int h = (int) c[3];
                byte[] inOrder = Ppm.canvasToP6(Pipeline.renderSvgGpu(text, w, h, null));
                byte[] shuffled = Ppm.canvasToP6(Pipeline.renderSvgGpu(text, w, h, 99));
                byte[] ref = readBytes((String) c[1]);
                assertEquals("max_channel_difference " + c[0], Ppm.maxChannelDifference(inOrder, ref), 0);
                assertTrue("in_order = shuffled " + c[0], java.util.Arrays.equals(inOrder, shuffled));
            }
        });

        scenario("Pipeline: a clip on a shape that isn't grouped", () -> {
            String svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'>"
                    + "<clipPath id='c'><circle cx='32' cy='32' r='20'/></clipPath>"
                    + "<rect x='4' y='4' width='56' height='40' fill='#c83' clip-path='url(#c)'/></svg>";
            byte[] gpu = Ppm.canvasToP6(Pipeline.renderSvgGpu(svg, 64, 64, 3));
            byte[] cpu = Ppm.canvasToP6(SvgWalker.renderSvg(svg, 64, 64));
            assertEquals("max_channel_difference", Ppm.maxChannelDifference(gpu, cpu), 0);
        });
    }

    // ---- §24.6: the unhappy path ---------------------------------------------------

    private static void registerUnhappy() {
        scenario("Unhappy path: groups nested two deep spill, one deep don't", () -> {
            Scene harbor = new Scene(Encoder.encodeSvg(readText("reference/chapter-20/harbor.svg"), 480, 320),
                    480, 320);
            Scene rose = new Scene(Encoder.encodeSvg(readText("reference/chapter-20/rose.svg"), 400, 400),
                    400, 400);
            FineStats fh = new FineStats();
            FineStats fr = new FineStats();
            Pipeline.runPipeline(harbor, null, fh);
            Pipeline.runPipeline(rose, null, fr);
            assertEquals("STACK_DEPTH", Pipeline.STACK_DEPTH, 2);
            assertEquals("fh.spills", fh.spills, 0);
            assertEquals("fr.spills", fr.spills, 200);
            assertEquals("fr.tiles", fr.tiles, 625);
            assertEquals("max_group_depth(rose.commands)", Pipeline.maxGroupDepth(rose.commands), 2);
            assertEquals("max_group_depth(harbor.commands)", Pipeline.maxGroupDepth(harbor.commands), 1);
        });
    }

    // ---- §24.9: Plate 24, and the chapter's renders --------------------------------

    private static void registerPlate() {
        scenario("Plate: plate_24", () ->
                checkRender(Chapter24Figures.plate24(), "reference/chapter-24/plate-24.ppm", 400, 200));
        scenario("Plate: msaa_demo", () ->
                checkRender(Chapter24Figures.msaaDemo(), "reference/chapter-24/msaa-demo.ppm", 192, 480));
        scenario("Plate: spill_map", () ->
                checkRender(Chapter24Figures.spillMap(), "reference/chapter-24/spill-map.ppm", 810, 400));
        scenario("Plate: tiger_assembly", () ->
                checkRender(Chapter24Figures.tigerAssembly(), "reference/chapter-24/tiger-assembly.ppm", 900, 900));

        scenario("Plate: what plate_24 shows", () -> {
            byte[] p6 = Ppm.canvasToP6(Chapter24Figures.plate24());
            assertTriple("(100,100)", Ppm.ppmPixel(p6, 100, 100), new int[] {233, 187, 86});
            assertTriple("(100,40)", Ppm.ppmPixel(p6, 100, 40), new int[] {173, 139, 69});
            assertTriple("(5,5)", Ppm.ppmPixel(p6, 5, 5), new int[] {39, 39, 44});
            assertTriple("(241,46)", Ppm.ppmPixel(p6, 241, 46), new int[] {202, 187, 140});
            assertTriple("(258,46)", Ppm.ppmPixel(p6, 258, 46), new int[] {195, 157, 75});
            assertTriple("(258,100)", Ppm.ppmPixel(p6, 258, 100), new int[] {184, 97, 152});
        });

        scenario("Plate: what the other renders show", () -> {
            byte[] msaa = Ppm.canvasToP6(Chapter24Figures.msaaDemo());
            byte[] spills = Ppm.canvasToP6(Chapter24Figures.spillMap());
            assertTriple("msaa(10,10)", Ppm.ppmPixel(msaa, 10, 10), new int[] {39, 39, 44});
            assertTriple("msaa(10,90)", Ppm.ppmPixel(msaa, 10, 90), new int[] {243, 196, 89});
            assertTriple("spills(415,5)", Ppm.ppmPixel(spills, 415, 5), new int[] {39, 39, 44});
            assertTriple("spills(605,50)", Ppm.ppmPixel(spills, 605, 50), new int[] {237, 124, 196});
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
            long t0 = System.nanoTime();
            try {
                bodies.get(i).run();
                passed++;
                System.out.println("PASS  " + name + "  (" + (System.nanoTime() - t0) / 1_000_000 + " ms)");
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
        java.nio.file.Files.createDirectories(java.nio.file.Path.of("out"));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "plate-24.ppm"),
                Ppm.canvasToP6(Chapter24Figures.plate24()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "msaa-demo.ppm"),
                Ppm.canvasToP6(Chapter24Figures.msaaDemo()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "spill-map.ppm"),
                Ppm.canvasToP6(Chapter24Figures.spillMap()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "tiger-assembly.ppm"),
                Ppm.canvasToP6(Chapter24Figures.tigerAssembly()));
    }
}
