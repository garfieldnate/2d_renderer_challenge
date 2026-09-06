import java.util.ArrayList;
import java.util.List;

/**
 * §5.1: a subpath is a list of points, in order, and a flag for whether it
 * was closed. The list is mutable -- move_to, line_to and close build it up
 * one call at a time.
 */
public final class Subpath {
    public final List<Tuple> points = new ArrayList<>();
    public boolean closed = false;
}
