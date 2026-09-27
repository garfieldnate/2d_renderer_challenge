import java.util.ArrayList;
import java.util.List;

/**
 * §20.4: arc_cubics(x1, y1, rx, ry, angle_degrees, large, sweep, x2, y2)
 * turns an SVG elliptical arc into cubics: chapter 8's arc gives the center
 * form, the swept angle is cut into n equal pieces (n = ceil(|delta| /
 * (pi / 2) - 0.000001), at least 1), and each piece's inner control points
 * sit on the tangents at its ends, 4/3 tan(d/4) of a radius along them.
 * Coincident endpoints have no arc; a zero radius gives one straight cubic
 * at the thirds of the chord.
 */
public final class ArcCubics {
    private ArcCubics() {}

    public static List<Curve> arcCubics(double x1, double y1, double rx, double ry, double angleDegrees,
            boolean large, boolean sweep, double x2, double y2) {
        List<Curve> out = new ArrayList<>();
        if (x1 == x2 && y1 == y2) {
            return out;
        }
        if (rx == 0 || ry == 0) {
            Tuple p1 = Tuple.point(x1, y1);
            Tuple p2 = Tuple.point(x2, y2);
            out.add(Curve.cubic(
                    p1,
                    Tuple.point(x1 + (x2 - x1) / 3, y1 + (y2 - y1) / 3),
                    Tuple.point(x1 + 2 * (x2 - x1) / 3, y1 + 2 * (y2 - y1) / 3),
                    p2));
            return out;
        }
        Arc a = Arc.arc(x1, y1, rx, ry, angleDegrees * (Math.PI / 180), large, sweep, x2, y2);
        double delta = a.deltaTheta;
        int n = (int) Math.max(1, Math.ceil(Math.abs(delta) / (Math.PI / 2) - 1e-6));
        double step = delta / n;
        double k = 4.0 / 3.0 * Math.tan(step / 4);
        double cphi = Math.cos(a.phi);
        double sphi = Math.sin(a.phi);

        for (int i = 0; i < n; i++) {
            double t0 = a.theta1 + step * i;
            double t1 = t0 + step;
            double c0 = Math.cos(t0);
            double s0 = Math.sin(t0);
            double c1 = Math.cos(t1);
            double s1 = Math.sin(t1);
            Tuple p0 = (i == 0) ? Tuple.point(x1, y1) : on(a, cphi, sphi, c0, s0);
            Tuple p1c = on(a, cphi, sphi, c0 - k * s0, s0 + k * c0);
            Tuple p2c = on(a, cphi, sphi, c1 + k * s1, s1 - k * c1);
            Tuple p3 = (i == n - 1) ? Tuple.point(x2, y2) : on(a, cphi, sphi, c1, s1);
            out.add(Curve.cubic(p0, p1c, p2c, p3));
        }
        return out;
    }

    private static Tuple on(Arc a, double cphi, double sphi, double u, double v) {
        double ex = a.rx * u;
        double ey = a.ry * v;
        return Tuple.point(a.cx + cphi * ex - sphi * ey, a.cy + sphi * ex + cphi * ey);
    }
}
