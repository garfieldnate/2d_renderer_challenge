import java.util.ArrayList;
import java.util.List;

/**
 * §23.7: glyph atlases. bake_sdf bakes chapter 17's bitmap box into a field;
 * bake_msdf colours each edge of the outline so a corner survives bilinear
 * sampling, by Chlumsky's multi-channel signed distance field; bake_mtsdf
 * adds bake_sdf's field as a fourth, ordinary channel.
 */
public final class Msdf {
    private Msdf() {}

    public static final int RED = 1;
    public static final int GREEN = 2;
    public static final int BLUE = 4;
    public static final int CYAN = 6;
    public static final int MAGENTA = 5;
    public static final int YELLOW = 3;
    public static final int WHITE = 7;

    private static final double TIE_EPS = 1e-12;

    // ---- the box ---------------------------------------------------------

    public record Box(int left, int top, int width, int height, Matrix matrix) {}

    public static Box bakeBox(Font font, String name, double size, double spread) {
        double s = size / font.unitsPerEm;
        Bounds b = Glyphs.glyphBounds(font, name);
        int left = (int) Math.floor(b.minX() * s) - (int) spread;
        int right = (int) Math.ceil(b.maxX() * s) + (int) spread;
        int top = (int) Math.floor(-b.maxY() * s) - (int) spread;
        int bottom = (int) Math.ceil(-b.minY() * s) + (int) spread;
        Matrix m = Glyphs.textMatrix(font, size, -left, -top);
        return new Box(left, top, right - left, bottom - top, m);
    }

    public static Baked bakeSdf(Font font, String name, double size, double spread) {
        Box box = bakeBox(font, name, size, spread);
        List<List<Curve>> outline = Glyphs.glyphOutline(font, name);
        List<Curve> device = new ArrayList<>();
        for (List<Curve> contour : outline) {
            for (Curve c : contour) {
                device.add(Curves.transformCurve(c, box.matrix()));
            }
        }
        Path glyphPath = Glyphs.glyphPath(font, name, box.matrix(), 0.01);
        Field f = Field.field(box.width(), box.height(), (x, y) -> {
            Tuple p = Tuple.point(x, y);
            double best = Double.POSITIVE_INFINITY;
            for (Curve c : device) {
                best = Math.min(best, CurveDistance.distanceToQuadratic(p, c));
            }
            boolean inside = Winding.insideNonzero(glyphPath, x, y);
            double d = inside ? -best : best;
            return Math.max(-spread, Math.min(spread, d));
        });
        return new Baked(box.left(), box.top(), box.width(), box.height(), new Field[] {f});
    }

    // ---- colouring the edges ------------------------------------------------

    public static boolean isCorner(Tuple a, Tuple b) {
        return Tuple.dot(a, b) <= 0 || Math.abs(Tuple.cross(a, b)) > Math.sin(3);
    }

    private static Tuple dirAt(Curve c, double t) {
        Tuple d = Curves.derivative(c, t);
        if (d.magnitude() < 1e-12) {
            List<Tuple> pts = c.points();
            d = pts.get(pts.size() - 1).subtract(pts.get(0));
        }
        return d.normalize();
    }

    public record ColoredEdges(List<Curve> curves, List<Integer> masks) {}

    public static ColoredEdges colorEdges(List<Curve> contour) {
        int n = contour.size();
        Tuple[] startDir = new Tuple[n];
        Tuple[] endDir = new Tuple[n];
        for (int i = 0; i < n; i++) {
            startDir[i] = dirAt(contour.get(i), 0);
            endDir[i] = dirAt(contour.get(i), 1);
        }
        List<Integer> corners = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            Tuple prevEnd = endDir[(i - 1 + n) % n];
            if (isCorner(prevEnd, startDir[i])) {
                corners.add(i);
            }
        }
        if (corners.isEmpty()) {
            List<Integer> masks = new ArrayList<>();
            for (int i = 0; i < n; i++) {
                masks.add(WHITE);
            }
            return new ColoredEdges(contour, masks);
        }

