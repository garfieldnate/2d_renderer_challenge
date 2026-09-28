/**
 * §24.5: lcg_shuffle(n, seed) is Fisher-Yates from the end, the same in
 * every language: x starts at seed, and for i from n - 1 down to 1, x <-
 * (1103515245 * x + 12345) mod 2^31, j = x mod (i + 1), swap entries i and
 * j. The product needs 62 bits, which a plain Java long holds exactly.
 */
public final class Lcg {
    private Lcg() {}

    private static final long MOD = 1L << 31;

    public static int[] lcgShuffle(int n, long seed) {
        int[] order = new int[n];
        for (int i = 0; i < n; i++) {
            order[i] = i;
        }
        long x = seed;
        for (int i = n - 1; i > 0; i--) {
            x = Math.floorMod(1103515245L * x + 12345L, MOD);
            int j = (int) (x % (i + 1));
            int t = order[i];
            order[i] = order[j];
            order[j] = t;
        }
        return order;
    }
}
