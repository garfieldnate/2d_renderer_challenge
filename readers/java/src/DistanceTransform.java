/**
 * §23.6: the distance transform. edt_1d(f) is Felzenszwalb and
 * Huttenlocher's lower envelope of parabolas, exact and O(n).
 * distance_transform(bits, w, h) runs it down every column, then along every
 * row of the result. Every number is a whole number and the only division
 * is compared, never kept, so the answer is exact.
 */
public final class DistanceTransform {
    private DistanceTransform() {}

    public static long farValue(int w, int h) {
        return (long) w * w + (long) h * h;
    }

    /** d[q] = min over p of (q - p)^2 + f[p]. */
    public static long[] edt1d(long[] f) {
        int n = f.length;
        long[] d = new long[n];
        int[] v = new int[n];
        double[] z = new double[n + 1];
        int k = 0;
        v[0] = 0;
        z[0] = Double.NEGATIVE_INFINITY;
        z[1] = Double.POSITIVE_INFINITY;
        for (int q = 1; q < n; q++) {
            double s = intersect(f, q, v[k]);
            while (s <= z[k]) {
                k--;
                s = intersect(f, q, v[k]);
            }
            k++;
            v[k] = q;
            z[k] = s;
            z[k + 1] = Double.POSITIVE_INFINITY;
        }
        k = 0;
        for (int q = 0; q < n; q++) {
            while (z[k + 1] < q) {
                k++;
            }
            long dq = (long) (q - v[k]) * (q - v[k]) + f[v[k]];
            d[q] = dq;
        }
        return d;
    }

    private static double intersect(long[] f, int q, int vk) {
        return ((double) (f[q] + (long) q * q) - (double) (f[vk] + (long) vk * vk)) / (2.0 * q - 2.0 * vk);
    }

    public static long[] distanceTransform(boolean[] bits, int w, int h) {
        long far = farValue(w, h);
        long[] f = new long[w * h];
        for (int i = 0; i < f.length; i++) {
            f[i] = bits[i] ? 0 : far;
        }
        // down every column
        long[] afterCols = new long[w * h];
        for (int x = 0; x < w; x++) {
            long[] col = new long[h];
            for (int y = 0; y < h; y++) {
                col[y] = f[y * w + x];
            }
            long[] out = edt1d(col);
            for (int y = 0; y < h; y++) {
                afterCols[y * w + x] = out[y];
            }
        }
        // along every row of the result
        long[] result = new long[w * h];
        for (int y = 0; y < h; y++) {
            long[] row = new long[w];
            for (int x = 0; x < w; x++) {
                row[x] = afterCols[y * w + x];
            }
            long[] out = edt1d(row);
            for (int x = 0; x < w; x++) {
                result[y * w + x] = out[x];
            }
        }
        return result;
    }

    public static long[] bruteDistanceTransform(boolean[] bits, int w, int h) {
        long far = farValue(w, h);
        long[] result = new long[w * h];
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                long best = far;
                for (int oy = 0; oy < h; oy++) {
                    for (int ox = 0; ox < w; ox++) {
                        if (bits[oy * w + ox]) {
                            long dd = (long) (x - ox) * (x - ox) + (long) (y - oy) * (y - oy);
                            best = Math.min(best, dd);
                        }
                    }
                }
                result[y * w + x] = best;
            }
        }
        return result;
    }

    public static boolean[] bitsOf(CoverageBuffer cov) {
        boolean[] bits = new boolean[cov.width * cov.height];
        for (int y = 0; y < cov.height; y++) {
            for (int x = 0; x < cov.width; x++) {
                bits[y * cov.width + x] = cov.coverageAt(x, y) >= 0.5;
            }
        }
        return bits;
    }

    public static CoverageBuffer coverageOf(int w, int h, double[] values) {
        CoverageBuffer cov = new CoverageBuffer(w, h);
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                cov.setCoverage(x, y, values[y * w + x]);
            }
        }
        return cov;
    }

    public static Field fieldFromCoverage(CoverageBuffer cov) {
        int w = cov.width, h = cov.height;
        boolean[] on = bitsOf(cov);
        boolean[] off = new boolean[on.length];
        for (int i = 0; i < on.length; i++) {
            off[i] = !on[i];
        }
        long[] toOn = distanceTransform(on, w, h);
        long[] toOff = distanceTransform(off, w, h);
        double[] values = new double[w * h];
        for (int i = 0; i < values.length; i++) {
            if (!on[i]) {
                values[i] = Math.sqrt(toOn[i]) - 0.5;
            } else {
                values[i] = -(Math.sqrt(toOff[i]) - 0.5);
            }
        }
        return new Field(w, h, values);
    }
}
