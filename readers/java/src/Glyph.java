import java.util.List;

/**
 * §16.1: a glyph is an advance, its contours (loops of on/off-curve points,
 * font units, y up) and its components (empty for anything that isn't a
 * composite).
 */
public record Glyph(double advance, List<List<ContourPoint>> contours, List<Component> components) {}
