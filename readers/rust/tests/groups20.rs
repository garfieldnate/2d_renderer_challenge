// features/chapter20-groups.feature

use renderer::{
    approx_eq, color, colors_eq, coverage_at, coverage_buffer, draw_coverage, layer, layer_pixel, pixel, pixel_at,
    pixels_eq, render_svg, set_coverage, solid, union_coverage, Canvas, Color,
};

fn assert_px(c: &Canvas, x: i64, y: i64, expected: Color) {
    let actual = pixel_at(c, x, y);
    assert!(colors_eq(actual, expected), "pixel ({x},{y}): expected {expected:?}, got {actual:?}");
}

#[test]
fn painting_into_a_layer_at_a_coverage_and_an_alpha() {
    let mut cov = coverage_buffer(2, 1);
    set_coverage(&mut cov, 0, 0, 0.5);
    set_coverage(&mut cov, 1, 0, 1.0);
    let mut l = layer(2, 1);
    draw_coverage(&mut l, &cov, &solid(color(1.0, 0.0, 0.0)), 0.5);
    assert!(pixels_eq(layer_pixel(&l, 0, 0), pixel(0.25, 0.0, 0.0, 0.25)));
    assert!(pixels_eq(layer_pixel(&l, 1, 0), pixel(0.5, 0.0, 0.0, 0.5)));
    assert!(approx_eq(coverage_at(&union_coverage(&cov, &cov), 0, 0), 0.75));
    assert!(approx_eq(coverage_at(&union_coverage(&cov, &cov), 1, 0), 1.0));
}

#[test]
fn an_elements_opacity_fades_its_fill_and_stroke_together() {
    let c = render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' stroke='blue' stroke-width='2' opacity='0.5'/></svg>", 4, 4);
    assert_px(&c, 1, 1, color(1.0, 0.5, 0.5));
    assert_px(&c, 0, 0, color(0.5, 0.5, 1.0));
}

#[test]
fn a_groups_opacity_applies_after_its_children_are_flattened() {
    let g = render_svg("<svg viewBox='0 0 4 4'><g opacity='0.5'><rect width='4' height='4' fill='red'/><rect width='4' height='4' fill='blue'/></g></svg>", 4, 4);
    let e = render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' opacity='0.5'/><rect width='4' height='4' fill='blue' opacity='0.5'/></svg>", 4, 4);
    assert_px(&g, 0, 0, color(0.5, 0.5, 1.0));
    assert_px(&e, 0, 0, color(0.5, 0.25, 0.75));
}

#[test]
fn a_clip_on_a_shape_and_on_a_group() {
    let s = render_svg("<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='2' height='4'/></clipPath><rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>", 4, 4);
    let g = render_svg("<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='2' height='4'/></clipPath><g clip-path='url(#c)' opacity='0.5'><rect width='4' height='4' fill='red'/></g></svg>", 4, 4);
    assert_px(&s, 0, 0, color(1.0, 0.0, 0.0));
    assert_px(&s, 3, 0, color(1.0, 1.0, 1.0));
    assert_px(&g, 0, 0, color(1.0, 0.5, 0.5));
    assert_px(&g, 3, 0, color(1.0, 1.0, 1.0));
}

#[test]
fn a_clip_is_the_union_of_its_shapes() {
    let c = render_svg("<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='1' height='4'/><rect x='3' width='1' height='4'/></clipPath><rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>", 4, 4);
    let h = render_svg("<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='0.5' height='4'/><rect width='0.5' height='4'/></clipPath><rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>", 4, 4);
    assert_px(&c, 0, 0, color(1.0, 0.0, 0.0));
    assert_px(&c, 1, 0, color(1.0, 1.0, 1.0));
    assert_px(&c, 3, 0, color(1.0, 0.0, 0.0));
    assert_px(&h, 0, 0, color(1.0, 0.25, 0.25));
}

#[test]
fn each_clip_shape_has_its_own_clip_rule() {
    let e = render_svg("<svg viewBox='0 0 10 10'><clipPath id='c'><path clip-rule='evenodd' d='M0 0H10V10H0Z M2 2H8V8H2Z'/></clipPath><rect width='10' height='10' fill='red' clip-path='url(#c)'/></svg>", 10, 10);
    let n = render_svg("<svg viewBox='0 0 10 10'><clipPath id='c'><path d='M0 0H10V10H0Z M2 2H8V8H2Z'/></clipPath><rect width='10' height='10' fill='red' clip-path='url(#c)'/></svg>", 10, 10);
    assert_px(&e, 0, 0, color(1.0, 0.0, 0.0));
    assert_px(&e, 5, 5, color(1.0, 1.0, 1.0));
    assert_px(&n, 5, 5, color(1.0, 0.0, 0.0));
}

#[test]
fn a_clip_lives_in_the_user_space_of_the_element_that_uses_it() {
    let u = render_svg("<svg viewBox='0 0 8 4'><clipPath id='c'><rect width='2' height='4'/></clipPath><rect width='4' height='4' fill='red' clip-path='url(#c)' transform='translate(4 0)'/></svg>", 8, 4);
    let t = render_svg("<svg viewBox='0 0 4 4'><clipPath id='c' transform='translate(2 0)'><rect width='2' height='4'/></clipPath><rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>", 4, 4);
    let k = render_svg("<svg viewBox='0 0 4 4'><clipPath id='c'><rect width='2' height='4' transform='translate(2 0)'/></clipPath><rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>", 4, 4);
    assert_px(&u, 4, 0, color(1.0, 0.0, 0.0));
    assert_px(&u, 6, 0, color(1.0, 1.0, 1.0));
    assert_px(&t, 0, 0, color(1.0, 1.0, 1.0));
    assert_px(&t, 3, 0, color(1.0, 0.0, 0.0));
    assert_px(&k, 0, 0, color(1.0, 1.0, 1.0));
    assert_px(&k, 3, 0, color(1.0, 0.0, 0.0));
}

#[test]
fn an_empty_clip_hides_everything_and_a_missing_one_hides_nothing() {
    assert_px(&render_svg("<svg viewBox='0 0 4 4'><clipPath id='c'/><rect width='4' height='4' fill='red' clip-path='url(#c)'/></svg>", 4, 4), 0, 0, color(1.0, 1.0, 1.0));
    assert_px(&render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' clip-path='url(#nope)'/></svg>", 4, 4), 0, 0, color(1.0, 0.0, 0.0));
}
