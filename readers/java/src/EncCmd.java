import java.util.List;

/**
 * §24.5: encode_svg's raw output, before Scene numbers every path as a
 * draw: Fill(path, rule, paint, alpha, clip), Push(opacity, clip) and Pop.
 */
public sealed interface EncCmd permits EncFill, EncPush, EncPop {}

record EncFill(Path path, String rule, Paint paint, double alpha, List<ClipPart> clip) implements EncCmd {}

record EncPush(double opacity, List<ClipPart> clip) implements EncCmd {}

record EncPop() implements EncCmd {}
