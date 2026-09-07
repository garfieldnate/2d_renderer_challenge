import java.io.IOException;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A small main-method test runner translating every scenario in
 * features/chapter07-*.feature into a Java test. No JUnit, no network:
 * run from the project root so reference/chapter-07/*.ppm resolves.
 */
public final class Chapter07Tests {

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

    // ---- scenario registration ----------------------------------------------

    private static void registerAll() {
        registerCells();
        registerRow();
        registerWalk();
        registerResolve();
        registerFill();
        registerPlate();
    }

    // features/chapter07-cells.feature
    private static void registerCells() {
        scenario("Cells: a fresh accumulator is all zeros", () -> {
            Accumulator acc = new Accumulator(4, 3);
            assertEquals("acc.width", acc.width, 4);
            assertEquals("acc.height", acc.height, 3);
            assertDoubleEq("area_at(acc, 1, 0)", acc.areaAt(1, 0), 0);
            assertDoubleEq("cover_at(acc, 3, 2)", acc.coverAt(3, 2), 0);
        });

        scenario("Cells: add_cell deposits an area and a cover", () -> {
            Accumulator acc = new Accumulator(4, 3);
            acc.addCell(1, 0, 0.3, 0.7);
            assertDoubleEq("area_at(acc, 1, 0)", acc.areaAt(1, 0), 0.3);
            assertDoubleEq("cover_at(acc, 1, 0)", acc.coverAt(1, 0), 0.7);
            assertDoubleEq("area_at(acc, 0, 0)", acc.areaAt(0, 0), 0);
            assertDoubleEq("cover_at(acc, 2, 0)", acc.coverAt(2, 0), 0);
        });

        scenario("Cells: add_cell accumulates rather than overwrites", () -> {
            Accumulator acc = new Accumulator(4, 3);
            acc.addCell(2, 1, 0.25, 0.5);
            acc.addCell(2, 1, 0.25, 0.5);
            assertDoubleEq("area_at(acc, 2, 1)", acc.areaAt(2, 1), 0.5);
            assertDoubleEq("cover_at(acc, 2, 1)", acc.coverAt(2, 1), 1.0);
        });

        scenario("Cells: a deposit left of the buffer folds onto column 0 as cover", () -> {
            Accumulator acc = new Accumulator(4, 3);
            acc.addCell(-2, 0, 0.3, 0.7);
            assertDoubleEq("area_at(acc, 0, 0)", acc.areaAt(0, 0), 0.7);
            assertDoubleEq("cover_at(acc, 0, 0)", acc.coverAt(0, 0), 0.7);
        });

        scenario("Cells: a deposit right of the buffer is dropped", () -> {
            Accumulator acc = new Accumulator(4, 3);
            acc.addCell(9, 0, 0.3, 0.7);
            assertDoubleEq("area_at(acc, 3, 0)", acc.areaAt(3, 0), 0);
            assertDoubleEq("cover_at(acc, 3, 0)", acc.coverAt(3, 0), 0);
        });
    }

    // features/chapter07-row.feature
    private static void registerRow() {
        scenario("Row: a piece that stays in one cell", () -> {
            Accumulator acc = new Accumulator(4, 3);
            Fill.accumulateRow(acc, 0, 1.5, 1.5, 1.0);
            assertDoubleEq("area_at(acc, 1, 0)", acc.areaAt(1, 0), 0.5);
            assertDoubleEq("cover_at(acc, 1, 0)", acc.coverAt(1, 0), 1.0);
        });

        scenario("Row: a slanted piece in one cell leans its area toward the left", () -> {
            Accumulator acc = new Accumulator(4, 3);
            Fill.accumulateRow(acc, 0, 1.0, 1.5, 1.0);
            assertDoubleEq("area_at(acc, 1, 0)", acc.areaAt(1, 0), 0.75);
            assertDoubleEq("cover_at(acc, 1, 0)", acc.coverAt(1, 0), 1.0);
        });

        scenario("Row: a piece that spans several cells shares its height by width", () -> {
            Accumulator acc = new Accumulator(4, 3);
            Fill.accumulateRow(acc, 2, 0.0, 3.0, 1.0);
            assertDoubleEq("area_at(acc, 0, 2)", acc.areaAt(0, 2), 0.1667, 0.0001);
            assertDoubleEq("area_at(acc, 1, 2)", acc.areaAt(1, 2), 0.1667, 0.0001);
            assertDoubleEq("area_at(acc, 2, 2)", acc.areaAt(2, 2), 0.1667, 0.0001);
            assertDoubleEq("cover_at(acc, 0, 2)", acc.coverAt(0, 2), 0.3333, 0.0001);
            assertDoubleEq("cover_at(acc, 1, 2)", acc.coverAt(1, 2), 0.3333, 0.0001);
            assertDoubleEq("cover_at(acc, 2, 2)", acc.coverAt(2, 2), 0.3333, 0.0001);
        });

        scenario("Row: a negative height deposits negative numbers", () -> {
            Accumulator acc = new Accumulator(4, 3);
            Fill.accumulateRow(acc, 0, 1.5, 1.5, -1.0);
            assertDoubleEq("area_at(acc, 1, 0)", acc.areaAt(1, 0), -0.5);
            assertDoubleEq("cover_at(acc, 1, 0)", acc.coverAt(1, 0), -1.0);
        });
    }