        int first = corners.get(0);
        List<Curve> rotated = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            rotated.add(contour.get((first + i) % n));
        }
        List<Integer> rotatedCorners = new ArrayList<>();
        for (int idx : corners) {
            rotatedCorners.add(((idx - first) % n + n) % n);
        }
        rotatedCorners.sort(Integer::compare);

        if (rotatedCorners.size() == 1) {
            while (rotated.size() < 3) {
                List<Curve> next = new ArrayList<>();
                for (Curve c : rotated) {
                    Curve[] halves = Curves.splitAt(c, 0.5);
                    next.add(halves[0]);
                    next.add(halves[1]);
                }
                rotated = next;
            }
            int m = rotated.size();
            List<Integer> masks = new ArrayList<>();
            for (int j = 0; j < m; j++) {
                int third = (3 * j) / m;
                masks.add(third == 0 ? CYAN : third == 1 ? WHITE : MAGENTA);
            }
            return new ColoredEdges(rotated, masks);
        }

        int numRuns = rotatedCorners.size();
        Integer[] masksArr = new Integer[rotated.size()];
        for (int r = 0; r < numRuns; r++) {
            int startIdx = rotatedCorners.get(r);
            int endIdx = (r + 1 < numRuns) ? rotatedCorners.get(r + 1) : rotated.size();
            int color = (r % 2 == 0) ? CYAN : MAGENTA;
            if (r == numRuns - 1 && numRuns % 2 == 1) {
                color = YELLOW;
            }
            for (int k = startIdx; k < endIdx; k++) {
                masksArr[k] = color;
            }
        }
        List<Integer> masks = new ArrayList<>();
        for (Integer m : masksArr) {
            masks.add(m);
        }
        return new ColoredEdges(rotated, masks);
    }

    // ---- pseudo-distance and the multi-channel texel -------------------------

    public static double pseudoDistance(Tuple p, Curve c, double t, double d) {
        List<Tuple> pts = c.points();
        Tuple start = pts.get(0);
        Tuple end = pts.get(pts.size() - 1);
        Tuple startDir = dirAt(c, 0);
        Tuple endDir = dirAt(c, 1);
        if (t == 0 && Tuple.dot(p.subtract(start), startDir) < 0) {
            double side = Tuple.cross(startDir, p.subtract(start));
            return side > 0 ? -Math.abs(side) : Math.abs(side);
        }
        if (t == 1 && Tuple.dot(p.subtract(end), endDir) > 0) {
            double side = Tuple.cross(endDir, p.subtract(end));
            return side > 0 ? -Math.abs(side) : Math.abs(side);
        }
        Tuple dir = dirAt(c, t);
        double side = Tuple.cross(dir, p.subtract(Curves.pointAt(c, t)));
        return side > 0 ? -d : d;
    }

    private record Best(Curve curve, double t, double d, double o) {}

    private static double msdfChannel(Tuple p, List<Curve> curves, List<Integer> masks, int channel) {
        Best best = null;
        for (int i = 0; i < curves.size(); i++) {
            if ((masks.get(i) & channel) == 0) {
                continue;
            }
            Curve c = curves.get(i);
            double t = CurveDistance.nearestTQuadratic(p, c);
            double d = Curves.pointAt(c, t).subtract(p).magnitude();
            double o = 0;
            if (t == 0 || t == 1) {
                Tuple dir = dirAt(c, t);
                Tuple toP = p.subtract(Curves.pointAt(c, t));
                double mag = toP.magnitude();
                Tuple unit = mag == 0 ? Tuple.vector(0, 0) : toP.divide(mag);
                o = Math.abs(Tuple.dot(dir, unit));
            }
            if (best == null || d < best.d() - TIE_EPS
                    || (Math.abs(d - best.d()) <= TIE_EPS && o < best.o())) {
                best = new Best(c, t, d, o);
            }
        }
        if (best == null) {
            return 0;
        }
        return pseudoDistance(p, best.curve(), best.t(), best.d());
    }

    public static Baked bakeMsdf(Font font, String name, double size, double spread) {
        Box box = bakeBox(font, name, size, spread);
        List<List<Curve>> outline = Glyphs.glyphOutline(font, name);
        List<Curve> allCurves = new ArrayList<>();
        List<Integer> allMasks = new ArrayList<>();
        for (List<Curve> contour : outline) {
            List<Curve> device = new ArrayList<>();
            for (Curve c : contour) {
                device.add(Curves.transformCurve(c, box.matrix()));
            }
            if (device.isEmpty()) {
                continue;
            }
            ColoredEdges colored = colorEdges(device);
            allCurves.addAll(colored.curves());
            allMasks.addAll(colored.masks());
        }
        Field r = Field.field(box.width(), box.height(),
                (x, y) -> clampSpread(msdfChannel(Tuple.point(x, y), allCurves, allMasks, RED), spread));
        Field g = Field.field(box.width(), box.height(),
                (x, y) -> clampSpread(msdfChannel(Tuple.point(x, y), allCurves, allMasks, GREEN), spread));
        Field b = Field.field(box.width(), box.height(),
                (x, y) -> clampSpread(msdfChannel(Tuple.point(x, y), allCurves, allMasks, BLUE), spread));
        return new Baked(box.left(), box.top(), box.width(), box.height(), new Field[] {r, g, b});
    }

    public static Baked bakeMtsdf(Font font, String name, double size, double spread) {
        Baked msdf = bakeMsdf(font, name, size, spread);
        Baked sdf = bakeSdf(font, name, size, spread);
        return new Baked(msdf.left, msdf.top, msdf.width, msdf.height,
                new Field[] {msdf.channels[0], msdf.channels[1], msdf.channels[2], sdf.channels[0]});
    }

    private static double clampSpread(double d, double spread) {
        return Math.max(-spread, Math.min(spread, d));
    }

    // ---- helper curves for scenarios and figures ------------------------------

    public static Curve lineCurve(Tuple a, Tuple b) {
        return Curve.quadratic(a, a.add(b).divide(2), b);
    }

    public static List<Curve> circleCurves(double cx, double cy, double r) {
        List<Curve> out = new ArrayList<>();
        double cr = r / Math.cos(Math.PI / 8);
        Tuple[] ends = new Tuple[8];
        for (int i = 0; i < 8; i++) {
            double a = 2 * Math.PI * i / 8;
            ends[i] = Tuple.point(cx + r * Math.cos(a), cy + r * Math.sin(a));
        }
        for (int i = 0; i < 8; i++) {
            double a = 2 * Math.PI * i / 8 + Math.PI / 8;
            Tuple control = Tuple.point(cx + cr * Math.cos(a), cy + cr * Math.sin(a));
            out.add(Curve.quadratic(ends[i], control, ends[(i + 1) % 8]));
        }
        return out;
    }

    // ---- sampling and drawing --------------------------------------------------

    public static double sampleField(Field f, double sx, double sy) {
        double gx = sx - 0.5, gy = sy - 0.5;
        int x0 = (int) Math.floor(gx), y0 = (int) Math.floor(gy);
        double fx = gx - x0, fy = gy - y0;
        double v00 = texelClamped(f, x0, y0), v10 = texelClamped(f, x0 + 1, y0);
        double v01 = texelClamped(f, x0, y0 + 1), v11 = texelClamped(f, x0 + 1, y0 + 1);
        double top = v00 + (v10 - v00) * fx;
        double bot = v01 + (v11 - v01) * fx;
        return top + (bot - top) * fy;
    }

    private static double texelClamped(Field f, int x, int y) {
        int cx = Math.max(0, Math.min(f.width - 1, x));
        int cy = Math.max(0, Math.min(f.height - 1, y));
        return Field.fieldAt(f, cx, cy);
    }

    public static double median3(double a, double b, double c) {
        return Math.max(Math.min(a, b), Math.min(Math.max(a, b), c));
    }

    private static double medianDistance(Baked baked, double u, double v) {
        if (baked.channels.length == 1) {
            return sampleField(baked.channels[0], u, v);
        }
        double a = sampleField(baked.channels[0], u, v);
        double b = sampleField(baked.channels[1], u, v);
        double c = sampleField(baked.channels[2], u, v);
        return median3(a, b, c);
    }

    public static void drawBaked(Canvas canvas, Baked baked, double scale, double x, double y, Color col) {
        int x0 = (int) Math.floor(x + baked.left * scale);
        int y0 = (int) Math.floor(y + baked.top * scale);
        int x1 = (int) Math.ceil(x + (baked.left + baked.width) * scale);
        int y1 = (int) Math.ceil(y + (baked.top + baked.height) * scale);
        for (int py = y0; py < y1; py++) {
            for (int px = x0; px < x1; px++) {
                double u = (px + 0.5 - x) / scale - baked.left;
                double v = (py + 0.5 - y) / scale - baked.top;
                double distance = medianDistance(baked, u, v);
                double k = Math.max(0, Math.min(1, 0.5 - scale * distance));
                if (k > 0 && px >= 0 && px < canvas.width && py >= 0 && py < canvas.height) {
                    canvas.writePixel(px, py, Mixer.mix(canvas.pixelAt(px, py), col, k, true));
                }
            }
        }
    }

    public interface KOf {
        double apply(double distancePixels);
    }

    /** §23.9: draw_effect -- draw_baked with the distance read from the true channel or the median, and a custom mix. */
    public static void drawEffect(Canvas canvas, Baked baked, double scale, double x, double y, Color col,
            boolean useTrue, KOf kOf) {
        int x0 = (int) Math.floor(x + baked.left * scale);
        int y0 = (int) Math.floor(y + baked.top * scale);
        int x1 = (int) Math.ceil(x + (baked.left + baked.width) * scale);
        int y1 = (int) Math.ceil(y + (baked.top + baked.height) * scale);
        for (int py = y0; py < y1; py++) {
            for (int px = x0; px < x1; px++) {
                if (px < 0 || px >= canvas.width || py < 0 || py >= canvas.height) {
                    continue;
                }
                double u = (px + 0.5 - x) / scale - baked.left;
                double v = (py + 0.5 - y) / scale - baked.top;
                double distanceTexels = useTrue ? sampleField(baked.channels[3], u, v) : medianDistance(baked, u, v);
                double distancePixels = scale * distanceTexels;
                double k = Math.max(0, Math.min(1, kOf.apply(distancePixels)));
                if (k > 0) {
                    canvas.writePixel(px, py, Mixer.mix(canvas.pixelAt(px, py), col, k, true));
                }
            }
        }
    }
}
