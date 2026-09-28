import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * §24.9: plate_24, msaa_demo, spill_map and tiger_assembly, exactly as
 * chapter24-plate.feature's own prose spells them out.
 */
public final class Chapter24Figures {
    private Chapter24Figures() {}

    private static final Color PAPER = new Color(0.02, 0.02, 0.025);
    private static final Color ORANGE = new Color(0.9, 0.55, 0.1);
    private static final Color CYAN = new Color(0.2, 0.75, 0.9);
    private static final Color MAGENTA = new Color(0.85, 0.2, 0.55);

    private static String readTextFile(String path) {
        try {
            return new String(
                    java.nio.file.Files.readAllBytes(java.nio.file.Path.of(path)),
                    java.nio.charset.StandardCharsets.UTF_8);
        } catch (java.io.IOException e) {
            throw new RuntimeException(e);
        }
    }

    /** centred_star() is chapter 5's star moved by (19.5, 19.5). */
    public static Path centredStar() {
        return Paths.transformPath(Figures.star(), Transforms.translation(19.5, 19.5));
    }

    private static Color windingColor(int w) {
        if (w == 0) {
            return PAPER;
        }
        if (w < 0) {
            return Mixer.mix(PAPER, CYAN, 0.6);
        }
        return Mixer.mix(PAPER, ORANGE, w == 1 ? 0.45 : 0.9);
    }

    public static Canvas plate24() {
        Canvas c = new Canvas(400, 200);
        Stencil s = Stencils.stencilBuffer(centredStar(), 200, 200);
        for (int y = 0; y < 200; y++) {
            for (int x = 0; x < 200; x++) {
                c.writePixel(x, y, windingColor(s.values[y * 200 + x]));
            }
        }

        Font font = Figures.robotoFont();
        Matrix m = Glyphs.textMatrix(font, 700, -120, 420);
        List<Curve> cs = LoopBlinn.glyphCurves(font, "g", m);
        Tuple anchor = cs.get(0).points().get(0);
        Stencil lb = LoopBlinn.loopBlinnStencil(cs, anchor, 200, 200);
        Stencil tm = LoopBlinn.curveTerms(cs, 200, 200);
        for (int y = 0; y < 200; y++) {
            for (int x = 0; x < 200; x++) {
                int i = y * 200 + x;
                Color col = PAPER;
                if (tm.values[i] > 0) {
                    col = Mixer.mix(col, CYAN, 0.55);
                } else if (tm.values[i] < 0) {
                    col = Mixer.mix(col, MAGENTA, 0.55);
                }
                if (lb.values[i] != 0) {
                    col = Mixer.mix(col, ORANGE, 0.6);
                }
                c.writePixel(200 + x, y, col);
            }
        }
        return c;
    }

    public static Canvas msaaDemo() {
        Path sliver = Msaa.sliver();
        CoverageBuffer[] strips = new CoverageBuffer[] {
            Msaa.msaaCoverage(sliver, "nonzero", 80, 40, 1),
            Msaa.msaaCoverage(sliver, "nonzero", 80, 40, 4),
            Msaa.msaaCoverage(sliver, "nonzero", 80, 40, 16),
            Msaa.msaaCoverage(sliver, "nonzero", 80, 40, 64),
            Fill.fillPath(sliver, "nonzero", 80, 40),
        };
        Canvas out = new Canvas(192, 480);
        for (int r = 0; r < strips.length; r++) {
            Canvas small = new Canvas(24, 12);
            for (int y = 0; y < 12; y++) {
                for (int x = 0; x < 24; x++) {
                    double k = strips[r].coverageAt(x + 30, y + 4);
                    small.writePixel(x, y, k > 0 ? Mixer.mix(PAPER, ORANGE, k) : PAPER);
                }
            }
            Canvas mag = Magnify.magnify(small, 8);
            for (int y = 0; y < 96; y++) {
                for (int x = 0; x < 192; x++) {
                    out.writePixel(x, r * 96 + y, mag.pixelAt(x, y));
                }
            }
        }
        return out;
    }

