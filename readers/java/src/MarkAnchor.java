/**
 * §19.5: one entry of the font's optional marks section -- a mark glyph's
 * anchor class ("above" or "below") and its own anchor point, in font
 * units.
 */
public record MarkAnchor(String anchorClass, double x, double y) {}
