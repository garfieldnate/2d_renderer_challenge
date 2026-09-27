import java.util.ArrayList;
import java.util.List;

/**
 * §20.9: paint servers. A fill or stroke of url(#id) names a gradient
 * element somewhere in the document. gradient_stops(el) reads the stop
 * children in order. paint_server(root, ref, bbox, ctm) builds the paint:
 * objectBoundingBox (the default) means the gradient's coordinates live in
 * the unit square of bbox; userSpaceOnUse means they're in user space.
 * gradientTransform is multiplied on last, on the right.
 */
public final class SvgPaint {
    private SvgPaint() {}

    private static double lengthAttr(SvgElement el, String name, double dflt) {
        String v = el.attribute(name);
        if (v == null) {
            return dflt;
        }
        v = v.trim();
        if (v.endsWith("%")) {
            String body = v.substring(0, v.length() - 1);
            SvgNumbers.NumberResult r = SvgNumbers.readNumber(body, 0);
            if (r.value() == null || r.index() != body.length()) {
                return dflt;
            }
            return r.value() / 100;
        }
        Double n = SvgStyle.numberValue(v);
        return n == null ? dflt : n;
    }

    public static List<Stop> gradientStops(SvgElement el) {
        List<Stop> out = new ArrayList<>();
        double last = 0;
        for (SvgElement s : el.children) {
            if (!s.name.equals("stop")) {
                continue;
            }
            double o = lengthAttr(s, "offset", 0);
            o = Math.max(last, Math.min(1, Math.max(0, o)));
            last = o;
            SvgStyle.Style st = SvgStyle.computedStyle(s, SvgStyle.initialStyle());
            out.add(new Stop(o, st.stopColor));
        }
        return out;
    }

    private static String spreadMethod(String v) {
        if ("pad".equals(v) || "reflect".equals(v) || "repeat".equals(v)) {
            return v;
        }
        return "pad";
    }

    public static Paint paintServer(SvgElement root, String ref, Bounds bbox, Matrix ctm) {
        String id = ref.substring(5, ref.length() - 1);
        SvgElement el = Xml.findById(root, id);
        if (el == null || !(el.name.equals("linearGradient") || el.name.equals("radialGradient"))) {
            return null;
        }
        List<Stop> stops = gradientStops(el);
        if (stops.isEmpty()) {
            return null;
        }
        if (stops.size() == 1) {
            return Paint.solid(stops.get(0).color());
        }
        Matrix m = ctm;
        boolean objectBoundingBox = !"userSpaceOnUse".equals(el.attribute("gradientUnits"));
        if (objectBoundingBox) {
            double bw = bbox.maxX() - bbox.minX();
            double bh = bbox.maxY() - bbox.minY();
            if (bw <= 0 || bh <= 0) {
                return null;
            }
            m = m.multiply(Transforms.translation(bbox.minX(), bbox.minY())).multiply(Transforms.scaling(bw, bh));
        }
        m = m.multiply(SvgTransform.parseTransform(el.attribute("gradientTransform")));
        if (m.determinant() == 0) {
            return null;
        }
        String ext = spreadMethod(el.attribute("spreadMethod"));
        Paint g;
        if (el.name.equals("linearGradient")) {
            double x1 = lengthAttr(el, "x1", 0);
            double y1 = lengthAttr(el, "y1", 0);
            double x2 = lengthAttr(el, "x2", 1);
            double y2 = lengthAttr(el, "y2", 0);
            if (x1 == x2 && y1 == y2) {
                return Paint.solid(stops.get(stops.size() - 1).color());
            }
            g = new LinearGradient(Tuple.point(x1, y1), Tuple.point(x2, y2), stops, ext);
        } else {
            double cx = lengthAttr(el, "cx", 0.5);
            double cy = lengthAttr(el, "cy", 0.5);
            double r = lengthAttr(el, "r", 0.5);
            double fx = lengthAttr(el, "fx", cx);
            double fy = lengthAttr(el, "fy", cy);
            double fr = lengthAttr(el, "fr", 0);
            if (r <= 0) {
                return Paint.solid(stops.get(stops.size() - 1).color());
            }
            g = new RadialGradient(Tuple.point(fx, fy), fr, Tuple.point(cx, cy), r, stops, ext);
        }
        return new TransformedPaint(g, m);
    }
}
