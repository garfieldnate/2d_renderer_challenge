// features/chapter11-paint.feature

use renderer::{color, colors_eq, identity, image, image_paint, opaque, paint_at, scaling, translation};

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
fn the_identity_transform_is_bit_exact_under_every_filter() {
    let img = rgbw();
    assert!(colors_eq(
        paint_at(&image_paint(img.clone(), identity(), "nearest", "clamp"), 0.5, 0.5),
        color(1.0, 0.0, 0.0)
    ));
    assert!(colors_eq(
        paint_at(&image_paint(img.clone(), identity(), "bilinear", "clamp"), 0.5, 0.5),
        color(1.0, 0.0, 0.0)
    ));
    assert!(colors_eq(
        paint_at(&image_paint(img.clone(), identity(), "bicubic", "clamp"), 0.5, 0.5),
        color(1.0, 0.0, 0.0)
    ));
    assert!(colors_eq(
        paint_at(&image_paint(img.clone(), identity(), "bilinear", "clamp"), 1.5, 0.5),
        color(0.0, 1.0, 0.0)
    ));
    assert!(colors_eq(
        paint_at(&image_paint(img, identity(), "bilinear", "clamp"), 1.5, 1.5),
        color(1.0, 1.0, 1.0)
    ));
}

#[test]
fn the_transform_places_the_image_and_the_inverse_finds_the_texel() {
    let img = rgbw();
    let p = image_paint(img, translation(10.0, 0.0), "nearest", "clamp");
    assert!(colors_eq(paint_at(&p, 10.5, 0.5), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(paint_at(&p, 11.5, 0.5), color(0.0, 1.0, 0.0)));
}

#[test]
fn a_doubled_image_samples_the_same_texel_across_two_device_pixels() {
    let img = rgbw();
    let p = image_paint(img, scaling(2.0, 2.0), "nearest", "clamp");
    assert!(colors_eq(paint_at(&p, 0.5, 0.5), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(paint_at(&p, 1.5, 0.5), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(paint_at(&p, 2.5, 0.5), color(0.0, 1.0, 0.0)));
}
