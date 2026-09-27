/**
 * §20.3: one command of a build path, always in absolute coordinates and
 * always one of six ops: M, L, C, Q, A, Z. args holds op's numbers: M/L are
 * (x, y); C is (x1, y1, x2, y2, x, y); Q is (qx, qy, x, y); A is (rx, ry,
 * angle degrees, large-arc flag, sweep flag, x, y); Z has none.
 */
public record SvgCommand(String op, double[] args) {}
