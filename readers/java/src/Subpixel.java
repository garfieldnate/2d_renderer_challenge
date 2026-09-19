/**
 * §17.1: subpixel_of(x) splits a fractional pen position into a whole pixel
 * and one of four quarters.
 */
public record Subpixel(int whole, int quarter) {}
