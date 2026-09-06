import java.io.IOException;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter06-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-06/*.ppm resolves.
 */
public final class Chapter06Tests {

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

    private static void assertTupleEq(String what, Tuple actual, Tuple expected) {
        if (!actual.approxEquals(expected)) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
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

    private static void assertBoundsEq(String what, Bounds actual, Bounds expected) {
        if (!Numbers.approxEqual(actual.minX(), expected.minX())
                || !Numbers.approxEqual(actual.minY(), expected.minY())
                || !Numbers.approxEqual(actual.maxX(), expected.maxX())
                || !Numbers.approxEqual(actual.maxY(), expected.maxY())) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertSpansEq(String what, List<Span> actual, List<Span> expected) {
        boolean same = actual.size() == expected.size();
        if (same) {
            for (int i = 0; i < actual.size(); i++) {
                Span a = actual.get(i);
                Span e = expected.get(i);
                if (!Numbers.approxEqual(a.x0(), e.x0()) || !Numbers.approxEqual(a.x1(), e.x1())) {
                    same = false;
                    break;
                }
            }
        }
        if (!same) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    private static void assertCrossingsEq(String what, List<Crossing> actual, List<Crossing> expected) {
        boolean same = actual.size() == expected.size();
        if (same) {
            for (int i = 0; i < actual.size(); i++) {
                Crossing a = actual.get(i);
                Crossing e = expected.get(i);
                if (!Numbers.approxEqual(a.x(), e.x()) || a.direction() != e.direction()) {
                    same = false;
                    break;
                }
            }
        }
        if (!same) {
            throw new AssertionError(what + ": expected " + expected + " but got " + actual);
        }
    }

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerEdges();
        registerSpans();
        registerSweep();
        registerPlate();
    }

    // features/chapter06-edges.feature
    private static void registerEdges() {
        scenario("Edges: a rectangle has two edges in its table", () -> {
            Path p = Paths.polygon(Tuple.point(2, 2), Tuple.point(6, 2), Tuple.point(6, 6), Tuple.point(2, 6));
            List<TableEdge> t = EdgeTable.edgeTable(p);
            assertEquals("length(t)", t.size(), 2);
            assertDoubleEq("t[0].y_top", t.get(0).yTop(), 2);
            assertDoubleEq("t[0].y_bottom", t.get(0).yBottom(), 6);
            assertDoubleEq("t[0].x_top", t.get(0).xTop(), 2);
            assertDoubleEq("t[0].slope", t.get(0).slope(), 0);
            assertEquals("t[0].direction", t.get(0).direction(), -1);
            assertDoubleEq("t[1].x_top", t.get(1).xTop(), 6);
            assertEquals("t[1].direction", t.get(1).direction(), 1);
        });

        scenario("Edges: a triangle's edges carry their slopes", () -> {
            Path p = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(5, 10));
            List<TableEdge> t = EdgeTable.edgeTable(p);
            assertEquals("length(t)", t.size(), 2);
            assertDoubleEq("t[0].x_top", t.get(0).xTop(), 0);
            assertDoubleEq("t[0].slope", t.get(0).slope(), 0.5);
            assertEquals("t[0].direction", t.get(0).direction(), -1);
            assertDoubleEq("t[1].x_top", t.get(1).xTop(), 10);
            assertDoubleEq("t[1].slope", t.get(1).slope(), -0.5);
            assertEquals("t[1].direction", t.get(1).direction(), 1);
        });

        scenario("Edges: the table is sorted by top, then by x at the top", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(2, 2));
            p.lineTo(Tuple.point(4, 1));
            p.lineTo(Tuple.point(6, 3));
            p.lineTo(Tuple.point(8, 1));
            p.lineTo(Tuple.point(9, 6));
            p.lineTo(Tuple.point(1, 6));
            p.close();
            List<TableEdge> t = EdgeTable.edgeTable(p);
            assertEquals("length(t)", t.size(), 5);
            assertDoubleEq("t[0].y_top", t.get(0).yTop(), 1);
            assertDoubleEq("t[0].x_top", t.get(0).xTop(), 4);
            assertDoubleEq("t[1].y_top", t.get(1).yTop(), 1);
            assertDoubleEq("t[1].x_top", t.get(1).xTop(), 4);
            assertDoubleEq("t[2].y_top", t.get(2).yTop(), 1);
            assertDoubleEq("t[2].x_top", t.get(2).xTop(), 8);
            assertDoubleEq("t[3].y_top", t.get(3).yTop(), 1);
            assertDoubleEq("t[3].x_top", t.get(3).xTop(), 8);
            assertDoubleEq("t[4].y_top", t.get(4).yTop(), 2);
            assertDoubleEq("t[4].x_top", t.get(4).xTop(), 2);
        });

