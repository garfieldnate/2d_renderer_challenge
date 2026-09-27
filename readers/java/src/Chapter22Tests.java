import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter22-*.feature into a Java test. No JUnit, no network: run
 * from the project root so reference/chapter-22/*.ppm resolve.
 */
public final class Chapter22Tests {

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

    private static void assertSegEq(String what, Seg actual, Seg expected) {
        if (!actual.equals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertTupleListEq(String what, List<Tuple> actual, List<Tuple> expected) {
        if (actual.size() != expected.size()) {
            throw new AssertionError(what + ": expected " + expected.size() + " points but got "
                    + actual.size() + " (" + actual + " vs " + expected + ")");
        }
        for (int i = 0; i < actual.size(); i++) {
            if (!actual.get(i).approxEquals(expected.get(i))) {
                throw new AssertionError(what + ": point " + i + " expected " + expected.get(i)
                        + " but got " + actual.get(i));
            }
        }
    }

    private static void assertPointListsEq(String what, List<List<Tuple>> actual, List<List<Tuple>> expected) {
        if (actual.size() != expected.size()) {
            throw new AssertionError(what + ": expected " + expected.size() + " contours but got "
                    + actual.size() + " (" + actual + " vs " + expected + ")");
        }
        for (int i = 0; i < actual.size(); i++) {
            assertTupleListEq(what + " contour " + i, actual.get(i), expected.get(i));
        }
    }

    private static void assertWindingEq(String what, int[][] actual, int[][] expected) {
        if (actual[0][0] != expected[0][0] || actual[0][1] != expected[0][1]
                || actual[1][0] != expected[1][0] || actual[1][1] != expected[1][1]) {
            throw new AssertionError(what + ": expected " + java.util.Arrays.deepToString(expected)
                    + " but got " + java.util.Arrays.deepToString(actual));
        }
    }

    private static void assertKeptEq(String what, List<KeptEdge> actual, List<Tuple[]> expected) {
        if (actual.size() != expected.size()) {
            throw new AssertionError(what + ": expected " + expected.size() + " edges but got " + actual.size());
        }
        for (int i = 0; i < actual.size(); i++) {
            if (!actual.get(i).from().approxEquals(expected.get(i)[0])
                    || !actual.get(i).to().approxEquals(expected.get(i)[1])) {
                throw new AssertionError(what + ": edge " + i + " expected (" + expected.get(i)[0] + " -> "
                        + expected.get(i)[1] + ") but got (" + actual.get(i).from() + " -> " + actual.get(i).to() + ")");
            }
        }
    }

    private static byte[] readBytes(String path) throws IOException {
        return java.nio.file.Files.readAllBytes(java.nio.file.Path.of(path));
    }

    private static Tuple pt(double x, double y) {
        return Tuple.point(x, y);
    }

    private static Seg seg(Tuple a, Tuple b, int wa, int wb) {
        return Seg.seg(a, b, wa, wb);
    }

    private static Tuple[] pair(Tuple a, Tuple b) {
        return new Tuple[] {a, b};
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerGrid();
        registerMeet();
        registerSplit();
        registerSweep();
        registerBentley();
        registerInside();
        registerCombine();
        registerRobust();
        registerPlate();
    }

    // ---- §22.1: a grid ------------------------------------------------------

    private static void registerGrid() {
        scenario("Grid: a coordinate becomes a whole number of grid units, halves up", () -> {
            assertEquals("grid(1)", Grid.grid(1), 256L);
            assertEquals("grid(0.5)", Grid.grid(0.5), 128L);
            assertEquals("grid(3.14159)", Grid.grid(3.14159), 804L);
            assertEquals("grid(0.001953125)", Grid.grid(0.001953125), 1L);
            assertEquals("grid(-0.001953125)", Grid.grid(-0.001953125), 0L);
            assertEquals("grid(0.0019)", Grid.grid(0.0019), 0L);
            assertEquals("grid(-0.003)", Grid.grid(-0.003), -1L);
            assertTupleEq("snap_point(point(2.5,-0.25))", Grid.snapPoint(pt(2.5, -0.25)), pt(640, -64));
        });

        scenario("Grid: a square moved a millionth of a pixel snaps back onto itself", () -> {
            Path a = Paths.polygon(pt(10, 10), pt(30, 10), pt(30, 30), pt(10, 30));
            Path b = Paths.polygon(pt(10.000001, 10), pt(30, 10.000001), pt(30.000001, 30), pt(10, 30.000001));
            assertEquals("xor is empty",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", b, "nonzero", "xor")).size(), 0);
            assertPointListsEq("union is the square",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", b, "nonzero", "union")),
                    List.of(List.of(pt(10, 10), pt(30, 10), pt(30, 30), pt(10, 30))));
        });

        scenario("Grid: orient says which way three points turn", () -> {
            assertDoubleEq("orient ccw", Grid.orient(pt(0, 0), pt(256, 0), pt(0, 256)), 65536);
            assertDoubleEq("orient cw", Grid.orient(pt(0, 0), pt(256, 0), pt(0, -256)), -65536);
            assertDoubleEq("orient collinear", Grid.orient(pt(0, 0), pt(256, 0), pt(512, 0)), 0);
        });

        scenario("Grid: orient is exact at the far corners of the grid", () -> {
            Tuple a = pt(-262144, -262144);
            Tuple b = pt(262144, 262143);
            Tuple c = pt(262143, 262142);
            assertDoubleEq("orient(a,b,c)", Grid.orient(a, b, c), -1);
            assertDoubleEq("orient(a,b,origin)", Grid.orient(a, b, pt(0, 0)), 262144);
            assertDoubleEq("orient(a, corner, origin)", Grid.orient(a, pt(262144, 262144), pt(0, 0)), 0);
        });

        scenario("Grid: the sweep's order is top to bottom, then left to right", () -> {
            assertTrue("(5,1) before (0,2)", Grid.lexLess(pt(5, 1), pt(0, 2)));
            assertTrue("not (0,2) before (5,1)", !Grid.lexLess(pt(0, 2), pt(5, 1)));
            assertTrue("(1,3) before (2,3)", Grid.lexLess(pt(1, 3), pt(2, 3)));
            assertTrue("not a point before itself", !Grid.lexLess(pt(2, 3), pt(2, 3)));
        });
    }

    // ---- §22.2: segments, and where two of them meet ------------------------

    private static void registerMeet() {
        scenario("Meet: a segment keeps its ends in the sweep's order", () -> {
            Seg s = seg(pt(10, 0), pt(0, 0), 1, 0);
            assertTupleEq("s.lo", s.lo, pt(0, 0));
            assertTupleEq("s.hi", s.hi, pt(10, 0));
            assertEquals("s.wa", s.wa, -1);
            assertEquals("s.wb", s.wb, 0);
            assertSegEq("s equals reversed", s, seg(pt(0, 0), pt(10, 0), -1, 0));
            assertTrue("direction matters", !seg(pt(0, 5), pt(10, 5), 0, 1).equals(seg(pt(10, 5), pt(0, 5), 0, 1)));
            assertTupleEq("lo picks the lex-least end", seg(pt(4, 9), pt(6, 2), 0, 1).lo, pt(6, 2));
        });

        scenario("Meet: a path's segments are its edges on the grid", () -> {
            List<Seg> segs = Splitting.pathSegments(
                    Paths.polygon(pt(1, 1), pt(2, 1), pt(2, 2), pt(1, 2)), "a");
            assertEquals("length", segs.size(), 4);
            assertSegEq("segs[0]", segs.get(0), seg(pt(256, 256), pt(512, 256), 1, 0));
            assertSegEq("segs[1]", segs.get(1), seg(pt(512, 256), pt(512, 512), 1, 0));
            assertSegEq("segs[2]", segs.get(2), seg(pt(256, 512), pt(512, 512), -1, 0));
            assertSegEq("segs[3]", segs.get(3), seg(pt(256, 256), pt(256, 512), -1, 0));

            List<Seg> dropped = Splitting.pathSegments(
                    Paths.polygon(pt(1, 1), pt(2, 1), pt(2.001, 1), pt(2, 2)), "b");
            assertEquals("a zero-length edge is dropped", dropped.size(), 3);
            assertSegEq("dropped[0]", dropped.get(0), seg(pt(256, 256), pt(512, 256), 0, 1));
            assertSegEq("dropped[1]", dropped.get(1), seg(pt(512, 256), pt(512, 512), 0, 1));
            assertSegEq("dropped[2]", dropped.get(2), seg(pt(256, 256), pt(512, 512), 0, -1));
        });

        scenario("Meet: two segments crossing are both split where they cross", () -> {
            MeetResult m = BoolMeet.meet(seg(pt(0, 0), pt(10, 10), 1, 0), seg(pt(0, 10), pt(10, 0), 1, 0));
            assertEquals("kind", m.kind(), "cross");
            assertTupleListEq("on_s", m.onS(), List.of(pt(5, 5)));
            assertTupleListEq("on_t", m.onT(), List.of(pt(5, 5)));
        });

        scenario("Meet: a crossing between grid points rounds to one, halves up", () -> {
            Seg s = seg(pt(0, 0), pt(3, 1), 1, 0);
            Seg t = seg(pt(0, 1), pt(3, 0), 0, 1);
            assertTupleEq("crossing_point(s,t)", BoolMeet.crossingPoint(s, t), pt(2, 1));
            assertTupleEq("second",
                    BoolMeet.crossingPoint(seg(pt(-3, 0), pt(0, 1), 1, 0), seg(pt(-3, 1), pt(0, 0), 0, 1)),
                    pt(-1, 1));
            assertTupleEq("third",
                    BoolMeet.crossingPoint(seg(pt(2, 0), pt(10, 12), 1, 0), seg(pt(9, 0), pt(6, 7), 1, 0)),
                    pt(6, 6));
            assertTupleEq("fourth",
                    BoolMeet.crossingPoint(seg(pt(2, 0), pt(10, 12), 1, 0), seg(pt(7, 4), pt(3, 7), 1, 0)),
                    pt(5, 5));
        });

        scenario("Meet: a crossing that rounds onto an end splits only the other segment", () -> {
            MeetResult m = BoolMeet.meet(seg(pt(0, 0), pt(100, 1), 1, 0), seg(pt(0, 1), pt(1, -1), 1, 0));
            assertEquals("kind", m.kind(), "cross");
            assertEquals("on_s empty", m.onS().size(), 0);
            assertTupleListEq("on_t", m.onT(), List.of(pt(0, 0)));
        });

        scenario("Meet: an end touching the middle of another segment splits it", () -> {
            MeetResult m = BoolMeet.meet(seg(pt(0, 0), pt(10, 0), 1, 0), seg(pt(5, 0), pt(5, 10), 1, 0));
            assertEquals("kind", m.kind(), "touch");
            assertTupleListEq("on_s", m.onS(), List.of(pt(5, 0)));
            assertEquals("on_t empty", m.onT().size(), 0);
        });

        scenario("Meet: collinear segments that overlap split each other at their ends", () -> {
            MeetResult m = BoolMeet.meet(seg(pt(0, 0), pt(10, 0), 1, 0), seg(pt(4, 0), pt(14, 0), 1, 0));
            MeetResult n = BoolMeet.meet(seg(pt(0, 0), pt(10, 0), 1, 0), seg(pt(2, 0), pt(6, 0), 1, 0));
            MeetResult same = BoolMeet.meet(seg(pt(0, 0), pt(10, 0), 1, 0), seg(pt(10, 0), pt(0, 0), 1, 0));
            assertEquals("m.kind", m.kind(), "overlap");
            assertTupleListEq("m.on_s", m.onS(), List.of(pt(4, 0)));
            assertTupleListEq("m.on_t", m.onT(), List.of(pt(10, 0)));
            assertEquals("n.kind", n.kind(), "overlap");
            assertTupleListEq("n.on_s", n.onS(), List.of(pt(2, 0), pt(6, 0)));
            assertEquals("n.on_t empty", n.onT().size(), 0);
            assertEquals("same.kind", same.kind(), "overlap");
            assertEquals("same.on_s empty", same.onS().size(), 0);
            assertEquals("same.on_t empty", same.onT().size(), 0);
        });

        scenario("Meet: segments that share only an end, or nothing, aren't split", () -> {
            assertEquals("share an end",
                    BoolMeet.meet(seg(pt(0, 0), pt(10, 0), 1, 0), seg(pt(10, 0), pt(10, 10), 1, 0)).kind(), "end");
            assertEquals("collinear, share an end",
                    BoolMeet.meet(seg(pt(0, 0), pt(10, 0), 1, 0), seg(pt(10, 0), pt(20, 0), 1, 0)).kind(), "end");
            assertEquals("parallel, no touch",
                    BoolMeet.meet(seg(pt(0, 0), pt(10, 0), 1, 0), seg(pt(0, 1), pt(10, 1), 1, 0)).kind(), "none");
            assertEquals("collinear, disjoint",
                    BoolMeet.meet(seg(pt(0, 0), pt(10, 0), 1, 0), seg(pt(11, 0), pt(20, 0), 1, 0)).kind(), "none");
            assertEquals("far apart",
                    BoolMeet.meet(seg(pt(0, 0), pt(10, 0), 1, 0), seg(pt(12, -5), pt(12, 5), 1, 0)).kind(), "none");
            assertEquals("crossing lines, disjoint segments",
                    BoolMeet.meet(seg(pt(0, 0), pt(4, 4), 1, 0), seg(pt(3, 0), pt(9, 2), 1, 0)).kind(), "none");
        });
    }

    // ---- §22.3: splitting until nothing crosses ------------------------------

    private static void registerSplit() {
        scenario("Split: split points come in order along the segment", () -> {
            SweepStats st = new SweepStats();
            List<List<Tuple>> splits = Splitting.findSplits(List.of(
                    seg(pt(10, 0), pt(0, 5), 1, 0),
                    seg(pt(2, -1), pt(3, 9), 1, 0),
                    seg(pt(7, -1), pt(8, 9), 1, 0)), "brute", st);
            assertTupleListEq("splits[0]", splits.get(0), List.of(pt(7, 1), pt(2, 4)));
            assertTupleListEq("splits[1]", splits.get(1), List.of(pt(2, 4)));
            assertTupleListEq("splits[2]", splits.get(2), List.of(pt(7, 1)));
            assertEquals("st.tests", st.tests, 3);
        });

        scenario("Split: rounded points go in order along the segment, not in the sweep's order", () -> {
            List<Seg> segs = List.of(
                    seg(pt(6, 0), pt(5, 100), 1, 0),
                    seg(pt(15, 42), pt(-5, 59), 0, 1),
                    seg(pt(12, 43), pt(-3, 59), 0, 1));
            List<List<Tuple>> splits = Splitting.findSplits(segs, "brute", new SweepStats());
            assertTupleListEq("splits[0]", splits.get(0), List.of(pt(6, 50), pt(5, 50)));
            assertTrue("lex_less(5,50 ; 6,50)", Grid.lexLess(pt(5, 50), pt(6, 50)));
        });

        scenario("Split: merging adds windings, and a segment that adds nothing goes", () -> {
            List<Seg> m = Splitting.mergeSegments(List.of(
                    seg(pt(0, 0), pt(4, 0), 1, 0),
                    seg(pt(4, 0), pt(0, 0), 1, 0),
                    seg(pt(1, 1), pt(2, 2), 1, 0),
                    seg(pt(0, 0), pt(0, 4), 0, 1),
                    seg(pt(0, 4), pt(0, 0), 0, -1)));
            assertEquals("length", m.size(), 2);
            assertSegEq("m[0]", m.get(0), seg(pt(0, 0), pt(0, 4), 0, 2));
            assertSegEq("m[1]", m.get(1), seg(pt(1, 1), pt(2, 2), 1, 0));
        });

        scenario("Split: two overlapping squares split into twelve segments in two passes", () -> {
            Path a = Paths.polygon(pt(0, 0), pt(10, 0), pt(10, 10), pt(0, 10));
            Path b = Paths.polygon(pt(5, 5), pt(15, 5), pt(15, 15), pt(5, 15));
            SweepStats st = new SweepStats();
            List<Seg> segs = new ArrayList<>(Splitting.pathSegments(a, "a"));
            segs.addAll(Splitting.pathSegments(b, "b"));
            List<Seg> out = Splitting.splitSegments(segs, "brute", st);
            assertEquals("length", out.size(), 12);
            assertSegEq("segs[2]", out.get(2), seg(pt(2560, 0), pt(2560, 1280), 1, 0));
            assertSegEq("segs[3]", out.get(3), seg(pt(1280, 1280), pt(2560, 1280), 0, 1));
            assertSegEq("segs[4]", out.get(4), seg(pt(1280, 1280), pt(1280, 2560), 0, -1));
            assertEquals("st.passes", st.passes, 2);
            assertEquals("st.tests", st.tests, 94);
        });

        scenario("Split: rounding a crossing can make a new meeting, so the loop goes round again", () -> {
            List<Seg> segs = List.of(
                    seg(pt(2, 0), pt(10, 12), 1, 0),
                    seg(pt(9, 0), pt(6, 7), 1, 0),
                    seg(pt(7, 4), pt(3, 7), 1, 0));
            SweepStats st = new SweepStats();
            List<List<Tuple>> first = Splitting.findSplits(
                    Splitting.mergeSegments(segs), "brute", new SweepStats());
            List<Seg> out = Splitting.splitSegments(segs, "brute", st);
            assertTupleListEq("first[0]", first.get(0), List.of(pt(5, 5), pt(6, 6)));
            assertTupleListEq("first[1]", first.get(1), List.of(pt(6, 6)));
            assertTupleListEq("first[2]", first.get(2), List.of(pt(5, 5)));
            assertEquals("st.passes", st.passes, 3);
            List<Seg> expected = List.of(
                    seg(pt(2, 0), pt(5, 5), 1, 0),
                    seg(pt(9, 0), pt(7, 4), 1, 0),
                    seg(pt(7, 4), pt(5, 5), 1, 0),
                    seg(pt(7, 4), pt(6, 6), 1, 0),
                    seg(pt(5, 5), pt(6, 6), 1, 0),
                    seg(pt(5, 5), pt(3, 7), 1, 0),
                    seg(pt(6, 6), pt(6, 7), 1, 0),
                    seg(pt(6, 6), pt(10, 12), 1, 0));
            assertEquals("out length", out.size(), expected.size());
            for (int i = 0; i < expected.size(); i++) {
                assertSegEq("out[" + i + "]", out.get(i), expected.get(i));
            }
        });
    }

    // ---- §22.6: a faster way to find crossings -------------------------------

    private static void registerSweep() {
        scenario("Sweep: the sweep finds what every pair finds", () -> {
            List<Seg> segs = Figures.struckSegments(1);
            SweepStats brute = new SweepStats();
            SweepStats sweep = new SweepStats();
            List<List<Tuple>> a = Splitting.findSplits(segs, "brute", brute);
            List<List<Tuple>> b = Splitting.findSplits(segs, "sweep", sweep);
            assertEquals("length(segs)", segs.size(), 787);
            assertPointsMatch("a = b", a, b);
            assertEquals("brute.tests", brute.tests, 309291);
            assertEquals("sweep.tests", sweep.tests, 34326);
        });

        scenario("Sweep: only pairs whose rows overlap are tested", () -> {
            List<Seg> segs = List.of(
                    seg(pt(0, 0), pt(10, 10), 1, 0),
                    seg(pt(0, 20), pt(10, 30), 1, 0),
                    seg(pt(10, 0), pt(0, 10), 0, 1),
                    seg(pt(5, 10), pt(5, 20), 0, 1));
            SweepStats st = new SweepStats();
            SweepStats brute = new SweepStats();
            List<List<Tuple>> splits = Splitting.findSplits(segs, "sweep", st);
            List<List<Tuple>> bruteSplits = Splitting.findSplits(segs, "brute", brute);
            assertPointsMatch("splits = brute", splits, bruteSplits);
            assertEquals("st.tests", st.tests, 3);
            assertEquals("brute.tests", brute.tests, 6);
            assertTupleListEq("splits[0]", splits.get(0), List.of(pt(5, 5)));
            assertTupleListEq("splits[2]", splits.get(2), List.of(pt(5, 5)));
            assertEquals("splits[3] empty", splits.get(3).size(), 0);
        });

        scenario("Sweep: a segment that ends where another starts is out of the list", () -> {
            SweepStats st = new SweepStats();
            Splitting.findSplits(List.of(
                    seg(pt(0, 0), pt(0, 10), 1, 0),
                    seg(pt(0, 10), pt(0, 20), 1, 0)), "sweep", st);
            assertEquals("st.tests", st.tests, 0);
        });
    }

    private static void assertPointsMatch(String what, List<List<Tuple>> a, List<List<Tuple>> b) {
        assertEquals(what + ": length", a.size(), b.size());
        for (int i = 0; i < a.size(); i++) {
            assertTupleListEq(what + "[" + i + "]", a.get(i), b.get(i));
        }
    }

    // ---- §22.7: Bentley-Ottmann ----------------------------------------------

    private static void registerBentley() {
        scenario("Bentley: three segments through one point are split in one event", () -> {
            SweepStats st = new SweepStats();
            List<List<Tuple>> splits = Splitting.findSplits(List.of(
                    seg(pt(0, 0), pt(12, 12), 1, 0),
                    seg(pt(12, 0), pt(0, 12), 1, 0),
                    seg(pt(6, 0), pt(6, 12), 1, 0)), "bentley-ottmann", st);
            assertTupleListEq("splits[0]", splits.get(0), List.of(pt(6, 6)));
            assertTupleListEq("splits[1]", splits.get(1), List.of(pt(6, 6)));
            assertTupleListEq("splits[2]", splits.get(2), List.of(pt(6, 6)));
            assertEquals("st.events", st.events, 7);
            assertEquals("st.tests", st.tests, 2);
        });

        scenario("Bentley: a crossing between grid points is an exact event, split rounded", () -> {
            SweepStats st = new SweepStats();
            List<List<Tuple>> splits = Splitting.findSplits(List.of(
                    seg(pt(0, 0), pt(3, 1), 1, 0),
                    seg(pt(0, 1), pt(3, 0), 0, 1)), "bentley-ottmann", st);
            assertTupleListEq("splits[0]", splits.get(0), List.of(pt(2, 1)));
            assertTupleListEq("splits[1]", splits.get(1), List.of(pt(2, 1)));
            assertEquals("st.events", st.events, 5);
            assertEquals("st.tests", st.tests, 1);
        });

        scenario("Bentley: a horizontal segment is last among those leaving a point", () -> {
            SweepStats st = new SweepStats();
            List<List<Tuple>> splits = Splitting.findSplits(List.of(
                    seg(pt(0, 5), pt(10, 5), 1, 0),
                    seg(pt(5, 0), pt(5, 10), 1, 0),
                    seg(pt(2, 0), pt(8, 10), 1, 0)), "bentley-ottmann", st);
            assertTupleListEq("splits[0]", splits.get(0), List.of(pt(5, 5)));
            assertTupleListEq("splits[1]", splits.get(1), List.of(pt(5, 5)));
            assertTupleListEq("splits[2]", splits.get(2), List.of(pt(5, 5)));
            assertEquals("st.events", st.events, 7);
            assertEquals("st.tests", st.tests, 2);
        });

        scenario("Bentley: neighbours that part and meet again find their crossing twice, and it's one event", () -> {
            SweepStats st = new SweepStats();
            List<List<Tuple>> splits = Splitting.findSplits(List.of(
                    seg(pt(0, 0), pt(10, 10), 1, 0),
                    seg(pt(10, 0), pt(0, 10), 1, 0),
                    seg(pt(5, 1), pt(5, 3), 1, 0)), "bentley-ottmann", st);
            assertTupleListEq("splits[0]", splits.get(0), List.of(pt(5, 5)));
            assertTupleListEq("splits[1]", splits.get(1), List.of(pt(5, 5)));
            assertEquals("splits[2] empty", splits.get(2).size(), 0);
            assertEquals("st.events", st.events, 7);
            assertEquals("st.tests", st.tests, 4);
        });

        scenario("Bentley: finds what every pair finds, testing neighbours only", () -> {
            List<Seg> segs = Figures.struckSegments(1);
            SweepStats st = new SweepStats();
            List<List<Tuple>> splits = Splitting.findSplits(segs, "bentley-ottmann", st);
            List<List<Tuple>> brute = Splitting.findSplits(segs, "brute", new SweepStats());
            assertPointsMatch("splits = brute", splits, brute);
            assertEquals("st.tests", st.tests, 1659);
            assertEquals("st.events", st.events, 879);
        });

        scenario("Bentley: the whole split, three ways, one answer", () -> {
            List<Seg> segs = Figures.struckSegments(2);
            SweepStats brute = new SweepStats();
            SweepStats sweep = new SweepStats();
            SweepStats bo = new SweepStats();
            List<Seg> a = Splitting.splitSegments(segs, "brute", brute);
            List<Seg> b = Splitting.splitSegments(segs, "sweep", sweep);
            List<Seg> c = Splitting.splitSegments(segs, "bentley-ottmann", bo);
            assertEquals("a = b", a, b);
            assertEquals("a = c", a, c);
            assertEquals("length(c)", c.size(), 1559);
            assertEquals("brute.tests", brute.tests, 2012677);
            assertEquals("sweep.tests", sweep.tests, 278841);
            assertEquals("bo.tests", bo.tests, 5224);
            assertEquals("bo.events", bo.events, 2823);
            assertEquals("bo.passes", bo.passes, 2);
        });
    }

    // ---- §22.4: which side is inside ------------------------------------------

    private static void registerInside() {
        scenario("Inside: the two sides of a square's edges", () -> {
            List<Seg> sq = Splitting.mergeSegments(List.of(
                    seg(pt(0, 0), pt(4, 0), 1, 0),
                    seg(pt(4, 0), pt(4, 4), 1, 0),
                    seg(pt(4, 4), pt(0, 4), 1, 0),
                    seg(pt(0, 4), pt(0, 0), 1, 0)));
            assertSegEq("sq[0]", sq.get(0), seg(pt(0, 0), pt(4, 0), 1, 0));
            assertWindingEq("winding_beside(sq,0)", Inside.windingBeside(sq, 0), new int[][] {{0, 0}, {1, 0}});
            assertSegEq("sq[1]", sq.get(1), seg(pt(0, 0), pt(0, 4), -1, 0));
            assertWindingEq("winding_beside(sq,1)", Inside.windingBeside(sq, 1), new int[][] {{1, 0}, {0, 0}});
            assertWindingEq("winding_beside(sq,2)", Inside.windingBeside(sq, 2), new int[][] {{0, 0}, {1, 0}});
            assertWindingEq("winding_beside(sq,3)", Inside.windingBeside(sq, 3), new int[][] {{1, 0}, {0, 0}});
        });

        scenario("Inside: where two squares overlap, both paths wind around the middle", () -> {
            Path a = Paths.polygon(pt(0, 0), pt(10, 0), pt(10, 10), pt(0, 10));
            Path b = Paths.polygon(pt(5, 5), pt(15, 5), pt(15, 15), pt(5, 15));
            List<Seg> segList = new ArrayList<>(Splitting.pathSegments(a, "a"));
            segList.addAll(Splitting.pathSegments(b, "b"));
            List<Seg> segs = Splitting.splitSegments(segList, "brute", new SweepStats());
            assertSegEq("segs[3]", segs.get(3), seg(pt(1280, 1280), pt(2560, 1280), 0, 1));
            assertWindingEq("winding_beside(segs,3)", Inside.windingBeside(segs, 3), new int[][] {{1, 0}, {1, 1}});
            assertSegEq("segs[6]", segs.get(6), seg(pt(2560, 1280), pt(2560, 2560), 1, 0));
            assertWindingEq("winding_beside(segs,6)", Inside.windingBeside(segs, 6), new int[][] {{0, 1}, {1, 1}});
        });

        scenario("Inside: the ray breaks a tie in y by x, as the sweep does", () -> {
            List<Seg> segs = List.of(
                    seg(pt(0, 0), pt(0, 10), 1, 0),
                    seg(pt(4, 0), pt(4, 5), 0, 1),
                    seg(pt(4, 5), pt(4, 20), 0, -1));
            List<Seg> flat = List.of(
                    seg(pt(0, 0), pt(10, 0), 1, 0),
                    seg(pt(12, -5), pt(12, 0), 0, 1),
                    seg(pt(12, 0), pt(12, 5), 0, -1));
            assertWindingEq("winding_beside(segs,0)", Inside.windingBeside(segs, 0), new int[][] {{0, 1}, {1, 1}});
            assertWindingEq("winding_beside(flat,0)", Inside.windingBeside(flat, 0), new int[][] {{0, 1}, {1, 1}});
        });

        scenario("Inside: what each operation calls inside", () -> {
            String[] ops = {"union", "intersection", "difference", "xor"};
            boolean[] both = {true, true, false, false};
            boolean[] aOnly = {true, false, true, true};
            boolean[] bOnly = {true, false, false, true};
            for (int i = 0; i < ops.length; i++) {
                assertEquals(ops[i] + "(t,t)", Inside.opInside(ops[i], true, true), both[i]);
                assertEquals(ops[i] + "(t,f)", Inside.opInside(ops[i], true, false), aOnly[i]);
                assertEquals(ops[i] + "(f,t)", Inside.opInside(ops[i], false, true), bOnly[i]);
                assertEquals(ops[i] + "(f,f)", Inside.opInside(ops[i], false, false), false);
            }
        });

        scenario("Inside: a winding of 2 is inside under nonzero and outside under even-odd", () -> {
            assertEquals("inside_rule(2,nonzero)", Inside.insideRule(2, "nonzero"), true);
            assertEquals("inside_rule(2,evenodd)", Inside.insideRule(2, "evenodd"), false);
            assertEquals("inside_rule(-1,evenodd)", Inside.insideRule(-1, "evenodd"), true);
            assertEquals("inside_rule(-2,nonzero)", Inside.insideRule(-2, "nonzero"), true);
            assertEquals("inside_rule(0,nonzero)", Inside.insideRule(0, "nonzero"), false);
        });

        scenario("Inside: the kept edges run with the inside on their right", () -> {
            Path a = Paths.polygon(pt(0, 0), pt(10, 0), pt(10, 10), pt(0, 10));
            Path b = Paths.polygon(pt(5, 5), pt(15, 5), pt(15, 15), pt(5, 15));
            List<Seg> segList = new ArrayList<>(Splitting.pathSegments(a, "a"));
            segList.addAll(Splitting.pathSegments(b, "b"));
            List<Seg> segs = Splitting.splitSegments(segList, "brute", new SweepStats());
            assertKeptEq("intersection", Inside.keepEdges(segs, "nonzero", "nonzero", "intersection"), List.of(
                    pair(pt(1280, 1280), pt(2560, 1280)),
                    pair(pt(1280, 2560), pt(1280, 1280)),
                    pair(pt(2560, 1280), pt(2560, 2560)),
                    pair(pt(2560, 2560), pt(1280, 2560))));
            assertKeptEq("difference", Inside.keepEdges(segs, "nonzero", "nonzero", "difference"), List.of(
                    pair(pt(0, 0), pt(2560, 0)),
                    pair(pt(0, 2560), pt(0, 0)),
                    pair(pt(2560, 0), pt(2560, 1280)),
                    pair(pt(2560, 1280), pt(1280, 1280)),
                    pair(pt(1280, 1280), pt(1280, 2560)),
                    pair(pt(1280, 2560), pt(0, 2560))));
            assertEquals("union length", Inside.keepEdges(segs, "nonzero", "nonzero", "union").size(), 8);
            assertEquals("xor length", Inside.keepEdges(segs, "nonzero", "nonzero", "xor").size(), 12);
        });
    }

    // ---- §22.5, §22.9: stitching and the four operations -----------------------

    private static void registerCombine() {
        scenario("Combine: stitching follows the pairs and drops the straight vertex", () -> {
            List<List<Tuple>> c = Stitching.stitch(List.of(
                    new KeptEdge(pt(4, 4), pt(0, 4)),
                    new KeptEdge(pt(0, 0), pt(2, 0)),
                    new KeptEdge(pt(0, 4), pt(0, 0)),
                    new KeptEdge(pt(4, 0), pt(4, 4)),
                    new KeptEdge(pt(2, 0), pt(4, 0))));
            assertPointListsEq("c", c, List.of(List.of(pt(0, 0), pt(4, 0), pt(4, 4), pt(0, 4))));
        });

        scenario("Combine: turning furthest right keeps two squares that touch at a corner apart", () -> {
            List<List<Tuple>> c = Stitching.stitch(List.of(
                    new KeptEdge(pt(0, 0), pt(4, 0)),
                    new KeptEdge(pt(4, 0), pt(4, 4)),
                    new KeptEdge(pt(4, 4), pt(0, 4)),
                    new KeptEdge(pt(0, 4), pt(0, 0)),
                    new KeptEdge(pt(4, 4), pt(8, 4)),
                    new KeptEdge(pt(8, 4), pt(8, 8)),
                    new KeptEdge(pt(8, 8), pt(4, 8)),
                    new KeptEdge(pt(4, 8), pt(4, 4))));
            assertPointListsEq("c", c, List.of(
                    List.of(pt(0, 0), pt(4, 0), pt(4, 4), pt(0, 4)),
                    List.of(pt(4, 4), pt(8, 4), pt(8, 8), pt(4, 8))));
        });

        scenario("Combine: two squares, four ways", () -> {
            Path a = Paths.polygon(pt(0, 0), pt(10, 0), pt(10, 10), pt(0, 10));
            Path b = Paths.polygon(pt(5, 5), pt(15, 5), pt(15, 15), pt(5, 15));
            assertPointListsEq("union",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", b, "nonzero", "union")),
                    List.of(List.of(pt(0, 0), pt(10, 0), pt(10, 5), pt(15, 5), pt(15, 15), pt(5, 15), pt(5, 10),
                            pt(0, 10))));
            assertPointListsEq("intersection",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", b, "nonzero", "intersection")),
                    List.of(List.of(pt(5, 5), pt(10, 5), pt(10, 10), pt(5, 10))));
            assertPointListsEq("difference",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", b, "nonzero", "difference")),
                    List.of(List.of(pt(0, 0), pt(10, 0), pt(10, 5), pt(5, 5), pt(5, 10), pt(0, 10))));
            assertPointListsEq("xor",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", b, "nonzero", "xor")),
                    List.of(
                            List.of(pt(0, 0), pt(10, 0), pt(10, 5), pt(5, 5), pt(5, 10), pt(0, 10)),
                            List.of(pt(10, 5), pt(15, 5), pt(15, 15), pt(5, 15), pt(5, 10), pt(10, 10))));
        });

        scenario("Combine: the result winds clockwise, whichever way the input wound", () -> {
            Path ccw = Paths.polygon(pt(0, 0), pt(0, 10), pt(10, 10), pt(10, 0));
            assertDoubleEq("polygon_area(ccw)", Fill.polygonArea(ccw), -100);
            Path simplified = BoolCombine.simplify(ccw, "nonzero");
            assertPointListsEq("point_lists(simplify(ccw))", BoolCombine.pointLists(simplified),
                    List.of(List.of(pt(0, 0), pt(10, 0), pt(10, 10), pt(0, 10))));
            assertDoubleEq("polygon_area(simplify(ccw))", Fill.polygonArea(simplified), 100);
        });

        scenario("Combine: a hole winds the other way", () -> {
            Path outer = Paths.polygon(pt(0, 0), pt(12, 0), pt(12, 12), pt(0, 12));
            Path inner = Paths.polygon(pt(4, 4), pt(8, 4), pt(8, 8), pt(4, 8));
            Path r = BoolCombine.combine(outer, "nonzero", inner, "nonzero", "difference");
            assertPointListsEq("point_lists(r)", BoolCombine.pointLists(r), List.of(
                    List.of(pt(0, 0), pt(12, 0), pt(12, 12), pt(0, 12)),
                    List.of(pt(4, 4), pt(4, 8), pt(8, 8), pt(8, 4))));
            assertDoubleEq("polygon_area(r)", Fill.polygonArea(r), 128);
        });

        scenario("Combine: one path's own overlaps are resolved by its fill rule", () -> {
            Path p = new Path();
            p.moveTo(pt(0, 0));
            p.lineTo(pt(10, 0));
            p.lineTo(pt(10, 10));
            p.lineTo(pt(0, 10));
            p.close();
            p.moveTo(pt(5, 5));
            p.lineTo(pt(15, 5));
            p.lineTo(pt(15, 15));
            p.lineTo(pt(5, 15));
            p.close();
            assertPointListsEq("simplify nonzero", BoolCombine.pointLists(BoolCombine.simplify(p, "nonzero")),
                    List.of(List.of(pt(0, 0), pt(10, 0), pt(10, 5), pt(15, 5), pt(15, 15), pt(5, 15), pt(5, 10),
                            pt(0, 10))));
            assertEquals("simplify evenodd contour count",
                    BoolCombine.pointLists(BoolCombine.simplify(p, "evenodd")).size(), 2);
            assertDoubleEq("polygon_area(simplify evenodd)",
                    Fill.polygonArea(BoolCombine.simplify(p, "evenodd")), 150);
        });

        scenario("Combine: the star's crossings become corners", () -> {
            Path star = Figures.star();
            assertPointListsEq("simplify(star,nonzero)",
                    BoolCombine.pointLists(BoolCombine.simplify(star, "nonzero")),
                    List.of(List.of(
                            pt(80.5, 10.5), pt(96.21484375, 58.8671875), pt(147.07421875, 58.8671875),
                            pt(105.9296875, 88.76171875), pt(121.64453125, 137.1328125), pt(80.5, 107.23828125),
                            pt(39.35546875, 137.1328125), pt(55.0703125, 88.76171875), pt(13.92578125, 58.8671875),
                            pt(64.78515625, 58.8671875))));
            assertEquals("simplify(star,evenodd) contour count",
                    BoolCombine.pointLists(BoolCombine.simplify(star, "evenodd")).size(), 5);
            assertDoubleEq("polygon_area(nonzero)",
                    Fill.polygonArea(BoolCombine.simplify(star, "nonzero")), 5500.767746, 0.000001);
            assertDoubleEq("polygon_area(evenodd)",
                    Fill.polygonArea(BoolCombine.simplify(star, "evenodd")), 3800.918060, 0.000001);
        });

        scenario("Combine: a shape with itself", () -> {
            Path a = Figures.plateGlyph();
            assertPointListsEq("union",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", a, "nonzero", "union")),
                    BoolCombine.pointLists(BoolCombine.simplify(a, "nonzero")));
            assertPointListsEq("intersection",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", a, "nonzero", "intersection")),
                    BoolCombine.pointLists(BoolCombine.simplify(a, "nonzero")));
            assertEquals("difference empty",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", a, "nonzero", "difference")).size(), 0);
            assertEquals("xor empty",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", a, "nonzero", "xor")).size(), 0);
        });

        scenario("Combine: the areas add up", () -> {
            Path a = Figures.plateGlyph();
            Path b = Figures.plateStar();
            double union = Fill.polygonArea(BoolCombine.combine(a, "nonzero", b, "evenodd", "union"));
            double both = Fill.polygonArea(BoolCombine.combine(a, "nonzero", b, "evenodd", "intersection"));
            double aOnly = Fill.polygonArea(BoolCombine.combine(a, "nonzero", b, "evenodd", "difference"));
            double bOnly = Fill.polygonArea(BoolCombine.combine(b, "evenodd", a, "nonzero", "difference"));
            double either = Fill.polygonArea(BoolCombine.combine(a, "nonzero", b, "evenodd", "xor"));
            assertDoubleEq("union = either + both", union, either + both, 0.000001);
            assertDoubleEq("union = a_only + b_only + both", union, aOnly + bOnly + both, 0.000001);
            double aArea = Fill.polygonArea(BoolCombine.simplify(a, "nonzero"));
            double bArea = Fill.polygonArea(BoolCombine.simplify(b, "evenodd"));
            assertDoubleEq("union + both = a + b", union + both, aArea + bArea, 0.05);
        });

        scenario("Combine: either fill rule fills the result the same", () -> {
            Path r = BoolCombine.combine(Figures.plateGlyph(), "nonzero", Figures.plateStar(), "evenodd", "xor");
            assertTrue("max_coverage_difference <= 0.000001",
                    CoverageBuffer.maxCoverageDifference(
                            Fill.fillPath(r, "nonzero", 200, 200), Fill.fillPath(r, "evenodd", 200, 200))
                            <= 0.000001);
        });
    }

    // ---- §22.8: the hard cases -------------------------------------------------

    private static void registerRobust() {
        scenario("Robust: a crossing computed in floating point is on neither segment", () -> {
            Tuple a = pt(2.6, 2.3);
            Tuple b = pt(10, 4.7);
            Tuple c = pt(8.4, 4.8);
            Tuple d = pt(6.4, 1.5);
            Tuple p = Figures.floatCrossing(a, b, c, d);
            assertTrue("cross(b-a,p-a) != 0",
                    Tuple.cross(b.subtract(a), p.subtract(a)) != 0);
            assertTrue("cross(d-c,p-c) != 0",
                    Tuple.cross(d.subtract(c), p.subtract(c)) != 0);
        });

        scenario("Robust: squares sharing an edge unite into one rectangle", () -> {
            Path a = Paths.polygon(pt(0, 0), pt(10, 0), pt(10, 10), pt(0, 10));
            Path b = Paths.polygon(pt(10, 0), pt(20, 0), pt(20, 10), pt(10, 10));
            assertPointListsEq("union",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", b, "nonzero", "union")),
                    List.of(List.of(pt(0, 0), pt(20, 0), pt(20, 10), pt(0, 10))));
            assertEquals("intersection empty",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", b, "nonzero", "intersection")).size(), 0);
        });

        scenario("Robust: squares sharing part of an edge", () -> {
            Path a = Paths.polygon(pt(0, 0), pt(10, 0), pt(10, 10), pt(0, 10));
            Path b = Paths.polygon(pt(10, 4), pt(20, 4), pt(20, 14), pt(10, 14));
            assertPointListsEq("union",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", b, "nonzero", "union")),
                    List.of(List.of(pt(0, 0), pt(10, 0), pt(10, 4), pt(20, 4), pt(20, 14), pt(10, 14), pt(10, 10),
                            pt(0, 10))));
        });

        scenario("Robust: squares touching at a corner share a point and nothing else", () -> {
            Path a = Paths.polygon(pt(0, 0), pt(10, 0), pt(10, 10), pt(0, 10));
            Path b = Paths.polygon(pt(10, 10), pt(20, 10), pt(20, 20), pt(10, 20));
            assertEquals("union has two contours",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", b, "nonzero", "union")).size(), 2);
            assertEquals("intersection empty",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", b, "nonzero", "intersection")).size(), 0);
        });

        scenario("Robust: two triangles that share only their top point stay two contours", () -> {
            Path a = Paths.polygon(pt(5, 0), pt(10, 8), pt(7, 8));
            Path b = Paths.polygon(pt(5, 0), pt(3, 8), pt(0, 8));
            assertPointListsEq("union",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", b, "nonzero", "union")),
                    List.of(List.of(pt(5, 0), pt(3, 8), pt(0, 8)), List.of(pt(5, 0), pt(10, 8), pt(7, 8))));
        });

        scenario("Robust: a corner resting on an edge", () -> {
            Path a = Paths.polygon(pt(0, 0), pt(10, 0), pt(10, 10), pt(0, 10));
            Path b = Paths.polygon(pt(5, 10), pt(8, 15), pt(2, 15));
            assertPointListsEq("union",
                    BoolCombine.pointLists(BoolCombine.combine(a, "nonzero", b, "nonzero", "union")),
                    List.of(List.of(pt(0, 0), pt(10, 0), pt(10, 10), pt(0, 10)),
                            List.of(pt(5, 10), pt(8, 15), pt(2, 15))));
        });

        scenario("Robust: a spike that goes out and comes back adds nothing", () -> {
            Path p = Paths.polygon(pt(0, 0), pt(10, 0), pt(10, 5), pt(18, 5), pt(10, 5), pt(10, 10), pt(0, 10));
            assertPointListsEq("simplify",
                    BoolCombine.pointLists(BoolCombine.simplify(p, "nonzero")),
                    List.of(List.of(pt(0, 0), pt(10, 0), pt(10, 10), pt(0, 10))));
        });

        scenario("Robust: a sliver thinner than the grid is gone, and one a grid unit thick stays", () -> {
            Path thin = Paths.polygon(pt(0, 0), pt(10, 0), pt(10, 0.001), pt(0, 0.001));
            assertEquals("thin sliver gone", BoolCombine.pointLists(BoolCombine.simplify(thin, "nonzero")).size(), 0);
            Path thick = Paths.polygon(pt(0, 0), pt(10, 0), pt(10, 0.003), pt(0, 0.003));
            assertPointListsEq("grid-unit sliver stays",
                    BoolCombine.pointLists(BoolCombine.simplify(thick, "nonzero")),
                    List.of(List.of(pt(0, 0), pt(10, 0), pt(10, 0.00390625), pt(0, 0.00390625))));
        });
    }

    // ---- §22.9: Plate 22, and a seal --------------------------------------------

    private static void registerPlate() {
        scenario("Plate 22", () -> {
            Canvas c = Figures.plate22();
            byte[] ref = readBytes("reference/chapter-22/plate-22.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 800);
            assertEquals("c.height", c.height, 200);
            assertTriple("(129,75)", Ppm.ppmPixel(p6, 129, 75), new int[] {243, 196, 89}, 1);
            assertTriple("(129,114)", Ppm.ppmPixel(p6, 129, 114), new int[] {243, 196, 89}, 1);
            assertTriple("(156,96)", Ppm.ppmPixel(p6, 156, 96), new int[] {243, 196, 89}, 1);
            assertTriple("(329,75)", Ppm.ppmPixel(p6, 329, 75), new int[] {243, 196, 89}, 1);
            assertTriple("(329,114)", Ppm.ppmPixel(p6, 329, 114), new int[] {39, 39, 44}, 1);
            assertTriple("(356,96)", Ppm.ppmPixel(p6, 356, 96), new int[] {39, 39, 44}, 1);
            assertTriple("(529,75)", Ppm.ppmPixel(p6, 529, 75), new int[] {39, 39, 44}, 1);
            assertTriple("(529,114)", Ppm.ppmPixel(p6, 529, 114), new int[] {243, 196, 89}, 1);
            assertTriple("(556,96)", Ppm.ppmPixel(p6, 556, 96), new int[] {39, 39, 44}, 1);
            assertTriple("(729,75)", Ppm.ppmPixel(p6, 729, 75), new int[] {39, 39, 44}, 1);
            assertTriple("(729,114)", Ppm.ppmPixel(p6, 729, 114), new int[] {243, 196, 89}, 1);
            assertTriple("(756,96)", Ppm.ppmPixel(p6, 756, 96), new int[] {243, 196, 89}, 1);
            assertTriple("(5,5)", Ppm.ppmPixel(p6, 5, 5), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("The seal", () -> {
            Canvas c = Figures.seal();
            byte[] ref = readBytes("reference/chapter-22/seal.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 480);
            assertEquals("c.height", c.height, 480);
            assertTriple("(240,452)", Ppm.ppmPixel(p6, 240, 452), new int[] {243, 196, 89}, 1);
            assertTriple("(240,40)", Ppm.ppmPixel(p6, 240, 40), new int[] {39, 39, 44}, 1);
            assertTriple("(240,200)", Ppm.ppmPixel(p6, 240, 200), new int[] {243, 196, 89}, 1);
            assertTriple("(76,215)", Ppm.ppmPixel(p6, 76, 215), new int[] {39, 39, 44}, 1);
            assertTriple("(430,240)", Ppm.ppmPixel(p6, 430, 240), new int[] {243, 196, 89}, 1);
            assertTriple("(240,352)", Ppm.ppmPixel(p6, 240, 352), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static void assertTriple(String what, int[] actual, int[] expected, int tolerance) {
        for (int i = 0; i < 3; i++) {
            if (Math.abs(actual[i] - expected[i]) > tolerance) {
                throw new AssertionError(what + ": expected " + java.util.Arrays.toString(expected)
                        + " but got " + java.util.Arrays.toString(actual) + " (tolerance " + tolerance + ")");
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
        java.nio.file.Files.createDirectories(java.nio.file.Path.of("out"));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "plate-22.ppm"), Ppm.canvasToP6(Figures.plate22()));
        java.nio.file.Files.write(java.nio.file.Path.of("out", "seal.ppm"), Ppm.canvasToP6(Figures.seal()));
    }
}
