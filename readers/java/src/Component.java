/**
 * §16.3: one piece of a composite glyph -- another glyph's name, placed
 * through a six-number transform [a, b, c, d, dx, dy].
 */
public record Component(String glyph, double[] transform) {}
