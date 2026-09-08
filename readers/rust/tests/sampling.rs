// features/chapter11-sampling.feature

use renderer::{approx_eq, catmull, color, colors_eq, image, opaque, pixel_color, sample_bicubic, sample_bilinear, sample_nearest};

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
fn every_sampler_returns_the_texel_exactly_at_its_center() {
    let img = rgbw();
    assert!(colors_eq(pixel_color(sample_nearest(&img, 0.5, 0.5)), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_color(sample_bilinear(&img, 0.5, 0.5)), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_color(sample_bicubic(&img, 0.5, 0.5)), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_color(sample_bilinear(&img, 1.5, 1.5)), color(1.0, 1.0, 1.0)));
}

#[test]
fn nearest_takes_the_texel_the_point_falls_in() {
    let img = rgbw();
    assert!(colors_eq(pixel_color(sample_nearest(&img, 0.9, 0.1)), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_color(sample_nearest(&img, 1.1, 0.1)), color(0.0, 1.0, 0.0)));
}

#[test]
fn bilinear_blends_toward_its_neighbours() {
    let img = rgbw();
    assert!(colors_eq(pixel_color(sample_bilinear(&img, 1.0, 0.5)), color(0.5, 0.5, 0.0)));
    assert!(colors_eq(pixel_color(sample_bilinear(&img, 1.0, 1.0)), color(0.5, 0.5, 0.5)));
}

#[test]
fn the_catmull_rom_weights_sum_to_one_and_pass_through_the_samples() {
    let w0 = catmull(0.0);
    assert!(approx_eq(w0[0], 0.0) && approx_eq(w0[1], 1.0) && approx_eq(w0[2], 0.0) && approx_eq(w0[3], 0.0));

    let w1 = catmull(0.5);
    assert!(approx_eq(w1[0], -0.0625));
    assert!(approx_eq(w1[1], 0.5625));
    assert!(approx_eq(w1[2], 0.5625));
    assert!(approx_eq(w1[3], -0.0625));
}
