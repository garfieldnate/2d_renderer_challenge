/** §25.4: a floating selection is a chapter 9 layer lifted out of the canvas, plus how far it's moved. */
public final class Floating {
    public final Layer layer;
    public double dx = 0;
    public double dy = 0;

    public Floating(Layer layer) {
        this.layer = layer;
    }
}
