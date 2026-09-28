import java.util.ArrayList;
import java.util.List;

/**
 * §24.4: paint as a shader. shade_tile(paint, tx, ty, seed) evaluates
 * paint_at at the center of every pixel of the 16 by 16 tile (tx, ty),
 * visiting them in raster order when seed is none (null) and in
 * lcg_shuffle(256, seed) order otherwise, and answers the colours in
 * raster order -- a pure function of position gives the same answer either
 * way.
 */
public final class Shader {
    private Shader() {}

    public static final int TILE = 16;

    public static List<Color> shadeTile(Paint paint, int tx, int ty, Integer seed) {
        int n = TILE * TILE;
        int[] order = new int[n];
        if (seed == null) {
            for (int i = 0; i < n; i++) {
                order[i] = i;
            }
        } else {
            order = Lcg.lcgShuffle(n, seed);
        }
        Color[] out = new Color[n];
        for (int idx : order) {
            int x = tx * TILE + idx % TILE;
            int y = ty * TILE + idx / TILE;
            out[idx] = paint.paintAt(x + 0.5, y + 0.5);
        }
        List<Color> result = new ArrayList<>(n);
        for (Color c : out) {
            result.add(c);
        }
        return result;
    }
}
