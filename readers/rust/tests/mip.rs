// features/chapter11-mip.feature

use renderer::{color, colors_eq, downsample, image, image_texel, mip_chain, mip_level_for, opaque, pixel_color};

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
fn downsample_averages_each_2x2_block() {
    let img = rgbw();
    let d = downsample(&img);
    assert_eq!(d.width, 1);
    assert_eq!(d.height, 1);
    assert!(colors_eq(pixel_color(image_texel(&d, 0, 0, "clamp")), color(0.5, 0.5, 0.5)));
}

#[test]
fn a_mip_chain_halves_down_to_a_single_pixel() {
    let img = rgbw();
    let chain = mip_chain(&img);
    assert_eq!(chain.len(), 2);
    assert_eq!(chain[0].width, 2);
    assert_eq!(chain[1].width, 1);
    assert!(colors_eq(pixel_color(image_texel(&chain[1], 0, 0, "clamp")), color(0.5, 0.5, 0.5)));
}

#[test]
fn the_mip_level_follows_the_minification() {
    assert_eq!(mip_level_for(2.0), 0);
    assert_eq!(mip_level_for(1.0), 0);
    assert_eq!(mip_level_for(0.5), 1);
    assert_eq!(mip_level_for(0.25), 2);
    assert_eq!(mip_level_for(0.3), 1);
}
