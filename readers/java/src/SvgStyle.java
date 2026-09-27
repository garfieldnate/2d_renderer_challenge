import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * §20.6: colours and the style cascade. computed_style(el, parent) is the
 * element's value for every property in the table: an inherited property
 * starts at the parent's value and any other at its initial value; then
 * each presentation attribute the element has overrides that; then each
 * declaration in its style attribute overrides those, in the order
 * written. inherit takes the parent's value, inherited or not. A value
 * that doesn't parse is ignored.
 */
public final class SvgStyle {
    private SvgStyle() {}

    /** fill/stroke/clip-path hold either null ("none"), a Color, or (fill/stroke only) a "url(#id)" string. */
    public static final class Style {
        public Object fill = new Color(0, 0, 0);
        public double fillOpacity = 1;
        public String fillRule = "nonzero";
        public Object stroke = null;
        public double strokeWidth = 1;
        public double strokeOpacity = 1;
        public String strokeLinecap = "butt";
        public String strokeLinejoin = "miter";
        public double strokeMiterlimit = 4;
        public double[] strokeDasharray = null;
        public double strokeDashoffset = 0;
        public String clipRule = "nonzero";
        public double opacity = 1;
        public String clipPath = null;
        public Color stopColor = new Color(0, 0, 0);

        public Style copy() {
            Style s = new Style();
            s.fill = fill;
            s.fillOpacity = fillOpacity;
            s.fillRule = fillRule;
            s.stroke = stroke;
            s.strokeWidth = strokeWidth;
            s.strokeOpacity = strokeOpacity;
            s.strokeLinecap = strokeLinecap;
            s.strokeLinejoin = strokeLinejoin;
            s.strokeMiterlimit = strokeMiterlimit;
            s.strokeDasharray = strokeDasharray;
            s.strokeDashoffset = strokeDashoffset;
            s.clipRule = clipRule;
            s.opacity = opacity;
            s.clipPath = clipPath;
            s.stopColor = stopColor;
            return s;
        }
    }

    private static final Set<String> PROPERTY_NAMES = new LinkedHashSet<>(List.of(
            "fill", "fill-opacity", "fill-rule", "stroke", "stroke-width", "stroke-opacity", "stroke-linecap",
            "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray", "stroke-dashoffset", "clip-rule", "opacity",
            "clip-path", "stop-color"));

    private static final Set<String> INHERITED = Set.of(
            "fill", "fill-opacity", "fill-rule", "stroke", "stroke-width", "stroke-opacity", "stroke-linecap",
            "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray", "stroke-dashoffset", "clip-rule");

    /** The one sentinel meaning "didn't parse", so the caller can ignore it and keep the old value. */
    private static final Object INVALID = new Object();

    public static Style initialStyle() {
        return new Style();
    }

    public static Double numberValue(String raw) {
        String s = raw.trim();
        if (s.endsWith("px")) {
            s = s.substring(0, s.length() - 2);
        }
        SvgNumbers.NumberResult r = SvgNumbers.readNumber(s, 0);
        if (r.value() == null || r.index() != s.length()) {
            return null;
        }
        return r.value();
    }

    private static String urlOf(String raw) {
        String s = raw.trim();
        if (s.startsWith("url(") && s.contains(")")) {
            return s.substring(0, s.indexOf(')') + 1).replace(" ", "");
        }
        return null;
    }

    private static Object getProp(Style s, String name) {
        return switch (name) {
            case "fill" -> s.fill;
            case "fill-opacity" -> s.fillOpacity;
            case "fill-rule" -> s.fillRule;
            case "stroke" -> s.stroke;
            case "stroke-width" -> s.strokeWidth;
            case "stroke-opacity" -> s.strokeOpacity;
            case "stroke-linecap" -> s.strokeLinecap;
            case "stroke-linejoin" -> s.strokeLinejoin;
            case "stroke-miterlimit" -> s.strokeMiterlimit;
            case "stroke-dasharray" -> s.strokeDasharray;
            case "stroke-dashoffset" -> s.strokeDashoffset;
            case "clip-rule" -> s.clipRule;
            case "opacity" -> s.opacity;
            case "clip-path" -> s.clipPath;
            case "stop-color" -> s.stopColor;
            default -> throw new IllegalArgumentException(name);
        };
    }

