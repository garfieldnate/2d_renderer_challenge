import java.util.ArrayList;
import java.util.List;

/**
 * §24.5: encode_svg(text, width, height) is chapter 20's walker drawing
 * nothing: it answers the scene as a flat list, in document order, of
 * fills, pushes and pops (EncCmd below). Scene(commands, width, height)
 * numbers every path, clip parts included, as a draw: draws is the flat
 * list of (path, rule) every fill and every clip part refers to by index,
 * and commands is the same list of operations with paths and clip parts
 * replaced by draw indices.
 */
public final class Scene {
    public final int width;
    public final int height;
    public final int cols;
    public final int rows;
    public final List<Op> commands;
    public final List<Draw> draws;

    public Scene(List<EncCmd> cmds, int width, int height) {
        this.width = width;
        this.height = height;
        this.cols = (width + Tiles.TILE - 1) / Tiles.TILE;
        this.rows = (height + Tiles.TILE - 1) / Tiles.TILE;
        List<Draw> draws = new ArrayList<>();
        List<Op> ops = new ArrayList<>();
        for (EncCmd c : cmds) {
            if (c instanceof EncFill f) {
                List<Integer> clipIdx = idsOf(f.clip(), draws);
                draws.add(new Draw(f.path(), f.rule()));
                ops.add(new FillOp(draws.size() - 1, f.paint(), f.alpha(), clipIdx));
            } else if (c instanceof EncPush ps) {
                List<Integer> clipIdx = idsOf(ps.clip(), draws);
                ops.add(new PushOp(ps.opacity(), clipIdx));
            } else {
                ops.add(new PopOp());
            }
        }
        this.draws = draws;
        this.commands = ops;
    }

    private static List<Integer> idsOf(List<ClipPart> parts, List<Draw> draws) {
        if (parts == null) {
            return null;
        }
        List<Integer> ids = new ArrayList<>();
        for (ClipPart part : parts) {
            draws.add(new Draw(part.path(), part.rule()));
            ids.add(draws.size() - 1);
        }
        return ids;
    }
}
