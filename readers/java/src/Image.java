/**
 * §11.1: an image is a grid of pixels -- premultiplied, the chapter 9
 * representation, because every sampler in this chapter is a weighted
 * average of texels and averaging straight-alpha pixels drags a
 * transparent texel's stored colour into the result. A photo read by
 * {@link Images#readImage} is opaque, so premultiplication makes no visible
 * difference here; it matters the first time an image has a soft edge.
 */
public final class Image {
    public final int width;
    public final int height;
    private final Pixel[] texels;

    public Image(int width, int height, Pixel[] texels) {
        this.width = width;
        this.height = height;
        this.texels = texels;
    }

    /** The texel at exactly (ix, iy); both known to be in bounds. */
    Pixel raw(int ix, int iy) {
        return texels[iy * width + ix];
    }
}
