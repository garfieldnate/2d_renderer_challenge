import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * §20.1: the document. An element is its local name (any namespace prefix
 * stripped, so the root of an SVG file is "svg" whatever prefix or xmlns it
 * was written with), its attributes (the text exactly as written, xmlns
 * declarations themselves excluded) and its children in document order --
 * text and comments between them are not children.
 */
public final class SvgElement {
    public final String name;
    public final Map<String, String> attributes;
    public final List<SvgElement> children;

    public SvgElement(String name, Map<String, String> attributes, List<SvgElement> children) {
        this.name = name;
        this.attributes = attributes;
        this.children = children;
    }

    /** attribute(el, name): the attribute's text exactly as written, or null ("none") when absent. */
    public String attribute(String attrName) {
        return attributes.get(attrName);
    }

    static Map<String, String> newAttributeMap() {
        return new LinkedHashMap<>();
    }
}
