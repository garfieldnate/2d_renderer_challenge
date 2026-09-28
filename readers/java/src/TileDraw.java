import java.util.Map;

/**
 * §24.5: the coarse stage's answer for one draw in one tile: "empty"
 * outside its window, "solid" when every row's arriving sum agrees on the
 * same whole number that fills under the rule, "partial" otherwise, with
 * the arriving sum for each row and the tile's own deposited cells.
 */
public record TileDraw(Kind kind, double[] arriving, Map<Integer, double[]> cells) {
    public enum Kind { EMPTY, SOLID, PARTIAL }

    public static final TileDraw EMPTY_TD = new TileDraw(Kind.EMPTY, null, null);

    public static TileDraw solid() {
        return new TileDraw(Kind.SOLID, null, null);
    }
}
