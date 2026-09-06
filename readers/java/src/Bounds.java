/**
 * §5.1: bounds(p), the smallest axis-aligned box around every point of every
 * subpath, as (min x, min y, max x, max y). An empty path's bounds are
 * (0, 0, 0, 0), not whatever the language's min of nothing happens to be.
 */
public record Bounds(double minX, double minY, double maxX, double maxY) {}
