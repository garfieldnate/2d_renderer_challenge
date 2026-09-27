import java.util.List;

/**
 * §22.2: how two segments meet -- a kind ("none", "end", "cross", "touch",
 * or "overlap") and two lists of split points, on_s for the first segment
 * and on_t for the second, in the sweep's order.
 */
public record MeetResult(String kind, List<Tuple> onS, List<Tuple> onT) {}
