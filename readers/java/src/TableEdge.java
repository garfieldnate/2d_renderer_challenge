/**
 * §6.1: one entry of the edge table -- an edge prepared for the sweep.
 * y_top and y_bottom are its two ends, smaller first; x_top is where it
 * crosses y_top; slope is dx per unit of y (descending); direction is +1
 * when the path heads down the canvas along it (from a to b with
 * a.y &lt; b.y), -1 when it heads up.
 */
public record TableEdge(double yTop, double yBottom, double xTop, double slope, int direction) {}