    // features/chapter07-walk.feature
    private static void registerWalk() {
        scenario("Walk: an edge going up the canvas carries a positive height", () -> {
            Accumulator acc = new Accumulator(4, 3);
            Fill.accumulate(acc, Tuple.point(1.5, 3), Tuple.point(1.5, 0));
            assertDoubleEq("area_at(acc, 1, 0)", acc.areaAt(1, 0), 0.5);
            assertDoubleEq("cover_at(acc, 1, 0)", acc.coverAt(1, 0), 1.0);
            assertDoubleEq("area_at(acc, 1, 1)", acc.areaAt(1, 1), 0.5);
            assertDoubleEq("cover_at(acc, 1, 2)", acc.coverAt(1, 2), 1.0);
        });

        scenario("Walk: the same edge going down carries a negative height", () -> {
            Accumulator acc = new Accumulator(4, 3);
            Fill.accumulate(acc, Tuple.point(1.5, 0), Tuple.point(1.5, 3));
            assertDoubleEq("area_at(acc, 1, 0)", acc.areaAt(1, 0), -0.5);
            assertDoubleEq("cover_at(acc, 1, 1)", acc.coverAt(1, 1), -1.0);
        });

        scenario("Walk: a partial-height edge deposits only its height", () -> {
            Accumulator acc = new Accumulator(4, 3);
            Fill.accumulate(acc, Tuple.point(1.5, 0.75), Tuple.point(1.5, 0.25));
            assertDoubleEq("area_at(acc, 1, 0)", acc.areaAt(1, 0), 0.25);
            assertDoubleEq("cover_at(acc, 1, 0)", acc.coverAt(1, 0), 0.5);
            assertDoubleEq("cover_at(acc, 1, 1)", acc.coverAt(1, 1), 0);
        });

        scenario("Walk: an edge that crosses several rows is clipped to each", () -> {
            Accumulator acc = new Accumulator(4, 3);
            Fill.accumulate(acc, Tuple.point(1.5, 2.5), Tuple.point(1.5, 0.5));
            assertDoubleEq("cover_at(acc, 1, 0)", acc.coverAt(1, 0), 0.5);
            assertDoubleEq("cover_at(acc, 1, 1)", acc.coverAt(1, 1), 1.0);
            assertDoubleEq("cover_at(acc, 1, 2)", acc.coverAt(1, 2), 0.5);
        });

        scenario("Walk: an edge reaching above and below the buffer fills every row it can", () -> {
            Accumulator acc = new Accumulator(4, 3);
            Fill.accumulate(acc, Tuple.point(1.5, 5), Tuple.point(1.5, -2));
            assertDoubleEq("cover_at(acc, 1, 0)", acc.coverAt(1, 0), 1.0);
            assertDoubleEq("cover_at(acc, 1, 1)", acc.coverAt(1, 1), 1.0);
            assertDoubleEq("cover_at(acc, 1, 2)", acc.coverAt(1, 2), 1.0);
        });

        scenario("Walk: a horizontal edge deposits nothing", () -> {
            Accumulator acc = new Accumulator(4, 3);
            Fill.accumulate(acc, Tuple.point(0, 1), Tuple.point(3, 1));
            assertDoubleEq("area_at(acc, 1, 1)", acc.areaAt(1, 1), 0);
            assertDoubleEq("cover_at(acc, 1, 1)", acc.coverAt(1, 1), 0);
        });

        scenario("Walk: an edge entirely left of the buffer covers every cell to its right", () -> {
            Accumulator acc = new Accumulator(4, 3);
            Fill.accumulate(acc, Tuple.point(-3, 3), Tuple.point(-3, 0));
            assertDoubleEq("area_at(acc, 0, 0)", acc.areaAt(0, 0), 1.0);
            assertDoubleEq("cover_at(acc, 0, 0)", acc.coverAt(0, 0), 1.0);
            assertDoubleEq("area_at(acc, 1, 0)", acc.areaAt(1, 0), 0);
        });

        scenario("Walk: an edge entirely right of the buffer deposits nothing", () -> {
            Accumulator acc = new Accumulator(4, 3);
            Fill.accumulate(acc, Tuple.point(10, 3), Tuple.point(10, 0));
            assertDoubleEq("area_at(acc, 3, 0)", acc.areaAt(3, 0), 0);
            assertDoubleEq("cover_at(acc, 3, 0)", acc.coverAt(3, 0), 0);
        });
    }

