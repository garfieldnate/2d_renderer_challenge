/**
 * §20.5: parse_transform(s) turns a transform list into one chapter 4
 * matrix. The functions multiply in the order written, left to right, so
 * the rightmost one is the first to touch a point. An empty or missing
 * attribute is the identity, and so is one that doesn't parse.
 */
public final class SvgTransform {
    private SvgTransform() {}

    private static final String WS = " \t\r\n";

    private static boolean allNumbers(String inner, int count) {
        int i = SvgNumbers.skipSep(inner, 0);
        int got = 0;
        while (i < inner.length()) {
            SvgNumbers.NumberResult r = SvgNumbers.readNumber(inner, i);
            if (r.value() == null) {
                return false;
            }
            got++;
            i = SvgNumbers.skipSep(inner, r.index());
        }
        return got == count;
    }

    private static Matrix transformFunction(String name, double[] a) {
        double rad = Math.PI / 180;
        if (name.equals("matrix") && a.length == 6) {
            return Matrix.matrix3(a[0], a[2], a[4], a[1], a[3], a[5], 0, 0, 1);
        }
        if (name.equals("translate") && (a.length == 1 || a.length == 2)) {
            return Transforms.translation(a[0], a.length == 2 ? a[1] : 0);
        }
        if (name.equals("scale") && (a.length == 1 || a.length == 2)) {
            return Transforms.scaling(a[0], a.length == 2 ? a[1] : a[0]);
        }
        if (name.equals("rotate") && a.length == 1) {
            return Transforms.rotation(a[0] * rad);
        }
        if (name.equals("rotate") && a.length == 3) {
            return Transforms.translation(a[1], a[2])
                    .multiply(Transforms.rotation(a[0] * rad))
                    .multiply(Transforms.translation(-a[1], -a[2]));
        }
        if (name.equals("skewX") && a.length == 1) {
            return Transforms.shearing(Math.tan(a[0] * rad), 0);
        }
        if (name.equals("skewY") && a.length == 1) {
            return Transforms.shearing(0, Math.tan(a[0] * rad));
        }
        return null;
    }

    public static Matrix parseTransform(String s) {
        if (s == null) {
            return Matrix.identity();
        }
        Matrix m = Matrix.identity();
        int i = SvgNumbers.skipSep(s, 0);
        int n = s.length();
        while (i < n) {
            int j = i;
            while (j < n && Character.isLetter(s.charAt(j))) {
                j++;
            }
            String name = s.substring(i, j);
            while (j < n && WS.indexOf(s.charAt(j)) >= 0) {
                j++;
            }
            if (name.isEmpty() || j >= n || s.charAt(j) != '(') {
                return Matrix.identity();
            }
            int k = s.indexOf(')', j);
            if (k < 0) {
                return Matrix.identity();
            }
            String inner = s.substring(j + 1, k);
            double[] args = SvgNumbers.numberList(inner);
            if (!allNumbers(inner, args.length)) {
                return Matrix.identity();
            }
            Matrix t = transformFunction(name, args);
            if (t == null) {
                return Matrix.identity();
            }
            m = m.multiply(t);
            i = SvgNumbers.skipSep(s, k + 1);
        }
        return m;
    }
}
