import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * §24.3: sampling instead of area. sample_pattern(n) is n sample points
 * inside the unit pixel: for 1, (0.5, 0.5); for 4, a rotated grid; for 16,
 * sixteen rooks with no two on a row or a column; for 64, chapter 2's 8 by
 * 8 grid. msaa_coverage(p, rule, width, height, n) is, at every pixel, the
 * number of samples whose stencil (stencil_buffer with that sample's ox,
 * oy) fills under the rule, divided by n. sliver() is a thin polygon whose
 * top edge climbs one pixel in forty.
 */
public final class Msaa {
    private Msaa() {}

    private static final Map<Integer, List<Tuple>> PATTERNS = buildPatterns();

    private static Map<Integer, List<Tuple>> buildPatterns() {
        Map<Integer, List<Tuple>> m = new java.util.HashMap<>();
        m.put(1, List.of(Tuple.point(0.5, 0.5)));
        m.put(4, List.of(
                Tuple.point(0.375, 0.125), Tuple.point(0.875, 0.375),
                Tuple.point(0.125, 0.625), Tuple.point(0.625, 0.875)));
        List<Tuple> p16 = new ArrayList<>();
        for (int k = 0; k < 16; k++) {
            p16.add(Tuple.point((k + 0.5) / 16.0, (((5 * k + 3) % 16) + 0.5) / 16.0));
        }
        m.put(16, p16);
        List<Tuple> p64 = new ArrayList<>();
        for (int j = 0; j < 8; j++) {
            for (int i = 0; i < 8; i++) {
                p64.add(Tuple.point((i + 0.5) / 8.0, (j + 0.5) / 8.0));
            }
        }
        m.put(64, p64);
        return m;
    }

    public static List<Tuple> samplePattern(int n) {
        return PATTERNS.get(n);
    }

    public static CoverageBuffer msaaCoverage(Path p, String rule, int width, int height, int n) {
        double[] cov = new double[width * height];
        for (Tuple o : samplePattern(n)) {
            Stencil s = Stencils.stencilBuffer(p, width, height, o.x, o.y);
            for (int i = 0; i < width * height; i++) {
                if (Fill.applyRule(s.values[i], rule) == 1.0) {
                    cov[i]++;
                }
            }
        }
        CoverageBuffer out = new CoverageBuffer(width, height);
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                out.setCoverage(x, y, cov[y * width + x] / n);
            }
        }
        return out;
    }

    public static Path sliver() {
        return Paths.polygon(
                Tuple.point(2, 10.3), Tuple.point(78, 12.2), Tuple.point(78, 30), Tuple.point(2, 30));
    }
}