    // features/chapter07-resolve.feature
    private static void registerResolve() {
        scenario("Resolve: apply_rule turns a winding number into coverage", () -> {
            assertDoubleEq("apply_rule(0, \"nonzero\")", Fill.applyRule(0, "nonzero"), 0);
            assertDoubleEq("apply_rule(1, \"nonzero\")", Fill.applyRule(1, "nonzero"), 1);
            assertDoubleEq("apply_rule(0.25, \"nonzero\")", Fill.applyRule(0.25, "nonzero"), 0.25);
            assertDoubleEq("apply_rule(-0.25, \"nonzero\")", Fill.applyRule(-0.25, "nonzero"), 0.25);
            assertDoubleEq("apply_rule(1.5, \"nonzero\")", Fill.applyRule(1.5, "nonzero"), 1);
            assertDoubleEq("apply_rule(2, \"nonzero\")", Fill.applyRule(2, "nonzero"), 1);
            assertDoubleEq("apply_rule(0.25, \"evenodd\")", Fill.applyRule(0.25, "evenodd"), 0.25);
            assertDoubleEq("apply_rule(0.75, \"evenodd\")", Fill.applyRule(0.75, "evenodd"), 0.75);
            assertDoubleEq("apply_rule(1.25, \"evenodd\")", Fill.applyRule(1.25, "evenodd"), 0.75);
            assertDoubleEq("apply_rule(1.5, \"evenodd\")", Fill.applyRule(1.5, "evenodd"), 0.5);
            assertDoubleEq("apply_rule(2, \"evenodd\")", Fill.applyRule(2, "evenodd"), 0);
            assertDoubleEq("apply_rule(3.25, \"evenodd\")", Fill.applyRule(3.25, "evenodd"), 0.75);
            assertDoubleEq("apply_rule(-1.5, \"evenodd\")", Fill.applyRule(-1.5, "evenodd"), 0.5);
        });

        scenario("Resolve: resolve turns one deposited edge into a half-covered column", () -> {
            Accumulator acc = new Accumulator(4, 3);
            Fill.accumulate(acc, Tuple.point(1.5, 3), Tuple.point(1.5, 0));
            CoverageBuffer cov = Fill.resolve(acc, "nonzero");
            assertDoubleEq("coverage_at(cov, 0, 0)", cov.coverageAt(0, 0), 0);
            assertDoubleEq("coverage_at(cov, 1, 0)", cov.coverageAt(1, 0), 0.5);
            assertDoubleEq("coverage_at(cov, 2, 0)", cov.coverageAt(2, 0), 1.0);
            assertDoubleEq("coverage_at(cov, 3, 0)", cov.coverageAt(3, 0), 1.0);
        });
    }

