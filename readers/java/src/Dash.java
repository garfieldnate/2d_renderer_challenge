import java.util.ArrayList;
import java.util.List;

/**
 * §15.2, §15.3: dashing is a path-to-path transform, walked by arc length,
 * that runs before chapter 13's stroker ever sees the path.
 *
 * normalize_pattern(pattern) turns the list given into the list the walk
 * uses: an odd number of entries is repeated so on and off alternate the
 * same way every cycle; a negative entry, or a pattern whose entries sum
 * to nothing, is no pattern at all and comes back empty, which dash treats
 * as draw the path solid.
 *
 * dash(path, pattern, phase) walks every subpath from its start, on for
 * pattern[0], off for pattern[1] and around, straight through the
 * vertices -- a dash that reaches a corner turns it, and the stroker gives
 * that corner a join. phase is how far into the pattern the walk begins,
 * taken modulo the pattern's sum. A zero-length entry is a single point,
 * which chapter 13 strokes into a dot under a round cap. Zero-length
 * segments are skipped, and a dash that would begin exactly at the end of
 * a subpath is not emitted.
 *
 * §15.4: every subpath restarts the pattern from the phase. A closed
 * subpath is walked around its closing segment too, and if the walk is on
 * both when it leaves the start and when it gets back, the last dash
 * absorbs the first, turning the starting corner as one subpath -- unless
 * a single dash covers the whole loop, in which case it comes back as the
 * loop, closed.
 */
public final class Dash {
    private static final double EPSILON = 1e-9;

    private Dash() {}

    public static double[] normalizePattern(double[] pattern) {
        double sum = 0;
        boolean negative = false;
        for (double v : pattern) {
            sum += v;
            if (v < 0) {
                negative = true;
            }
        }
        if (negative || sum <= 0) {
            return new double[0];
        }
        if (pattern.length % 2 == 1) {
            double[] doubled = new double[pattern.length * 2];
            System.arraycopy(pattern, 0, doubled, 0, pattern.length);
            System.arraycopy(pattern, 0, doubled, pattern.length, pattern.length);
            return doubled;
        }
        return pattern.clone();
    }

    public static Path dash(Path path, double[] pattern, double phase) {
        double[] pat = normalizePattern(pattern);
        if (pat.length == 0) {
            return copyOf(path);
        }
        int n = pat.length;
        double total = 0;
        for (double v : pat) {
            total += v;
        }

        Path out = new Path();
        for (Subpath sp : path.subpaths()) {
            List<Tuple> pts = new ArrayList<>(sp.points);
            if (sp.closed && pts.size() > 1) {
                pts.add(pts.get(0));
            }

            int i = 0;
            double remaining = pat[0];
            boolean on = true;
            double ph = ((phase % total) + total) % total;
            while (ph > 0) {
                if (ph >= remaining) {
                    ph -= remaining;
                    i = (i + 1) % n;
                    remaining = pat[i];
                    on = !on;
                } else {
                    remaining -= ph;
                    ph = 0;
                }
            }

            int firstIdx = out.subpaths().size();
            boolean curOpen = false;
            for (int k = 0; k < pts.size() - 1; k++) {
                Tuple a = pts.get(k);
                Tuple b = pts.get(k + 1);
                double seg = b.subtract(a).magnitude();
                if (seg < EPSILON) {
                    continue;
                }
                double pos = 0;
                while (pos < seg) {
                    double step = Math.min(remaining, seg - pos);
                    if (on) {
                        if (!curOpen) {
                            out.moveTo(lerp(a, b, pos / seg));
                            curOpen = true;
                        }
                        if (step > 0) {
                            out.lineTo(lerp(a, b, (pos + step) / seg));
                        }
                    }
                    pos += step;
                    remaining -= step;
                    if (remaining <= EPSILON) {
                        i = (i + 1) % n;
                        remaining = pat[i];
                        on = !on;
                        curOpen = false;
                    }
                }
            }

            // §15.4: a closed subpath's last dash absorbs its first.
            List<Subpath> outSubs = out.subpaths();
            if (sp.closed && outSubs.size() > firstIdx) {
                Subpath head = outSubs.get(firstIdx);
                Subpath tail = outSubs.get(outSubs.size() - 1);
                Tuple start = pts.get(0);
                boolean headAtStart = head.points.get(0).subtract(start).magnitude() < EPSILON;
                boolean tailAtStart =
                        tail.points.get(tail.points.size() - 1).subtract(start).magnitude() < EPSILON;
                if (headAtStart && tailAtStart) {
                    if (head == tail) {
                        tail.points.remove(tail.points.size() - 1);
                        tail.closed = true;
                    } else {
                        tail.points.addAll(head.points.subList(1, head.points.size()));
                        outSubs.remove(firstIdx);
                    }
                }
            }
        }
        return out;
    }

    /** A test helper: how many dashes (subpaths) the walk produces. */
    public static int dashCount(Path path, double[] pattern, double phase) {
        return dash(path, pattern, phase).subpaths().size();
    }

    private static Tuple lerp(Tuple a, Tuple b, double t) {
        return a.add(b.subtract(a).scale(t));
    }

    private static Path copyOf(Path path) {
        Path out = new Path();
        for (Subpath sp : path.subpaths()) {
            boolean first = true;
            for (Tuple p : sp.points) {
                if (first) {
                    out.moveTo(p);
                    first = false;
                } else {
                    out.lineTo(p);
                }
            }
            if (sp.closed) {
                out.close();
            }
        }
        return out;
    }
}
