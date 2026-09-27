import java.io.IOException;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter20-*.feature into a Java test. No JUnit, no network: run
 * from the project root so reference/chapter-20 resolves.
 */
public final class Chapter20Tests {

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

    private static void assertPixelEq(String what, Pixel actual, Pixel expected) {
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertMatrixEq(String what, Matrix actual, Matrix expected) {
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected\n" + expected + "\nbut got\n" + actual);
        }
    }

    private static void assertBoundsEq(String what, Bounds actual, Bounds expected) {
        if (!Numbers.approxEqual(actual.minX(), expected.minX())
                || !Numbers.approxEqual(actual.minY(), expected.minY())
                || !Numbers.approxEqual(actual.maxX(), expected.maxX())
                || !Numbers.approxEqual(actual.maxY(), expected.maxY())) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertDoubleArrayEq(String what, double[] actual, double[] expected) {
        if (actual.length != expected.length) {
            throw new AssertionError(what + ": expected " + Arrays.toString(expected)
                    + " but got " + Arrays.toString(actual));
        }
        for (int i = 0; i < actual.length; i++) {
            if (!Numbers.approxEqual(actual[i], expected[i])) {
                throw new AssertionError(what + ": expected " + Arrays.toString(expected)
                        + " but got " + Arrays.toString(actual));
            }
        }
    }

    private static void assertPointsEq(String what, List<Tuple> actual, List<Tuple> expected) {
        if (actual.size() != expected.size()) {
            throw new AssertionError(what + ": expected " + expected.size() + " points but got " + actual.size()
                    + " (" + actual + ")");
        }
        for (int i = 0; i < actual.size(); i++) {
            if (!actual.get(i).approxEquals(expected.get(i))) {
                throw new AssertionError(what + "[" + i + "]: expected " + expected.get(i)
                        + " but got " + actual.get(i));
            }
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

    private static Color c(double r, double g, double b) {
        return new Color(r, g, b);
    }

    private static Tuple pt(double x, double y) {
        return Tuple.point(x, y);
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerNumbers();
        registerPathData();
        registerBuilding();
        registerDocument();
        registerShapes();
        registerTransform();
        registerStyle();
        registerViewBox();
        registerPaint();
        registerGroups();
        registerWalker();
        registerPlate();
    }

    // ---- §20.2: numbers -----------------------------------------------------

    private static void registerNumbers() {
        scenario("Numbers: a number is read, and the index moves past it", () -> {
            SvgNumbers.NumberResult r1 = SvgNumbers.readNumber("12.5e1,3", 0);
            assertDoubleEq("read_number(\"12.5e1,3\", 0).value", r1.value(), 125);
            assertEquals("read_number(\"12.5e1,3\", 0).index", r1.index(), 6);
            SvgNumbers.NumberResult r2 = SvgNumbers.readNumber("M-.5", 1);
            assertDoubleEq("read_number(\"M-.5\", 1).value", r2.value(), -0.5);
            assertEquals("read_number(\"M-.5\", 1).index", r2.index(), 4);
            assertEquals("read_number(\"x\", 0).value", SvgNumbers.readNumber("x", 0).value(), null);
            assertEquals("read_number(\"-\", 0).value", SvgNumbers.readNumber("-", 0).value(), null);
            assertEquals("read_number(\".\", 0).value", SvgNumbers.readNumber(".", 0).value(), null);
        });

        scenario("Numbers: signs and a second point separate numbers without any space", () -> {
            assertDoubleArrayEq("number_list(\"10,20 30-40\")", SvgNumbers.numberList("10,20 30-40"),
                    new double[] {10, 20, 30, -40});
            assertDoubleArrayEq("number_list(\".5.5\")", SvgNumbers.numberList(".5.5"), new double[] {0.5, 0.5});
            assertDoubleArrayEq("number_list(\"0.5.5.5\")", SvgNumbers.numberList("0.5.5.5"),
                    new double[] {0.5, 0.5, 0.5});
            assertDoubleArrayEq("number_list(\"+3 -0\")", SvgNumbers.numberList("+3 -0"), new double[] {3, 0});
        });

        scenario("Numbers: exponents, and an e that isn't one", () -> {
            assertDoubleArrayEq("number_list(\"1e2 1E-1 -.5e+1\")", SvgNumbers.numberList("1e2 1E-1 -.5e+1"),
                    new double[] {100, 0.1, -5});
            assertDoubleArrayEq("number_list(\"1e5.5\")", SvgNumbers.numberList("1e5.5"),
                    new double[] {100000, 0.5});
            assertDoubleArrayEq("number_list(\"3.\")", SvgNumbers.numberList("3."), new double[] {3});
            assertDoubleArrayEq("number_list(\"1e\")", SvgNumbers.numberList("1e"), new double[] {1});
        });

        scenario("Numbers: one comma between numbers, and the list stops at anything else", () -> {
            assertDoubleArrayEq("number_list(\"5 , 6\")", SvgNumbers.numberList("5 , 6"), new double[] {5, 6});
            assertDoubleArrayEq("number_list(\" 5\\t6\\n7 \")", SvgNumbers.numberList(" 5\t6\n7 "),
                    new double[] {5, 6, 7});
            assertDoubleArrayEq("number_list(\"5,,6\")", SvgNumbers.numberList("5,,6"), new double[] {5});
            assertDoubleArrayEq("number_list(\"1 2 x 3\")", SvgNumbers.numberList("1 2 x 3"), new double[] {1, 2});
            assertDoubleArrayEq("number_list(\"\")", SvgNumbers.numberList(""), new double[0]);
        });

        scenario("Numbers: a flag is one character and needs no separator", () -> {
            SvgNumbers.FlagResult f1 = SvgNumbers.readFlag("0110", 0);
            assertEquals("read_flag(\"0110\", 0).value", f1.value(), 0);
            assertEquals("read_flag(\"0110\", 0).index", f1.index(), 1);
            SvgNumbers.FlagResult f2 = SvgNumbers.readFlag("0110", 1);
            assertEquals("read_flag(\"0110\", 1).value", f2.value(), 1);
            assertEquals("read_flag(\"0110\", 1).index", f2.index(), 2);
            assertEquals("read_flag(\"2\", 0).value", SvgNumbers.readFlag("2", 0).value(), null);
        });
    }

    // ---- §20.3: path data -----------------------------------------------------

    private static double[] a(SvgCommand cmd) {
        return cmd.args();
    }

    private static void registerPathData() {
        scenario("PathData: absolute commands come back as they were", () -> {
            List<SvgCommand> cmds = SvgPathData.pathCommands("M10 20 L30 40 Z");
            assertEquals("length(cmds)", cmds.size(), 3);
            assertEquals("cmds[0].op", cmds.get(0).op(), "M");
            assertDoubleArrayEq("cmds[0].args", a(cmds.get(0)), new double[] {10, 20});
            assertEquals("cmds[1].op", cmds.get(1).op(), "L");
            assertDoubleArrayEq("cmds[1].args", a(cmds.get(1)), new double[] {30, 40});
            assertEquals("cmds[2].op", cmds.get(2).op(), "Z");
            assertDoubleArrayEq("cmds[2].args", a(cmds.get(2)), new double[0]);
        });

        scenario("PathData: relative commands are made absolute, and Z returns to the subpath's start", () -> {
            List<SvgCommand> cmds = SvgPathData.pathCommands("m10 20 l5 5 z l1 1");
            assertDoubleArrayEq("cmds[0].args", a(cmds.get(0)), new double[] {10, 20});
            assertEquals("cmds[1].op", cmds.get(1).op(), "L");
            assertDoubleArrayEq("cmds[1].args", a(cmds.get(1)), new double[] {15, 25});
            assertEquals("cmds[2].op", cmds.get(2).op(), "Z");
            assertEquals("cmds[3].op", cmds.get(3).op(), "L");
            assertDoubleArrayEq("cmds[3].args", a(cmds.get(3)), new double[] {11, 21});
        });

        scenario("PathData: H and V become L", () -> {
            List<SvgCommand> cmds = SvgPathData.pathCommands("M0 0 H10 V10 h-5 v-5");
            assertEquals("length(cmds)", cmds.size(), 5);
            assertEquals("cmds[1].op", cmds.get(1).op(), "L");
            assertDoubleArrayEq("cmds[1].args", a(cmds.get(1)), new double[] {10, 0});
            assertDoubleArrayEq("cmds[2].args", a(cmds.get(2)), new double[] {10, 10});
            assertDoubleArrayEq("cmds[3].args", a(cmds.get(3)), new double[] {5, 10});
            assertDoubleArrayEq("cmds[4].args", a(cmds.get(4)), new double[] {5, 5});
        });

        scenario("PathData: a repeated argument group repeats the command, and after M the repeats are L", () -> {
            List<SvgCommand> cmds = SvgPathData.pathCommands("M10 10 20 20 30 10");
            assertEquals("length(cmds)", cmds.size(), 3);
            assertEquals("cmds[1].op", cmds.get(1).op(), "L");
            assertDoubleArrayEq("cmds[1].args", a(cmds.get(1)), new double[] {20, 20});
            assertEquals("cmds[2].op", cmds.get(2).op(), "L");
            assertDoubleArrayEq("cmds[2].args", a(cmds.get(2)), new double[] {30, 10});
            assertDoubleArrayEq("path_commands(\"m10 10 20 20 30 10\")[2].args",
                    a(SvgPathData.pathCommands("m10 10 20 20 30 10").get(2)), new double[] {60, 40});
            assertEquals("length(path_commands(\"M0 0 L1 1 2 2 3 3\"))",
                    SvgPathData.pathCommands("M0 0 L1 1 2 2 3 3").size(), 4);
        });

        scenario("PathData: S reflects the previous cubic's second control point", () -> {
            List<SvgCommand> cmds = SvgPathData.pathCommands("M0 0 C10 0 20 10 20 20 S30 40 40 40");
            assertEquals("cmds[2].op", cmds.get(2).op(), "C");
            assertDoubleArrayEq("cmds[2].args", a(cmds.get(2)), new double[] {20, 30, 30, 40, 40, 40});
            List<SvgCommand> cmds2 =
                    SvgPathData.pathCommands("M0 0 C10 0 20 10 20 20 S30 40 40 40 S50 30 60 20");
            assertDoubleArrayEq("cmds2[3].args", a(cmds2.get(3)), new double[] {50, 40, 50, 30, 60, 20});
        });

        scenario("PathData: S after anything but a cubic starts its curve at the current point", () -> {
            List<SvgCommand> cmds = SvgPathData.pathCommands("M0 0 L5 5 S10 0 20 0");
            assertEquals("cmds[2].op", cmds.get(2).op(), "C");
            assertDoubleArrayEq("cmds[2].args", a(cmds.get(2)), new double[] {5, 5, 10, 0, 20, 0});
        });

        scenario("PathData: T reflects the previous quadratic's control point, again and again", () -> {
            List<SvgCommand> cmds = SvgPathData.pathCommands("M0 0 Q10 0 10 10 T20 20 T30 30");
            assertEquals("cmds[2].op", cmds.get(2).op(), "Q");
            assertDoubleArrayEq("cmds[2].args", a(cmds.get(2)), new double[] {10, 20, 20, 20});
            assertDoubleArrayEq("cmds[3].args", a(cmds.get(3)), new double[] {30, 20, 30, 30});
            assertDoubleArrayEq("path_commands(\"M0 0 L5 5 T10 10\")[2].args",
                    a(SvgPathData.pathCommands("M0 0 L5 5 T10 10").get(2)), new double[] {5, 5, 10, 10});
            assertDoubleArrayEq("path_commands(\"M0 0 C1 1 2 2 3 3 T10 10\")[2].args",
                    a(SvgPathData.pathCommands("M0 0 C1 1 2 2 3 3 T10 10").get(2)), new double[] {3, 3, 10, 10});
        });

        scenario("PathData: arc flags are packed without separators", () -> {
            List<SvgCommand> cmds = SvgPathData.pathCommands("M0 0a1 1 0 0110 0");
            assertEquals("length(cmds)", cmds.size(), 2);
            assertEquals("cmds[1].op", cmds.get(1).op(), "A");
            assertDoubleArrayEq("cmds[1].args", a(cmds.get(1)), new double[] {1, 1, 0, 0, 1, 10, 0});
            assertDoubleArrayEq("path_commands(\"M0 0 a-5 -5 30 1 0 10 0\")[1].args",
                    a(SvgPathData.pathCommands("M0 0 a-5 -5 30 1 0 10 0").get(1)),
                    new double[] {5, 5, 30, 1, 0, 10, 0});
        });

        scenario("PathData: nothing needs a separator where a sign or a point can do the job", () -> {
            List<SvgCommand> cmds = SvgPathData.pathCommands("M1,2l3-4-5.5.5e1");
            assertEquals("length(cmds)", cmds.size(), 3);
            assertDoubleArrayEq("cmds[1].args", a(cmds.get(1)), new double[] {4, -2});
            assertDoubleArrayEq("cmds[2].args", a(cmds.get(2)), new double[] {-1.5, 3});
        });

        scenario("PathData: the path must start with a moveto", () -> {
            assertEquals("length(path_commands(\"L10 10\"))", SvgPathData.pathCommands("L10 10").size(), 0);
            assertEquals("length(path_commands(\"\"))", SvgPathData.pathCommands("").size(), 0);
            List<SvgCommand> cmds = SvgPathData.pathCommands("M0 0 z m1 1");
            assertEquals("length(path_commands(\"M0 0 z m1 1\"))", cmds.size(), 3);
            assertEquals("cmds[2].op", cmds.get(2).op(), "M");
        });

        scenario("PathData: at an error, the commands so far are the answer", () -> {
            assertEquals("length", SvgPathData.pathCommands("M10 10 L20 20 L30 x 40").size(), 2);
            assertEquals("length", SvgPathData.pathCommands("M 10,10 L 20,20 30").size(), 2);
            assertEquals("length", SvgPathData.pathCommands("M0 0 L5 5 Z 6 6").size(), 3);
            assertEquals("length", SvgPathData.pathCommands("M0 0 L5 5 X 6 6").size(), 2);
            assertEquals("length", SvgPathData.pathCommands("M0 0 a1 1 0 2 0 5 5").size(), 1);
        });

        scenario("PathData: the tiger's first path", () -> {
            SvgElement root = Xml.parseXml(readText("reference/chapter-20/tiger.svg"));
            List<SvgCommand> cmds = SvgPathData.pathCommands(Xml.findById(root, "path8").attribute("d"));
            assertEquals("length(cmds)", cmds.size(), 5);
            assertDoubleArrayEq("cmds[0].args", a(cmds.get(0)), new double[] {-122.3, 84.285});
            assertEquals("cmds[1].op", cmds.get(1).op(), "C");
            assertDoubleArrayEq("cmds[1].args", a(cmds.get(1)),
                    new double[] {-122.3, 84.285, -122.2, 86.179, -123.03, 86.16});
            assertDoubleArrayEq("cmds[2].args", a(cmds.get(2)),
                    new double[] {-123.85, 86.141, -140.3, 38.066, -160.83, 40.309});
            assertDoubleArrayEq("cmds[3].args", a(cmds.get(3)),
                    new double[] {-160.83, 40.309, -143.05, 32.956, -122.3, 84.285});
            assertEquals("cmds[4].op", cmds.get(4).op(), "Z");
        });
    }

    // ---- §20.4: from commands to a path --------------------------------------

    private static void registerBuilding() {
        scenario("Building: a quarter circle is one cubic with handles 0.5523 of a radius long", () -> {
            List<Curve> cs = ArcCubics.arcCubics(10, 0, 10, 10, 0, false, true, 0, 10);
            assertEquals("length(cs)", cs.size(), 1);
            List<Tuple> points = cs.get(0).points();
            assertTupleEq("cs[0].points[0]", points.get(0), pt(10, 0));
            assertTupleEq("cs[0].points[1]", points.get(1), pt(10, 5.5228));
            assertTupleEq("cs[0].points[2]", points.get(2), pt(5.5228, 10));
            assertTupleEq("cs[0].points[3]", points.get(3), pt(0, 10));
            assertEquals("length(arc_cubics(8.3, 1.1, 3.3, 3.3, 0, 0, 1, 5, 4.4))",
                    ArcCubics.arcCubics(8.3, 1.1, 3.3, 3.3, 0, false, true, 5, 4.4).size(), 1);
        });

        scenario("Building: a half turn is two quarters, and the sweep flag says which way round", () -> {
            List<Curve> cs = ArcCubics.arcCubics(0, 0, 5, 5, 0, false, true, 10, 0);
            assertEquals("length(cs)", cs.size(), 2);
            assertTupleEq("cs[0].points[3]", cs.get(0).points().get(3), pt(5, -5));
            assertTupleEq("cs[1].points[1]", cs.get(1).points().get(1), pt(7.7614, -5));
            assertTupleEq("cs[1].points[3]", cs.get(1).points().get(3), pt(10, 0));
            assertTupleEq("sweep=0",
                    ArcCubics.arcCubics(0, 0, 5, 5, 0, false, false, 10, 0).get(0).points().get(3), pt(5, 5));
        });

        scenario("Building: radii too small to reach are grown, as chapter 8 does", () -> {
            List<Curve> cs = ArcCubics.arcCubics(0, 0, 1, 1, 0, false, true, 10, 0);
            assertEquals("length(cs)", cs.size(), 2);
            assertTupleEq("cs[0].points[3]", cs.get(0).points().get(3), pt(5, -5));
        });

        scenario("Building: the large-arc flag takes the long way round", () -> {
            assertEquals("length", ArcCubics.arcCubics(0, 0, 10, 10, 0, true, false, 0.01, 0).size(), 4);
            assertEquals("length", ArcCubics.arcCubics(0, 0, 10, 10, 0, false, false, 0.01, 0).size(), 1);
        });

        scenario("Building: no arc between coincident points, and a line when a radius is zero", () -> {
            assertEquals("length", ArcCubics.arcCubics(3, 3, 5, 5, 0, false, true, 3, 3).size(), 0);
            List<Curve> cs = ArcCubics.arcCubics(0, 0, 0, 5, 0, false, true, 9, 3);
            assertEquals("length", cs.size(), 1);
            assertTupleEq("cs[0].points[1]", cs.get(0).points().get(1), pt(3, 1));
            assertTupleEq("cs[0].points[2]", cs.get(0).points().get(2), pt(6, 2));
        });

        scenario("Building: points go through the matrix, and Z then L starts at the subpath's start", () -> {
            Path p = SvgBuilder.buildPath(
                    SvgPathData.pathCommands("M0 0 L10 0 L10 10 Z L0 10"), Transforms.scaling(2, 2), 0.1);
            assertEquals("length(subpaths(p))", p.subpaths().size(), 2);
            assertPointsEq("subpaths(p)[0].points", p.subpaths().get(0).points,
                    List.of(pt(0, 0), pt(20, 0), pt(20, 20)));
            assertTrue("subpaths(p)[0].closed", p.subpaths().get(0).closed);
            assertPointsEq("subpaths(p)[1].points", p.subpaths().get(1).points, List.of(pt(0, 0), pt(0, 20)));
            assertTrue("subpaths(p)[1].closed = false", !p.subpaths().get(1).closed);
        });

        scenario("Building: a moveto on its own is dropped, but a closed point stays", () -> {
            Path p = SvgBuilder.buildPath(
                    SvgPathData.pathCommands("M0 0 L10 0 M20 20 M5 5 L6 6 M7 7"), Matrix.identity(), 0.1);
            assertEquals("length(subpaths(p))", p.subpaths().size(), 2);
            assertPointsEq("subpaths(p)[1].points", p.subpaths().get(1).points, List.of(pt(5, 5), pt(6, 6)));
            assertEquals("length",
                    SvgBuilder.buildPath(SvgPathData.pathCommands("M1 1 Z"), Matrix.identity(), 0.1)
                            .subpaths().size(),
                    1);
        });

        scenario("Building: curves are flattened after the transform, so a bigger curve gets more points", () -> {
            assertEquals("identity",
                    SvgBuilder.buildPath(SvgPathData.pathCommands("M0 0 Q10 0 10 10"), Matrix.identity(), 0.1)
                            .subpaths().get(0).points.size(),
                    13);
            assertEquals("scaled",
                    SvgBuilder.buildPath(SvgPathData.pathCommands("M0 0 Q10 0 10 10"), Transforms.scaling(10, 10), 0.1)
                            .subpaths().get(0).points.size(),
                    33);
        });

        scenario("Building: an arc in a path ends exactly at its end point", () -> {
            Path p = SvgBuilder.buildPath(SvgPathData.pathCommands("M0 0 A5 5 0 0 1 10 0"), Matrix.identity(), 0.1);
            List<Tuple> points = p.subpaths().get(0).points;
            assertEquals("length(subpaths(p)[0].points)", points.size(), 17);
            assertTupleEq("subpaths(p)[0].points[16]", points.get(16), pt(10, 0));
            assertTupleEq("subpaths(p)[0].points[8]", points.get(8), pt(5, -5));
        });

        scenario("Building: the bounds of the geometry, not of the control points", () -> {
            assertBoundsEq("commands_bounds(...C...)",
                    SvgBuilder.commandsBounds(SvgPathData.pathCommands("M0 0 C0 -10 10 -10 10 0")),
                    new Bounds(0, -7.5, 10, 0));
            assertBoundsEq("commands_bounds(...Q...)",
                    SvgBuilder.commandsBounds(SvgPathData.pathCommands("M0 0 Q10 20 20 0")),
                    new Bounds(0, 0, 20, 10));
            assertBoundsEq("commands_bounds(...A sweep1...)",
                    SvgBuilder.commandsBounds(SvgPathData.pathCommands("M0 0 A5 5 0 0 1 10 0")),
                    new Bounds(0, -5, 10, 0));
            assertBoundsEq("commands_bounds(...A sweep0...)",
                    SvgBuilder.commandsBounds(SvgPathData.pathCommands("M0 0 A5 5 0 0 0 10 0")),
                    new Bounds(0, 0, 10, 5));
            assertBoundsEq("commands_bounds(\"\")",
                    SvgBuilder.commandsBounds(SvgPathData.pathCommands("")), new Bounds(0, 0, 0, 0));
        });
    }

    // ---- §20.1: the document --------------------------------------------------

    private static void registerDocument() {
        scenario("Document: an element is its local name, its attributes and its children", () -> {
            SvgElement root = Xml.parseXml("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 10 10'>"
                    + "<g id='a' fill='red'><rect width='2'/><!-- a note --><circle r='1'/></g></svg>");
            assertEquals("root.name", root.name, "svg");
            assertEquals("attribute(root, \"viewBox\")", root.attribute("viewBox"), "0 0 10 10");
            assertEquals("length(children(root))", root.children.size(), 1);
            assertEquals("children(root)[0].name", root.children.get(0).name, "g");
            assertEquals("attribute(children(root)[0], \"fill\")", root.children.get(0).attribute("fill"), "red");
            assertEquals("attribute(children(root)[0], \"stroke\")", root.children.get(0).attribute("stroke"), null);
            assertEquals("length(children(children(root)[0]))", root.children.get(0).children.size(), 2);
            assertEquals("children(children(root)[0])[1].name", root.children.get(0).children.get(1).name,
                    "circle");
        });

        scenario("Document: a prefixed element has the same local name", () -> {
            SvgElement root = Xml.parseXml("<s:svg xmlns:s='http://www.w3.org/2000/svg'><s:path d='M0 0'/></s:svg>");
            assertEquals("root.name", root.name, "svg");
            assertEquals("children(root)[0].name", root.children.get(0).name, "path");
            assertEquals("attribute(children(root)[0], \"d\")", root.children.get(0).attribute("d"), "M0 0");
        });

        scenario("Document: an id is found anywhere in the document, even ahead of where it is used", () -> {
            SvgElement root = Xml.parseXml("<svg><rect fill='url(#g)' width='4' height='4'/><defs>"
                    + "<linearGradient id='g'><stop offset='0'/></linearGradient></defs></svg>");
            assertEquals("find_by_id(root, \"g\").name", Xml.findById(root, "g").name, "linearGradient");
            assertEquals("find_by_id(root, \"nothing\")", Xml.findById(root, "nothing"), null);
        });
    }

    // ---- §20.7: basic shapes ----------------------------------------------------

    private static void registerShapes() {
        scenario("Shapes: a rectangle is four corners, clockwise on screen, closed", () -> {
            List<SvgCommand> cmds =
                    SvgShapes.shapeCommands(Xml.parseXml("<rect x='1' y='2' width='10' height='5'/>"));
            assertEquals("length(cmds)", cmds.size(), 5);
            assertDoubleArrayEq("cmds[0].args", a(cmds.get(0)), new double[] {1, 2});
            assertDoubleArrayEq("cmds[1].args", a(cmds.get(1)), new double[] {11, 2});
            assertDoubleArrayEq("cmds[2].args", a(cmds.get(2)), new double[] {11, 7});
            assertDoubleArrayEq("cmds[3].args", a(cmds.get(3)), new double[] {1, 7});
            assertEquals("cmds[4].op", cmds.get(4).op(), "Z");
        });

        scenario("Shapes: rounded corners are quarter arcs between the sides", () -> {
            List<SvgCommand> cmds = SvgShapes.shapeCommands(Xml.parseXml("<rect width='10' height='6' rx='2'/>"));
            assertEquals("length(cmds)", cmds.size(), 10);
            assertDoubleArrayEq("cmds[0].args", a(cmds.get(0)), new double[] {2, 0});
            assertDoubleArrayEq("cmds[1].args", a(cmds.get(1)), new double[] {8, 0});
            assertEquals("cmds[2].op", cmds.get(2).op(), "A");
            assertDoubleArrayEq("cmds[2].args", a(cmds.get(2)), new double[] {2, 2, 0, 0, 1, 10, 2});
            assertDoubleArrayEq("cmds[8].args", a(cmds.get(8)), new double[] {2, 2, 0, 0, 1, 2, 0});
        });

        scenario("Shapes: a corner radius is at most half a side, and one radius stands for both", () -> {
            List<SvgCommand> cmds =
                    SvgShapes.shapeCommands(Xml.parseXml("<rect width='10' height='6' rx='20' ry='1'/>"));
            assertDoubleArrayEq("cmds[0].args", a(cmds.get(0)), new double[] {5, 0});
            assertDoubleArrayEq("cmds[2].args", a(cmds.get(2)), new double[] {5, 1, 0, 0, 1, 10, 1});
            assertDoubleArrayEq("ry only",
                    a(SvgShapes.shapeCommands(Xml.parseXml("<rect width='10' height='6' ry='3'/>")).get(2)),
                    new double[] {3, 3, 0, 0, 1, 10, 3});
            assertEquals("negative ry has no rounding",
                    SvgShapes.shapeCommands(Xml.parseXml("<rect width='10' height='6' ry='-3'/>")).size(), 5);
        });

        scenario("Shapes: a circle and an ellipse are four quarter arcs from the right-hand point", () -> {
            List<SvgCommand> cmds =
                    SvgShapes.shapeCommands(Xml.parseXml("<ellipse cx='5' cy='5' rx='4' ry='2'/>"));
            assertEquals("length(cmds)", cmds.size(), 6);
            assertDoubleArrayEq("cmds[0].args", a(cmds.get(0)), new double[] {9, 5});
            assertDoubleArrayEq("cmds[1].args", a(cmds.get(1)), new double[] {4, 2, 0, 0, 1, 5, 7});
            assertDoubleArrayEq("cmds[2].args", a(cmds.get(2)), new double[] {4, 2, 0, 0, 1, 1, 5});
            assertDoubleArrayEq("cmds[3].args", a(cmds.get(3)), new double[] {4, 2, 0, 0, 1, 5, 3});
            assertDoubleArrayEq("cmds[4].args", a(cmds.get(4)), new double[] {4, 2, 0, 0, 1, 9, 5});
            assertEquals("cmds[5].op", cmds.get(5).op(), "Z");
            assertBoundsEq("commands_bounds(circle)",
                    SvgBuilder.commandsBounds(SvgShapes.shapeCommands(Xml.parseXml("<circle cx='5' cy='5' r='4'/>"))),
                    new Bounds(1, 1, 9, 9));
        });

        scenario("Shapes: lines, polylines and polygons", () -> {
            assertEquals("length(line)",
                    SvgShapes.shapeCommands(Xml.parseXml("<line x1='1' y1='2' x2='3' y2='4'/>")).size(), 2);
            assertDoubleArrayEq("line[1].args",
                    a(SvgShapes.shapeCommands(Xml.parseXml("<line x1='1' y1='2' x2='3' y2='4'/>")).get(1)),
                    new double[] {3, 4});
            assertEquals("length(polyline)",
                    SvgShapes.shapeCommands(Xml.parseXml("<polyline points='0,0 10,0 10,10 5'/>")).size(), 3);
            assertEquals("length(polygon)",
                    SvgShapes.shapeCommands(Xml.parseXml("<polygon points='0 0 10 0 10 10'/>")).size(), 4);
            assertEquals("polygon[3].op",
                    SvgShapes.shapeCommands(Xml.parseXml("<polygon points='0 0 10 0 10 10'/>")).get(3).op(), "Z");
        });

        scenario("Shapes: shapes that don't render have no commands", () -> {
            assertEquals("rect 0", SvgShapes.shapeCommands(Xml.parseXml("<rect width='0' height='6'/>")).size(), 0);
            assertEquals("circle r0", SvgShapes.shapeCommands(Xml.parseXml("<circle r='0'/>")).size(), 0);
            assertEquals("ellipse", SvgShapes.shapeCommands(Xml.parseXml("<ellipse rx='3'/>")).size(), 0);
            assertEquals("polygon empty", SvgShapes.shapeCommands(Xml.parseXml("<polygon points=''/>")).size(), 0);
            assertEquals("text", SvgShapes.shapeCommands(Xml.parseXml("<text/>")).size(), 0);
        });
    }

    // ---- §20.5: the transform attribute -----------------------------------------

    private static void registerTransform() {
        scenario("Transform: matrix lists its six numbers column by column", () -> {
            Matrix m = SvgTransform.parseTransform("matrix(1 2 3 4 5 6)");
            assertMatrixEq("m", m, Matrix.matrix3(1, 3, 5, 2, 4, 6, 0, 0, 1));
        });

        scenario("Transform: translate, scale and their one-number forms", () -> {
            assertTupleEq("translate(10 20)", SvgTransform.parseTransform("translate(10 20)").multiply(pt(1, 1)),
                    pt(11, 21));
            assertTupleEq("translate(10)", SvgTransform.parseTransform("translate(10)").multiply(pt(1, 1)),
                    pt(11, 1));
            assertTupleEq("scale(2)", SvgTransform.parseTransform("scale(2)").multiply(pt(1, 1)), pt(2, 2));
            assertTupleEq("scale(2,3)", SvgTransform.parseTransform("scale(2,3)").multiply(pt(1, 1)), pt(2, 3));
            assertTupleEq("translate(1e1 -2e0)",
                    SvgTransform.parseTransform("translate(1e1 -2e0)").multiply(pt(1, 1)), pt(11, -1));
        });

        scenario("Transform: rotate is in degrees, clockwise on screen, and can turn about a point", () -> {
            assertTupleEq("rotate(90)", SvgTransform.parseTransform("rotate(90)").multiply(pt(1, 1)), pt(-1, 1));
            assertTupleEq("rotate(90 10 10) * (1,1)",
                    SvgTransform.parseTransform("rotate(90 10 10)").multiply(pt(1, 1)), pt(19, 1));
            assertTupleEq("rotate(90 10 10) * (10,10)",
                    SvgTransform.parseTransform("rotate(90 10 10)").multiply(pt(10, 10)), pt(10, 10));
        });

        scenario("Transform: skewX leans x with y, skewY leans y with x", () -> {
            assertTupleEq("skewX(45) * (1,1)", SvgTransform.parseTransform("skewX(45)").multiply(pt(1, 1)),
                    pt(2, 1));
            assertTupleEq("skewY(45) * (1,1)", SvgTransform.parseTransform("skewY(45)").multiply(pt(1, 1)),
                    pt(1, 2));
            assertTupleEq("skewX(45) * (1,0)", SvgTransform.parseTransform("skewX(45)").multiply(pt(1, 0)),
                    pt(1, 0));
        });

        scenario("Transform: a list applies right to left", () -> {
            assertTupleEq("translate then scale",
                    SvgTransform.parseTransform("translate(10,20) scale(2)").multiply(pt(1, 1)), pt(12, 22));
            assertTupleEq("scale then translate",
                    SvgTransform.parseTransform("scale(2) translate(10,20)").multiply(pt(1, 1)), pt(22, 42));
            assertMatrixEq("comma-separated == space-separated",
                    SvgTransform.parseTransform("translate(10 20),scale(2)"),
                    SvgTransform.parseTransform("translate(10 20) scale(2)"));
            assertTupleEq("translate then rotate",
                    SvgTransform.parseTransform("translate(10 20)rotate(90)").multiply(pt(1, 1)), pt(9, 21));
            assertTupleEq("space before parens",
                    SvgTransform.parseTransform("translate (5 5)").multiply(pt(1, 1)), pt(6, 6));
        });

        scenario("Transform: nothing, or anything broken, is the identity", () -> {
            assertMatrixEq("empty", SvgTransform.parseTransform(""), Matrix.identity());
            assertMatrixEq("none", SvgTransform.parseTransform(null), Matrix.identity());
            assertMatrixEq("rotate(30 1)", SvgTransform.parseTransform("rotate(30 1)"), Matrix.identity());
            assertMatrixEq("unknown function", SvgTransform.parseTransform("translate(1 2) bogus(3)"),
                    Matrix.identity());
            assertMatrixEq("missing paren", SvgTransform.parseTransform("scale(2"), Matrix.identity());
        });
    }

    // ---- §20.6: colours and the style cascade -----------------------------------

    private static void registerStyle() {
        scenario("Style: three spellings of one colour, decoded to light", () -> {
            assertColorEq("#f80", SvgColor.parseColor("#f80"), c(1, 0.2462, 0));
            assertColorEq("#FF8800", SvgColor.parseColor("#FF8800"), c(1, 0.2462, 0));
            assertColorEq("rgb(255, 136, 0)", SvgColor.parseColor("rgb(255, 136, 0)"), c(1, 0.2462, 0));
            assertColorEq("#808080", SvgColor.parseColor("#808080"), c(0.2159, 0.2159, 0.2159));
        });

        scenario("Style: percentages, clamping, names, and what isn't a colour", () -> {
            assertColorEq("rgb(50%,0%,100%)", SvgColor.parseColor("rgb(50%, 0%, 100%)"), c(0.2140, 0, 1));
            assertColorEq("rgb(300,-5,0)", SvgColor.parseColor("rgb(300,-5,0)"), c(1, 0, 0));
            assertColorEq("orange", SvgColor.parseColor("orange"), c(1, 0.3763, 0));
            assertColorEq("RED", SvgColor.parseColor("RED"), c(1, 0, 0));
            assertColorEq(" blue ", SvgColor.parseColor(" blue "), c(0, 0, 1));
            assertColorEq("gray == #808080", SvgColor.parseColor("gray"), SvgColor.parseColor("#808080"));
            assertEquals("#12345", SvgColor.parseColor("#12345"), null);
            assertEquals("currentColor", SvgColor.parseColor("currentColor"), null);
            assertEquals("rgb(1,2)", SvgColor.parseColor("rgb(1,2)"), null);
        });

        scenario("Style: the initial style", () -> {
            SvgStyle.Style s = SvgStyle.initialStyle();
            assertColorEq("s.fill", (Color) s.fill, c(0, 0, 0));
            assertEquals("s.stroke", s.stroke, null);
            assertDoubleEq("s.stroke_width", s.strokeWidth, 1);
            assertEquals("s.fill_rule", s.fillRule, "nonzero");
            assertDoubleEq("s.opacity", s.opacity, 1);
            assertDoubleEq("s.stroke_miterlimit", s.strokeMiterlimit, 4);
            assertEquals("s.stroke_linecap", s.strokeLinecap, "butt");
            assertEquals("s.stroke_linejoin", s.strokeLinejoin, "miter");
            assertEquals("s.stroke_dasharray", s.strokeDasharray, null);
            assertEquals("s.clip_path", s.clipPath, null);
        });

        scenario("Style: inherited properties come down from the parent, opacity doesn't", () -> {
            SvgElement root = Xml.parseXml("<g fill='#808080' stroke-width='3px' opacity='0.5'><rect/></g>");
            SvgStyle.Style gs = SvgStyle.computedStyle(root, SvgStyle.initialStyle());
            SvgStyle.Style rs = SvgStyle.computedStyle(root.children.get(0), gs);
            assertColorEq("gs.fill", (Color) gs.fill, c(0.2159, 0.2159, 0.2159));
            assertDoubleEq("gs.stroke_width", gs.strokeWidth, 3);
            assertDoubleEq("gs.opacity", gs.opacity, 0.5);
            assertColorEq("rs.fill", (Color) rs.fill, c(0.2159, 0.2159, 0.2159));
            assertDoubleEq("rs.stroke_width", rs.strokeWidth, 3);
            assertDoubleEq("rs.opacity", rs.opacity, 1);
        });

        scenario("Style: a style declaration beats a presentation attribute, whatever the order", () -> {
            SvgElement root = Xml.parseXml("<g><rect style='fill: lime' fill='red'/></g>");
            SvgStyle.Style rs = SvgStyle.computedStyle(
                    root.children.get(0), SvgStyle.computedStyle(root, SvgStyle.initialStyle()));
            assertColorEq("rs.fill", (Color) rs.fill, c(0, 1, 0));
        });

        scenario("Style: inherit, a value that doesn't parse, and a url reference", () -> {
            SvgElement root = Xml.parseXml("<g opacity='0.5' style='stroke: blue; fill-opacity: 0.25'>"
                    + "<rect opacity='inherit' stroke-width='-2' fill-rule='odd' stroke='#nope' "
                    + "fill='url(#sky)'/></g>");
            SvgStyle.Style gs = SvgStyle.computedStyle(root, SvgStyle.initialStyle());
            SvgStyle.Style rs = SvgStyle.computedStyle(root.children.get(0), gs);
            assertDoubleEq("rs.opacity", rs.opacity, 0.5);
            assertDoubleEq("rs.stroke_width", rs.strokeWidth, 1);
            assertEquals("rs.fill_rule", rs.fillRule, "nonzero");
            assertColorEq("rs.stroke", (Color) rs.stroke, c(0, 0, 1));
            assertDoubleEq("rs.fill_opacity", rs.fillOpacity, 0.25);
            assertEquals("rs.fill", rs.fill, "url(#sky)");
        });

        scenario("Style: dash arrays, rules, caps and joins", () -> {
            SvgElement root = Xml.parseXml("<path stroke-dasharray='5, 3 2' stroke-linecap='round' "
                    + "stroke-linejoin='bevel' fill-rule='evenodd' stroke-miterlimit='10' "
                    + "stroke-dashoffset='1.5' fill='none'/>");
            SvgStyle.Style s = SvgStyle.computedStyle(root, SvgStyle.initialStyle());
            assertDoubleArrayEq("s.stroke_dasharray", s.strokeDasharray, new double[] {5, 3, 2});
            assertEquals("s.stroke_linecap", s.strokeLinecap, "round");
            assertEquals("s.stroke_linejoin", s.strokeLinejoin, "bevel");
            assertEquals("s.fill_rule", s.fillRule, "evenodd");
            assertDoubleEq("s.stroke_miterlimit", s.strokeMiterlimit, 10);
            assertDoubleEq("s.stroke_dashoffset", s.strokeDashoffset, 1.5);
            assertEquals("s.fill", s.fill, null);
        });
    }

    // ---- §20.8: viewBox and preserveAspectRatio ---------------------------------

    private static void registerViewBox() {
        scenario("ViewBox: meet fits the whole box and centres it", () -> {
            Matrix m = ViewBox.viewBoxMatrix("0 0 60 80", "xMidYMid meet", 120, 90);
            assertTupleEq("m * (0,0)", m.multiply(pt(0, 0)), pt(26.25, 0));
            assertTupleEq("m * (60,80)", m.multiply(pt(60, 80)), pt(93.75, 90));
            assertMatrixEq("default aspect", ViewBox.viewBoxMatrix("0 0 60 80", null, 120, 90), m);
            assertMatrixEq("meet is default", ViewBox.viewBoxMatrix("0 0 60 80", "xMidYMid", 120, 90), m);
        });

        scenario("ViewBox: the alignment words slide the box along the spare axis", () -> {
            assertTupleEq("xMinYMid meet * (0,0)",
                    ViewBox.viewBoxMatrix("0 0 60 80", "xMinYMid meet", 120, 90).multiply(pt(0, 0)), pt(0, 0));
            assertTupleEq("xMaxYMid meet * (0,0)",
                    ViewBox.viewBoxMatrix("0 0 60 80", "xMaxYMid meet", 120, 90).multiply(pt(0, 0)), pt(52.5, 0));
            assertTupleEq("xMaxYMid meet * (60,80)",
                    ViewBox.viewBoxMatrix("0 0 60 80", "xMaxYMid meet", 120, 90).multiply(pt(60, 80)),
                    pt(120, 90));
        });

        scenario("ViewBox: slice fills the viewport and spills", () -> {
            assertTupleEq("xMidYMid slice * (0,0)",
                    ViewBox.viewBoxMatrix("0 0 60 80", "xMidYMid slice", 120, 90).multiply(pt(0, 0)),
                    pt(0, -35));
            assertTupleEq("xMidYMid slice * (60,80)",
                    ViewBox.viewBoxMatrix("0 0 60 80", "xMidYMid slice", 120, 90).multiply(pt(60, 80)),
                    pt(120, 125));
            assertTupleEq("xMidYMin slice * (0,0)",
                    ViewBox.viewBoxMatrix("0 0 60 80", "xMidYMin slice", 120, 90).multiply(pt(0, 0)), pt(0, 0));
            assertTupleEq("xMaxYMax slice * (0,0)",
                    ViewBox.viewBoxMatrix("0 0 60 80", "xMaxYMax slice", 120, 90).multiply(pt(0, 0)),
                    pt(0, -70));
        });

        scenario("ViewBox: none stretches each axis on its own", () -> {
            Matrix m = ViewBox.viewBoxMatrix("0 0 60 80", "none", 120, 90);
            assertMatrixEq("m", m, Transforms.scaling(2, 1.125));
        });

        scenario("ViewBox: the box's origin moves to the viewport's", () -> {
            assertTupleEq("origin moves",
                    ViewBox.viewBoxMatrix("10 20 60 80", "xMidYMid meet", 120, 90).multiply(pt(10, 20)),
                    pt(26.25, 0));
            assertTupleEq("negative origin, comma separated",
                    ViewBox.viewBoxMatrix("-5,-5,10,10", null, 100, 100).multiply(pt(0, 0)), pt(50, 50));
        });

        scenario("ViewBox: no usable viewBox is the identity", () -> {
            assertMatrixEq("none", ViewBox.viewBoxMatrix(null, null, 50, 50), Matrix.identity());
            assertMatrixEq("zero height", ViewBox.viewBoxMatrix("0 0 0 5", null, 50, 50), Matrix.identity());
            assertMatrixEq("only three numbers", ViewBox.viewBoxMatrix("0 0 50", null, 50, 50), Matrix.identity());
        });

        scenario("ViewBox: one drawing, five ways to fit it", () -> {
            Canvas c = Figures.aspectDemo();
            byte[] ref = readBytes("reference/chapter-20/aspect_demo.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 660);
            assertEquals("c.height", c.height, 110);
            assertTriple("ppm_pixel(p6, 70, 39)", Ppm.ppmPixel(p6, 70, 39), new int[] {232, 85, 58}, 1);
            assertTriple("ppm_pixel(p6, 240, 50)", Ppm.ppmPixel(p6, 240, 50), new int[] {255, 255, 255}, 1);
            assertTriple("ppm_pixel(p6, 280, 50)", Ppm.ppmPixel(p6, 280, 50), new int[] {255, 255, 255}, 1);
            assertTriple("ppm_pixel(p6, 335, 50)", Ppm.ppmPixel(p6, 335, 50), new int[] {232, 85, 58}, 1);
            assertTriple("ppm_pixel(p6, 150, 95)", Ppm.ppmPixel(p6, 150, 95), new int[] {59, 91, 122}, 1);
            assertTriple("ppm_pixel(p6, 590, 27)", Ppm.ppmPixel(p6, 590, 27), new int[] {232, 85, 58}, 1);
            assertTriple("ppm_pixel(p6, 5, 5)", Ppm.ppmPixel(p6, 5, 5), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    // ---- §20.9: paint servers ---------------------------------------------------

    private static void registerPaint() {
        scenario("Paint: a paint seen through a matrix", () -> {
            Paint g = new LinearGradient(pt(0, 0), pt(1, 0),
                    List.of(new Stop(0, c(0, 0, 0)), new Stop(1, c(1, 1, 1))), "pad");
            assertColorEq("scaling(10,1)",
                    new TransformedPaint(g, Transforms.scaling(10, 1)).paintAt(5, 0), c(0.5, 0.5, 0.5));
            assertColorEq("translation then scaling",
                    new TransformedPaint(g, Transforms.translation(10, 0).multiply(Transforms.scaling(10, 1)))
                            .paintAt(12.5, 3),
                    c(0.25, 0.25, 0.25));
        });

        scenario("Paint: stops are fractions, never going backwards, and only stop children count", () -> {
            SvgElement root = Xml.parseXml("<linearGradient><stop offset='50%' style='stop-color: red'/>"
                    + "<stop offset='20%' stop-color='blue'/><circle/><stop offset='1.5' stop-color='lime'/>"
                    + "</linearGradient>");
            List<Stop> stops = SvgPaint.gradientStops(root);
            assertEquals("length(stops)", stops.size(), 3);
            assertDoubleEq("stops[0].offset", stops.get(0).offset(), 0.5);
            assertColorEq("stops[0].color", stops.get(0).color(), c(1, 0, 0));
            assertDoubleEq("stops[1].offset", stops.get(1).offset(), 0.5);
            assertColorEq("stops[1].color", stops.get(1).color(), c(0, 0, 1));
            assertDoubleEq("stops[2].offset", stops.get(2).offset(), 1);
            assertColorEq("stops[2].color", stops.get(2).color(), c(0, 1, 0));
        });

        scenario("Paint: objectBoundingBox spreads the gradient across the shape's bounds", () -> {
            SvgElement root = Xml.parseXml("<svg><linearGradient id='a'><stop offset='0' stop-color='black'/>"
                    + "<stop offset='1' stop-color='white'/></linearGradient></svg>");
            Bounds bbox = new Bounds(10, 0, 30, 10);
            Paint p = SvgPaint.paintServer(root, "url(#a)", bbox, Matrix.identity());
            assertColorEq("paint_at(p, 10, 5)", p.paintAt(10, 5), c(0, 0, 0));
            assertColorEq("paint_at(p, 15, 5)", p.paintAt(15, 5), c(0.25, 0.25, 0.25));
            assertColorEq("paint_at(p, 20, 5)", p.paintAt(20, 5), c(0.5, 0.5, 0.5));
            assertColorEq("paint_at(p, 30, 5)", p.paintAt(30, 5), c(1, 1, 1));
            assertColorEq("paint_at(scaled ctm, 40, 10)",
                    SvgPaint.paintServer(root, "url(#a)", bbox, Transforms.scaling(2, 2)).paintAt(40, 10),
                    c(0.5, 0.5, 0.5));
        });

        scenario("Paint: userSpaceOnUse leaves the coordinates in user space", () -> {
            SvgElement root = Xml.parseXml("<svg><linearGradient id='u' gradientUnits='userSpaceOnUse' x1='0' "
                    + "y1='0' x2='100' y2='0'><stop offset='0' stop-color='black'/>"
                    + "<stop offset='1' stop-color='white'/></linearGradient></svg>");
            Bounds bbox = new Bounds(10, 0, 30, 10);
            assertColorEq("identity ctm",
                    SvgPaint.paintServer(root, "url(#u)", bbox, Matrix.identity()).paintAt(50, 5),
                    c(0.5, 0.5, 0.5));
            assertColorEq("scaled ctm",
                    SvgPaint.paintServer(root, "url(#u)", bbox, Transforms.scaling(2, 2)).paintAt(100, 0),
                    c(0.5, 0.5, 0.5));
        });

        scenario("Paint: gradientTransform applies inside the bounding box's square", () -> {
            SvgElement root = Xml.parseXml("<svg><linearGradient id='t' gradientTransform='rotate(90)'>"
                    + "<stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/>"
                    + "</linearGradient></svg>");
            Paint p = SvgPaint.paintServer(root, "url(#t)", new Bounds(10, 0, 30, 10), Matrix.identity());
            assertColorEq("paint_at(p, 20, 2.5)", p.paintAt(20, 2.5), c(0.25, 0.25, 0.25));
            assertColorEq("paint_at(p, 11, 5)", p.paintAt(11, 5), c(0.5, 0.5, 0.5));
        });

        scenario("Paint: spreadMethod is the extend mode", () -> {
            SvgElement root = Xml.parseXml("<svg><linearGradient id='r' x2='0.25' spreadMethod='reflect'>"
                    + "<stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/>"
                    + "</linearGradient><linearGradient id='p' x2='25%' spreadMethod='repeat'>"
                    + "<stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/>"
                    + "</linearGradient></svg>");
            Bounds bbox = new Bounds(10, 0, 30, 10);
            Paint r = SvgPaint.paintServer(root, "url(#r)", bbox, Matrix.identity());
            Paint p = SvgPaint.paintServer(root, "url(#p)", bbox, Matrix.identity());
            assertColorEq("r@17.5", r.paintAt(17.5, 5), c(0.5, 0.5, 0.5));
            assertColorEq("r@20", r.paintAt(20, 5), c(0, 0, 0));
            assertColorEq("r@22.5", r.paintAt(22.5, 5), c(0.5, 0.5, 0.5));
            assertColorEq("p@19.9", p.paintAt(19.9, 5), c(0.98, 0.98, 0.98));
            assertColorEq("p@20.1", p.paintAt(20.1, 5), c(0.02, 0.02, 0.02));
        });

        scenario("Paint: a radial gradient, centred and focal", () -> {
            SvgElement root = Xml.parseXml("<svg><radialGradient id='c'><stop offset='0' stop-color='white'/>"
                    + "<stop offset='1' stop-color='black'/></radialGradient>"
                    + "<radialGradient id='f' fx='0.25'><stop offset='0' stop-color='white'/>"
                    + "<stop offset='1' stop-color='black'/></radialGradient></svg>");
            Bounds bbox = new Bounds(10, 0, 30, 10);
            Paint centred = SvgPaint.paintServer(root, "url(#c)", bbox, Matrix.identity());
            Paint focal = SvgPaint.paintServer(root, "url(#f)", bbox, Matrix.identity());
            assertColorEq("centred@20,5", centred.paintAt(20, 5), c(1, 1, 1));
            assertColorEq("centred@25,5", centred.paintAt(25, 5), c(0.5, 0.5, 0.5));
            assertColorEq("centred@20,0", centred.paintAt(20, 0), c(0, 0, 0));
            assertColorEq("focal@15,5", focal.paintAt(15, 5), c(1, 1, 1));
            assertColorEq("focal@17.5,5", focal.paintAt(17.5, 5), c(0.8333, 0.8333, 0.8333));
        });

        scenario("Paint: when there's nothing to paint with, and when there's one colour", () -> {
            SvgElement root = Xml.parseXml("<svg><linearGradient id='one'>"
                    + "<stop offset='0.3' stop-color='red'/></linearGradient>"
                    + "<linearGradient id='empty'/>"
                    + "<linearGradient id='same' x2='0'><stop offset='0' stop-color='red'/>"
                    + "<stop offset='1' stop-color='blue'/></linearGradient>"
                    + "<clipPath id='k'/>"
                    + "<linearGradient id='a'><stop offset='0'/><stop offset='1' stop-color='white'/>"
                    + "</linearGradient></svg>");
            Bounds bbox = new Bounds(10, 0, 30, 10);
            assertColorEq("one stop",
                    SvgPaint.paintServer(root, "url(#one)", bbox, Matrix.identity()).paintAt(0, 0), c(1, 0, 0));
            assertColorEq("coincident points",
                    SvgPaint.paintServer(root, "url(#same)", bbox, Matrix.identity()).paintAt(15, 5), c(0, 0, 1));
            assertEquals("empty", SvgPaint.paintServer(root, "url(#empty)", bbox, Matrix.identity()), null);
            assertEquals("not a gradient", SvgPaint.paintServer(root, "url(#k)", bbox, Matrix.identity()), null);
            assertEquals("missing", SvgPaint.paintServer(root, "url(#missing)", bbox, Matrix.identity()), null);
            assertEquals("zero-width bbox",
                    SvgPaint.paintServer(root, "url(#a)", new Bounds(0, 0, 10, 0), Matrix.identity()), null);
        });
    }

    // ---- §20.10: clips and group opacity ----------------------------------------

    private static void registerGroups() {
        scenario("Groups: painting into a layer at a coverage and an alpha", () -> {
            CoverageBuffer cov = new CoverageBuffer(2, 1);
            cov.setCoverage(0, 0, 0.5);
            cov.setCoverage(1, 0, 1);
            Layer l = new Layer(2, 1);
            Groups.drawCoverage(l, cov, Paint.solid(c(1, 0, 0)), 0.5);
            assertPixelEq("layer_pixel(l, 0, 0)", l.pixelAt(0, 0), new Pixel(0.25, 0, 0, 0.25));
            assertPixelEq("layer_pixel(l, 1, 0)", l.pixelAt(1, 0), new Pixel(0.5, 0, 0, 0.5));
            assertDoubleEq("coverage_at(union_coverage(cov, cov), 0, 0)",
                    Clipping.unionCoverage(cov, cov).coverageAt(0, 0), 0.75);
            assertDoubleEq("coverage_at(union_coverage(cov, cov), 1, 0)",
                    Clipping.unionCoverage(cov, cov).coverageAt(1, 0), 1);
        });

        scenario("Groups: an element's opacity fades its fill and stroke together", () -> {
            Canvas c = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' stroke='blue' "
                            + "stroke-width='2' opacity='0.5'/></svg>",
                    4, 4);
            assertColorEq("pixel_at(c, 1, 1)", c.pixelAt(1, 1), c(1, 0.5, 0.5));
            assertColorEq("pixel_at(c, 0, 0)", c.pixelAt(0, 0), c(0.5, 0.5, 1));
        });

        scenario("Groups: a group's opacity applies after its children are flattened", () -> {
            Canvas g = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 4 4'><g opacity='0.5'><rect width='4' height='4' fill='red'/>"
                            + "<rect width='4' height='4' fill='blue'/></g></svg>",
                    4, 4);
            Canvas e = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' opacity='0.5'/>"
                            + "<rect width='4' height='4' fill='blue' opacity='0.5'/></svg>",
                    4, 4);
            assertColorEq("pixel_at(g, 0, 0)", g.pixelAt(0, 0), c(0.5, 0.5, 1));
            assertColorEq("pixel_at(e, 0, 0)", e.pixelAt(0, 0), c(0.5, 0.25, 0.75));
        });

        scenario("Groups: a clip on a shape, and on a group", () -> {
            Canvas s = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='2' height='4'/></clipPath>"
                            + "<rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>",
                    4, 4);
            Canvas g = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='2' height='4'/></clipPath>"
                            + "<g clip-path='url(#c)' opacity='0.5'><rect width='4' height='4' fill='red'/>"
                            + "</g></svg>",
                    4, 4);
            assertColorEq("pixel_at(s, 0, 0)", s.pixelAt(0, 0), c(1, 0, 0));
            assertColorEq("pixel_at(s, 3, 0)", s.pixelAt(3, 0), c(1, 1, 1));
            assertColorEq("pixel_at(g, 0, 0)", g.pixelAt(0, 0), c(1, 0.5, 0.5));
            assertColorEq("pixel_at(g, 3, 0)", g.pixelAt(3, 0), c(1, 1, 1));
        });

        scenario("Groups: a clip is the union of its shapes", () -> {
            Canvas c1 = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='1' height='4'/>"
                            + "<rect x='3' width='1' height='4'/></clipPath>"
                            + "<rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>",
                    4, 4);
            Canvas h = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='0.5' height='4'/>"
                            + "<rect width='0.5' height='4'/></clipPath>"
                            + "<rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>",
                    4, 4);
            assertColorEq("pixel_at(c, 0, 0)", c1.pixelAt(0, 0), c(1, 0, 0));
            assertColorEq("pixel_at(c, 1, 0)", c1.pixelAt(1, 0), c(1, 1, 1));
            assertColorEq("pixel_at(c, 3, 0)", c1.pixelAt(3, 0), c(1, 0, 0));
            assertColorEq("pixel_at(h, 0, 0)", h.pixelAt(0, 0), c(1, 0.25, 0.25));
        });

        scenario("Groups: each clip shape has its own clip-rule", () -> {
            Canvas e = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 10 10'><clipPath id='c'><path clip-rule='evenodd' "
                            + "d='M0 0H10V10H0Z M2 2H8V8H2Z'/></clipPath>"
                            + "<rect width='10' height='10' fill='red' clip-path='url(#c)'/></svg>",
                    10, 10);
            Canvas n = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 10 10'><clipPath id='c'><path d='M0 0H10V10H0Z M2 2H8V8H2Z'/>"
                            + "</clipPath><rect width='10' height='10' fill='red' clip-path='url(#c)'/></svg>",
                    10, 10);
            assertColorEq("pixel_at(e, 0, 0)", e.pixelAt(0, 0), c(1, 0, 0));
            assertColorEq("pixel_at(e, 5, 5)", e.pixelAt(5, 5), c(1, 1, 1));
            assertColorEq("pixel_at(n, 5, 5)", n.pixelAt(5, 5), c(1, 0, 0));
        });