    // features/chapter07-fill.feature
    private static void registerFill() {
        scenario("Fill: a square whose edges sit on pixel centers", () -> {
            Path p = Paths.polygon(
                    Tuple.point(1.5, 1.5), Tuple.point(5.5, 1.5), Tuple.point(5.5, 5.5), Tuple.point(1.5, 5.5));
            CoverageBuffer cov = Fill.fillPath(p, "nonzero", 8, 8);
            assertDoubleEq("coverage_at(cov, 1, 1)", cov.coverageAt(1, 1), 0.25);
            assertDoubleEq("coverage_at(cov, 3, 1)", cov.coverageAt(3, 1), 0.5);
            assertDoubleEq("coverage_at(cov, 1, 3)", cov.coverageAt(1, 3), 0.5);
            assertDoubleEq("coverage_at(cov, 3, 3)", cov.coverageAt(3, 3), 1.0);
            assertDoubleEq("coverage_at(cov, 0, 0)", cov.coverageAt(0, 0), 0);
            assertDoubleEq("ink(cov)", cov.ink(), 16.0);
            assertDoubleEq("ink(cov) = polygon_area(p)", cov.ink(), Fill.polygonArea(p));
        });

        scenario("Fill: the ink of a filled polygon is its exact area", () -> {
            Path r = Paths.polygon(Tuple.point(1.5, 2), Tuple.point(4.75, 2), Tuple.point(4.75, 5), Tuple.point(1.5, 5));
            Path t = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(5, 10));
            CoverageBuffer cr = Fill.fillPath(r, "nonzero", 8, 8);
            CoverageBuffer ct = Fill.fillPath(t, "nonzero", 20, 20);
            assertDoubleEq("ink(cr)", cr.ink(), 9.75);
            assertDoubleEq("ink(cr) = polygon_area(r)", cr.ink(), Fill.polygonArea(r));
            assertDoubleEq("coverage_at(cr, 1, 3)", cr.coverageAt(1, 3), 0.5);
            assertDoubleEq("coverage_at(cr, 2, 3)", cr.coverageAt(2, 3), 1.0);
            assertDoubleEq("coverage_at(cr, 4, 3)", cr.coverageAt(4, 3), 0.75);
            assertDoubleEq("ink(ct)", ct.ink(), 50.0);
            assertDoubleEq("ink(ct) = polygon_area(t)", ct.ink(), Fill.polygonArea(t));
        });

        scenario("Fill: a polygon circle's ink is its exact area, where the supersampler misses", () -> {
            Path p = Paths.circlePath(10.3, 9.7, 7, 12);
            CoverageBuffer cov = Fill.fillPath(p, "nonzero", 20, 20);
            assertDoubleEq("ink(cov) = polygon_area(p)", cov.ink(), Fill.polygonArea(p));
            assertDoubleEq("ink(cov)", cov.ink(), 147.0, 0.0001);
        });

