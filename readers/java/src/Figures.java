/** §1.6, §1.8, §1.9: the five renders this chapter asks for. */
public final class Figures {
    private Figures() {}

    public static Canvas grayMatch() {
        Canvas c = new Canvas(300, 100);
        for (int y = 0; y <= 99; y++) {
            for (int x = 0; x <= 99; x++) {
                boolean on = (x + y) % 2 == 0;
                c.writePixel(x, y, on ? new Color(1, 1, 1) : new Color(0, 0, 0));
            }
        }
        double g = Srgb.decode(128.0 / 255.0);
        for (int y = 0; y <= 99; y++) {
            for (int x = 100; x <= 199; x++) {
                c.writePixel(x, y, new Color(g, g, g));
            }
        }
        for (int y = 0; y <= 99; y++) {
            for (int x = 200; x <= 299; x++) {
                c.writePixel(x, y, new Color(0.5, 0.5, 0.5));
            }
        }
        return c;
    }

    public static Canvas quarterMatch() {
        Canvas c = new Canvas(200, 100);
        for (int y = 0; y <= 99; y++) {
            for (int x = 0; x <= 99; x++) {
                boolean on = (x + y) % 4 == 0;
                c.writePixel(x, y, on ? new Color(1, 1, 1) : new Color(0, 0, 0));
            }
        }
        for (int y = 0; y <= 99; y++) {
            for (int x = 100; x <= 199; x++) {
                c.writePixel(x, y, new Color(0.25, 0.25, 0.25));
            }
        }
        return c;
    }

    public static Canvas ramp() {
        Canvas c = new Canvas(256, 32);
        for (int x = 0; x <= 255; x++) {
            double g = x / 255.0;
            for (int y = 0; y <= 31; y++) {
                c.writePixel(x, y, new Color(g, g, g));
            }
        }
        return c;
    }

    public static Canvas clampPair() {
        Canvas c = new Canvas(200, 100);
        for (int y = 0; y <= 99; y++) {
            for (int x = 0; x <= 99; x++) {
                c.writePixel(x, y, new Color(2, 0.5, 0.5));
            }
        }
        for (int y = 0; y <= 99; y++) {
            for (int x = 100; x <= 199; x++) {
                c.writePixel(x, y, new Color(1, 0.25, 0.25));
            }
        }
        return c;
    }

    public static Canvas plate01() {
        Canvas c = new Canvas(400, 180);
        Color[][] ramps = {
            {new Color(0, 0, 0), new Color(1, 1, 1)},
            {new Color(0.7, 0, 0), new Color(0, 0.3, 0.02)}
        };
        boolean savedBlending = Mixer.linearBlending;
        try {
            for (int i = 0; i < ramps.length; i++) {
                Color a = ramps[i][0];
                Color b = ramps[i][1];
                int top = i * 90;
                for (int x = 0; x <= 399; x++) {
                    double t = x / 399.0;
                    Mixer.linearBlending = false;
                    Color naive = Mixer.mix(a, b, t);
                    Mixer.linearBlending = true;
                    Color light = Mixer.mix(a, b, t);
                    for (int y = top; y <= top + 39; y++) {
                        c.writePixel(x, y, naive);
                    }
                    for (int y = top + 45; y <= top + 84; y++) {
                        c.writePixel(x, y, light);
                    }
                }
            }
        } finally {
            // The switch is left on: it's turned back on inside the loop
            // above on every iteration, matching the book's rule that a
            // scenario which turns it off must turn it back on.
            Mixer.linearBlending = true;
        }
        return c;
    }
}