    @SuppressWarnings("unchecked")
    private static void setProp(Style s, String name, Object value) {
        switch (name) {
            case "fill" -> s.fill = value;
            case "fill-opacity" -> s.fillOpacity = (Double) value;
            case "fill-rule" -> s.fillRule = (String) value;
            case "stroke" -> s.stroke = value;
            case "stroke-width" -> s.strokeWidth = (Double) value;
            case "stroke-opacity" -> s.strokeOpacity = (Double) value;
            case "stroke-linecap" -> s.strokeLinecap = (String) value;
            case "stroke-linejoin" -> s.strokeLinejoin = (String) value;
            case "stroke-miterlimit" -> s.strokeMiterlimit = (Double) value;
            case "stroke-dasharray" -> s.strokeDasharray = (double[]) value;
            case "stroke-dashoffset" -> s.strokeDashoffset = (Double) value;
            case "clip-rule" -> s.clipRule = (String) value;
            case "opacity" -> s.opacity = (Double) value;
            case "clip-path" -> s.clipPath = (String) value;
            case "stop-color" -> s.stopColor = (Color) value;
            default -> throw new IllegalArgumentException(name);
        }
    }

    /** Returns the parsed value, null (the property's "none"), or INVALID when the text doesn't parse. */
    private static Object parseProperty(String name, String value) {
        String v = value.trim();
        switch (name) {
            case "fill":
            case "stroke": {
                if (v.equals("none")) {
                    return null;
                }
                if (v.startsWith("url(")) {
                    String u = urlOf(v);
                    return u == null ? INVALID : u;
                }
                Color c = SvgColor.parseColor(v);
                return c == null ? INVALID : c;
            }
            case "stop-color": {
                Color c = SvgColor.parseColor(v);
                return c == null ? INVALID : c;
            }
            case "fill-opacity":
            case "stroke-opacity":
            case "opacity": {
                Double n = numberValue(v);
                return n == null ? INVALID : Math.min(1, Math.max(0, n));
            }
            case "stroke-width": {
                Double n = numberValue(v);
                return (n == null || n < 0) ? INVALID : n;
            }
            case "stroke-miterlimit": {
                Double n = numberValue(v);
                return (n == null || n < 1) ? INVALID : n;
            }
            case "stroke-dashoffset": {
                Double n = numberValue(v);
                return n == null ? INVALID : n;
            }
            case "stroke-dasharray": {
                if (v.equals("none")) {
                    return null;
                }
                String[] parts = v.replace(",", " ").trim().split("\\s+");
                if (parts.length == 1 && parts[0].isEmpty()) {
                    return INVALID;
                }
                double[] nums = new double[parts.length];
                for (int i = 0; i < parts.length; i++) {
                    Double n = numberValue(parts[i]);
                    if (n == null) {
                        return INVALID;
                    }
                    nums[i] = n;
                }
                return nums;
            }
            case "fill-rule":
            case "clip-rule":
                return (v.equals("nonzero") || v.equals("evenodd")) ? v : INVALID;
            case "stroke-linecap":
                return (v.equals("butt") || v.equals("round") || v.equals("square")) ? v : INVALID;
            case "stroke-linejoin":
                return (v.equals("miter") || v.equals("round") || v.equals("bevel")) ? v : INVALID;
            case "clip-path": {
                if (v.equals("none")) {
                    return null;
                }
                String u = urlOf(v);
                return u == null ? INVALID : u;
            }
            default:
                return INVALID;
        }
    }

    public static Style computedStyle(SvgElement el, Style parent) {
        Style s = new Style();
        for (String name : PROPERTY_NAMES) {
            Object initial = getProp(new Style(), name);
            setProp(s, name, INHERITED.contains(name) ? getProp(parent, name) : initial);
        }
        List<String[]> decls = new ArrayList<>();
        for (String name : PROPERTY_NAMES) {
            String v = el.attribute(name);
            if (v != null) {
                decls.add(new String[] {name, v});
            }
        }
        String style = el.attribute("style");
        if (style != null) {
            for (String part : style.split(";")) {
                int c = part.indexOf(':');
                if (c >= 0) {
                    String name = part.substring(0, c).trim();
                    if (PROPERTY_NAMES.contains(name)) {
                        decls.add(new String[] {name, part.substring(c + 1).trim()});
                    }
                }
            }
        }
        for (String[] d : decls) {
            String name = d[0];
            String raw = d[1];
            if (raw.trim().equals("inherit")) {
                setProp(s, name, getProp(parent, name));
                continue;
            }
            Object v = parseProperty(name, raw);
            if (v != INVALID) {
                setProp(s, name, v);
            }
        }
        return s;
    }
}
