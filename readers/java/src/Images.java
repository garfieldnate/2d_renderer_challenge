import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * §11.1: read_image(ppm) is chapter 1's PPM writer run backwards -- parse
 * the P6 header, and for every pixel decode its three bytes from sRGB back
 * to linear light, storing an opaque premultiplied pixel. image(w, h,
 * pixels) builds one directly from already-premultiplied pixels, the way a
 * scenario hands over red, green, blue and white by hand.
 *
 * image_texel(img, ix, iy, extend) is the pixel at an integer texel, with
 * an index outside the image folded back in by the extend mode: clamp
 * holds the edge texel, repeat wraps for a tiling pattern, reflect bounces
 * so the tile meets itself without a seam -- the same three modes as a
 * gradient's, one dimension up. Omitting extend defaults to clamp, which
 * only matters when the caller's index is already out of range.
 *
 * §11.4: downsample(img) is one level of the mip pyramid -- the box average
 * of each 2x2 block, premultiplied, so a level and its parent agree on the
 * picture's overall colour. mip_chain(img) halves repeatedly down to a
 * single pixel. mip_level_for(scale) is floor(-log2(scale)), clamped to
 * never go below the full-resolution level 0 -- a scale of 1 or larger
 * (any magnification) reads the base image, and a scale of exactly a power
 * of two reads exactly the matching level.
 */
public final class Images {
    private Images() {}

    public static Image image(int width, int height, List<Pixel> texels) {
        return new Image(width, height, texels.toArray(new Pixel[0]));
    }

    public static Image readImage(byte[] p6) {
        int pos = 2; // past "P6"
        int[] header = new int[3]; // width, height, maxval
        for (int t = 0; t < 3; t++) {
            while (isWhitespace(p6[pos])) {
                pos++;
            }
            int start = pos;
            while (!isWhitespace(p6[pos])) {
                pos++;
            }
            header[t] = Integer.parseInt(new String(p6, start, pos - start, StandardCharsets.US_ASCII));
        }
        pos++; // the single whitespace byte after maxval
        int width = header[0];
        int height = header[1];
        Pixel[] texels = new Pixel[width * height];
        for (int i = 0; i < texels.length; i++) {
            double r = Srgb.decode((p6[pos++] & 0xFF) / 255.0);
            double g = Srgb.decode((p6[pos++] & 0xFF) / 255.0);
            double b = Srgb.decode((p6[pos++] & 0xFF) / 255.0);
            texels[i] = Pixel.opaque(new Color(r, g, b));
        }
        return new Image(width, height, texels);
    }

    private static boolean isWhitespace(byte b) {
        return b == ' ' || b == '\n' || b == '\t' || b == '\r';
    }

    public static Pixel imageTexel(Image img, int ix, int iy) {
        return imageTexel(img, ix, iy, "clamp");
    }

    public static Pixel imageTexel(Image img, int ix, int iy, String extend) {
        return img.raw(wrap(ix, img.width, extend), wrap(iy, img.height, extend));
    }

    private static int wrap(int i, int n, String extend) {
        if (i >= 0 && i < n) {
            return i;
        }
        switch (extend) {
            case "clamp":
                return i < 0 ? 0 : n - 1;
            case "repeat": {
                int m = i % n;
                return m < 0 ? m + n : m;
            }
            case "reflect": {
                int period = 2 * n;
                int j = ((i % period) + period) % period;
                return j < n ? j : period - 1 - j;
            }
            default:
                throw new IllegalArgumentException("unknown extend mode: " + extend);
        }
    }

    /** §11.4: the box average of each 2x2 block, premultiplied channels alike. */
    public static Image downsample(Image img) {
        int nw = Math.max(1, img.width / 2);
        int nh = Math.max(1, img.height / 2);
        Pixel[] out = new Pixel[nw * nh];
        for (int y = 0; y < nh; y++) {
            for (int x = 0; x < nw; x++) {
                Pixel a = imageTexel(img, 2 * x, 2 * y, "clamp");
                Pixel b = imageTexel(img, 2 * x + 1, 2 * y, "clamp");
                Pixel c = imageTexel(img, 2 * x, 2 * y + 1, "clamp");
                Pixel d = imageTexel(img, 2 * x + 1, 2 * y + 1, "clamp");
                out[y * nw + x] = new Pixel(
                        (a.r + b.r + c.r + d.r) / 4.0,
                        (a.g + b.g + c.g + d.g) / 4.0,
                        (a.b + b.b + c.b + d.b) / 4.0,
                        (a.a + b.a + c.a + d.a) / 4.0);
            }
        }
        return new Image(nw, nh, out);
    }

    /** §11.4: the whole pyramid, base image first, halving down to a single pixel. */
    public static List<Image> mipChain(Image img) {
        List<Image> chain = new ArrayList<>();
        chain.add(img);
        Image current = img;
        while (current.width > 1 || current.height > 1) {
            current = downsample(current);
            chain.add(current);
        }
        return chain;
    }

    /**
     * §11.4: which mip level's texels are about the size of an output
     * pixel, given how much the placing transform shrinks lengths
     * (chapter 4's approx_scale). floor rather than round: a scale exactly
     * halfway between two levels (like 0.3, between levels 1 and 2) reads
     * the coarser one, and a small floating point wobble around an exact
     * power of two must not read one level too shallow -- hence the tiny
     * epsilon nudging the boundary the right way.
     */
    public static int mipLevelFor(double scale) {
        double raw = -Math.log(scale) / Math.log(2);
        int level = (int) Math.floor(raw + 1e-9);
        return Math.max(0, level);
    }
}
