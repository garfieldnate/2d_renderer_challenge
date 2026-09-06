namespace Chapter01;

/// <summary>
/// A 3 by 3 matrix of real numbers, written row by row. M[r, c] is the
/// entry in row r, column c, both counted from zero. Multiplying a matrix
/// by a tuple treats (x, y, w) as a column; every transform below has
/// bottom row 0 0 1, so that dot product comes out as w unchanged - points
/// stay points, vectors stay vectors.
/// </summary>
public readonly struct Matrix3
{
    private readonly double[] _m; // nine entries, row-major

    public Matrix3(
        double m00, double m01, double m02,
        double m10, double m11, double m12,
        double m20, double m21, double m22)
    {
        _m = new[] { m00, m01, m02, m10, m11, m12, m20, m21, m22 };
    }

    private Matrix3(double[] m) => _m = m;

    public double this[int r, int c] => _m[r * 3 + c];

    public static Matrix3 Identity() => new(1, 0, 0, 0, 1, 0, 0, 0, 1);

    public static Matrix3 operator *(Matrix3 a, Matrix3 b)
    {
        var result = new double[9];
        for (int r = 0; r < 3; r++)
        {
            for (int c = 0; c < 3; c++)
            {
                result[r * 3 + c] = a[r, 0] * b[0, c] + a[r, 1] * b[1, c] + a[r, 2] * b[2, c];
            }
        }
        return new Matrix3(result);
    }

    /// <summary>Treats (x, y, w) as a column: the result's x is row 0 dotted with the tuple, y is row 1, w is row 2.</summary>
    public static Tuple2 operator *(Matrix3 m, Tuple2 t)
    {
        double x = m[0, 0] * t.X + m[0, 1] * t.Y + m[0, 2] * t.W;
        double y = m[1, 0] * t.X + m[1, 1] * t.Y + m[1, 2] * t.W;
        double w = m[2, 0] * t.X + m[2, 1] * t.Y + m[2, 2] * t.W;
        return new Tuple2(x, y, w);
    }

    public Matrix3 Transpose()
    {
        var result = new double[9];
        for (int r = 0; r < 3; r++)
        {
            for (int c = 0; c < 3; c++)
            {
                result[c * 3 + r] = this[r, c];
            }
        }
        return new Matrix3(result);
    }

    /// <summary>The two row (or column) indices that aren't i, in order.</summary>
    private static (int First, int Second) OtherTwo(int i) => i switch
    {
        0 => (1, 2),
        1 => (0, 2),
        _ => (0, 1),
    };

    /// <summary>The 2 by 2 determinant left when row r and column c are deleted.</summary>
    private double Minor(int r, int c)
    {
        var rows = OtherTwo(r);
        var cols = OtherTwo(c);
        return this[rows.First, cols.First] * this[rows.Second, cols.Second] -
               this[rows.First, cols.Second] * this[rows.Second, cols.First];
    }

    private double Cofactor(int r, int c) => (r + c) % 2 == 1 ? -Minor(r, c) : Minor(r, c);

    /// <summary>A cofactor expansion along the first row.</summary>
    public double Determinant() =>
        this[0, 0] * Cofactor(0, 0) + this[0, 1] * Cofactor(0, 1) + this[0, 2] * Cofactor(0, 2);

    /// <summary>Zero means there is no inverse.</summary>
    public bool IsInvertible() => Determinant() != 0;

    /// <summary>
    /// The matrix of cofactors, transposed, divided by the determinant.
    /// Undefined (division by zero) when IsInvertible() is false - callers
    /// check first.
    /// </summary>
    public Matrix3 Inverse()
    {
        double d = Determinant();
        var result = new double[9];
        for (int r = 0; r < 3; r++)
        {
            for (int c = 0; c < 3; c++)
            {
                result[c * 3 + r] = Cofactor(r, c) / d; // [c, r]: the transpose happens here
            }
        }
        return new Matrix3(result);
    }

    // --- The four transforms, each a small matrix ------------------------

    public static Matrix3 Translation(double tx, double ty) => new(1, 0, tx, 0, 1, ty, 0, 0, 1);

    public static Matrix3 Scaling(double sx, double sy) => new(sx, 0, 0, 0, sy, 0, 0, 0, 1);

    /// <summary>Radians. Turns the x axis toward the y axis - clockwise on a canvas, where y points down.</summary>
    public static Matrix3 Rotation(double r)
    {
        double cos = Math.Cos(r), sin = Math.Sin(r);
        return new Matrix3(cos, -sin, 0, sin, cos, 0, 0, 0, 1);
    }

    public static Matrix3 Shearing(double xy, double yx) => new(1, xy, 0, yx, 1, 0, 0, 0, 1);

    /// <summary>
    /// One number for how much this matrix stretches lengths: the square
    /// root of the absolute value of the determinant of the upper-left 2 by
    /// 2. Exact for uniform scales and rotations; the geometric mean of the
    /// two axis scales otherwise, which is the book's chosen compromise
    /// (see §4.4) rather than the largest singular value.
    /// </summary>
    public double ApproxScale() => Math.Sqrt(Math.Abs(this[0, 0] * this[1, 1] - this[0, 1] * this[1, 0]));

    /// <summary>Every point of points, through m.</summary>
    public static List<Tuple2> TransformPoints(IReadOnlyList<Tuple2> points, Matrix3 m)
    {
        var result = new List<Tuple2>(points.Count);
        foreach (var p in points) result.Add(m * p);
        return result;
    }
}
