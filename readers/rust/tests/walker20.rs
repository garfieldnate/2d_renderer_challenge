// features/chapter20-walker.feature

use renderer::{color, colors_eq, pixel_at, render_svg, Canvas, Color};

fn assert_px(c: &Canvas, x: i64, y: i64, expected: Color) {
    let actual = pixel_at(c, x, y);
    assert!(colors_eq(actual, expected), "pixel ({x},{y}): expected {expected:?}, got {actual:?}");
}

#[test]
fn later_elements_paint_over_earlier_ones_and_paper_shows_through() {
    let c = render_svg("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 4 4'><rect width='4' height='4' fill='red'/><rect x='2' width='2' height='4' fill='blue'/></svg>", 4, 4);
    assert_px(&c, 0, 0, color(1.0, 0.0, 0.0));
    assert_px(&c, 3, 0, color(0.0, 0.0, 1.0));
    assert_px(&render_svg("<svg><rect width='2' height='2'/></svg>", 4, 4), 0, 0, color(0.0, 0.0, 0.0));
    assert_px(&render_svg("<svg><rect width='2' height='2'/></svg>", 4, 4), 3, 3, color(1.0, 1.0, 1.0));
}

#[test]
fn the_stroke_is_drawn_over_the_fill_centred_on_the_outline() {
    let c = render_svg("<svg viewBox='0 0 10 10'><rect x='2' y='2' width='6' height='6' fill='red' stroke='blue' stroke-width='2'/></svg>", 10, 10);
    assert_px(&c, 1, 1, color(0.0, 0.0, 1.0));
    assert_px(&c, 2, 5, color(0.0, 0.0, 1.0));
    assert_px(&c, 5, 5, color(1.0, 0.0, 0.0));
    assert_px(&c, 0, 0, color(1.0, 1.0, 1.0));
}

#[test]
fn a_squashed_transform_squashes_the_pen() {
    let c = render_svg("<svg viewBox='0 0 20 10'><rect x='2' y='2' width='6' height='6' fill='none' stroke='black' stroke-width='2' transform='scale(2 1)'/></svg>", 20, 10);
    assert_px(&c, 2, 5, color(0.0, 0.0, 0.0));
    assert_px(&c, 5, 5, color(0.0, 0.0, 0.0));
    assert_px(&c, 10, 1, color(0.0, 0.0, 0.0));
    assert_px(&c, 10, 3, color(1.0, 1.0, 1.0));
}

#[test]
fn dashes_are_measured_in_user_space_too() {
    let c = render_svg("<svg viewBox='0 0 20 2'><line x1='0' y1='1' x2='10' y2='1' stroke='black' stroke-width='2' stroke-dasharray='2 3' transform='scale(2 1)'/></svg>", 20, 2);
    assert_px(&c, 0, 1, color(0.0, 0.0, 0.0));
    assert_px(&c, 3, 1, color(0.0, 0.0, 0.0));
    assert_px(&c, 4, 1, color(1.0, 1.0, 1.0));
    assert_px(&c, 9, 1, color(1.0, 1.0, 1.0));
    assert_px(&c, 10, 1, color(0.0, 0.0, 0.0));
}

#[test]
fn the_dash_offset_moves_the_pattern_along_the_path() {
    let c = render_svg("<svg viewBox='0 0 10 2'><line x1='0' y1='1' x2='10' y2='1' stroke='black' stroke-width='2' stroke-dasharray='2 3' stroke-dashoffset='1'/></svg>", 10, 2);
    assert_px(&c, 0, 1, color(0.0, 0.0, 0.0));
    assert_px(&c, 1, 1, color(1.0, 1.0, 1.0));
    assert_px(&c, 3, 1, color(1.0, 1.0, 1.0));
    assert_px(&c, 4, 1, color(0.0, 0.0, 0.0));
    assert_px(&c, 5, 1, color(0.0, 0.0, 0.0));
    assert_px(&c, 6, 1, color(1.0, 1.0, 1.0));
}

#[test]
fn caps_and_fill_rules_reach_the_fill_and_the_stroker() {
    let c = render_svg("<svg viewBox='0 0 10 4'><line x1='2' y1='2' x2='8' y2='2' stroke='black' stroke-width='2' stroke-linecap='square'/></svg>", 10, 4);
    let e = render_svg("<svg viewBox='0 0 10 10'><path fill-rule='evenodd' d='M0 0H10V10H0Z M2 2H8V8H2Z'/></svg>", 10, 10);
    assert_px(&c, 1, 2, color(0.0, 0.0, 0.0));
    assert_px(&c, 8, 2, color(0.0, 0.0, 0.0));
    assert_px(&c, 0, 2, color(1.0, 1.0, 1.0));
    assert_px(&e, 0, 0, color(0.0, 0.0, 0.0));
    assert_px(&e, 5, 5, color(1.0, 1.0, 1.0));
}

#[test]
fn fill_opacity_and_stroke_opacity_fade_one_paint_each() {
    let c = render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' fill-opacity='0.5' stroke='blue' stroke-width='2' stroke-opacity='0.25'/></svg>", 4, 4);
    assert_px(&c, 1, 1, color(1.0, 0.5, 0.5));
    assert_px(&c, 0, 0, color(0.75, 0.375, 0.625));
}

#[test]
fn a_gradient_fill_spans_the_shapes_own_bounds() {
    let c = render_svg("<svg viewBox='0 0 8 4'><linearGradient id='g'><stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/></linearGradient><rect x='4' width='4' height='4' fill='url(#g)'/></svg>", 8, 4);
    assert_px(&c, 4, 0, color(0.125, 0.125, 0.125));
    assert_px(&c, 5, 0, color(0.375, 0.375, 0.375));
    assert_px(&c, 7, 0, color(0.875, 0.875, 0.875));
}

#[test]
fn what_isnt_drawn() {
    assert_px(&render_svg("<svg viewBox='0 0 4 4'><defs><rect width='4' height='4' fill='red'/></defs><clipPath id='c'><rect width='4' height='4'/></clipPath><text>hi</text><title>t</title><foo><rect width='4' height='4'/></foo></svg>", 4, 4), 0, 0, color(1.0, 1.0, 1.0));
    assert_px(&render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='red' stroke='blue' transform='scale(0)'/></svg>", 4, 4), 0, 0, color(1.0, 1.0, 1.0));
    assert_px(&render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='url(#nope)' stroke='blue' stroke-width='2'/></svg>", 4, 4), 1, 1, color(1.0, 1.0, 1.0));
    assert_px(&render_svg("<svg viewBox='0 0 4 4'><rect width='4' height='4' fill='url(#nope)' stroke='blue' stroke-width='2'/></svg>", 4, 4), 0, 0, color(0.0, 0.0, 1.0));
}
