import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * The epilogue: book_cover() is the program printed at the end of the book --
 * chapter 20's render_svg of reference/epilogue/cover.svg, then the title and
 * subtitle laid out by chapter 18 and drawn by chapter 18's draw_run. Named
 * bookCover() (not cover(), which chapter 24 already owns) to follow this
 * codebase's existing naming, and bookCoverGlow() for the chapter-23 bonus
 * variant with a soft glow baked and drawn under the title.
 */
public final class Epilogue {
    private Epilogue() {}

    private static final Color TITLE_COLOR = new Color(0.9, 0.86, 0.79);
    private static final Color SUBTITLE_COLOR = new Color(1, 0.33, 0.085);

    private static final String TITLE_TEXT = "The 2D Renderer Challenge";
    private static final String SUBTITLE_TEXT = "A test-driven guide to drawing every pixel yourself";

    private static String readText(String path) {
        try {
            return Files.readString(Path.of(path));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    private static Font roboto() {
        return Fonts.loadFont(readText("reference/chapter-16/roboto.json"));
    }

    /** §E.4: book_cover() -- the document, then the title and subtitle drawn on top of it. */
    public static Canvas bookCover() {
        Canvas c = SvgWalker.renderSvg(readText("reference/epilogue/cover.svg"), 480, 680);
        Font font = roboto();
        List<Placement> title = Layout.layoutParagraph(font, TITLE_TEXT, 44, 40, 530, 400, "left", true);
        List<Placement> sub = Layout.layoutRun(font, SUBTITLE_TEXT, 15, 40, 640, true);
        Layout.drawRun(c, font, title, 44, TITLE_COLOR, true);
        Layout.drawRun(c, font, sub, 15, SUBTITLE_COLOR, true);
        return c;
    }

    /**
     * §E.5: glow_of(d) = 0.45 x (1 - clamp(d / 10, 0, 1))^2 -- 0.45 inside the letter
     * and on its edge, falling to 0 ten pixels out.
     */
    public static double glowOf(double d) {
        double t = 1 - clamp01(d / 10);
        return 0.45 * t * t;
    }

    private static double clamp01(double v) {
        return Math.max(0, Math.min(1, v));
    }

    /** §E.5: book_cover_glow() -- book_cover() with a baked MTSDF glow behind the title. */
    public static Canvas bookCoverGlow() {
        Canvas c = SvgWalker.renderSvg(readText("reference/epilogue/cover.svg"), 480, 680);
        Font font = roboto();
        List<Placement> title = Layout.layoutParagraph(font, TITLE_TEXT, 44, 40, 530, 400, "left", true);
        List<Placement> sub = Layout.layoutRun(font, SUBTITLE_TEXT, 15, 40, 640, true);

        double scale = 44.0 / 32.0;
        Map<String, Baked> cache = new HashMap<>();
        for (Placement pl : title) {
            cache.computeIfAbsent(pl.name(), n -> Msdf.bakeMtsdf(font, n, 32, 8));
        }
        for (Placement pl : title) {
            Msdf.drawEffect(c, cache.get(pl.name()), scale, pl.x(), pl.y(), SUBTITLE_COLOR, true, Epilogue::glowOf);
        }

        Layout.drawRun(c, font, title, 44, TITLE_COLOR, true);
        Layout.drawRun(c, font, sub, 15, SUBTITLE_COLOR, true);
        return c;
    }
}
