import java.util.List;

/**
 * §24.5: a Scene's own command list, with every path (fill or clip part)
 * already numbered as a draw index.
 */
public sealed interface Op permits FillOp, PushOp, PopOp {}

record FillOp(int draw, Paint paint, double alpha, List<Integer> clip) implements Op {}

record PushOp(double opacity, List<Integer> clip) implements Op {}

record PopOp() implements Op {}
