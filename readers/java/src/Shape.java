/** §2.1: a shape is a function from a point to yes or no. That's the whole interface. */
public interface Shape {
    boolean inside(double x, double y);
}
