import java.util.ArrayDeque;
import java.util.Deque;

/**
 * §25.4: a history(c) is a command stack over a canvas. history_fill(h, x0,
 * y0, x1, y1, col) is an edit that first saves the canvas pixels of its
 * rectangle (end exclusive, cut to the canvas) and then sets them to col;
 * undo(h) puts the saved pixels back, keeps the ones it replaced for redo,
 * and answers true (false with nothing to undo); redo(h) does the
 * reverse; a new edit throws the redo stack away. stored_pixels(h) is how
 * many pixels both stacks hold.
 */
public final class History {
    private record Edit(int x0, int y0, int x1, int y1, Color[] pixels) {
        int count() {
            return pixels.length;
        }
    }

    private final Canvas canvas;
    private final Deque<Edit> undoStack = new ArrayDeque<>();
    private final Deque<Edit> redoStack = new ArrayDeque<>();

    public History(Canvas canvas) {
        this.canvas = canvas;
    }

    private Color[] capture(int x0, int y0, int x1, int y1) {
        Color[] pixels = new Color[Math.max(0, (x1 - x0)) * Math.max(0, (y1 - y0))];
        int i = 0;
        for (int y = y0; y < y1; y++) {
            for (int x = x0; x < x1; x++) {
                pixels[i++] = canvas.pixelAt(x, y);
            }
        }
        return pixels;
    }

    private void restore(Edit e) {
        int i = 0;
        for (int y = e.y0(); y < e.y1(); y++) {
            for (int x = e.x0(); x < e.x1(); x++) {
                canvas.writePixel(x, y, e.pixels()[i++]);
            }
        }
    }

    public void historyFill(int x0, int y0, int x1, int y1, Color col) {
        int cx0 = Math.max(0, x0);
        int cy0 = Math.max(0, y0);
        int cx1 = Math.min(canvas.width, x1);
        int cy1 = Math.min(canvas.height, y1);
        Color[] saved = capture(cx0, cy0, cx1, cy1);
        Edit e = new Edit(cx0, cy0, cx1, cy1, saved);
        for (int y = cy0; y < cy1; y++) {
            for (int x = cx0; x < cx1; x++) {
                canvas.writePixel(x, y, col);
            }
        }
        undoStack.push(e);
        redoStack.clear();
    }

    public boolean undo() {
        if (undoStack.isEmpty()) {
            return false;
        }
        Edit e = undoStack.pop();
        Color[] replaced = capture(e.x0(), e.y0(), e.x1(), e.y1());
        restore(e);
        redoStack.push(new Edit(e.x0(), e.y0(), e.x1(), e.y1(), replaced));
        return true;
    }

    public boolean redo() {
        if (redoStack.isEmpty()) {
            return false;
        }
        Edit e = redoStack.pop();
        Color[] replaced = capture(e.x0(), e.y0(), e.x1(), e.y1());
        restore(e);
        undoStack.push(new Edit(e.x0(), e.y0(), e.x1(), e.y1(), replaced));
        return true;
    }

    public int storedPixels() {
        int total = 0;
        for (Edit e : undoStack) {
            total += e.count();
        }
        for (Edit e : redoStack) {
            total += e.count();
        }
        return total;
    }
}
