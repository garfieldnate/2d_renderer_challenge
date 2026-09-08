import java.util.List;

/**
 * §10.3: a linear gradient has an axis, p0 to p1. The parameter of a point
 * is how far along that axis it projects, as a fraction of the axis length
 * -- a dot product over the squared length. Perpendicular to the axis it
 * doesn't change, which is why a linear gradient comes out in stripes
 * square to its axis.
 */
public final class LinearGradient implements Paint {
    public final Tuple p0;
    public final Tuple p1;
    public final List<Stop> stops;
    public final String extend;

    public LinearGradient(Tuple p0, Tuple p1, List<Stop> stops, String extend) {
        this.p0 = p0;
        this.p1 = p1;
        this.stops = stops;
        this.extend = extend;
    }

    public double linearT(double x, double y) {
        double dx = p1.x - p0.x;
        double dy = p1.y - p0.y;
        return ((x - p0.x) * dx + (y - p0.y) * dy) / (dx * dx + dy * dy);
    }

    @Override
    public Color paintAt(double x, double y) {
        return Stops.sampleStops(stops, Stops.extend(linearT(x, y), extend));
    }
}
