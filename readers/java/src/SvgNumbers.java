import java.util.ArrayList;
import java.util.List;

/**
 * §20.2: numbers. read_number(s, i) reads the number that starts at index i
 * of s and answers the number and the index right past it, or none and i
 * when there's no number there. number_list(s) reads numbers separated by
 * whitespace and at most one comma, stopping at the first thing that isn't
 * a number. read_flag(s, i) reads a single 0 or 1 with no separator needed.
 */
public final class SvgNumbers {
    private SvgNumbers() {}

    private static final String WS = " \t\r\n";

    public record NumberResult(Double value, int index) {}

    public record FlagResult(Integer value, int index) {}

    private static boolean isDigit(char ch) {
        return ch >= '0' && ch <= '9';
    }

    /** skip_sep: whitespace, then at most one comma, then more whitespace. */
    public static int skipSep(String s, int i) {
        while (i < s.length() && WS.indexOf(s.charAt(i)) >= 0) {
            i++;
        }
        if (i < s.length() && s.charAt(i) == ',') {
            i++;
            while (i < s.length() && WS.indexOf(s.charAt(i)) >= 0) {
                i++;
            }
        }
        return i;
    }

    public static NumberResult readNumber(String s, int i) {
        int j = i;
        int digits = 0;
        int n = s.length();
        if (j < n && (s.charAt(j) == '+' || s.charAt(j) == '-')) {
            j++;
        }
        while (j < n && isDigit(s.charAt(j))) {
            j++;
            digits++;
        }
        if (j < n && s.charAt(j) == '.') {
            j++;
            while (j < n && isDigit(s.charAt(j))) {
                j++;
                digits++;
            }
        }
        if (digits == 0) {
            return new NumberResult(null, i);
        }
        if (j < n && (s.charAt(j) == 'e' || s.charAt(j) == 'E')) {
            int k = j + 1;
            if (k < n && (s.charAt(k) == '+' || s.charAt(k) == '-')) {
                k++;
            }
            if (k < n && isDigit(s.charAt(k))) {
                while (k < n && isDigit(s.charAt(k))) {
                    k++;
                }
                j = k;
            }
        }
        double value = Double.parseDouble(s.substring(i, j));
        return new NumberResult(value, j);
    }

    public static double[] numberList(String s) {
        List<Double> out = new ArrayList<>();
        int i = skipSep(s, 0);
        while (i < s.length()) {
            NumberResult r = readNumber(s, i);
            if (r.value() == null) {
                break;
            }
            out.add(r.value());
            i = skipSep(s, r.index());
        }
        double[] result = new double[out.size()];
        for (int k = 0; k < out.size(); k++) {
            result[k] = out.get(k);
        }
        return result;
    }

    public static FlagResult readFlag(String s, int i) {
        if (i < s.length() && (s.charAt(i) == '0' || s.charAt(i) == '1')) {
            return new FlagResult(s.charAt(i) - '0', i + 1);
        }
        return new FlagResult(null, i);
    }
}
