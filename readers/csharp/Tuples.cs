namespace Chapter01;

/// <summary>
/// A point or a vector, both (x, y, w): w = 1 for a point, w = 0 for a
/// vector, so the arithmetic keeps them straight - point minus point is a
/// vector, point plus vector is a point - and the matrices in Matrix.cs can
/// tell them apart. Coordinates are real numbers.
/// </summary>
public readonly struct Tuple2
{
    public double X { get; }
    public double Y { get; }
    public double W { get; }

    public Tuple2(double x, double y, double w)
    {
        X = x;
        Y = y;
        W = w;
    }

    public static Tuple2 Point(double x, double y) => new(x, y, 1);
    public static Tuple2 Vector(double x, double y) => new(x, y, 0);

    public static Tuple2 operator +(Tuple2 a, Tuple2 b) => new(a.X + b.X, a.Y + b.Y, a.W + b.W);
    public static Tuple2 operator -(Tuple2 a, Tuple2 b) => new(a.X - b.X, a.Y - b.Y, a.W - b.W);
    public static Tuple2 operator -(Tuple2 a) => new(-a.X, -a.Y, -a.W);
    public static Tuple2 operator *(Tuple2 a, double scalar) => new(a.X * scalar, a.Y * scalar, a.W * scalar);
    public static Tuple2 operator /(Tuple2 a, double scalar) => new(a.X / scalar, a.Y / scalar, a.W / scalar);

    /// <summary>sqrt(x^2 + y^2). w plays no part - length is a property of the direction, not the tag.</summary>
    public double Magnitude() => Math.Sqrt(X * X + Y * Y);

    /// <summary>A vector of length 1, pointing the same way.</summary>
    public Tuple2 Normalize() => this / Magnitude();

    /// <summary>a.x*b.x + a.y*b.y: zero when a and b are perpendicular.</summary>
    public static double Dot(Tuple2 a, Tuple2 b) => a.X * b.X + a.Y * b.Y;

    /// <summary>
    /// a.x*b.y - a.y*b.x. Its size is the area of the parallelogram a and b
    /// span; its sign says which way you turned from a to b - positive is
    /// the side the y axis points to, which on a canvas (y down) is
    /// clockwise on the screen.
    /// </summary>
    public static double Cross(Tuple2 a, Tuple2 b) => a.X * b.Y - a.Y * b.X;

    public override string ToString() =>
        W == 1 ? $"point({X}, {Y})" : W == 0 ? $"vector({X}, {Y})" : $"tuple({X}, {Y}, {W})";
}
