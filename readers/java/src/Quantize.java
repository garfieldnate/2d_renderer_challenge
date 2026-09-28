import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * §25.3: median_cut(colors, n) makes a palette of at most n byte colours.
 * nearest_index(palette, col) is the entry with the least squared distance
 * in bytes, the lowest index on a tie. The dithers work in linear light.
 * canvas_to_bmp8/read_bmp8 write and read an 8-bit indexed BMP.
 */
public final class Quantize {
    private Quantize() {}

    public record BmpImage(int width, int height, List<int[]> palette, int[] indices) {}

    private static String key(int[] c) {
        return c[0] + "," + c[1] + "," + c[2];
    }

    private static double range(List<int[]> box, int k) {
        int lo = Integer.MAX_VALUE;
        int hi = Integer.MIN_VALUE;
        for (int[] c : box) {
            lo = Math.min(lo, c[k]);
            hi = Math.max(hi, c[k]);
        }
        return hi - lo;
    }

    public static List<int[]> medianCut(List<int[]> colors, int n) {
        Map<String, Integer> counts = new LinkedHashMap<>();
        List<int[]> distinct = new ArrayList<>();
        for (int[] c : colors) {
            String k = key(c);
            if (counts.containsKey(k)) {
                counts.put(k, counts.get(k) + 1);
            } else {
                counts.put(k, 1);
                distinct.add(c);
            }
        }
        distinct.sort((a, b) -> a[0] != b[0] ? a[0] - b[0] : a[1] != b[1] ? a[1] - b[1] : a[2] - b[2]);

        List<List<int[]>> boxes = new ArrayList<>();
        boxes.add(distinct);
        while (boxes.size() < n) {
            int bi = -1;
            double bw = -1;
            for (int i = 0; i < boxes.size(); i++) {
                List<int[]> b = boxes.get(i);
                if (b.size() < 2) {
                    continue;
                }
                double w = Math.max(range(b, 0), Math.max(range(b, 1), range(b, 2)));
                if (w > bw) {
                    bw = w;
                    bi = i;
                }
            }
            if (bi < 0) {
                break;
            }
            List<int[]> box = boxes.get(bi);
            double[] ws = {range(box, 0), range(box, 1), range(box, 2)};
            int ch = 0;
            for (int k = 1; k < 3; k++) {
                if (ws[k] > ws[ch]) {
                    ch = k;
                }
            }
            int chFinal = ch;
            List<int[]> sorted = new ArrayList<>(box);
            sorted.sort((a, b) -> a[chFinal] - b[chFinal]);
            int total = 0;
            for (int[] c : sorted) {
                total += counts.get(key(c));
            }
            int run = 0;
            int cut = 1;
            for (int j = 0; j < sorted.size(); j++) {
                run += counts.get(key(sorted.get(j)));
                if (2 * run >= total) {
                    cut = j + 1;
                    break;
                }
            }
            cut = Math.min(Math.max(cut, 1), sorted.size() - 1);
            List<int[]> firstHalf = new ArrayList<>(sorted.subList(0, cut));
            List<int[]> secondHalf = new ArrayList<>(sorted.subList(cut, sorted.size()));
            boxes.remove(bi);
            boxes.add(bi, secondHalf);
            boxes.add(bi, firstHalf);
        }

        List<int[]> result = new ArrayList<>();
        for (List<int[]> box : boxes) {
            long total = 0;
            double[] sum = new double[3];
            for (int[] c : box) {
                int w = counts.get(key(c));
                total += w;
                for (int k = 0; k < 3; k++) {
                    sum[k] += c[k] * (double) w;
                }
            }
            int[] entry = new int[3];
            for (int k = 0; k < 3; k++) {
                entry[k] = (int) Math.floor(sum[k] / total + 0.5);
            }
            result.add(entry);
        }
        return result;
    }

    public static int nearestIndex(List<int[]> palette, int[] col) {
        int best = -1;
        long bestDist = Long.MAX_VALUE;
        for (int i = 0; i < palette.size(); i++) {
            int[] p = palette.get(i);
            long dr = p[0] - col[0];
            long dg = p[1] - col[1];
            long db = p[2] - col[2];
            long d = dr * dr + dg * dg + db * db;
            if (best < 0 || d < bestDist) {
                bestDist = d;
                best = i;
            }
        }
        return best;
    }

