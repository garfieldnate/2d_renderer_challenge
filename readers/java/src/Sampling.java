/**
 * §11.2: the three magnification filters, each a handful of lines over the
 * texels. Every sampler works in texel-centre space: a texel's colour sits
 * at (tx + 0.5, ty + 0.5), so the source coordinate is shifted by -0.5
 * before it's split into an integer texel and a fractional blend. For
 * sample_nearest that shift and a round-to-nearest cancel out algebraically
 * into a plain floor of the untouched coordinate -- floor(sx - 0.5 + 0.5)
 * is floor(sx) -- so it's written that way, but it is the same texel-centre
 * rule as the other two, not an exception to it.
 *
 * sample_bilinear blends the four texels around the point by distance.
 * sample_bicubic fits a Catmull-Rom curve through the sixteen texels
 * around it; catmull(t) is that curve's four weights for a fractional
 * offset t, summing to one and passing exactly through t = 0's sample.
 * Every blend is premultiplied, straight down r, g, b and a alike (Pixel's
 * own lerp_pixel), for the reason chapter 9 already found: averaging
 * straight-alpha pixels drags a transparent texel's colour into the
 * result.
 */
public final class Sampling {
    private Sampling() {}

    public static Pixel sampleNearest(Image img, double sx, double sy) {
        return sampleNearest(img, sx, sy, "clamp");
    }

    public static Pixel sampleNearest(Image img, double sx, double sy, String extend) {
        return Images.imageTexel(img, (int) Math.floor(sx), (int) Math.floor(sy), extend);
    }

    public static Pixel sampleBilinear(Image img, double sx, double sy) {
        return sampleBilinear(img, sx, sy, "clamp");
    }

    public static Pixel sampleBilinear(Image img, double sx, double sy, String extend) {
        double gx = sx - 0.5;
        double gy = sy - 0.5;
        int x0 = (int) Math.floor(gx);
        int y0 = (int) Math.floor(gy);
        double fx = gx - x0;
        double fy = gy - y0;
        Pixel top = Pixel.lerpPixel(
                Images.imageTexel(img, x0, y0, extend), Images.imageTexel(img, x0 + 1, y0, extend), fx);
        Pixel bottom = Pixel.lerpPixel(
                Images.imageTexel(img, x0, y0 + 1, extend), Images.imageTexel(img, x0 + 1, y0 + 1, extend), fx);
        return Pixel.lerpPixel(top, bottom, fy);
    }

    /** §11.2: the Catmull-Rom weights for a fractional offset t, over the four samples at -1, 0, 1, 2. */
    public static double[] catmull(double t) {
        double t2 = t * t;
        double t3 = t2 * t;
        return new double[] {
            -0.5 * t3 + t2 - 0.5 * t,
            1.5 * t3 - 2.5 * t2 + 1,
            -1.5 * t3 + 2 * t2 + 0.5 * t,
            0.5 * t3 - 0.5 * t2
        };
    }

    public static Pixel sampleBicubic(Image img, double sx, double sy) {
        return sampleBicubic(img, sx, sy, "clamp");
    }

    public static Pixel sampleBicubic(Image img, double sx, double sy, String extend) {
        double gx = sx - 0.5;
        double gy = sy - 0.5;
        int x0 = (int) Math.floor(gx);
        int y0 = (int) Math.floor(gy);
        double[] wx = catmull(gx - x0);
        double[] wy = catmull(gy - y0);
        double r = 0;
        double g = 0;
        double b = 0;
        double a = 0;
        for (int j = 0; j < 4; j++) {
            for (int i = 0; i < 4; i++) {
                Pixel p = Images.imageTexel(img, x0 - 1 + i, y0 - 1 + j, extend);
                double w = wx[i] * wy[j];
                r += w * p.r;
                g += w * p.g;
                b += w * p.b;
                a += w * p.a;
            }
        }
        return new Pixel(r, g, b, a);
    }

    /** §11.3: dispatch by the filter's name, the way Stops.extend dispatches by mode. */
    public static Pixel sample(Image img, double sx, double sy, String filter, String extend) {
        switch (filter) {
            case "nearest":
                return sampleNearest(img, sx, sy, extend);
            case "bilinear":
                return sampleBilinear(img, sx, sy, extend);
            case "bicubic":
                return sampleBicubic(img, sx, sy, extend);
            default:
                throw new IllegalArgumentException("unknown filter: " + filter);
        }
    }
}
