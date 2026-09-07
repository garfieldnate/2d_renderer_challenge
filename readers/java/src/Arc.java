/**
 * §8.4: arc(x1, y1, rx, ry, phi, large_arc, sweep, x2, y2) turns SVG's
 * endpoint form of an elliptical arc into the center form the SVG spec's
 * appendix F.6 derives: a center, radii (grown if they were too small to
 * reach, with corrected set), the x-axis rotation phi in radians, a start
 * angle and a swept angle. arc_point(a, t) walks it from t = 0 at the start
 * to t = 1 at the end. Coincident endpoints or a zero radius describe no
 * arc at all -- null, Java's "none".
 */
public final class Arc {
    public final double cx;
    public final double cy;
    public final double rx;
    public final double ry;
    public final double phi;
    public final double theta1;
    public final double deltaTheta;
    public final boolean corrected;

    private Arc(double cx, double cy, double rx, double ry, double phi,
                double theta1, double deltaTheta, boolean corrected) {
        this.cx = cx;
        this.cy = cy;
        this.rx = rx;
        this.ry = ry;
        this.phi = phi;
        this.theta1 = theta1;
        this.deltaTheta = deltaTheta;
        this.corrected = corrected;
    }

    private static double angleBetween(double ux, double uy, double vx, double vy) {
        double dot = ux * vx + uy * vy;
        double lenU = Math.hypot(ux, uy);
        double lenV = Math.hypot(vx, vy);
        double cos = dot / (lenU * lenV);
        cos = Math.max(-1.0, Math.min(1.0, cos)); // guard the acos domain
        double angle = Math.acos(cos);
        double cross = ux * vy - uy * vx;
        return cross < 0 ? -angle : angle;
    }

    public static Arc arc(double x1, double y1, double rx, double ry, double phi,
                          boolean largeArc, boolean sweep, double x2, double y2) {
        if (x1 == x2 && y1 == y2) {
            return null; // coincident endpoints: no arc
        }
        if (rx == 0 || ry == 0) {
            return null; // a zero radius describes no ellipse
        }
        rx = Math.abs(rx);
        ry = Math.abs(ry);

        double cosPhi = Math.cos(phi);
        double sinPhi = Math.sin(phi);
        double dx2 = (x1 - x2) / 2.0;
        double dy2 = (y1 - y2) / 2.0;
        double x1p = cosPhi * dx2 + sinPhi * dy2;
        double y1p = -sinPhi * dx2 + cosPhi * dy2;

        boolean corrected = false;
        double lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
        if (lambda > 1) {
            double scale = Math.sqrt(lambda);
            rx *= scale;
            ry *= scale;
            corrected = true;
        }

        double sign = (largeArc != sweep) ? 1 : -1;
        double rx2 = rx * rx;
        double ry2 = ry * ry;
        double num = rx2 * ry2 - rx2 * y1p * y1p - ry2 * x1p * x1p;
        double denom = rx2 * y1p * y1p + ry2 * x1p * x1p;
        double co = sign * Math.sqrt(Math.max(0.0, num / denom));
        double cxp = co * (rx * y1p / ry);
        double cyp = co * (-ry * x1p / rx);

        double cx = cosPhi * cxp - sinPhi * cyp + (x1 + x2) / 2.0;
        double cy = sinPhi * cxp + cosPhi * cyp + (y1 + y2) / 2.0;

        double ux = (x1p - cxp) / rx;
        double uy = (y1p - cyp) / ry;
        double vx = (-x1p - cxp) / rx;
        double vy = (-y1p - cyp) / ry;

        double theta1 = angleBetween(1, 0, ux, uy);
        double deltaTheta = angleBetween(ux, uy, vx, vy);

        if (!sweep && deltaTheta > 0) {
            deltaTheta -= 2 * Math.PI;
        } else if (sweep && deltaTheta < 0) {
            deltaTheta += 2 * Math.PI;
        }

        return new Arc(cx, cy, rx, ry, phi, theta1, deltaTheta, corrected);
    }

    public static Tuple arcPoint(Arc a, double t) {
        double theta = a.theta1 + t * a.deltaTheta;
        double cosPhi = Math.cos(a.phi);
        double sinPhi = Math.sin(a.phi);
        double ct = Math.cos(theta);
        double st = Math.sin(theta);
        double x = a.cx + a.rx * ct * cosPhi - a.ry * st * sinPhi;
        double y = a.cy + a.rx * ct * sinPhi + a.ry * st * cosPhi;
        return Tuple.point(x, y);
    }
}
