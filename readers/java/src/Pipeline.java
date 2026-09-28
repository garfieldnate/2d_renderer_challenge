import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * §24.5: the compute pipeline. Chapter 21's tiler taken apart into stages
 * that each read one array and write another, sharing nothing: flatten
 * (every draw's edges as segments), bin (every segment's chapter 7
 * deposits, filed by tile), coarse (every tile's own command list), and
 * fine (every tile's list run into its own block, with a small stack of
 * blocks for groups). run_pipeline runs all four, the fine stage over
 * every tile in raster or shuffled order, and answers the canvas.
 */
public final class Pipeline {
    private Pipeline() {}

    public static final int STACK_DEPTH = 2;

    public interface DepositSink {
        void deposit(int x, int row, double area, double cover);
    }

    public record Segment(int draw, Tuple a, Tuple b) {}

    public record Deposit(int draw, int x, int row, double area, double cover) {}

    public record TileKey(int tx, int ty) {}

    public record TileBlock(double[] block, int x0, int y0, int tw, int th) {}

    /**
     * §21.2's deposits, computed without ever writing into an accumulator:
     * one call to the sink per (row, cell) piece an edge leaves behind,
     * including the pieces left and right of the buffer that chapter 7's
     * Accumulator would fold or drop -- that's the caller's job here, so a
     * pipeline stage can file each one under the tile it belongs to.
     */
    public static void depositsOf(Tuple a, Tuple b, int height, DepositSink sink) {
        if (a.y == b.y) {
            return;
        }
        int sign = a.y > b.y ? 1 : -1;
        Tuple top = a.y > b.y ? b : a;
        Tuple bot = a.y > b.y ? a : b;
        double slope = (bot.x - top.x) / (bot.y - top.y);
        int first = Math.max((int) Math.floor(top.y), 0);
        int last = Math.min((int) Math.ceil(bot.y) - 1, height - 1);
        for (int row = first; row <= last; row++) {
            double ya = Math.max(top.y, row);
            double yb = Math.min(bot.y, row + 1);
            double xa0 = top.x + (ya - top.y) * slope;
            double xb0 = top.x + (yb - top.y) * slope;
            double hg = sign * (yb - ya);
            double xa = Math.min(xa0, xb0);
            double xb = Math.max(xa0, xb0);
            int ca = (int) Math.floor(xa);
            int cb = (int) Math.floor(xb);
            if (ca == cb) {
                double xm = (xa + xb) / 2 - ca;
                sink.deposit(ca, row, hg * (1 - xm), hg);
            } else {
                double dx = xb - xa;
                for (int c = ca; c <= cb; c++) {
                    double lo = Math.max(xa, c);
                    double hi = Math.min(xb, c + 1);
                    double sh = hg * (hi - lo) / dx;
                    double mm = (lo + hi) / 2 - c;
                    sink.deposit(c, row, sh * (1 - mm), sh);
                }
            }
        }
    }

    public static List<Segment> flattenStage(Scene sc) {
        List<Segment> out = new ArrayList<>();
        for (int d = 0; d < sc.draws.size(); d++) {
            for (Edge e : sc.draws.get(d).path().edges()) {
                out.add(new Segment(d, e.a(), e.b()));
            }
        }
        return out;
    }

    public static Map<TileKey, List<Deposit>> binStage(Scene sc, List<Segment> segs) {
        Map<TileKey, List<Deposit>> bins = new HashMap<>();
        int w = sc.width;
        for (Segment sg : segs) {
            depositsOf(sg.a(), sg.b(), sc.height, (x, row, ar, co) -> {
                int xx = x;
                double aa = ar;
                if (xx < 0) {
                    xx = 0;
                    aa = co;
                }
                if (xx >= w) {
                    return;
                }
                TileKey key = new TileKey(xx / Tiles.TILE, row / Tiles.TILE);
                bins.computeIfAbsent(key, k -> new ArrayList<>()).add(new Deposit(sg.draw(), xx, row, aa, co));
            });
        }
        return bins;
    }

    public static Map<TileKey, List<TileCommand>> coarseStage(Scene sc, Map<TileKey, List<Deposit>> bins) {
        int w = sc.width;
        int h = sc.height;
        int tile = Tiles.TILE;
        int numDraws = sc.draws.size();

        List<Map<Integer, double[]>> totals = new ArrayList<>();
        for (int i = 0; i < numDraws; i++) {
            totals.add(new HashMap<>());
        }
        for (List<Deposit> deps : bins.values()) {
            for (Deposit dp : deps) {
                Map<Integer, double[]> m = totals.get(dp.draw());
                int key = dp.row() * w + dp.x();
                double[] c = m.get(key);
                if (c != null) {
                    c[0] += dp.area();
                    c[1] += dp.cover();
                } else {
                    m.put(key, new double[] {dp.area(), dp.cover()});
                }
            }
        }

        List<BoundedFill.IntBounds> windows = new ArrayList<>();
        for (Draw dr : sc.draws) {
            windows.add(BoundedFill.fillBounds(dr.path(), w, h));
        }

        List<Map<Integer, int[]>> rowsOf = new ArrayList<>();
        for (int d = 0; d < numDraws; d++) {
            Map<Integer, List<Integer>> byRow = new HashMap<>();
            for (int key : totals.get(d).keySet()) {
                int x = key % w;
                int row = (key - x) / w;
                byRow.computeIfAbsent(row, k -> new ArrayList<>()).add(x);
            }
            Map<Integer, int[]> sorted = new HashMap<>();
            for (Map.Entry<Integer, List<Integer>> e : byRow.entrySet()) {
                List<Integer> xs = e.getValue();
                java.util.Collections.sort(xs);
                int[] arr = new int[xs.size()];
                for (int i = 0; i < xs.size(); i++) {
                    arr[i] = xs.get(i);
                }
                sorted.put(e.getKey(), arr);
            }
            rowsOf.add(sorted);
        }

        Map<TileKey, List<TileCommand>> lists = new HashMap<>();
        for (int ty = 0; ty < sc.rows; ty++) {
            for (int tx = 0; tx < sc.cols; tx++) {
                Map<Integer, TileDraw> cache = new HashMap<>();
                List<TileCommand> cm = new ArrayList<>();
                for (Op op : sc.commands) {
                    if (op instanceof FillOp f) {
                        TileDraw td = tileDrawFor(f.draw(), tx, ty, w, h, tile, sc, windows, totals, rowsOf, cache);
                        if (td.kind() == TileDraw.Kind.EMPTY) {
                            continue;
                        }
                        List<ClipEntry> clipEntries = clipEntriesOf(f.clip(), tx, ty, w, h, tile, sc, windows,
                                totals, rowsOf, cache);
                        cm.add(new TileFill(td, sc.draws.get(f.draw()).rule(), f.paint(), f.alpha(), clipEntries));
                    } else if (op instanceof PushOp p) {
                        List<ClipEntry> clipEntries = clipEntriesOf(p.clip(), tx, ty, w, h, tile, sc, windows,
                                totals, rowsOf, cache);
                        cm.add(new TilePush(p.opacity(), clipEntries));
                    } else {
                        cm.add(new TilePop());
                    }
                }
                lists.put(new TileKey(tx, ty), CullOp.cullGroups(cm));
            }
        }
        return lists;
    }

    private static List<ClipEntry> clipEntriesOf(List<Integer> clip, int tx, int ty, int w, int h, int tile,
            Scene sc, List<BoundedFill.IntBounds> windows, List<Map<Integer, double[]>> totals,
            List<Map<Integer, int[]>> rowsOf, Map<Integer, TileDraw> cache) {
        if (clip == null) {
            return null;
        }
        List<ClipEntry> out = new ArrayList<>();
        for (int c : clip) {
            TileDraw ctd = tileDrawFor(c, tx, ty, w, h, tile, sc, windows, totals, rowsOf, cache);
            out.add(new ClipEntry(ctd, sc.draws.get(c).rule()));
        }
        return out;
    }

    private static TileDraw tileDrawFor(int d, int tx, int ty, int w, int h, int tile, Scene sc,
            List<BoundedFill.IntBounds> windows, List<Map<Integer, double[]>> totals,
            List<Map<Integer, int[]>> rowsOf, Map<Integer, TileDraw> cache) {
        TileDraw cached = cache.get(d);
        if (cached != null) {
            return cached;
        }
        BoundedFill.IntBounds bb = windows.get(d);
        TileDraw td;
        boolean inWindow = !bb.equals(BoundedFill.IntBounds.EMPTY)
                && Math.floorDiv(bb.x0(), tile) <= tx && tx <= Math.floorDiv(bb.x1() - 1, tile)
                && Math.floorDiv(bb.y0(), tile) <= ty && ty <= Math.floorDiv(bb.y1() - 1, tile);
        if (!inWindow) {
            td = TileDraw.EMPTY_TD;
        } else {
            String rule = sc.draws.get(d).rule();
            Map<Integer, double[]> cells = totals.get(d);
            Map<Integer, int[]> rows = rowsOf.get(d);
            int r1 = Math.min(h, (ty + 1) * tile);
            double[] arr = new double[r1 - ty * tile];
            Map<Integer, double[]> mine = new HashMap<>();
            boolean touched = false;
            int rowIdx = 0;
            for (int row = ty * tile; row < r1; row++, rowIdx++) {
                int[] xs = rows.getOrDefault(row, new int[0]);
                double run = 0;
                int k = 0;
                while (k < xs.length && xs[k] < tx * tile) {
                    run += cells.get(row * w + xs[k])[1];
                    k++;
                }
                arr[rowIdx] = run;
                while (k < xs.length && xs[k] < (tx + 1) * tile) {
                    int key = row * w + xs[k];
                    double[] v = cells.get(key);
                    mine.put(key, v);
                    if (v[0] != 0 || v[1] != 0) {
                        touched = true;
                    }
                    k++;
                }
            }
            if (touched) {
                td = new TileDraw(TileDraw.Kind.PARTIAL, arr, mine);
            } else {
                double n = Math.round(arr[0]);
                boolean mixed = false;
                for (double a : arr) {
                    if (Math.abs(a - n) > 0.000001) {
                        mixed = true;
                        break;
                    }
                }
                if (mixed) {
                    td = new TileDraw(TileDraw.Kind.PARTIAL, arr, mine);
                } else {
                    td = Fill.applyRule(n, rule) == 1.0 ? TileDraw.solid() : TileDraw.EMPTY_TD;
                }
            }
        }
        cache.put(d, td);
        return td;
    }

    public static double[] resolveTile(TileDraw td, String rule, int tx, int ty, int w, int h) {
        int x0 = tx * Tiles.TILE;
        int y0 = ty * Tiles.TILE;
        int x1 = Math.min(w, x0 + Tiles.TILE);
        int y1 = Math.min(h, y0 + Tiles.TILE);
        int tw = x1 - x0;
        int th = y1 - y0;
        double[] out = new double[tw * th];
        if (td.kind() == TileDraw.Kind.SOLID) {
            Arrays.fill(out, 1.0);
            return out;
        }
        if (td.kind() == TileDraw.Kind.EMPTY) {
            return out;
        }
        for (int j = 0; j < th; j++) {
            double run = td.arriving()[j];
            for (int x = x0; x < x1; x++) {
                double[] c = td.cells().get((y0 + j) * w + x);
                double ar = c != null ? c[0] : 0;
                double co = c != null ? c[1] : 0;
                out[j * tw + x - x0] = Fill.applyRule(run + ar, rule);
                run += co;
            }
        }
        return out;
    }

    public static double[] clipValues(List<ClipEntry> parts, int tx, int ty, int w, int h) {
        int x0 = tx * Tiles.TILE;
        int y0 = ty * Tiles.TILE;
        int n = (Math.min(w, x0 + Tiles.TILE) - x0) * (Math.min(h, y0 + Tiles.TILE) - y0);
        double[] v = new double[n];
        for (ClipEntry pr : parts) {
            double[] c = resolveTile(pr.td(), pr.rule(), tx, ty, w, h);
            for (int i = 0; i < n; i++) {
                v[i] = 1 - (1 - v[i]) * (1 - c[i]);
            }
        }
        return v;
    }

    public static TileBlock fineTile(Scene sc, List<TileCommand> cmds, int tx, int ty, FineStats fs) {
        int w = sc.width;
        int h = sc.height;
        int x0 = tx * Tiles.TILE;
        int y0 = ty * Tiles.TILE;
        int tw = Math.min(w, x0 + Tiles.TILE) - x0;
        int th = Math.min(h, y0 + Tiles.TILE) - y0;
        int n = tw * th;
        List<double[]> stack = new ArrayList<>();
        stack.add(new double[n * 4]);
        List<TilePush> pushes = new ArrayList<>();

        for (TileCommand c : cmds) {
            if (c instanceof TileFill f) {
                double[] cov = resolveTile(f.td(), f.rule(), tx, ty, w, h);
                double[] cv = f.clip() != null ? clipValues(f.clip(), tx, ty, w, h) : null;
                double[] top = stack.get(stack.size() - 1);
                Color solidColor = f.paint() instanceof Solid s ? s.color : null;
                boolean opaque = solidColor != null && f.alpha() == 1.0 && cv == null;
                boolean solidTile = f.td().kind() == TileDraw.Kind.SOLID;
                for (int i = 0; i < n; i++) {
                    int o = i * 4;
                    if (solidTile && opaque) {
                        top[o] = solidColor.red;
                        top[o + 1] = solidColor.green;
                        top[o + 2] = solidColor.blue;
                        top[o + 3] = 1;
                        continue;
                    }
                    double v = cov[i];
                    if (cv != null) {
                        v *= cv[i];
                    }
                    double k = v * f.alpha();
                    if (k > 0) {
                        int x = x0 + i % tw;
                        int y = y0 + i / tw;
                        Color cc = solidColor != null ? solidColor : f.paint().paintAt(x + 0.5, y + 0.5);
                        double t = 1 - k;
                        top[o] = cc.red * k + t * top[o];
                        top[o + 1] = cc.green * k + t * top[o + 1];
                        top[o + 2] = cc.blue * k + t * top[o + 2];
                        top[o + 3] = k + t * top[o + 3];
                    }
                }
            } else if (c instanceof TilePush p) {
                if (stack.size() >= STACK_DEPTH) {
                    fs.spills++;
                }
                stack.add(new double[n * 4]);
                pushes.add(p);
            } else {
                TilePush pc = pushes.remove(pushes.size() - 1);
                double[] g = stack.remove(stack.size() - 1);
                double[] base = stack.get(stack.size() - 1);
                double op = pc.opacity();
                if (pc.clip() != null) {
                    double[] cv2 = clipValues(pc.clip(), tx, ty, w, h);
                    for (int i = 0; i < n; i++) {
                        for (int q = 0; q < 4; q++) {
                            g[i * 4 + q] *= cv2[i];
                        }
                    }
                }
                for (int i = 0; i < n; i++) {
                    int o = i * 4;
                    if (g[o + 3] > 0) {
                        double sa = g[o + 3] * op;
                        double t = 1 - sa;
                        base[o] = g[o] * op + t * base[o];
                        base[o + 1] = g[o + 1] * op + t * base[o + 1];
                        base[o + 2] = g[o + 2] * op + t * base[o + 2];
                        base[o + 3] = sa + t * base[o + 3];
                    }
                }
            }
        }
        fs.tiles++;
        return new TileBlock(stack.get(0), x0, y0, tw, th);
    }

    public static Map<TileKey, List<TileCommand>> pipelineLists(Scene sc) {
        return coarseStage(sc, binStage(sc, flattenStage(sc)));
    }

    public static void putBlock(Layer l, TileBlock b) {
        for (int j = 0; j < b.th(); j++) {
            for (int i = 0; i < b.tw(); i++) {
                int q = (j * b.tw() + i) * 4;
                l.setPixel(b.x0() + i, b.y0() + j,
                        new Pixel(b.block()[q], b.block()[q + 1], b.block()[q + 2], b.block()[q + 3]));
            }
        }
    }

    public static Canvas runPipeline(Scene sc, Integer seed, FineStats fs) {
        Map<TileKey, List<TileCommand>> lists = pipelineLists(sc);
        Layer l = new Layer(sc.width, sc.height);
        List<TileKey> order = new ArrayList<>();
        for (int ty = 0; ty < sc.rows; ty++) {
            for (int tx = 0; tx < sc.cols; tx++) {
                order.add(new TileKey(tx, ty));
            }
        }
        if (seed != null) {
            int[] perm = Lcg.lcgShuffle(order.size(), seed);
            List<TileKey> shuffled = new ArrayList<>();
            for (int idx : perm) {
                shuffled.add(order.get(idx));
            }
            order = shuffled;
        }
        for (TileKey k : order) {
            List<TileCommand> cmds = lists.getOrDefault(k, List.of());
            TileBlock b = fineTile(sc, cmds, k.tx(), k.ty(), fs);
            putBlock(l, b);
        }
        return Layers.flattenLayer(l, new Color(1, 1, 1));
    }

    public static Canvas renderSvgGpu(String text, int width, int height, Integer seed) {
        Scene sc = new Scene(Encoder.encodeSvg(text, width, height), width, height);
        return runPipeline(sc, seed, new FineStats());
    }

    public static int maxGroupDepth(List<Op> commands) {
        int depth = 0;
        int max = 0;
        for (Op c : commands) {
            if (c instanceof PushOp) {
                depth++;
                max = Math.max(max, depth);
            } else if (c instanceof PopOp) {
                depth--;
            }
        }
        return max;
    }

    public static long depositCount(Map<TileKey, List<Deposit>> bins) {
        long total = 0;
        for (List<Deposit> l : bins.values()) {
            total += l.size();
        }
        return total;
    }

    public static long commandCount(Map<TileKey, List<TileCommand>> lists) {
        long total = 0;
        for (List<TileCommand> l : lists.values()) {
            total += l.size();
        }
        return total;
    }
}