    public static Canvas spillMap() {
        String roseSvg = readTextFile("reference/chapter-20/rose.svg");
        Scene sc = new Scene(Encoder.encodeSvg(roseSvg, 400, 400), 400, 400);
        Map<Pipeline.TileKey, List<TileCommand>> lists = Pipeline.pipelineLists(sc);
        Layer l = new Layer(400, 400);
        Map<Pipeline.TileKey, Integer> spills = new HashMap<>();
        int most = 0;
        for (int ty = 0; ty < sc.rows; ty++) {
            for (int tx = 0; tx < sc.cols; tx++) {
                FineStats fs = new FineStats();
                Pipeline.TileKey key = new Pipeline.TileKey(tx, ty);
                Pipeline.TileBlock b = Pipeline.fineTile(sc, lists.getOrDefault(key, List.of()), tx, ty, fs);
                Pipeline.putBlock(l, b);
                spills.put(key, fs.spills);
                most = Math.max(most, fs.spills);
            }
        }
        Canvas rose = Layers.flattenLayer(l, new Color(1, 1, 1));
        Canvas out = new Canvas(810, 400);
        out.fill(PAPER);
        for (int y = 0; y < 400; y++) {
            for (int x = 0; x < 400; x++) {
                out.writePixel(x, y, rose.pixelAt(x, y));
                int u = x % Tiles.TILE;
                int v = y % Tiles.TILE;
                int n = spills.getOrDefault(new Pipeline.TileKey(x / Tiles.TILE, y / Tiles.TILE), 0);
                if (u == 0 || v == 0 || u == Tiles.TILE - 1 || v == Tiles.TILE - 1 || n == 0) {
                    continue;
                }
                out.writePixel(410 + x, y, Mixer.mix(PAPER, MAGENTA, 0.2 + 0.8 * n / (double) most));
            }
        }
        return out;
    }

    public static Canvas tigerAssembly() {
        String tigerSvg = readTextFile("reference/chapter-20/tiger.svg");
        Scene sc = new Scene(Encoder.encodeSvg(tigerSvg, 450, 450), 450, 450);
        Map<Pipeline.TileKey, List<TileCommand>> lists = Pipeline.pipelineLists(sc);
        List<Pipeline.TileKey> tiles = new ArrayList<>();
        for (int ty = 0; ty < sc.rows; ty++) {
            for (int tx = 0; tx < sc.cols; tx++) {
                tiles.add(new Pipeline.TileKey(tx, ty));
            }
        }
        int[] perm = Lcg.lcgShuffle(tiles.size(), 2024);
        List<Pipeline.TileKey> order = new ArrayList<>();
        for (int idx : perm) {
            order.add(tiles.get(idx));
        }
        FineStats fs = new FineStats();
        Layer l = new Layer(450, 450);
        Set<Pipeline.TileKey> done = new HashSet<>();
        Canvas out = new Canvas(900, 900);
        out.fill(PAPER);
        int[] stops = {210, 420, 630, 841};
        int k = 0;
        for (int panel = 0; panel < 4; panel++) {
            int stop = stops[panel];
            while (k < stop) {
                Pipeline.TileKey t = order.get(k++);
                Pipeline.TileBlock b = Pipeline.fineTile(sc, lists.getOrDefault(t, List.of()), t.tx(), t.ty(), fs);
                Pipeline.putBlock(l, b);
                done.add(t);
            }
            Canvas c = Layers.flattenLayer(l, new Color(1, 1, 1));
            int ox = (panel % 2) * 450;
            int oy = (panel / 2) * 450;
            for (int y = 0; y < 450; y++) {
                for (int x = 0; x < 450; x++) {
                    if (done.contains(new Pipeline.TileKey(x / Tiles.TILE, y / Tiles.TILE))) {
                        out.writePixel(x + ox, y + oy, c.pixelAt(x, y));
                    }
                }
            }
        }
        return out;
    }
}
