/**
 * §5.3: filled(p, rule) is a shape whose inside is the rule ("nonzero" or
 * "evenodd") applied to the path's winding number at the point. Every path
 * can go through the same supersampler as chapter 2's circle.
 */
public final class FilledPath implements Shape {
    private final Path path;
    private final String rule;

    public FilledPath(Path path, String rule) {
        this.path = path;
        this.rule = rule;
    }

    @Override
    public boolean inside(double x, double y) {
        int w = Winding.windingAt(path, x, y);
        return rule.equals("nonzero") ? w != 0 : (w % 2 != 0);
    }
}
