/**
 * §21.1: wall-clock time depends on the machine; a scenario counts work
 * instead. cells: the accumulator cells a running sum resolved. blends:
 * the pixels composited one at a time (a paint sample and a source-over).
 * copies: the pixels written without a blend. stats() is all three at 0.
 */
public final class Stats {
    public long cells = 0;
    public long blends = 0;
    public long copies = 0;

    public static Stats stats() {
        return new Stats();
    }
}
