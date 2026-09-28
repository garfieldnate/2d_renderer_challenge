// features/chapter24-loopblinn.feature

use renderer::{
    approx_eq, curve_sign, glyph_path, glyph_stencil, inside_curve, loop_blinn_uv, point,
    quadratic, roboto, text_matrix, winding_mismatches,
};

fn approx_uv(got: Option<(f64, f64, f64)>, expected: (f64, f64, f64)) -> bool {
    match got {
        Some((u, v, s)) => approx_eq(u, expected.0) && approx_eq(v, expected.1) && approx_eq(s, expected.2),
        None => false,
    }
}

#[test]
fn the_control_points_carry_0_0_half_0_and_1_1() {
    let c = quadratic(point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0));
    assert!(approx_uv(loop_blinn_uv(&c, point(0.0, 0.0)), (0.0, 0.0, 0.0)));
    assert!(approx_uv(loop_blinn_uv(&c, point(10.0, 0.0)), (0.5, 0.0, 1.0)));
    assert!(approx_uv(loop_blinn_uv(&c, point(10.0, 10.0)), (1.0, 1.0, 0.0)));
    assert!(approx_uv(loop_blinn_uv(&c, point(7.0, 3.0)), (0.5, 0.3, 0.4)));
    let degenerate = quadratic(point(0.0, 0.0), point(5.0, 0.0), point(10.0, 0.0));
    assert_eq!(loop_blinn_uv(&degenerate, point(3.0, 1.0)), None);
}

#[test]
fn u_squared_minus_v_is_the_sliver_between_the_curve_and_its_chord() {
    let c = quadratic(point(0.0, 0.0), point(10.0, 0.0), point(10.0, 10.0));
    assert!(inside_curve(&c, point(7.0, 3.0)));
    assert!(!inside_curve(&c, point(9.0, 1.0)));
    assert!(!inside_curve(&c, point(4.0, 4.0)));
    assert!(!inside_curve(&c, point(7.5, 2.4)));
    assert!(inside_curve(&c, point(7.5, 2.6)));
    assert_eq!(curve_sign(&c), 1);
    let reversed = quadratic(point(10.0, 10.0), point(10.0, 0.0), point(0.0, 0.0));
    assert_eq!(curve_sign(&reversed), -1);
}

#[test]
fn a_glyph_without_flattening_agrees_with_one_flattened_to_a_thousandth_of_a_pixel() {
    let f = roboto();
    let m = text_matrix(&f, 200.0, 40.0, 140.0);
    let lb = glyph_stencil(&f, "g", m, 200, 200);
    assert_eq!(winding_mismatches(&lb, &glyph_path(&f, "g", m, 0.001)), 0);
    assert_eq!(lb.fragments, 22813);
    let amp = glyph_stencil(&f, "ampersand", m, 200, 200);
    assert_eq!(winding_mismatches(&amp, &glyph_path(&f, "ampersand", m, 0.001)), 0);
}