        scenario("Groups: a clip lives in the user space of the element that uses it", () -> {
            Canvas u = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 8 4'><clipPath id='c'><rect width='2' height='4'/></clipPath>"
                            + "<rect width='4' height='4' fill='red' clip-path='url(#c)' "
                            + "transform='translate(4 0)'/></svg>",
                    8, 4);
            Canvas t = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 4 4'><clipPath id='c' transform='translate(2 0)'>"
                            + "<rect width='2' height='4'/></clipPath>"
                            + "<rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>",
                    4, 4);
            Canvas k = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='2' height='4' "
                            + "transform='translate(2 0)'/></clipPath>"
                            + "<rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>",
                    4, 4);
            assertColorEq("pixel_at(u, 4, 0)", u.pixelAt(4, 0), c(1, 0, 0));
            assertColorEq("pixel_at(u, 6, 0)", u.pixelAt(6, 0), c(1, 1, 1));
            assertColorEq("pixel_at(t, 0, 0)", t.pixelAt(0, 0), c(1, 1, 1));
            assertColorEq("pixel_at(t, 3, 0)", t.pixelAt(3, 0), c(1, 0, 0));
            assertColorEq("pixel_at(k, 0, 0)", k.pixelAt(0, 0), c(1, 1, 1));
            assertColorEq("pixel_at(k, 3, 0)", k.pixelAt(3, 0), c(1, 0, 0));
        });

        scenario("Groups: an empty clip hides everything, and a missing one hides nothing", () -> {
            assertColorEq("empty clip",
                    SvgWalker.renderSvg(
                            "<svg viewBox='0 0 4 4'><clipPath id='c'/>"
                                    + "<rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>",
                            4, 4)
                            .pixelAt(0, 0),
                    c(1, 1, 1));
            assertColorEq("missing clip",
                    SvgWalker.renderSvg(
                            "<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' "
                                    + "clip-path='url(#nope)'/></svg>",
                            4, 4)
                            .pixelAt(0, 0),
                    c(1, 0, 0));
        });
    }

    // ---- §20.10: the walker -----------------------------------------------------

    private static void registerWalker() {
        scenario("Walker: later elements paint over earlier ones, and paper shows through", () -> {
            Canvas c = SvgWalker.renderSvg(
                    "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 4 4'>"
                            + "<rect width='4' height='4' fill='red'/>"
                            + "<rect x='2' width='2' height='4' fill='blue'/></svg>",
                    4, 4);
            assertColorEq("pixel_at(c, 0, 0)", c.pixelAt(0, 0), c(1, 0, 0));
            assertColorEq("pixel_at(c, 3, 0)", c.pixelAt(3, 0), c(0, 0, 1));
            assertColorEq("black default fill",
                    SvgWalker.renderSvg("<svg><rect width='2' height='2'/></svg>", 4, 4).pixelAt(0, 0), c(0, 0, 0));
            assertColorEq("outside the shape is paper",
                    SvgWalker.renderSvg("<svg><rect width='2' height='2'/></svg>", 4, 4).pixelAt(3, 3), c(1, 1, 1));
        });

        scenario("Walker: the stroke is drawn over the fill, centred on the outline", () -> {
            Canvas c = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 10 10'><rect x='2' y='2' width='6' height='6' fill='red' "
                            + "stroke='blue' stroke-width='2'/></svg>",
                    10, 10);
            assertColorEq("pixel_at(c, 1, 1)", c.pixelAt(1, 1), c(0, 0, 1));
            assertColorEq("pixel_at(c, 2, 5)", c.pixelAt(2, 5), c(0, 0, 1));
            assertColorEq("pixel_at(c, 5, 5)", c.pixelAt(5, 5), c(1, 0, 0));
            assertColorEq("pixel_at(c, 0, 0)", c.pixelAt(0, 0), c(1, 1, 1));
        });

        scenario("Walker: a squashed transform squashes the pen", () -> {
            Canvas c = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 20 10'><rect x='2' y='2' width='6' height='6' fill='none' "
                            + "stroke='black' stroke-width='2' transform='scale(2 1)'/></svg>",
                    20, 10);
            assertColorEq("pixel_at(c, 2, 5)", c.pixelAt(2, 5), c(0, 0, 0));
            assertColorEq("pixel_at(c, 5, 5)", c.pixelAt(5, 5), c(0, 0, 0));
            assertColorEq("pixel_at(c, 10, 1)", c.pixelAt(10, 1), c(0, 0, 0));
            assertColorEq("pixel_at(c, 10, 3)", c.pixelAt(10, 3), c(1, 1, 1));
        });

        scenario("Walker: dashes are measured in user space too", () -> {
            Canvas c = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 20 2'><line x1='0' y1='1' x2='10' y2='1' stroke='black' "
                            + "stroke-width='2' stroke-dasharray='2 3' transform='scale(2 1)'/></svg>",
                    20, 2);
            assertColorEq("pixel_at(c, 0, 1)", c.pixelAt(0, 1), c(0, 0, 0));
            assertColorEq("pixel_at(c, 3, 1)", c.pixelAt(3, 1), c(0, 0, 0));
            assertColorEq("pixel_at(c, 4, 1)", c.pixelAt(4, 1), c(1, 1, 1));
            assertColorEq("pixel_at(c, 9, 1)", c.pixelAt(9, 1), c(1, 1, 1));
            assertColorEq("pixel_at(c, 10, 1)", c.pixelAt(10, 1), c(0, 0, 0));
        });

        scenario("Walker: caps and fill rules reach the fill and the stroker", () -> {
            Canvas c = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 10 4'><line x1='2' y1='2' x2='8' y2='2' stroke='black' "
                            + "stroke-width='2' stroke-linecap='square'/></svg>",
                    10, 4);
            Canvas e = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 10 10'><path fill-rule='evenodd' "
                            + "d='M0 0H10V10H0Z M2 2H8V8H2Z'/></svg>",
                    10, 10);
            assertColorEq("pixel_at(c, 1, 2)", c.pixelAt(1, 2), c(0, 0, 0));
            assertColorEq("pixel_at(c, 8, 2)", c.pixelAt(8, 2), c(0, 0, 0));
            assertColorEq("pixel_at(c, 0, 2)", c.pixelAt(0, 2), c(1, 1, 1));
            assertColorEq("pixel_at(e, 0, 0)", e.pixelAt(0, 0), c(0, 0, 0));
            assertColorEq("pixel_at(e, 5, 5)", e.pixelAt(5, 5), c(1, 1, 1));
        });

        scenario("Walker: fill-opacity and stroke-opacity fade one paint each", () -> {
            Canvas c = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' fill-opacity='0.5' "
                            + "stroke='blue' stroke-width='2' stroke-opacity='0.25'/></svg>",
                    4, 4);
            assertColorEq("pixel_at(c, 1, 1)", c.pixelAt(1, 1), c(1, 0.5, 0.5));
            assertColorEq("pixel_at(c, 0, 0)", c.pixelAt(0, 0), c(0.75, 0.375, 0.625));
        });

        scenario("Walker: a gradient fill spans the shape's own bounds", () -> {
            Canvas c = SvgWalker.renderSvg(
                    "<svg viewBox='0 0 8 4'><linearGradient id='g'><stop offset='0' stop-color='black'/>"
                            + "<stop offset='1' stop-color='white'/></linearGradient>"
                            + "<rect x='4' width='4' height='4' fill='url(#g)'/></svg>",
                    8, 4);
            assertColorEq("pixel_at(c, 4, 0)", c.pixelAt(4, 0), c(0.125, 0.125, 0.125));
            assertColorEq("pixel_at(c, 5, 0)", c.pixelAt(5, 0), c(0.375, 0.375, 0.375));
            assertColorEq("pixel_at(c, 7, 0)", c.pixelAt(7, 0), c(0.875, 0.875, 0.875));
        });

        scenario("Walker: what isn't drawn", () -> {
            assertColorEq("defs/clipPath/text/title/unknown are skipped",
                    SvgWalker.renderSvg(
                                    "<svg viewBox='0 0 4 4'><defs><rect width='4' height='4' fill='red'/></defs>"
                                            + "<clipPath id='c'><rect width='4' height='4'/></clipPath>"
                                            + "<text>hi</text><title>t</title>"
                                            + "<foo><rect width='4' height='4'/></foo></svg>",
                                    4, 4)
                            .pixelAt(0, 0),
                    c(1, 1, 1));
            assertColorEq("a singular matrix draws nothing",
                    SvgWalker.renderSvg(
                                    "<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' "
                                            + "stroke='blue' transform='scale(0)'/></svg>",
                                    4, 4)
                            .pixelAt(0, 0),
                    c(1, 1, 1));
            assertColorEq("a missing paint server paints nothing",
                    SvgWalker.renderSvg(
                                    "<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='url(#nope)' "
                                            + "stroke='blue' stroke-width='2'/></svg>",
                                    4, 4)
                            .pixelAt(1, 1),
                    c(1, 1, 1));
            assertColorEq("...but the stroke still draws",
                    SvgWalker.renderSvg(
                                    "<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='url(#nope)' "
                                            + "stroke='blue' stroke-width='2'/></svg>",
                                    4, 4)
                            .pixelAt(0, 0),
                    c(0, 0, 1));
        });
    }

    // ---- Plate 20 ---------------------------------------------------------------

    private static void registerPlate() {
        scenario("Plate: a harbor at dusk", () -> {
            Canvas c = Figures.harbor();
            byte[] ref = readBytes("reference/chapter-20/harbor.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 480);
            assertEquals("c.height", c.height, 320);
            assertTriple("ppm_pixel(p6, 240, 20)", Ppm.ppmPixel(p6, 240, 20), new int[] {24, 18, 51}, 1);
            assertTriple("ppm_pixel(p6, 20, 280)", Ppm.ppmPixel(p6, 20, 280), new int[] {67, 32, 68}, 1);
            assertTriple("ppm_pixel(p6, 418, 156)", Ppm.ppmPixel(p6, 418, 156), new int[] {200, 50, 60}, 1);
            assertTriple("ppm_pixel(p6, 418, 161)", Ppm.ppmPixel(p6, 418, 161), new int[] {244, 239, 230}, 1);
            assertTriple("ppm_pixel(p6, 200, 262)", Ppm.ppmPixel(p6, 200, 262), new int[] {200, 50, 60}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate: a rose window", () -> {
            Canvas c = Figures.rose();
            byte[] ref = readBytes("reference/chapter-20/rose.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 400);
            assertEquals("c.height", c.height, 400);
            assertTriple("ppm_pixel(p6, 200, 200)", Ppm.ppmPixel(p6, 200, 200), new int[] {255, 248, 216}, 1);
            assertTriple("ppm_pixel(p6, 385, 385)", Ppm.ppmPixel(p6, 385, 385), new int[] {240, 168, 24}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate: the tiger", () -> {
            Canvas c = Figures.plate20();
            byte[] ref = readBytes("reference/chapter-20/tiger.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 450);
            assertEquals("c.height", c.height, 450);
            assertTriple("ppm_pixel(p6, 5, 5)", Ppm.ppmPixel(p6, 5, 5), new int[] {255, 255, 255}, 1);
            assertTriple("ppm_pixel(p6, 250, 200)", Ppm.ppmPixel(p6, 250, 200), new int[] {0, 0, 0}, 1);
            assertTriple("ppm_pixel(p6, 170, 330)", Ppm.ppmPixel(p6, 170, 330), new int[] {255, 114, 127}, 1);
            assertTriple("ppm_pixel(p6, 350, 100)", Ppm.ppmPixel(p6, 350, 100), new int[] {204, 114, 38}, 1);
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
        writeOne("aspect_demo.ppm", Figures.aspectDemo());
        writeOne("harbor.ppm", Figures.harbor());
        writeOne("rose.ppm", Figures.rose());
        writeOne("tiger.ppm", Figures.tiger());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
