import java.io.IOException;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter23-*.feature into a Java test. No JUnit, no network: run
 * from the project root so reference/chapter-16, reference/chapter-23
 * resolve.
 */
public final class Chapter23Tests {

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

    private static void assertTupleEq(String what, Tuple actual, Tuple expected) {
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertDoubleListEq(String what, List<Double> actual, List<Double> expected) {
        if (actual.size() != expected.size()) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
        for (int i = 0; i < actual.size(); i++) {
            if (!Numbers.approxEqual(actual.get(i), expected.get(i))) {
                throw new AssertionError(what + ": expected " + expected + " but got " + actual);
            }
        }
    }

    private static byte[] readBytes(String path) throws IOException {
        return java.nio.file.Files.readAllBytes(java.nio.file.Path.of(path));
    }

    private static Tuple pt(double x, double y) {
        return Tuple.point(x, y);
    }

    private static Tuple vec(double x, double y) {
        return Tuple.vector(x, y);
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerPrimitives();
        registerCurves();
        registerRender();
        registerFree();
        registerSmooth();
        registerTransform();
        registerAtlas();
        registerCompose();
        registerPlate();
    }

    // ---- §23.1: exact fields for primitives -----------------------------------

    private static void registerPrimitives() {
        scenario("Primitives: a circle", () -> {
            assertDoubleEq("sd_circle(3,4)", Sdf.sdCircle(pt(3, 4), pt(0, 0), 2), 3);
            assertDoubleEq("sd_circle(1,0)", Sdf.sdCircle(pt(1, 0), pt(0, 0), 2), -1);
            assertDoubleEq("sd_circle(2,0)", Sdf.sdCircle(pt(2, 0), pt(0, 0), 2), 0);
        });

        scenario("Primitives: a segment, beside it and beyond its ends", () -> {
            assertDoubleEq("beside", Sdf.distanceToSegment(pt(5, 3), pt(0, 0), pt(10, 0)), 3);
            assertDoubleEq("beyond start", Sdf.distanceToSegment(pt(-3, 4), pt(0, 0), pt(10, 0)), 5);
            assertDoubleEq("beyond end", Sdf.distanceToSegment(pt(13, -4), pt(0, 0), pt(10, 0)), 5);
            assertDoubleEq("degenerate", Sdf.distanceToSegment(pt(3, 4), pt(0, 0), pt(0, 0)), 5);
        });

        scenario("Primitives: a box, beside a side, off a corner, and inside", () -> {
            assertDoubleEq("beside a side", Sdf.sdBox(pt(13, 0), pt(0, 0), 10, 5), 3);
            assertDoubleEq("off a corner", Sdf.sdBox(pt(13, 9), pt(0, 0), 10, 5), 5);
            assertDoubleEq("inside 1", Sdf.sdBox(pt(2, 1), pt(0, 0), 10, 5), -4);
            assertDoubleEq("inside 2", Sdf.sdBox(pt(-2, -4), pt(0, 0), 10, 5), -1);
        });

        scenario("Primitives: rounding a box rounds its corners and nothing else", () -> {
            assertDoubleEq("off a corner", Sdf.sdRoundedBox(pt(13, 9), pt(0, 0), 10, 5, 2), 5.810250, 0.000001);
            assertDoubleEq("beside a side", Sdf.sdRoundedBox(pt(13, 0), pt(0, 0), 10, 5, 2), 3);
            assertDoubleEq("inside", Sdf.sdRoundedBox(pt(0, 0), pt(0, 0), 10, 5, 2), -5);
        });

        scenario("Primitives: a polygon's sign comes from chapter 5's winding number", () -> {
            Path sq = Paths.polygon(pt(0, 0), pt(10, 0), pt(10, 10), pt(0, 10));
            assertDoubleEq("inside", Sdf.sdPolygon(pt(5, 3), sq, "nonzero"), -3);
            assertDoubleEq("outside", Sdf.sdPolygon(pt(13, 14), sq, "nonzero"), 5);
            assertDoubleEq("star nonzero", Sdf.sdPolygon(pt(80.5, 80.5), Figures.star(), "nonzero"), -21.631190,
                    0.000001);
            assertDoubleEq("star evenodd", Sdf.sdPolygon(pt(80.5, 80.5), Figures.star(), "evenodd"), 21.631190,
                    0.000001);
        });
    }

    // ---- §23.2: fields for curves -----------------------------------------------

    private static void registerCurves() {
        scenario("Curves: cubic roots, and the cases that aren't cubic", () -> {
            assertDoubleListEq("t^3-6t^2+11t-6", CurveDistance.solveCubic(1, -6, 11, -6), List.of(1.0, 2.0, 3.0));
            assertDoubleListEq("t^3-8", CurveDistance.solveCubic(1, 0, 0, -8), List.of(2.0));
            assertDoubleListEq("2t^3-2t", CurveDistance.solveCubic(2, 0, -2, 0), List.of(-1.0, 0.0, 1.0));
            assertDoubleListEq("t^2-3t+2", CurveDistance.solveCubic(0, 1, -3, 2), List.of(1.0, 2.0));
            assertDoubleListEq("2t-1", CurveDistance.solveCubic(0, 0, 2, -1), List.of(0.5));
            assertDoubleListEq("1=0", CurveDistance.solveCubic(0, 0, 0, 1), List.of());
        });

        scenario("Curves: the nearest point of a quadratic", () -> {
            Curve flat = Curve.quadratic(pt(0, 0), pt(5, 0), pt(10, 0));
            Curve arch = Curve.quadratic(pt(10, 80), pt(50, -20), pt(90, 80));
            assertDoubleEq("flat, beside", CurveDistance.distanceToQuadratic(pt(5, 3), flat), 3);
            assertDoubleEq("flat, beyond", CurveDistance.distanceToQuadratic(pt(13, 4), flat), 5);
            assertDoubleEq("arch, below the peak", CurveDistance.distanceToQuadratic(pt(50, 20), arch), 10);
            assertDoubleEq("arch, above", CurveDistance.distanceToQuadratic(pt(50, 60), arch), 26.532998, 0.000001);
        });

        scenario("Curves: the nearest point of a cubic can be an end that Newton walks away from", () -> {
            Curve c = Curve.cubic(pt(30, 50), pt(10, 40), pt(10, 70), pt(10, 100));
            assertDoubleEq("distance", CurveDistance.distanceToCubic(pt(70, 80), c), 50);
            assertDoubleEq("nearest t", CurveDistance.nearestTCubic(pt(70, 80), c), 0);
        });

        scenario("Curves: the points are the same everywhere", () -> {
            List<Tuple> pts = CurveDistance.weylPoints(2, 0, 0, 100, 100);
            assertTupleEq("pts[0]", pts.get(0), pt(75.48776662466927, 56.98402909980532));
            assertTupleEq("pts[1]", pts.get(1), pt(50.97553324933854, 13.968058199610638));
        });

        scenario("Curves: both fields match a brute-force search over 10,000 points", () -> {
            List<Tuple> pts = CurveDistance.weylPoints(10000, 0, 0, 100, 100);
            Curve q = Curve.quadratic(pt(10, 80), pt(50, -20), pt(90, 80));
            Curve cu = Curve.cubic(pt(10, 80), pt(30, -10), pt(70, 120), pt(90, 20));
            assertTrue("quadratic error <= 1e-6", CurveDistance.maxCurveError(q, pts) <= 0.000001);
            assertTrue("cubic error <= 1e-6", CurveDistance.maxCurveError(cu, pts) <= 0.000001);
        });

        scenario("Curves: a cubic that loops back past the point", () -> {
            Curve c = Curve.cubic(pt(83.1679, 49.0113), pt(3.7744, 16.9556), pt(9.872, 71.7692), pt(90.0182, 19.9317));
            Tuple p = pt(52.2111, 45.0896);
            assertDoubleEq("distance_to_cubic", CurveDistance.distanceToCubic(p, c), 5.379229, 0.00001);
            assertDoubleEq("brute_distance", CurveDistance.bruteDistance(c, p), 5.379229, 0.00001);
            assertTrue("chapter 14's distance_to_curve is off by at least 0.02",
                    Offset.distanceToCurve(c, p) >= 5.4);
        });
    }

    // ---- §23.3: rendering a field -------------------------------------------------

    private static void registerRender() {
        scenario("Render: a field is sampled at pixel centers", () -> {
            Field f = Field.field(16, 16, (x, y) -> Sdf.sdCircle(pt(x, y), pt(8, 8), 3));
            assertDoubleEq("field_at(8,8)", Field.fieldAt(f, 8, 8), -2.292893, 0.000001);
            assertDoubleEq("field_at(11,8)", Field.fieldAt(f, 11, 8), 0.535534, 0.000001);
            assertDoubleEq("coverage_at(8,8)", Fields.fieldCoverage(f).coverageAt(8, 8), 1);
            assertDoubleEq("coverage_at(11,8)", Fields.fieldCoverage(f).coverageAt(11, 8), 0);
        });

        scenario("Render: along an edge that runs with the pixels, the field is exact", () -> {
            Path box = Paths.polygon(pt(10.3, 12.7), pt(50.6, 12.7), pt(50.6, 40.2), pt(10.3, 40.2));
            CoverageBuffer cov = Fields.fieldCoverage(Fields.polygonField(box, "nonzero", 64, 64));
            CoverageBuffer exact = Fill.fillPath(box, "nonzero", 64, 64);
            assertDoubleEq("cov(10,25)", cov.coverageAt(10, 25), 0.7);
            assertDoubleEq("exact(10,25)", exact.coverageAt(10, 25), 0.7);
            assertDoubleEq("cov(10,12)", cov.coverageAt(10, 12), 0.3);
            assertDoubleEq("exact(10,12)", exact.coverageAt(10, 12), 0.21);
            assertDoubleEq("max diff", CoverageBuffer.maxCoverageDifference(cov, exact), 0.12);
        });

        scenario("Render: along a slanted edge it's a little off", () -> {
            Path d = Paths.polygon(pt(74.37, 40.21), pt(40.37, 74.21), pt(6.37, 40.21), pt(40.37, 6.21));
            CoverageBuffer cov = Fields.fieldCoverage(Fields.polygonField(d, "nonzero", 80, 80));
            CoverageBuffer exact = Fill.fillPath(d, "nonzero", 80, 80);
            assertDoubleEq("cov(71,43)", cov.coverageAt(71, 43), 0.203015, 0.000001);
            assertDoubleEq("exact(71,43)", exact.coverageAt(71, 43), 0.1682);
        });

        scenario("Render: at the star's points it's a long way off, and inside it's wrong until simplified", () -> {
            Path star = Figures.star();
            CoverageBuffer exact = Fill.fillPath(star, "nonzero", 160, 160);
            CoverageBuffer rawCov = Fields.fieldCoverage(Fields.polygonField(star, "nonzero", 160, 160));
            CoverageBuffer raw = Fields.coverageError(rawCov, exact);
            CoverageBuffer clean = Fields.coverageError(
                    Fields.fieldCoverage(Fields.polygonField(BoolCombine.simplify(star, "nonzero"), "nonzero", 160, 160)),
                    exact);
            assertDoubleEq("max diff", CoverageBuffer.maxCoverageDifference(rawCov, exact), 0.491037, 0.000001);
            assertDoubleEq("ink(raw)", raw.ink(), 44.800368, 0.000001);
            assertDoubleEq("ink(clean)", clean.ink(), 9.808571, 0.000001);
            assertDoubleEq("raw(80,80)", raw.coverageAt(80, 80), 0);
            assertDoubleEq("raw(80,58)", raw.coverageAt(80, 58), 0.131190, 0.000001);
            assertDoubleEq("clean(80,58)", clean.coverageAt(80, 58), 0);
        });
    }

    // ---- §23.4: chapters 13, 14 and 22 for free ----------------------------------

    private static void registerFree() {
        scenario("Free: one line each", () -> {
            Field a = Field.fieldOf(3, 1, new double[] {-2, 1, 3});
            Field b = Field.fieldOf(3, 1, new double[] {1, -4, 2});
            assertArrayEq("union", Fields.fieldUnion(a, b).values, new double[] {-2, -4, 2});
            assertArrayEq("intersection", Fields.fieldIntersection(a, b).values, new double[] {1, 1, 3});
            assertArrayEq("difference", Fields.fieldDifference(a, b).values, new double[] {-1, 4, 3});
            assertArrayEq("xor", Fields.fieldXor(a, b).values, new double[] {-1, -1, 2});
            assertArrayEq("offset", Fields.fieldOffset(a, 2).values, new double[] {-4, -1, 1});
            assertArrayEq("stroke", Fields.fieldStroke(a, 2).values, new double[] {1, 0, 2});
        });

        scenario("Free: a stroke by field and chapter 13's round stroke", () -> {
            Path sp = Paths.transformPath(Figures.star(), Transforms.translation(19.5, 19.5));
            CoverageBuffer byPath = Fill.fillPath(Stroke.strokeToPath(sp, 10, "round", "round", 4), "nonzero", 200, 200);
            CoverageBuffer byField = Fields.fieldCoverage(Fields.fieldStroke(Fields.polygonField(sp, "nonzero", 200, 200), 10));
            assertTrue("max diff <= 0.42", CoverageBuffer.maxCoverageDifference(byPath, byField) <= 0.42);
            assertDoubleEq("ink(by_path)", byPath.ink(), 5906.224083, 0.000001);
            assertDoubleEq("ink(by_field)", byField.ink(), 5901.860165, 0.000001);
        });

        scenario("Free: a curve's stroke by field and chapter 14's", () -> {
            CoverageBuffer byPath = Fill.fillPath(Offset.strokeCurveToPath(Fields.sCurve(), 20, "round", 0.05), "nonzero", 200, 200);
            CoverageBuffer byField = Fields.fieldCoverage(Fields.fieldStroke(Fields.cubicField(Fields.sCurve(), 200, 200), 20));
            assertTrue("max diff <= 0.08", CoverageBuffer.maxCoverageDifference(byPath, byField) <= 0.08);
            assertDoubleEq("ink diff", byField.ink() - byPath.ink(), 4.120488, 0.001);
        });

        scenario("Free: chapter 22's plate by field", () -> {
            CoverageBuffer byPath = Fill.fillPath(
                    BoolCombine.combine(Figures.plateGlyph(), "nonzero", Figures.plateStar(), "evenodd", "xor"),
                    "nonzero", 200, 200);
            CoverageBuffer byField = Fields.fieldCoverage(
                    Fields.fieldXor(Fields.plateGlyphField(), Fields.polygonField(Figures.plateStar(), "evenodd", 200, 200)));
            assertTrue("max diff <= 0.42", CoverageBuffer.maxCoverageDifference(byPath, byField) <= 0.42);
            assertDoubleEq("ink diff", byField.ink() - byPath.ink(), 2.279815, 0.001);
        });
    }

    private static void assertArrayEq(String what, double[] actual, double[] expected) {
        if (actual.length != expected.length) {
            throw new AssertionError(what + ": length mismatch");
        }
        for (int i = 0; i < actual.length; i++) {
            if (!Numbers.approxEqual(actual[i], expected[i])) {
                throw new AssertionError(what + ": expected " + java.util.Arrays.toString(expected)
                        + " but got " + java.util.Arrays.toString(actual));
            }
        }
    }

    // ---- §23.5: something paths can't do -------------------------------------------

    private static void registerSmooth() {
        scenario("Smooth: far apart it's min; close together it's less", () -> {
            assertDoubleEq("far apart", Fields.smoothMin(1, 5, 2), 1);
            assertDoubleEq("equal, k=4", Fields.smoothMin(3, 3, 4), 2);
            assertDoubleEq("close, k=4", Fields.smoothMin(2, 3, 4), 1.4375);
            assertDoubleEq("k=0 is min", Fields.smoothMin(2, 3, 0), 2);
        });

        scenario("Smooth: the fillet fills the crease", () -> {
            Field sharp = Fields.filletField(0);
            Field filleted = Fields.filletField(32);
            assertDoubleEq("sharp(98,63)", Field.fieldAt(sharp, 98, 63), 3.044846, 0.000001);
            assertDoubleEq("filleted(98,63)", Field.fieldAt(filleted, 98, 63), -3.320843, 0.000001);
            assertDoubleEq("agree far from the crease", Field.fieldAt(sharp, 60, 70), Field.fieldAt(filleted, 60, 70));
            assertArrayEq("field_smooth_union(f,f,0) = f",
                    Fields.fieldSmoothUnion(Fields.filletField(0), Fields.filletField(0), 0).values,
                    Fields.filletField(0).values);
        });
    }

    // ---- §23.6: the distance transform ------------------------------------------

    private static void registerTransform() {
        scenario("Transform: one row", () -> {
            long big = DistanceTransform.farValue(5, 1);
            assertEquals("big", big, 26L);
            assertArrayEqLong("row1", DistanceTransform.edt1d(new long[] {0, big, big, 0, big}),
                    new long[] {0, 1, 1, 0, 1});
            assertArrayEqLong("row2", DistanceTransform.edt1d(new long[] {big, big, big, big, 0}),
                    new long[] {16, 9, 4, 1, 0});
            assertArrayEqLong("row3", DistanceTransform.edt1d(new long[] {4, big, 0, big, big}),
                    new long[] {4, 1, 0, 1, 4});
        });

        scenario("Transform: columns, then rows", () -> {
            boolean[] bits = new boolean[25];
            bits[12] = true;
            assertArrayEqLong("5x5", DistanceTransform.distanceTransform(bits, 5, 5),
                    new long[] {8, 5, 4, 5, 8, 5, 2, 1, 2, 5, 4, 1, 0, 1, 4, 5, 2, 1, 2, 5, 8, 5, 4, 5, 8});
            assertArrayEqLong("all off", DistanceTransform.distanceTransform(new boolean[6], 3, 2),
                    new long[] {13, 13, 13, 13, 13, 13});
        });

        scenario("Transform: the transform matches trying every pixel, exactly", () -> {
            boolean[] bits = DistanceTransform.bitsOf(Figures.transformBitmap());
            assertArrayEqLong("64x64", DistanceTransform.distanceTransform(bits, 64, 64),
                    DistanceTransform.bruteDistanceTransform(bits, 64, 64));
        });

        scenario("Transform: any coverage becomes a field", () -> {
            CoverageBuffer cov = Figures.transformBitmap();
            Field f = DistanceTransform.fieldFromCoverage(cov);
            assertArrayEq("small",
                    DistanceTransform.fieldFromCoverage(DistanceTransform.coverageOf(4, 1, new double[] {0, 0.4, 0.6, 1})).values,
                    new double[] {1.5, 0.5, -0.5, -1.5});
            assertDoubleEq("field_at(f,0,0)", Field.fieldAt(f, 0, 0), 27.784271, 0.000001);
            double[] range = Field.fieldRange(f);
            assertDoubleEq("range low", range[0], -2.5);
            assertDoubleEq("range high", range[1], 31.702484, 0.000001);
        });
    }

    private static void assertArrayEqLong(String what, long[] actual, long[] expected) {
        if (!java.util.Arrays.equals(actual, expected)) {
            throw new AssertionError(what + ": expected " + java.util.Arrays.toString(expected)
                    + " but got " + java.util.Arrays.toString(actual));
        }
    }

    // ---- §23.7: glyph atlases -----------------------------------------------------

    private static void registerAtlas() {
        scenario("Atlas: the box a glyph is baked into", () -> {
            Font f = Figures.robotoFont();
            Baked b = Msdf.bakeSdf(f, Fonts.glyphName(f, 69), 16, 3);
            assertEquals("left", b.left, -2);
            assertEquals("top", b.top, -15);
            assertEquals("width", b.width, 14);
            assertEquals("height", b.height, 18);
            assertDoubleEq("field_at(0,0)", Field.fieldAt(b.channels[0], 0, 0), 3);
            assertDoubleEq("field_at(4,9)", Field.fieldAt(b.channels[0], 4, 9), -0.401566, 0.000001);
        });

        scenario("Atlas: what a corner is", () -> {
            assertEquals("perpendicular", Msdf.isCorner(vec(1, 0), vec(0, 1)), true);
            assertEquals("reversed", Msdf.isCorner(vec(1, 0), vec(-1, 0)), true);
            assertEquals("5.73 degrees", Msdf.isCorner(vec(1, 0), vec(0.995004165, 0.099833417)), false);
            assertEquals("11.46 degrees", Msdf.isCorner(vec(1, 0), vec(0.980066578, 0.198669331)), true);
        });

        scenario("Atlas: colouring edges", () -> {
            List<Curve> sq = List.of(
                    Msdf.lineCurve(pt(0, 0), pt(10, 0)), Msdf.lineCurve(pt(10, 0), pt(10, 10)),
                    Msdf.lineCurve(pt(10, 10), pt(0, 10)), Msdf.lineCurve(pt(0, 10), pt(0, 0)));
            List<Curve> tri = List.of(
                    Msdf.lineCurve(pt(0, 0), pt(10, 0)), Msdf.lineCurve(pt(10, 0), pt(5, 8)),
                    Msdf.lineCurve(pt(5, 8), pt(0, 0)));
            List<Curve> house = List.of(
                    Msdf.lineCurve(pt(0, 0), pt(10, 0)), Msdf.lineCurve(pt(10, 0), pt(10, 10)),
                    Msdf.lineCurve(pt(10, 10), pt(5, 15)), Msdf.lineCurve(pt(5, 15), pt(0, 10)),
                    Msdf.lineCurve(pt(0, 10), pt(0, 0)));
            List<Curve> drop = List.of(
                    Curve.quadratic(pt(0, 0), pt(20, -20), pt(30, 0)),
                    Curve.quadratic(pt(30, 0), pt(40, 20), pt(20, 20)),
                    Curve.quadratic(pt(20, 20), pt(0, 20), pt(0, 0)));
            assertEquals("sq", Msdf.colorEdges(sq).masks(), List.of(6, 5, 6, 5));
            assertEquals("tri", Msdf.colorEdges(tri).masks(), List.of(6, 5, 3));
            assertEquals("house", Msdf.colorEdges(house).masks(), List.of(6, 5, 6, 5, 3));
            assertEquals("drop", Msdf.colorEdges(drop).masks(), List.of(6, 7, 5));
            assertEquals("circle", Msdf.colorEdges(Msdf.circleCurves(50, 50, 40)).masks(),
                    List.of(7, 7, 7, 7, 7, 7, 7, 7));
        });

        scenario("Atlas: pseudo-distance runs straight on past an end", () -> {
            Curve e = Msdf.lineCurve(pt(0, 0), pt(10, 0));
            assertDoubleEq("interior, above", Msdf.pseudoDistance(pt(5, 3), e, 0.5, 3), -3);
            assertDoubleEq("interior, below", Msdf.pseudoDistance(pt(5, -3), e, 0.5, 3), 3);
            assertDoubleEq("past the end", Msdf.pseudoDistance(pt(14, 3), e, 1, 5), -3);
            assertDoubleEq("past the start", Msdf.pseudoDistance(pt(-4, -3), e, 0, 5), 3);
        });

        scenario("Atlas: a texel's own value is at its center", () -> {
            Field f = Field.fieldOf(3, 2, new double[] {0, 4, 8, 2, 6, 10});
            assertDoubleEq("center", Msdf.sampleField(f, 1.5, 0.5), 4);
            assertDoubleEq("halfway", Msdf.sampleField(f, 1, 0.5), 2);
            assertDoubleEq("between rows", Msdf.sampleField(f, 1.5, 1), 5);
            assertDoubleEq("off the corner", Msdf.sampleField(f, 0, 0), 0);
            assertDoubleEq("off the far corner", Msdf.sampleField(f, 9, 9), 10);
        });

        scenario("Atlas: the median", () -> {
            assertDoubleEq("1,5,3", Msdf.median3(1, 5, 3), 3);
            assertDoubleEq("-2,4,-1", Msdf.median3(-2, 4, -1), -1);
            assertDoubleEq("7,7,2", Msdf.median3(7, 7, 2), 7);
        });

        scenario("Atlas: three channels at one texel", () -> {
            Font f = Figures.robotoFont();
            Baked m = Msdf.bakeMsdf(f, Fonts.glyphName(f, 69), 16, 3);
            assertDoubleEq("channel 0", Field.fieldAt(m.channels[0], 4, 9), -0.320313, 0.000001);
            assertDoubleEq("channel 1", Field.fieldAt(m.channels[1], 4, 9), -0.242188, 0.000001);
            assertDoubleEq("channel 2", Field.fieldAt(m.channels[2], 4, 9), -0.320313, 0.000001);
        });
    }

    // ---- §23.8: fields compose approximately -------------------------------------

    private static void registerCompose() {
        scenario("Compose: min is right outside and wrong inside", () -> {
            Path a = Figures.peanut()[0];
            Path b = Figures.peanut()[1];
            Path u = BoolCombine.combine(a, "nonzero", b, "nonzero", "union");
            assertDoubleEq("min outside",
                    Figures.minOf(Sdf.sdPolygon(pt(85, 20), a, "nonzero"), Sdf.sdPolygon(pt(85, 20), b, "nonzero")),
                    25.000200, 0.001);
            assertDoubleEq("true union outside", Sdf.sdPolygon(pt(85, 20), u, "nonzero"), 24.998, 0.001);
            assertDoubleEq("min in the waist",
                    Figures.minOf(Sdf.sdPolygon(pt(85, 80), a, "nonzero"), Sdf.sdPolygon(pt(85, 80), b, "nonzero")),
                    -14.992, 0.001);
            assertDoubleEq("true union in the waist", Sdf.sdPolygon(pt(85, 80), u, "nonzero"), -31.203, 0.001);
            assertDoubleEq("min deep inside",
                    Figures.minOf(Sdf.sdPolygon(pt(60, 80), a, "nonzero"), Sdf.sdPolygon(pt(60, 80), b, "nonzero")),
                    -39.979, 0.001);
            assertDoubleEq("true union deep inside", Sdf.sdPolygon(pt(60, 80), u, "nonzero"), -39.978, 0.001);
        });
    }

    // ---- §23.9: Plate 23, and the chapter's renders ------------------------------

    private static void registerPlate() {
        scenario("Plate: primitive_fields", () -> {
            checkRender(Chapter23Figures.primitiveFields(), "reference/chapter-23/primitive-fields.ppm", 640, 160);
        });
        scenario("Plate: error_map", () -> {
            checkRender(Chapter23Figures.errorMap(), "reference/chapter-23/error-map.ppm", 480, 160);
        });
        scenario("Plate: fields_vs_paths", () -> {
            checkRender(Chapter23Figures.fieldsVsPaths(), "reference/chapter-23/fields-vs-paths.ppm", 600, 400);
        });
        scenario("Plate: fillets", () -> {
            checkRender(Chapter23Figures.fillets(), "reference/chapter-23/fillets.ppm", 640, 160);
        });
        scenario("Plate: transform_demo", () -> {
            checkRender(Chapter23Figures.transformDemo(), "reference/chapter-23/transform-demo.ppm", 576, 192);
        });
        scenario("Plate: atlas_corners", () -> {
            checkRender(Chapter23Figures.atlasCorners(), "reference/chapter-23/atlas-corners.ppm", 1200, 400);
        });
        scenario("Plate: trap_shrink", () -> {
            checkRender(Chapter23Figures.trapShrink(), "reference/chapter-23/trap-shrink.ppm", 340, 160);
        });
        scenario("Plate: title", () -> {
            checkRender(Chapter23Figures.title(), "reference/chapter-23/title.ppm", 900, 220);
        });

        scenario("Plate: what the renders show", () -> {
            byte[] bands = Ppm.canvasToP6(Chapter23Figures.primitiveFields());
            byte[] errors = Ppm.canvasToP6(Chapter23Figures.errorMap());
            byte[] both = Ppm.canvasToP6(Chapter23Figures.fieldsVsPaths());
            byte[] fil = Ppm.canvasToP6(Chapter23Figures.fillets());
            byte[] atlas = Ppm.canvasToP6(Chapter23Figures.atlasCorners());
            byte[] shrunk = Ppm.canvasToP6(Chapter23Figures.trapShrink());
            assertTriple("bands(80,80)", Ppm.ppmPixel(bands, 80, 80), new int[] {57, 92, 101});
            assertTriple("bands(80,30)", Ppm.ppmPixel(bands, 80, 30), new int[] {185, 188, 184});
            assertTriple("bands(560,80)", Ppm.ppmPixel(bands, 560, 80), new int[] {145, 117, 62});
            assertTriple("errors(80,80)", Ppm.ppmPixel(errors, 80, 80), new int[] {243, 196, 89});
            assertTriple("errors(240,58)", Ppm.ppmPixel(errors, 240, 58), new int[] {180, 95, 149});
            assertTriple("errors(400,58)", Ppm.ppmPixel(errors, 400, 58), new int[] {39, 39, 44});
            assertTriple("both(529,114)", Ppm.ppmPixel(both, 529, 114), new int[] {243, 196, 89});
            assertTriple("both(529,314)", Ppm.ppmPixel(both, 529, 314), new int[] {243, 196, 89});
            assertTriple("both(529,75)", Ppm.ppmPixel(both, 529, 75), new int[] {39, 39, 44});
            assertTriple("fil(98,63)", Ppm.ppmPixel(fil, 98, 63), new int[] {39, 39, 44});
            assertTriple("fil(578,63)", Ppm.ppmPixel(fil, 578, 63), new int[] {243, 196, 89});
            assertTriple("atlas(78,83)", Ppm.ppmPixel(atlas, 78, 83), new int[] {39, 39, 44});
            assertTriple("atlas(378,83)", Ppm.ppmPixel(atlas, 378, 83), new int[] {243, 196, 89});
            assertTriple("shrunk(85,80)", Ppm.ppmPixel(shrunk, 85, 80), new int[] {39, 39, 44});
            assertTriple("shrunk(255,80)", Ppm.ppmPixel(shrunk, 255, 80), new int[] {243, 196, 89});
        });

        scenario("Plate 23", () -> {
            Canvas c = Chapter23Figures.plate23();
            byte[] ref = readBytes("reference/chapter-23/plate-23.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 800);
            assertEquals("c.height", c.height, 200);
            assertTriple("(3,3)", Ppm.ppmPixel(p6, 3, 3), new int[] {99, 82, 52});
            assertTriple("(206,3)", Ppm.ppmPixel(p6, 206, 3), new int[] {39, 39, 44});
            assertTriple("(283,45)", Ppm.ppmPixel(p6, 283, 45), new int[] {243, 196, 89});
            assertTriple("(606,100)", Ppm.ppmPixel(p6, 606, 100), new int[] {45, 40, 48});
            assertTrue("max_channel_difference <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static void checkRender(Canvas c, String refPath, int w, int h) throws IOException {
        byte[] ref = readBytes(refPath);
        byte[] p6 = Ppm.canvasToP6(c);
        assertEquals("width", c.width, w);
        assertEquals("height", c.height, h);
        assertTrue("max_channel_difference <= 1 (" + refPath + ")", Ppm.maxChannelDifference(p6, ref) <= 1);
    }

    private static void assertTriple(String what, int[] actual, int[] expected) {
        for (int i = 0; i < 3; i++) {
            if (Math.abs(actual[i] - expected[i]) > 1) {
                throw new AssertionError(what + ": expected " + java.util.Arrays.toString(expected)
                        + " but got " + java.util.Arrays.toString(actual));
            }
        }
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
        java.nio.file.Files.write(java.nio.file.Path.of("out", "primitive-fields.ppm"),
                Ppm.canvasToP6(Chapter23Figures.primitiveFields()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "error-map.ppm"),
                Ppm.canvasToP6(Chapter23Figures.errorMap()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "fields-vs-paths.ppm"),
                Ppm.canvasToP6(Chapter23Figures.fieldsVsPaths()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "fillets.ppm"),
                Ppm.canvasToP6(Chapter23Figures.fillets()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "transform-demo.ppm"),
                Ppm.canvasToP6(Chapter23Figures.transformDemo()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "atlas-corners.ppm"),
                Ppm.canvasToP6(Chapter23Figures.atlasCorners()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "trap-shrink.ppm"),
                Ppm.canvasToP6(Chapter23Figures.trapShrink()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "plate-23.ppm"),
                Ppm.canvasToP6(Chapter23Figures.plate23()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "title.ppm"),
                Ppm.canvasToP6(Chapter23Figures.title()));
    }
}
