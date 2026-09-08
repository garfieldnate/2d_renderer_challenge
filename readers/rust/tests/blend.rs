// features/chapter09-blend.feature

use renderer::{approx_eq_eps, blend, blend_color, color, colors_eq, opaque, over, pixel_color, pixels_eq};

#[test]
fn normal_is_source_over() {
    let src = renderer::from_color(color(1.0, 0.0, 0.0), 0.6);
    let dst = renderer::from_color(color(0.0, 0.0, 1.0), 0.4);
    assert!(pixels_eq(blend("normal", src, dst), over(src, dst)));
}

#[test]
fn the_separable_modes_opaque_source_over_opaque_backdrop() {
    let src = opaque(color(0.8, 0.8, 0.8));
    let dst = opaque(color(0.3, 0.3, 0.3));

    let cases: [(&str, f64); 12] = [
        ("normal", 0.8),
        ("multiply", 0.24),
        ("screen", 0.86),
        ("overlay", 0.48),
        ("darken", 0.3),
        ("lighten", 0.8),
        ("color-dodge", 1.0),
        ("color-burn", 0.125),
        ("hard-light", 0.72),
        ("soft-light", 0.448634),
        ("difference", 0.5),
        ("exclusion", 0.62),
    ];

    for (mode, value) in cases {
        let got = blend(mode, src, dst).r;
        assert!(approx_eq_eps(got, value, 0.0001), "mode {mode}: expected {value}, got {got}");
    }
}

#[test]
fn a_blended_pixel_over_an_opaque_backdrop_stays_opaque() {
    let src = opaque(color(0.8, 0.8, 0.8));
    let dst = opaque(color(0.3, 0.3, 0.3));
    assert!(approx_eq_eps(blend("multiply", src, dst).a, 1.0, 0.0001));
    assert!(approx_eq_eps(blend("screen", src, dst).a, 1.0, 0.0001));
}

#[test]
fn the_four_non_separable_modes_mix_a_saturated_red_with_a_blue() {
    let src = opaque(color(0.9, 0.2, 0.2));
    let dst = opaque(color(0.2, 0.4, 0.8));

    let hue = pixel_color(blend("hue", src, dst));
    assert!(colors_eq(hue, color(0.804, 0.204, 0.204)));

    let saturation = pixel_color(blend("saturation", src, dst));
    assert!(colors_eq(saturation, color(0.169333, 0.402667, 0.869333)));

    let colour = pixel_color(blend("color", src, dst));
    assert!(colors_eq(colour, color(0.874, 0.174, 0.174)));

    let luminosity = pixel_color(blend("luminosity", src, dst));
    assert!(colors_eq(luminosity, color(0.226, 0.426, 0.826)));
}

#[test]
fn blend_color_is_the_blend_function_on_two_straight_colours() {
    assert!(colors_eq(blend_color("multiply", color(0.8, 0.8, 0.8), color(0.5, 0.5, 0.5)), color(0.4, 0.4, 0.4)));
    assert!(colors_eq(
        blend_color("color", color(0.2, 0.4, 0.8), color(0.9, 0.2, 0.2)),
        color(0.874, 0.174, 0.174)
    ));
}
