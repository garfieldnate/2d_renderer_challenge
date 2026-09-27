import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.Map;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import org.w3c.dom.Attr;
import org.w3c.dom.Document;
import org.w3c.dom.NamedNodeMap;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

/**
 * §20.1: the document. parse_xml(text) is the document's root element,
 * built with the JDK's XML library (javax.xml), the book's stand-in for
 * "your XML library". find_by_id(root, id) searches the whole document.
 */
public final class Xml {
    private Xml() {}

    public static SvgElement parseXml(String text) {
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            factory.setNamespaceAware(false);
            factory.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);
            DocumentBuilder builder = factory.newDocumentBuilder();
            Document doc = builder.parse(new ByteArrayInputStream(text.getBytes(StandardCharsets.UTF_8)));
            return convert(doc.getDocumentElement());
        } catch (Exception e) {
            throw new RuntimeException("could not parse XML: " + e.getMessage(), e);
        }
    }

    private static String localName(String qualified) {
        int i = qualified.indexOf(':');
        return i < 0 ? qualified : qualified.substring(i + 1);
    }

    private static SvgElement convert(org.w3c.dom.Element e) {
        Map<String, String> attrs = SvgElement.newAttributeMap();
        NamedNodeMap am = e.getAttributes();
        for (int i = 0; i < am.getLength(); i++) {
            Attr a = (Attr) am.item(i);
            String an = a.getName();
            if (an.equals("xmlns") || an.startsWith("xmlns:")) {
                continue;
            }
            attrs.put(localName(an), a.getValue());
        }
        List<SvgElement> children = new ArrayList<>();
        NodeList kids = e.getChildNodes();
        for (int i = 0; i < kids.getLength(); i++) {
            Node n = kids.item(i);
            if (n.getNodeType() == Node.ELEMENT_NODE) {
                children.add(convert((org.w3c.dom.Element) n));
            }
        }
        return new SvgElement(localName(e.getNodeName()), attrs, children);
    }

    public static SvgElement findById(SvgElement root, String id) {
        Deque<SvgElement> queue = new ArrayDeque<>();
        queue.add(root);
        while (!queue.isEmpty()) {
            SvgElement e = queue.removeFirst();
            if (id.equals(e.attributes.get("id"))) {
                return e;
            }
            queue.addAll(e.children);
        }
        return null;
    }
}