    public static int[] remap(Canvas c, List<int[]> palette) {
        int[] out = new int[c.width * c.height];
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                out[y * c.width + x] = nearestIndex(palette, FloodFill.bytesAt(c, x, y));
            }
        }
        return out;
    }

    private static Color linColor(int[] byteColor) {
        return new Color(
                Srgb.decode(byteColor[0] / 255.0), Srgb.decode(byteColor[1] / 255.0), Srgb.decode(byteColor[2] / 255.0));
    }

    private static List<Color> linPal(List<int[]> pal) {
        List<Color> out = new ArrayList<>();
        for (int[] p : pal) {
            out.add(linColor(p));
        }
        return out;
    }

    private static int nearestLinear(List<Color> lp, Color v) {
        int best = -1;
        double bestDist = Double.MAX_VALUE;
        for (int i = 0; i < lp.size(); i++) {
            Color p = lp.get(i);
            double dr = p.red - v.red;
            double dg = p.green - v.green;
            double db = p.blue - v.blue;
            double d = dr * dr + dg * dg + db * db;
            if (best < 0 || d < bestDist) {
                bestDist = d;
                best = i;
            }
        }
        return best;
    }

    public static int[] threshold(Canvas c, List<int[]> pal) {
        List<Color> lp = linPal(pal);
        int[] out = new int[c.width * c.height];
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                out[y * c.width + x] = nearestLinear(lp, c.pixelAt(x, y));
            }
        }
        return out;
    }

    public static int[] orderedDither(Canvas c, List<int[]> pal) {
        List<Color> lp = linPal(pal);
        double lo = lp.get(0).green;
        double hi = lp.get(1).green;
        int[] out = new int[c.width * c.height];
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                double v = c.pixelAt(x, y).green;
                double t = lo + (hi - lo) * Dither.ditherThreshold(x, y);
                out[y * c.width + x] = v > t ? 1 : 0;
            }
        }
        return out;
    }

    public static int[] errorDiffuse(Canvas c, List<int[]> pal) {
        int w = c.width;
        int h = c.height;
        List<Color> lp = linPal(pal);
        double[][] err = new double[w * h][3];
        int[] out = new int[w * h];
        int[][] offsets = {{1, 0, 7}, {-1, 1, 3}, {0, 1, 5}, {1, 1, 1}};
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                Color p = c.pixelAt(x, y);
                double[] e = err[y * w + x];
                double vr = p.red + e[0];
                double vg = p.green + e[1];
                double vb = p.blue + e[2];
                Color v = new Color(vr, vg, vb);
                int idx = nearestLinear(lp, v);
                out[y * w + x] = idx;
                Color q = lp.get(idx);
                double dr = vr - q.red;
                double dg = vg - q.green;
                double db = vb - q.blue;
                for (int[] s : offsets) {
                    int nx = x + s[0];
                    int ny = y + s[1];
                    if (nx >= 0 && nx < w && ny < h) {
                        double[] t = err[ny * w + nx];
                        t[0] += dr * s[2] / 16.0;
                        t[1] += dg * s[2] / 16.0;
                        t[2] += db * s[2] / 16.0;
                    }
                }
            }
        }
        return out;
    }

    public static Canvas indexedCanvas(int[] indices, List<int[]> palette, int w, int h) {
        List<Color> lp = linPal(palette);
        Canvas c = new Canvas(w, h);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                c.writePixel(x, y, lp.get(indices[y * w + x]));
            }
        }
        return c;
    }

    public static Canvas rampCanvas(int w, int h) {
        Canvas c = new Canvas(w, h);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                double g = (double) x / (w - 1);
                c.writePixel(x, y, new Color(g, g, g));
            }
        }
        return c;
    }

    public static double meanLight(Canvas c) {
        double sum = 0;
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                sum += c.pixelAt(x, y).green;
            }
        }
        return sum / ((double) c.width * c.height);
    }

    public static List<int[]> canvasBytes(Canvas c) {
        List<int[]> out = new ArrayList<>();
        for (int y = 0; y < c.height; y++) {
            for (int x = 0; x < c.width; x++) {
                out.add(FloodFill.bytesAt(c, x, y));
            }
        }
        return out;
    }

    private static void writeU32LE(byte[] b, int off, long v) {
        b[off] = (byte) (v & 0xFF);
        b[off + 1] = (byte) ((v >> 8) & 0xFF);
        b[off + 2] = (byte) ((v >> 16) & 0xFF);
        b[off + 3] = (byte) ((v >> 24) & 0xFF);
    }

    private static void writeU16LE(byte[] b, int off, int v) {
        b[off] = (byte) (v & 0xFF);
        b[off + 1] = (byte) ((v >> 8) & 0xFF);
    }

    private static int readU32LE(byte[] b, int off) {
        return (b[off] & 0xFF) | ((b[off + 1] & 0xFF) << 8) | ((b[off + 2] & 0xFF) << 16)
                | ((b[off + 3] & 0xFF) << 24);
    }

    public static byte[] canvasToBmp8(int[] indices, List<int[]> palette, int w, int h) {
        int stride = ((w + 3) / 4) * 4;
        int off = 14 + 40 + 1024;
        int size = off + stride * h;
        byte[] b = new byte[size];
        b[0] = 66; // 'B'
        b[1] = 77; // 'M'
        writeU32LE(b, 2, size);
        writeU32LE(b, 10, off);
        writeU32LE(b, 14, 40);
        writeU32LE(b, 18, w);
        writeU32LE(b, 22, h);
        writeU16LE(b, 26, 1);
        writeU16LE(b, 28, 8);
        writeU32LE(b, 34, (long) stride * h);
        writeU32LE(b, 38, 2835);
        writeU32LE(b, 42, 2835);
        writeU32LE(b, 46, palette.size());
        for (int i = 0; i < palette.size(); i++) {
            int[] p = palette.get(i);
            b[54 + 4 * i] = (byte) p[2];
            b[55 + 4 * i] = (byte) p[1];
            b[56 + 4 * i] = (byte) p[0];
        }
        int row = 0;
        for (int y = h - 1; y >= 0; y--, row++) {
            for (int x = 0; x < w; x++) {
                b[off + row * stride + x] = (byte) indices[y * w + x];
            }
        }
        return b;
    }

    public static BmpImage readBmp8(byte[] b) {
        int off = readU32LE(b, 10);
        int w = readU32LE(b, 18);
        int h = readU32LE(b, 22);
        int used = readU32LE(b, 46);
        if (used == 0) {
            used = 256;
        }
        List<int[]> pal = new ArrayList<>();
        for (int i = 0; i < used; i++) {
            int blue = b[54 + 4 * i] & 0xFF;
            int green = b[55 + 4 * i] & 0xFF;
            int red = b[56 + 4 * i] & 0xFF;
            pal.add(new int[] {red, green, blue});
        }
        int stride = ((w + 3) / 4) * 4;
        int[] idx = new int[w * h];
        for (int row = 0; row < h; row++) {
            for (int x = 0; x < w; x++) {
                idx[(h - 1 - row) * w + x] = b[off + row * stride + x] & 0xFF;
            }
        }
        return new BmpImage(w, h, pal, idx);
    }
}
