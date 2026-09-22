import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Chapter 18: setting a line of text. Layout decides where every glyph
 * goes and never draws a pixel; draw_run (the seam, §18.5) hands the
 * result to chapter 17.
 *
 * §18.1: ascent/descent/line_height turn the font's vertical numbers into
 * pixels -- descent is a positive number even though the file's descender
 * is negative. layout_run walks the pen one glyph advance at a time (the
 * pair's kern first, when kerning is on, before placing each glyph after
 * the first) and answers one placement per character, spaces and
 * characters the font lacks included. run_advance is how far the pen
 * moved in all.
 *
 * §18.3: break_lines is greedy: each word joins the current line if the
 * line with it, one space added, still fits the measure; otherwise it
 * starts a new line. A word alone wider than the measure overflows.
 *
 * §18.4: layout_line lays one line inside a measure -- left leaves the
 * slack on the right, right on the left, center splits it, and justify
 * spreads it over the line's spaces (a line with no space can't be
 * justified and is laid out left). layout_paragraph breaks the text,
 * stacks every line by line_height, and lays the last line of a justified
 * paragraph out left.
 *
 * §18.5: draw_run(canvas, font, run, size, color, linear) is the seam --
 * every placement's x goes through chapter 17's subpixel_of, and its
 * baseline rounds to the nearest pixel row, halves up.
 */
public final class Layout {
    private Layout() {}

    public static double ascent(Font font, double size) {
        return font.ascender * size / font.unitsPerEm;
    }

    public static double descent(Font font, double size) {
        return -font.descender * size / font.unitsPerEm;
    }

    public static double lineHeight(Font font, double size) {
        return (font.ascender - font.descender + font.lineGap) * size / font.unitsPerEm;
    }

    public static List<Placement> layoutRun(Font font, String text, double size, double x, double y,
                                             boolean kerning) {
        List<Placement> out = new ArrayList<>();
        double pen = x;
        String prevName = null;
        for (int i = 0; i < text.length(); i++) {
            String name = Fonts.glyphName(font, text.charAt(i));
            if (kerning && prevName != null) {
                pen += Fonts.kern(font, prevName, name) * size / font.unitsPerEm;
            }
            out.add(new Placement(name, pen, y));
            pen += Glyphs.penAdvance(font, name, size);
            prevName = name;
        }
        return out;
    }

    public static double runAdvance(Font font, String text, double size, boolean kerning) {
        double total = 0;
        String prevName = null;
        for (int i = 0; i < text.length(); i++) {
            String name = Fonts.glyphName(font, text.charAt(i));
            if (kerning && prevName != null) {
                total += Fonts.kern(font, prevName, name) * size / font.unitsPerEm;
            }
            total += Glyphs.penAdvance(font, name, size);
            prevName = name;
        }
        return total;
    }

    private static final Pattern WORD = Pattern.compile("\\S+");

    private static List<String> words(String text) {
        List<String> out = new ArrayList<>();
        Matcher m = WORD.matcher(text);
        while (m.find()) {
            out.add(m.group());
        }
        return out;
    }

    /** §18.3: break_lines(font, text, size, measure, kerning). */
    public static List<String> breakLines(Font font, String text, double size, double measure,
                                           boolean kerning) {
        List<String> lines = new ArrayList<>();
        String current = "";
        for (String word : words(text)) {
            String candidate = current.isEmpty() ? word : current + " " + word;
            if (!current.isEmpty() && runAdvance(font, candidate, size, kerning) > measure) {
                lines.add(current);
                current = word;
            } else {
                current = candidate;
            }
        }
        if (!current.isEmpty()) {
            lines.add(current);
        }
        return lines;
    }

    /** §18.4: layout_line(font, text, size, x, y, measure, align, kerning). */
    public static List<Placement> layoutLine(Font font, String text, double size, double x, double y,
                                              double measure, String align, boolean kerning) {
        List<Placement> run = layoutRun(font, text, size, x, y, kerning);
        double slack = measure - runAdvance(font, text, size, kerning);
        boolean hasSpace = text.indexOf(' ') >= 0;
        List<Placement> out = new ArrayList<>(run.size());
        if (align.equals("justify") && hasSpace) {
            int spaceCount = 0;
            for (int i = 0; i < text.length(); i++) {
                if (text.charAt(i) == ' ') {
                    spaceCount++;
                }
            }
            double extra = slack / spaceCount;
            int seen = 0;
            for (int i = 0; i < run.size(); i++) {
                Placement p = run.get(i);
                out.add(new Placement(p.name(), p.x() + extra * seen, p.y()));
                if (text.charAt(i) == ' ') {
                    seen++;
                }
            }
        } else {
            double shift = align.equals("right") ? slack : align.equals("center") ? slack / 2 : 0;
            for (Placement p : run) {
                out.add(new Placement(p.name(), p.x() + shift, p.y()));
            }
        }
        return out;
    }

    /** §18.4: layout_paragraph(font, text, size, x, y, measure, align, kerning). */
    public static List<Placement> layoutParagraph(Font font, String text, double size, double x, double y,
                                                   double measure, String align, boolean kerning) {
        List<String> lines = breakLines(font, text, size, measure, kerning);
        List<Placement> out = new ArrayList<>();
        double lineHeight = lineHeight(font, size);
        for (int i = 0; i < lines.size(); i++) {
            String lineAlign = (align.equals("justify") && i == lines.size() - 1) ? "left" : align;
            out.addAll(layoutLine(font, lines.get(i), size, x, y + i * lineHeight, measure, lineAlign, kerning));
        }
        return out;
    }

    /** §18.5: draw_run(canvas, font, run, size, color, linear) -- the seam into chapter 17. */
    public static void drawRun(Canvas c, Font font, List<Placement> run, double size, Color color,
                                boolean linear) {
        for (Placement p : run) {
            Subpixel sq = Bitmaps.subpixelOf(p.x());
            int row = (int) Numbers.round(p.y());
            Bitmaps.paintBitmap(c, Bitmaps.glyphBitmap(font, p.name(), size, sq.quarter()), sq.whole(), row,
                    color, linear);
        }
    }
}
