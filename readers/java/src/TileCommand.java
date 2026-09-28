import java.util.List;

/** §24.5: one tile's own command list, after the coarse stage. */
public sealed interface TileCommand extends CullOp permits TileFill, TilePush, TilePop {}

record TileFill(TileDraw td, String rule, Paint paint, double alpha, List<ClipEntry> clip) implements TileCommand {
    @Override
    public boolean isPush() {
        return false;
    }

    @Override
    public boolean isPop() {
        return false;
    }
}

record TilePush(double opacity, List<ClipEntry> clip) implements TileCommand {
    @Override
    public boolean isPush() {
        return true;
    }

    @Override
    public boolean isPop() {
        return false;
    }
}

record TilePop() implements TileCommand {
    @Override
    public boolean isPush() {
        return false;
    }

    @Override
    public boolean isPop() {
        return true;
    }
}