        scenario("Edges: a horizontal edge is dropped, not clamped", () -> {
            Path p = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(10, 5), Tuple.point(0, 5));
            List<TableEdge> t = EdgeTable.edgeTable(p);
            assertEquals("length(t)", t.size(), 2);
            assertDoubleEq("t[0].x_top", t.get(0).xTop(), 0);
            assertDoubleEq("t[1].x_top", t.get(1).xTop(), 10);
        });

        scenario("Edges: an edge knows where it crosses a height", () -> {
            Path p = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(5, 10));
            List<TableEdge> t = EdgeTable.edgeTable(p);
            assertDoubleEq("x_at(t[0], 4)", EdgeTable.xAt(t.get(0), 4), 2);
            assertDoubleEq("x_at(t[1], 4)", EdgeTable.xAt(t.get(1), 4), 8);
            assertDoubleEq("x_at(t[0], 0.5)", EdgeTable.xAt(t.get(0), 0.5), 0.25);
        });

        scenario("Edges: the edge table is the same whichever way the path was drawn", () -> {
            Path a = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(5, 10));
            Path b = Paths.polygon(Tuple.point(0, 0), Tuple.point(5, 10), Tuple.point(10, 0));
            List<TableEdge> ta = EdgeTable.edgeTable(a);
            List<TableEdge> tb = EdgeTable.edgeTable(b);
            assertDoubleEq("ta[0].x_top", ta.get(0).xTop(), tb.get(0).xTop());
            assertDoubleEq("ta[0].slope", ta.get(0).slope(), tb.get(0).slope());
            assertEquals("ta[0].direction", ta.get(0).direction(), -1);
            assertEquals("tb[0].direction", tb.get(0).direction(), 1);
        });
    }

    // features/chapter06-spans.feature
    private static void registerSpans() {
        scenario("Spans: crossings on a row, sorted by x", () -> {
            Path p = Paths.polygon(Tuple.point(2, 2), Tuple.point(6, 2), Tuple.point(6, 6), Tuple.point(2, 6));
            List<TableEdge> t = EdgeTable.edgeTable(p);
            List<Crossing> xs = Spans.crossingsOnRow(t, 3.5);
            assertCrossingsEq("xs", xs, List.of(new Crossing(2, -1), new Crossing(6, 1)));
            assertCrossingsEq("crossings_on_row(t, 1.5)", Spans.crossingsOnRow(t, 1.5), List.of());
            assertCrossingsEq("crossings_on_row(t, 6)", Spans.crossingsOnRow(t, 6), List.of());
            assertEquals("length(crossings_on_row(t, 2))", Spans.crossingsOnRow(t, 2).size(), 2);
        });

        scenario("Spans: the star's crossings through its middle", () -> {
            Path p = Figures.star();
            List<Crossing> xs = Spans.crossingsOnRow(EdgeTable.edgeTable(p), 80.5);
            assertEquals("length(xs)", xs.size(), 4);
            assertDoubleEq("xs[0].x", xs.get(0).x(), 43.6988);
            assertEquals("xs[0].direction", xs.get(0).direction(), -1);
            assertDoubleEq("xs[1].x", xs.get(1).x(), 57.7556);
            assertEquals("xs[1].direction", xs.get(1).direction(), -1);
            assertDoubleEq("xs[2].x", xs.get(2).x(), 103.2444);
            assertEquals("xs[2].direction", xs.get(2).direction(), 1);
            assertDoubleEq("xs[3].x", xs.get(3).x(), 117.3012);
            assertEquals("xs[3].direction", xs.get(3).direction(), 1);
        });

        scenario("Spans: spans from crossings under each rule", () -> {
            List<Crossing> xs = List.of(
                    new Crossing(1, 1), new Crossing(3, 1), new Crossing(5, -1), new Crossing(7, -1));
            assertSpansEq("spans_from_crossings(xs, \"nonzero\")",
                    Spans.spansFromCrossings(xs, "nonzero"), List.of(new Span(1, 7)));
            assertSpansEq("spans_from_crossings(xs, \"evenodd\")",
                    Spans.spansFromCrossings(xs, "evenodd"), List.of(new Span(1, 3), new Span(5, 7)));
            assertSpansEq("spans_from_crossings([], \"nonzero\")",
                    Spans.spansFromCrossings(List.of(), "nonzero"), List.of());
        });

        scenario("Spans: the spans of an axis-aligned rectangle are exact", () -> {
            Path p = Paths.polygon(
                    Tuple.point(1.25, 2), Tuple.point(4.75, 2), Tuple.point(4.75, 5), Tuple.point(1.25, 5));
            assertSpansEq("spans(p, \"nonzero\", 1)", Spans.spans(p, "nonzero", 1), List.of());
            assertSpansEq("spans(p, \"nonzero\", 2)", Spans.spans(p, "nonzero", 2), List.of(new Span(1.25, 4.75)));
            assertSpansEq("spans(p, \"nonzero\", 4)", Spans.spans(p, "nonzero", 4), List.of(new Span(1.25, 4.75)));
            assertSpansEq("spans(p, \"nonzero\", 5)", Spans.spans(p, "nonzero", 5), List.of());
        });

        scenario("Spans: a rectangle whose edges sit on sample heights", () -> {
            Path p = Paths.polygon(
                    Tuple.point(1.5, 2.5), Tuple.point(4.5, 2.5), Tuple.point(4.5, 5.5), Tuple.point(1.5, 5.5));
            assertSpansEq("spans(p, \"nonzero\", 1)", Spans.spans(p, "nonzero", 1), List.of());
            assertSpansEq("spans(p, \"nonzero\", 2)", Spans.spans(p, "nonzero", 2), List.of(new Span(1.5, 4.5)));
            assertSpansEq("spans(p, \"nonzero\", 4)", Spans.spans(p, "nonzero", 4), List.of(new Span(1.5, 4.5)));
            assertSpansEq("spans(p, \"nonzero\", 5)", Spans.spans(p, "nonzero", 5), List.of());
        });

        scenario("Spans: a triangle's spans narrow by one per row", () -> {
            Path p = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(5, 10));
            double[][] examples = {{0, 0.25, 9.75}, {1, 0.75, 9.25}, {4, 2.25, 7.75}, {9, 4.75, 5.25}};
            for (double[] ex : examples) {
                int row = (int) ex[0];
                assertSpansEq("spans(p, \"nonzero\", " + row + ")", Spans.spans(p, "nonzero", row),
                        List.of(new Span(ex[1], ex[2])));
            }
        });

        scenario("Spans: the row past the triangle's apex has no span", () -> {
            Path p = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(5, 10));
            assertSpansEq("spans(p, \"nonzero\", 10)", Spans.spans(p, "nonzero", 10), List.of());
        });

        scenario("Spans: a flat top is not a span of its own", () -> {
            Path p = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(10, 5), Tuple.point(0, 5));
            assertEquals("length(edge_table(p))", EdgeTable.edgeTable(p).size(), 2);
            assertSpansEq("spans(p, \"nonzero\", 0)", Spans.spans(p, "nonzero", 0), List.of(new Span(0, 10)));
            assertSpansEq("spans(p, \"nonzero\", 4)", Spans.spans(p, "nonzero", 4), List.of(new Span(0, 10)));
            assertSpansEq("spans(p, \"nonzero\", 5)", Spans.spans(p, "nonzero", 5), List.of());
        });

        scenario("Spans: a ring is two spans under even-odd and one under nonzero", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(0, 0));
            p.lineTo(Tuple.point(10, 0));
            p.lineTo(Tuple.point(10, 10));
            p.lineTo(Tuple.point(0, 10));
            p.close();
            p.moveTo(Tuple.point(3, 3));
            p.lineTo(Tuple.point(7, 3));
            p.lineTo(Tuple.point(7, 7));
            p.lineTo(Tuple.point(3, 7));
            p.close();
            assertSpansEq("spans(p, \"nonzero\", 5)", Spans.spans(p, "nonzero", 5), List.of(new Span(0, 10)));
            assertSpansEq("spans(p, \"evenodd\", 5)", Spans.spans(p, "evenodd", 5),
                    List.of(new Span(0, 3), new Span(7, 10)));
        });

        scenario("Spans: the star's spans through its middle", () -> {
            Path p = Figures.star();
            assertSpansEq("spans(p, \"nonzero\", 80)", Spans.spans(p, "nonzero", 80),
                    List.of(new Span(43.6988, 117.3012)));
            assertSpansEq("spans(p, \"evenodd\", 80)", Spans.spans(p, "evenodd", 80),
                    List.of(new Span(43.6988, 57.7556), new Span(103.2444, 117.3012)));
        });

        scenario("Spans: fill_span fills the pixels whose centers are in the span", () -> {
            CoverageBuffer cov = new CoverageBuffer(8, 3);
            Spans.fillSpan(cov, 1, 1.25, 4.75);
            assertDoubleEq("coverage_at(cov, 0, 1)", cov.coverageAt(0, 1), 0);
            assertDoubleEq("coverage_at(cov, 1, 1)", cov.coverageAt(1, 1), 1);
            assertDoubleEq("coverage_at(cov, 4, 1)", cov.coverageAt(4, 1), 1);
            assertDoubleEq("coverage_at(cov, 5, 1)", cov.coverageAt(5, 1), 0);
            assertDoubleEq("coverage_at(cov, 2, 0)", cov.coverageAt(2, 0), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 4);
        });

        scenario("Spans: the span is half-open at its right end", () -> {
            CoverageBuffer cov = new CoverageBuffer(8, 3);
            Spans.fillSpan(cov, 1, 1.5, 4.5);
            assertDoubleEq("coverage_at(cov, 1, 1)", cov.coverageAt(1, 1), 1);
            assertDoubleEq("coverage_at(cov, 3, 1)", cov.coverageAt(3, 1), 1);
            assertDoubleEq("coverage_at(cov, 4, 1)", cov.coverageAt(4, 1), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 3);
        });

        scenario("Spans: a span may run off either side of the buffer", () -> {
            CoverageBuffer a = new CoverageBuffer(8, 3);
            CoverageBuffer b = new CoverageBuffer(8, 3);
            CoverageBuffer c = new CoverageBuffer(8, 3);
            Spans.fillSpan(a, 1, -3, 2.5);
            Spans.fillSpan(b, 1, 6.5, 20);
            Spans.fillSpan(c, 1, 2.5, 2.5);
            assertDoubleEq("ink(a)", a.ink(), 2);
            assertDoubleEq("coverage_at(a, 1, 1)", a.coverageAt(1, 1), 1);
            assertDoubleEq("ink(b)", b.ink(), 2);
            assertDoubleEq("coverage_at(b, 6, 1)", b.coverageAt(6, 1), 1);
            assertDoubleEq("ink(c)", c.ink(), 0);
        });
    }

    // features/chapter06-sweep.feature
    private static void registerSweep() {
        scenario("Sweep: two buffers that differ", () -> {
            CoverageBuffer a = new CoverageBuffer(3, 3);
            CoverageBuffer b = new CoverageBuffer(3, 3);
            a.setCoverage(1, 1, 1);
            b.setCoverage(1, 1, 0.25);
            assertDoubleEq("max_coverage_difference(a, b)", CoverageBuffer.maxCoverageDifference(a, b), 0.75);
            assertDoubleEq("max_coverage_difference(a, a)", CoverageBuffer.maxCoverageDifference(a, a), 0);
        });

        scenario("Sweep: buffers of different sizes are as different as it gets", () -> {
            CoverageBuffer a = new CoverageBuffer(3, 3);
            CoverageBuffer b = new CoverageBuffer(3, 4);
            assertDoubleEq("max_coverage_difference(a, b)", CoverageBuffer.maxCoverageDifference(a, b), 1);
        });

        scenario("Sweep: a rectangle", () -> {
            Path p = Paths.polygon(Tuple.point(2, 2), Tuple.point(6, 2), Tuple.point(6, 6), Tuple.point(2, 6));
            CoverageBuffer cov = Sweep.fillPathAliased(p, "nonzero", 8, 8);
            assertDoubleEq("coverage_at(cov, 2, 2)", cov.coverageAt(2, 2), 1);
            assertDoubleEq("coverage_at(cov, 5, 5)", cov.coverageAt(5, 5), 1);
            assertDoubleEq("coverage_at(cov, 6, 5)", cov.coverageAt(6, 5), 0);
            assertDoubleEq("coverage_at(cov, 5, 6)", cov.coverageAt(5, 6), 0);
            assertDoubleEq("coverage_at(cov, 1, 2)", cov.coverageAt(1, 2), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 16);
            assertDoubleEq("max_coverage_difference(cov, rasterize_centers(filled(p, \"nonzero\"), 8, 8))",
                    CoverageBuffer.maxCoverageDifference(cov,
                            Rasterizer.rasterizeCenters(Paths.filled(p, "nonzero"), 8, 8)),
                    0);
        });

        scenario("Sweep: a triangle", () -> {
            Path p = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(5, 10));
            CoverageBuffer cov = Sweep.fillPathAliased(p, "nonzero", 20, 20);
            assertDoubleEq("coverage_at(cov, 0, 0)", cov.coverageAt(0, 0), 1);
            assertDoubleEq("coverage_at(cov, 9, 0)", cov.coverageAt(9, 0), 1);
            assertDoubleEq("coverage_at(cov, 10, 0)", cov.coverageAt(10, 0), 0);
            assertDoubleEq("coverage_at(cov, 4, 8)", cov.coverageAt(4, 8), 1);
            assertDoubleEq("coverage_at(cov, 3, 8)", cov.coverageAt(3, 8), 0);
            assertDoubleEq("coverage_at(cov, 5, 9)", cov.coverageAt(5, 9), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 50);
            assertDoubleEq("max_coverage_difference(cov, rasterize_centers(filled(p, \"nonzero\"), 20, 20))",
                    CoverageBuffer.maxCoverageDifference(cov,
                            Rasterizer.rasterizeCenters(Paths.filled(p, "nonzero"), 20, 20)),
                    0);
        });

        scenario("Sweep: the same triangle drawn the other way round", () -> {
            Path a = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(5, 10));
            Path b = Paths.polygon(Tuple.point(0, 0), Tuple.point(5, 10), Tuple.point(10, 0));
            CoverageBuffer ca = Sweep.fillPathAliased(a, "nonzero", 20, 20);
            CoverageBuffer cb = Sweep.fillPathAliased(b, "nonzero", 20, 20);
            assertDoubleEq("max_coverage_difference(ca, cb)", CoverageBuffer.maxCoverageDifference(ca, cb), 0);
        });

        scenario("Sweep: a polygon circle", () -> {
            Path p = Paths.circlePath(10.3, 9.7, 7, 12);
            CoverageBuffer cov = Sweep.fillPathAliased(p, "nonzero", 20, 20);
            assertDoubleEq("ink(cov)", cov.ink(), 145);
            assertDoubleEq("max_coverage_difference(cov, rasterize_centers(filled(p, \"nonzero\"), 20, 20))",
                    CoverageBuffer.maxCoverageDifference(cov,
                            Rasterizer.rasterizeCenters(Paths.filled(p, "nonzero"), 20, 20)),
                    0);
        });

        scenario("Sweep: the star, both rules, matches chapter 5 pixel for pixel", () -> {
            Path p = Figures.star();
            CoverageBuffer nz = Sweep.fillPathAliased(p, "nonzero", 160, 160);
            CoverageBuffer eo = Sweep.fillPathAliased(p, "evenodd", 160, 160);
            assertDoubleEq("ink(nz)", nz.ink(), 5480);
            assertDoubleEq("ink(eo)", eo.ink(), 3780);
            assertDoubleEq("coverage_at(nz, 80, 80)", nz.coverageAt(80, 80), 1);
            assertDoubleEq("coverage_at(eo, 80, 80)", eo.coverageAt(80, 80), 0);
            assertDoubleEq("max_coverage_difference(nz, rasterize_centers(filled(p, \"nonzero\"), 160, 160))",
                    CoverageBuffer.maxCoverageDifference(nz,
                            Rasterizer.rasterizeCenters(Paths.filled(p, "nonzero"), 160, 160)),
                    0);
            assertDoubleEq("max_coverage_difference(eo, rasterize_centers(filled(p, \"evenodd\"), 160, 160))",
                    CoverageBuffer.maxCoverageDifference(eo,
                            Rasterizer.rasterizeCenters(Paths.filled(p, "evenodd"), 160, 160)),
                    0);
        });

        scenario("Sweep: an edge that starts on a sample height is active there, "
                + "and one that ends there is not", () -> {
            Path p = Paths.polygon(
                    Tuple.point(1.5, 2.5), Tuple.point(4.5, 2.5), Tuple.point(4.5, 5.5), Tuple.point(1.5, 5.5));
            CoverageBuffer cov = Sweep.fillPathAliased(p, "nonzero", 8, 8);
            assertDoubleEq("coverage_at(cov, 2, 1)", cov.coverageAt(2, 1), 0);
            assertDoubleEq("coverage_at(cov, 2, 2)", cov.coverageAt(2, 2), 1);
            assertDoubleEq("coverage_at(cov, 2, 4)", cov.coverageAt(2, 4), 1);
            assertDoubleEq("coverage_at(cov, 2, 5)", cov.coverageAt(2, 5), 0);
            assertDoubleEq("coverage_at(cov, 1, 3)", cov.coverageAt(1, 3), 1);
            assertDoubleEq("coverage_at(cov, 4, 3)", cov.coverageAt(4, 3), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 9);
            assertDoubleEq("max_coverage_difference(cov, rasterize_centers(filled(p, \"nonzero\"), 8, 8))",
                    CoverageBuffer.maxCoverageDifference(cov,
                            Rasterizer.rasterizeCenters(Paths.filled(p, "nonzero"), 8, 8)),
                    0);
        });

        scenario("Sweep: a polygon larger than the buffer fills it", () -> {
            Path p = Paths.polygon(
                    Tuple.point(-5, -5), Tuple.point(30, -5), Tuple.point(30, 30), Tuple.point(-5, 30));
            CoverageBuffer cov = Sweep.fillPathAliased(p, "nonzero", 8, 8);
            assertDoubleEq("ink(cov)", cov.ink(), 64);
        });

        scenario("Sweep: an empty path fills nothing", () -> {
            Path p = new Path();
            CoverageBuffer cov = Sweep.fillPathAliased(p, "nonzero", 8, 8);
            assertDoubleEq("ink(cov)", cov.ink(), 0);
        });

        scenario("Sweep: transform_path takes every point through the matrix and keeps the flags", () -> {
            Path p = Paths.polygon(
                    Tuple.point(1.25, 2), Tuple.point(4.75, 2), Tuple.point(4.75, 5), Tuple.point(1.25, 5));
            Path q = Paths.transformPath(p, Transforms.translation(10, 20));
            assertEquals("length(subpaths(q))", q.subpaths().size(), 1);
            assertEquals("subpaths(q)[0].closed", q.subpaths().get(0).closed, true);
            assertTupleEq("subpaths(q)[0].points[0]", q.subpaths().get(0).points.get(0), Tuple.point(11.25, 22));
            assertTupleEq("subpaths(q)[0].points[2]", q.subpaths().get(0).points.get(2), Tuple.point(14.75, 25));
            assertTupleEq("subpaths(p)[0].points[0]", p.subpaths().get(0).points.get(0), Tuple.point(1.25, 2));
        });

        scenario("Sweep: a transformed star fills where the transform put it", () -> {
            Matrix m = Transforms.translation(10, 10)
                    .multiply(Transforms.scaling(0.11, 0.11))
                    .multiply(Transforms.translation(-80.5, -80.5));
            Path p = Paths.transformPath(Figures.star(), m);
            CoverageBuffer nz = Sweep.fillPathAliased(p, "nonzero", 20, 20);
            CoverageBuffer eo = Sweep.fillPathAliased(p, "evenodd", 20, 20);
            assertBoundsEq("bounds(p)", p.bounds(), new Bounds(2.6769, 2.3, 17.3231, 16.2294));
            assertDoubleEq("ink(nz)", nz.ink(), 60);
            assertDoubleEq("ink(eo)", eo.ink(), 40);
            assertDoubleEq("max_coverage_difference(nz, rasterize_centers(filled(p, \"nonzero\"), 20, 20))",
                    CoverageBuffer.maxCoverageDifference(nz,
                            Rasterizer.rasterizeCenters(Paths.filled(p, "nonzero"), 20, 20)),
                    0);
        });
    }

    // features/chapter06-plate.feature
    private static void registerPlate() {
        scenario("Plate 6: the unit star", () -> {
            Path p = Figures.unitStar();
            assertEquals("length(edges(p))", p.edges().size(), 5);
            List<Tuple> pts = p.subpaths().get(0).points;
            assertTupleEq("subpaths(p)[0].points[0]", pts.get(0), Tuple.point(0, -1));
            assertTupleEq("subpaths(p)[0].points[1]", pts.get(1), Tuple.point(0.5878, 0.809));
            assertTupleEq("subpaths(p)[0].points[2]", pts.get(2), Tuple.point(-0.9511, -0.309));
            assertBoundsEq("bounds(p)", p.bounds(), new Bounds(-0.9511, -1, 0.9511, 0.809));
        });

        scenario("Plate 6: the spiral", () -> {
            Canvas c = Figures.spiral();
            byte[] ref = readReference("spiral.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 320);
            assertTriple("ppm_pixel(p6, 180, 160)", Ppm.ppmPixel(p6, 180, 160), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 183, 171)", Ppm.ppmPixel(p6, 183, 171), new int[] {124, 196, 237}, 1);
            assertTriple("ppm_pixel(p6, 179, 183)", Ppm.ppmPixel(p6, 179, 183), new int[] {237, 137, 149}, 1);
            assertTriple("ppm_pixel(p6, 104, 139)", Ppm.ppmPixel(p6, 104, 139), new int[] {237, 137, 149}, 1);
            assertTriple("ppm_pixel(p6, 230, 111)", Ppm.ppmPixel(p6, 230, 111), new int[] {124, 196, 237}, 1);
            assertTriple("ppm_pixel(p6, 32, 137)", Ppm.ppmPixel(p6, 32, 137), new int[] {124, 196, 237}, 1);
            assertTriple("ppm_pixel(p6, 34, 104)", Ppm.ppmPixel(p6, 34, 104), new int[] {237, 137, 149}, 1);
            assertTriple("ppm_pixel(p6, 160, 160)", Ppm.ppmPixel(p6, 160, 160), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 5, 5)", Ppm.ppmPixel(p6, 5, 5), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 300, 20)", Ppm.ppmPixel(p6, 300, 20), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 6: plate 6", () -> {
            Canvas c = Figures.plate06();
            byte[] ref = readReference("plate-06.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 640);
            assertEquals("c.height", c.height, 640);
            assertTriple("ppm_pixel(p6, 360, 320)", Ppm.ppmPixel(p6, 360, 320), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 68, 208)", Ppm.ppmPixel(p6, 68, 208), new int[] {237, 137, 149}, 1);
            assertTriple("ppm_pixel(p6, 320, 320)", Ppm.ppmPixel(p6, 320, 320), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference/chapter-06", filename));
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
        writeOne("spiral.ppm", Figures.spiral());
        writeOne("plate-06.ppm", Figures.plate06());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
