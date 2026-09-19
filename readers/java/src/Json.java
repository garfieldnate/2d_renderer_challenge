import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * §16.1: a tiny, hand-written JSON reader -- the book's font file is JSON,
 * and every language reads JSON, so this is the one loader chapter 16 asks
 * for. It parses the four shapes the font file actually uses (objects,
 * arrays, strings, numbers, booleans, null) into plain Java values: a
 * {@code Map<String, Object>} for an object, a {@code List<Object>} for an
 * array, {@code String}, {@code Double}, {@code Boolean}, or {@code null}.
 * No streaming, no comments, no trailing commas -- just enough to read
 * reference/chapter-16/roboto.json and the hand-written font literal in
 * chapter16-composites.feature's last scenario.
 */
public final class Json {
    private final String text;
    private int pos;

    private Json(String text) {
        this.text = text;
        this.pos = 0;
    }

    public static Object parse(String text) {
        Json p = new Json(text);
        p.skipWhitespace();
        Object value = p.parseValue();
        p.skipWhitespace();
        return value;
    }

    private void skipWhitespace() {
        while (pos < text.length() && Character.isWhitespace(text.charAt(pos))) {
            pos++;
        }
    }

    private char peek() {
        return text.charAt(pos);
    }

    private char next() {
        return text.charAt(pos++);
    }

    private void expect(char c) {
        if (pos >= text.length() || text.charAt(pos) != c) {
            throw new IllegalArgumentException("expected '" + c + "' at " + pos + " in " + text);
        }
        pos++;
    }

    private Object parseValue() {
        skipWhitespace();
        char c = peek();
        switch (c) {
            case '{':
                return parseObject();
            case '[':
                return parseArray();
            case '"':
                return parseString();
            case 't':
                expectLiteral("true");
                return Boolean.TRUE;
            case 'f':
                expectLiteral("false");
                return Boolean.FALSE;
            case 'n':
                expectLiteral("null");
                return null;
            default:
                return parseNumber();
        }
    }

    private void expectLiteral(String lit) {
        if (!text.startsWith(lit, pos)) {
            throw new IllegalArgumentException("expected '" + lit + "' at " + pos);
        }
        pos += lit.length();
    }

    private Map<String, Object> parseObject() {
        Map<String, Object> map = new LinkedHashMap<>();
        expect('{');
        skipWhitespace();
        if (peek() == '}') {
            pos++;
            return map;
        }
        while (true) {
            skipWhitespace();
            String key = parseString();
            skipWhitespace();
            expect(':');
            Object value = parseValue();
            map.put(key, value);
            skipWhitespace();
            char c = next();
            if (c == '}') {
                break;
            }
            if (c != ',') {
                throw new IllegalArgumentException("expected ',' or '}' at " + (pos - 1));
            }
        }
        return map;
    }

    private List<Object> parseArray() {
        List<Object> list = new ArrayList<>();
        expect('[');
        skipWhitespace();
        if (peek() == ']') {
            pos++;
            return list;
        }
        while (true) {
            Object value = parseValue();
            list.add(value);
            skipWhitespace();
            char c = next();
            if (c == ']') {
                break;
            }
            if (c != ',') {
                throw new IllegalArgumentException("expected ',' or ']' at " + (pos - 1));
            }
        }
        return list;
    }

    private String parseString() {
        expect('"');
        StringBuilder sb = new StringBuilder();
        while (true) {
            char c = next();
            if (c == '"') {
                break;
            }
            if (c == '\\') {
                char esc = next();
                switch (esc) {
                    case '"': sb.append('"'); break;
                    case '\\': sb.append('\\'); break;
                    case '/': sb.append('/'); break;
                    case 'b': sb.append('\b'); break;
                    case 'f': sb.append('\f'); break;
                    case 'n': sb.append('\n'); break;
                    case 'r': sb.append('\r'); break;
                    case 't': sb.append('\t'); break;
                    case 'u':
                        String hex = text.substring(pos, pos + 4);
                        pos += 4;
                        sb.append((char) Integer.parseInt(hex, 16));
                        break;
                    default:
                        throw new IllegalArgumentException("bad escape '\\" + esc + "'");
                }
            } else {
                sb.append(c);
            }
        }
        return sb.toString();
    }

    private Double parseNumber() {
        int start = pos;
        if (peek() == '-') {
            pos++;
        }
        while (pos < text.length() && (Character.isDigit(peek()) || peek() == '.'
                || peek() == 'e' || peek() == 'E' || peek() == '+' || peek() == '-')) {
            pos++;
        }
        return Double.parseDouble(text.substring(start, pos));
    }

    // ---- convenience readers for the parsed generic tree ------------------

    @SuppressWarnings("unchecked")
    public static Map<String, Object> asObject(Object o) {
        return (Map<String, Object>) o;
    }

    @SuppressWarnings("unchecked")
    public static List<Object> asArray(Object o) {
        return (List<Object>) o;
    }

    public static double asNumber(Object o) {
        return ((Double) o).doubleValue();
    }

    public static String asString(Object o) {
        return (String) o;
    }

    public static boolean asBoolean(Object o) {
        if (o instanceof Boolean b) {
            return b;
        }
        // The font's on-curve flag is stored as 0/1 in some hand-written
        // fixtures (chapter16-contours.feature builds contours as plain
        // [x, y, true/false] triples in Gherkin, but a JSON literal might
        // reasonably use 1/0); accept both.
        if (o instanceof Double d) {
            return d != 0.0;
        }
        return (Boolean) o;
    }
}
