/**
 * §10: paint is a function of position -- give it a point on the canvas, it
 * hands back a color. Paint.solid(c) is the constant function; the three
 * gradients are the interesting cases.
 */
public interface Paint {
    Color paintAt(double x, double y);

    static Paint solid(Color c) {
        return new Solid(c);
    }
}