        scenario("Fill: a scaled shape's ink scales with its area", () -> {
            Path t = Paths.transformPath(
                    Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(5, 10)),
                    Transforms.scaling(2, 3));
            CoverageBuffer cov = Fill.fillPath(t, "nonzero", 40, 40);
            assertDoubleEq("ink(cov)", cov.ink(), 300.0);
            assertDoubleEq("ink(cov) = polygon_area(t)", cov.ink(), Fill.polygonArea(t));
        });

        scenario("Fill: on a grid-aligned shape the fill and the supersampler agree exactly", () -> {
            Path r = Paths.polygon(Tuple.point(1.5, 2), Tuple.point(4.75, 2), Tuple.point(4.75, 5), Tuple.point(1.5, 5));
            Path t = Paths.polygon(Tuple.point(0, 0), Tuple.point(10, 0), Tuple.point(5, 10));
            assertDoubleEq("max_coverage_difference(fill_path(r), rasterize(filled(r)))",
                    CoverageBuffer.maxCoverageDifference(
                            Fill.fillPath(r, "nonzero", 8, 8),
                            Rasterizer.rasterize(Paths.filled(r, "nonzero"), 8, 8)),
                    0);
            assertDoubleEq("max_coverage_difference(fill_path(t), rasterize(filled(t)))",
                    CoverageBuffer.maxCoverageDifference(
                            Fill.fillPath(t, "nonzero", 20, 20),
                            Rasterizer.rasterize(Paths.filled(t, "nonzero"), 20, 20)),
                    0);
        });

        scenario("Fill: the fill replaces chapter 6's, agreeing on solid pixels and improving the edge", () -> {
            Path r = Paths.polygon(Tuple.point(1.5, 2), Tuple.point(4.75, 2), Tuple.point(4.75, 5), Tuple.point(1.5, 5));
            CoverageBuffer exact = Fill.fillPath(r, "nonzero", 8, 8);
            CoverageBuffer aliased = Sweep.fillPathAliased(r, "nonzero", 8, 8);
            assertDoubleEq("coverage_at(exact, 2, 3)", exact.coverageAt(2, 3), 1.0);
            assertDoubleEq("coverage_at(aliased, 2, 3)", aliased.coverageAt(2, 3), 1.0);
            assertDoubleEq("coverage_at(exact, 6, 3)", exact.coverageAt(6, 3), 0);
            assertDoubleEq("coverage_at(aliased, 6, 3)", aliased.coverageAt(6, 3), 0);
            assertDoubleEq("coverage_at(exact, 4, 3)", exact.coverageAt(4, 3), 0.75);
            assertDoubleEq("coverage_at(aliased, 4, 3)", aliased.coverageAt(4, 3), 1.0);
        });

        scenario("Fill: a doubled square is solid under nonzero and a hole under even-odd", () -> {
            Path p = new Path();
            p.moveTo(Tuple.point(1.5, 1.5));
            p.lineTo(Tuple.point(5.5, 1.5));
            p.lineTo(Tuple.point(5.5, 5.5));
            p.lineTo(Tuple.point(1.5, 5.5));
            p.close();
            p.moveTo(Tuple.point(1.5, 1.5));
            p.lineTo(Tuple.point(5.5, 1.5));
            p.lineTo(Tuple.point(5.5, 5.5));
            p.lineTo(Tuple.point(1.5, 5.5));
            p.close();
            CoverageBuffer nz = Fill.fillPath(p, "nonzero", 8, 8);
            CoverageBuffer eo = Fill.fillPath(p, "evenodd", 8, 8);
            assertDoubleEq("coverage_at(nz, 3, 3)", nz.coverageAt(3, 3), 1.0);
            assertDoubleEq("coverage_at(eo, 3, 3)", eo.coverageAt(3, 3), 0);
        });

        scenario("Fill: the star, both rules, filled exactly", () -> {
            Path p = Figures.star();
            CoverageBuffer nz = Fill.fillPath(p, "nonzero", 160, 160);
            CoverageBuffer eo = Fill.fillPath(p, "evenodd", 160, 160);
            assertDoubleEq("coverage_at(nz, 80, 80)", nz.coverageAt(80, 80), 1.0);
            assertDoubleEq("coverage_at(eo, 80, 80)", eo.coverageAt(80, 80), 0);
            assertDoubleEq("ink(nz)", nz.ink(), 5500.7654, 0.01);
            assertDoubleEq("ink(eo)", eo.ink(), 3801.1615, 0.01);
            assertDoubleEq("coverage_at(nz, 44, 80)", nz.coverageAt(44, 80), 0.9456, 0.001);
            assertDoubleEq("coverage_at(nz, 43, 80)", nz.coverageAt(43, 80), 0.3556, 0.001);
        });

        scenario("Fill: a polygon larger than the buffer fills it solid", () -> {
            Path p = Paths.polygon(
                    Tuple.point(-5, -5), Tuple.point(30, -5), Tuple.point(30, 30), Tuple.point(-5, 30));
            CoverageBuffer cov = Fill.fillPath(p, "nonzero", 8, 8);
            assertDoubleEq("ink(cov)", cov.ink(), 64.0);
        });

        scenario("Fill: an empty path fills nothing", () -> {
            Path p = new Path();
            CoverageBuffer cov = Fill.fillPath(p, "nonzero", 8, 8);
            assertDoubleEq("ink(cov)", cov.ink(), 0);
        });
    }

    // features/chapter07-plate.feature
    private static void registerPlate() {
        scenario("Plate 7: the needles, aliased against exact", () -> {
            Canvas c = Figures.needles();
            byte[] ref = readReference("needles.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 480);
            assertEquals("c.height", c.height, 240);
            assertDoubleEq("ink(fill_path_aliased(needle_path()))",
                    Sweep.fillPathAliased(Figures.needlePath(), "nonzero", 60, 60).ink(), 268.0);
            assertDoubleEq("ink(fill_path(needle_path())) = polygon_area(needle_path())",
                    Fill.fillPath(Figures.needlePath(), "nonzero", 60, 60).ink(),
                    Fill.polygonArea(Figures.needlePath()));
            assertTriple("ppm_pixel(p6, 120, 120)", Ppm.ppmPixel(p6, 120, 120), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 360, 120)", Ppm.ppmPixel(p6, 360, 120), new int[] {94, 78, 51}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 7: the soft square", () -> {
            Canvas c = Figures.softSquare();
            byte[] ref = readReference("soft-square.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 192);
            assertEquals("c.height", c.height, 192);
            assertTriple("ppm_pixel(p6, 96, 96)", Ppm.ppmPixel(p6, 96, 96), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 36, 36)", Ppm.ppmPixel(p6, 36, 36), new int[] {134, 109, 59}, 1);
            assertTriple("ppm_pixel(p6, 12, 12)", Ppm.ppmPixel(p6, 12, 12), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 7: the star, exact, both rules", () -> {
            Canvas c = Figures.starExact();
            byte[] ref = readReference("star-exact.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 160);
            assertTriple("ppm_pixel(p6, 80, 80)", Ppm.ppmPixel(p6, 80, 80), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 240, 80)", Ppm.ppmPixel(p6, 240, 80), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 7: the spiral, smooth", () -> {
            Canvas c = Figures.spiralSmooth();
            byte[] ref = readReference("spiral-smooth.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 320);
            assertEquals("c.height", c.height, 320);
            assertTriple("ppm_pixel(p6, 180, 160)", Ppm.ppmPixel(p6, 180, 160), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 160, 160)", Ppm.ppmPixel(p6, 160, 160), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });

        scenario("Plate 7: plate 7", () -> {
            Canvas c = Figures.plate07();
            byte[] ref = readReference("plate-07.ppm");
            byte[] p6 = Ppm.canvasToP6(c);
            assertEquals("c.width", c.width, 480);
            assertEquals("c.height", c.height, 480);
            assertTriple("ppm_pixel(p6, 240, 60)", Ppm.ppmPixel(p6, 240, 60), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 440, 240)", Ppm.ppmPixel(p6, 440, 240), new int[] {243, 196, 89}, 1);
            assertTriple("ppm_pixel(p6, 439, 257)", Ppm.ppmPixel(p6, 439, 257), new int[] {124, 196, 237}, 1);
            assertTriple("ppm_pixel(p6, 436, 274)", Ppm.ppmPixel(p6, 436, 274), new int[] {237, 137, 149}, 1);
            assertTriple("ppm_pixel(p6, 229, 210)", Ppm.ppmPixel(p6, 229, 210), new int[] {246, 243, 234}, 1);
            assertTriple("ppm_pixel(p6, 240, 240)", Ppm.ppmPixel(p6, 240, 240), new int[] {39, 39, 44}, 1);
            assertTriple("ppm_pixel(p6, 20, 20)", Ppm.ppmPixel(p6, 20, 20), new int[] {39, 39, 44}, 1);
            assertTrue("max_channel_difference(p6, ref) <= 1", Ppm.maxChannelDifference(p6, ref) <= 1);
        });
    }

    private static byte[] readReference(String filename) throws IOException {
        return Files.readAllBytes(java.nio.file.Path.of("reference/chapter-07", filename));
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
        writeOne("needles.ppm", Figures.needles());
        writeOne("soft-square.ppm", Figures.softSquare());
        writeOne("star-exact.ppm", Figures.starExact());
        writeOne("spiral-smooth.ppm", Figures.spiralSmooth());
        writeOne("plate-07.ppm", Figures.plate07());
    }

    private static void writeOne(String filename, Canvas c) throws IOException {
        Files.write(java.nio.file.Path.of("out", filename), Ppm.canvasToP6(c));
    }
}
