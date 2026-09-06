/**
 * §4.2: a 3 by 3 matrix of real numbers, row by row. get(r, c) is the entry
 * in row r, column c, both counting from 0. matrix3 takes nine numbers in
 * reading order for the times a Gherkin table is too much ceremony.
 *
 * Multiplying two matrices: (A * B)[r, c] is the dot product of row r of A
 * with column c of B. Multiplying a tuple treats (x, y, w) as a column;
 * every transform in this book has a bottom row of 0 0 1, so w survives
 * unchanged.
 *
 * The determinant is a cofactor expansion along the first row. The inverse
 * is the transposed matrix of cofactors, divided by the determinant --
 * transpose(M)[r, c] = M[c, r], and inverse writes each cofactor straight
 * into its transposed slot.
 */
public final class Matrix {
    private final double[] m; // nine entries, row-major

    private Matrix(double[] m) {
        this.m = m;
    }

    public static Matrix matrix3(double a, double b, double c,
                                  double d, double e, double f,
                                  double g, double h, double i) {
        return new Matrix(new double[] {a, b, c, d, e, f, g, h, i});
    }

    public static Matrix identity() {
        return matrix3(1, 0, 0, 0, 1, 0, 0, 0, 1);
    }

    public double get(int r, int c) {
        return m[r * 3 + c];
    }

    public Matrix multiply(Matrix o) {
        double[] result = new double[9];
        for (int r = 0; r < 3; r++) {
            for (int c = 0; c < 3; c++) {
                double sum = 0;
                for (int k = 0; k < 3; k++) {
                    sum += get(r, k) * o.get(k, c);
                }
                result[r * 3 + c] = sum;
            }
        }
        return new Matrix(result);
    }

    public Tuple multiply(Tuple t) {
        double x = get(0, 0) * t.x + get(0, 1) * t.y + get(0, 2) * t.w;
        double y = get(1, 0) * t.x + get(1, 1) * t.y + get(1, 2) * t.w;
        double w = get(2, 0) * t.x + get(2, 1) * t.y + get(2, 2) * t.w;
        return new Tuple(x, y, w);
    }

    public Matrix transpose() {
        double[] result = new double[9];
        for (int r = 0; r < 3; r++) {
            for (int c = 0; c < 3; c++) {
                result[c * 3 + r] = get(r, c);
            }
        }
        return new Matrix(result);
    }

    /** The two row (or column) indices that aren't `excl`, in order. */
    private static int[] others(int excl) {
        int[] result = new int[2];
        int idx = 0;
        for (int v = 0; v < 3; v++) {
            if (v != excl) {
                result[idx++] = v;
            }
        }
        return result;
    }

    /** minor(M, r, c): the 2x2 determinant left when row r and column c are deleted. */
    public double minor(int r, int c) {
        int[] rows = others(r);
        int[] cols = others(c);
        return get(rows[0], cols[0]) * get(rows[1], cols[1]) - get(rows[0], cols[1]) * get(rows[1], cols[0]);
    }

    public double cofactor(int r, int c) {
        double minor = minor(r, c);
        return ((r + c) % 2 == 1) ? -minor : minor;
    }

    public double determinant() {
        return get(0, 0) * cofactor(0, 0) + get(0, 1) * cofactor(0, 1) + get(0, 2) * cofactor(0, 2);
    }

    public boolean isInvertible() {
        return determinant() != 0;
    }

    public Matrix inverse() {
        double d = determinant();
        double[] result = new double[9];
        for (int r = 0; r < 3; r++) {
            for (int c = 0; c < 3; c++) {
                result[c * 3 + r] = cofactor(r, c) / d; // transpose happens here
            }
        }
        return new Matrix(result);
    }

    public boolean approxEquals(Matrix o) {
        for (int i = 0; i < 9; i++) {
            if (!Numbers.approxEqual(m[i], o.m[i])) {
                return false;
            }
        }
        return true;
    }

    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder();
        for (int r = 0; r < 3; r++) {
            sb.append('|');
            for (int c = 0; c < 3; c++) {
                sb.append(' ').append(get(r, c));
            }
            sb.append(" |\n");
        }
        return sb.toString();
    }
}
