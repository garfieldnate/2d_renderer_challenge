import java.util.List;

/**
 * §10.3: a conic gradient sweeps the parameter around a center -- the angle
 * from the center to the point, divided by a full turn, wrapping once
 * around.
 */
public final class ConicGradient implements Paint {
    public final Tuple center;
    public final double angle0;
    public final List<Stop> stops;
    public final String extend;

    public ConicGradient(Tuple center, double angle0, List<Stop> stops, String extend) {
        this.center = center;
        this.angle0 = angle0;
        this.stops = stops;
        this.extend = extend;
    }

    public double conicT(double x, double y) {
        double a = Math.atan2(y - center.y, x - center.x) - angle0;
        double t = a / (2 * Math.PI);
        return t - Math.floor(t);
    }

    @Override
    public Color paintAt(double x, double y) {
        return Stops.sampleStops(stops, Stops.extend(conicT(x, y), extend));
    }
}
