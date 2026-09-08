// features/chapter11-image.feature

use renderer::{
    approx_eq, canvas, canvas_to_p6, color, colors_eq, image, image_texel, opaque, pixel_alpha,
    pixel_color, read_image, write_pixel,
};

#[test]
fn a_ppm_reads_back_into_the_image_it_was_written_from() {
    let mut c = canvas(2, 2);
    write_pixel(&mut c, 0, 0, color(1.0, 0.0, 0.0));
    write_pixel(&mut c, 1, 0, color(0.0, 1.0, 0.0));
    write_pixel(&mut c, 0, 1, color(0.0, 0.0, 1.0));
    write_pixel(&mut c, 1, 1, color(1.0, 1.0, 1.0));
    let img = read_image(canvas_to_p6(&c));

    assert_eq!(img.width, 2);
    assert_eq!(img.height, 2);
    assert!(colors_eq(pixel_color(image_texel(&img, 0, 0, "clamp")), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_color(image_texel(&img, 1, 1, "clamp")), color(1.0, 1.0, 1.0)));
    assert!(approx_eq(pixel_alpha(image_texel(&img, 0, 0, "clamp")), 1.0));
}

fn rgbw() -> renderer::Image {
    image(
        2,
        2,
        vec![
            opaque(color(1.0, 0.0, 0.0)),
            opaque(color(0.0, 1.0, 0.0)),
            opaque(color(0.0, 0.0, 1.0)),
            opaque(color(1.0, 1.0, 1.0)),
        ],
    )
}

#[test]
fn clamp_holds_the_edge_texel() {
    let img = rgbw();
    assert!(colors_eq(pixel_color(image_texel(&img, -1, 0, "clamp")), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_color(image_texel(&img, 2, 0, "clamp")), color(0.0, 1.0, 0.0)));
}

#[test]
fn repeat_wraps_and_reflect_bounces() {
    let img = rgbw();
    assert!(colors_eq(pixel_color(image_texel(&img, 2, 0, "repeat")), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_color(image_texel(&img, -1, 0, "repeat")), color(0.0, 1.0, 0.0)));
    assert!(colors_eq(pixel_color(image_texel(&img, 2, 0, "reflect")), color(0.0, 1.0, 0.0)));
    assert!(colors_eq(pixel_color(image_texel(&img, -1, 0, "reflect")), color(1.0, 0.0, 0.0)));
}
