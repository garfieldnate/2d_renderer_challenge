/** §1.2: a color is three floating point numbers measuring light. 0 is none, 1 is full. */
public final class Color {
    public final double red;
    public final double green;
    public final double blue;

    public Color(double red, double green, double blue) {
        this.red = red;
        this.green = green;
        this.blue = blue;
    }

    public Color add(Color o) {
        return new Color(red + o.red, green + o.green, blue + o.blue);
    }

    public Color subtract(Color o) {
        return new Color(red - o.red, green - o.green, blue - o.blue);
    }

    public Color scale(double s) {
        return new Color(red * s, green * s, blue * s);
    }

    /** Hadamard product: component by component. */
    public Color multiply(Color o) {
        return new Color(red * o.red, green * o.green, blue * o.blue);
    }

    public boolean approxEquals(Color o) {
        return approxEquals(o, Numbers.DEFAULT_EPSILON);
    }

    public boolean approxEquals(Color o, double epsilon) {
        return Numbers.approxEqual(red, o.red, epsilon)
                && Numbers.approxEqual(green, o.green, epsilon)
                && Numbers.approxEqual(blue, o.blue, epsilon);
    }

    @Override
    public String toString() {
        return "color(" + red + ", " + green + ", " + blue + ")";
    }
}
