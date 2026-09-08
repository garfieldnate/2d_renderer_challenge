/** §10.1: a color stop, an offset in [0, 1] and a color, part of a gradient's stop table. */
public record Stop(double offset, Color color) {
    public static Stop stop(double offset, Color color) {
        return new Stop(offset, color);
    }
}
