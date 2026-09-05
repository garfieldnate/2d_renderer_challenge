// features/chapter03-quad.feature

use renderer::{approx_eq, approx_eq_eps, coverage_at, ink, inside, rasterize, thick_line};

#[test]
fn inside_a_thick_line() {
    let s = thick_line(0, 0, 4, 0, 1.0);
    assert!(inside(s, 2.5, 0.5));
    assert!(inside(s, 2.5, 1.0));
    assert!(!inside(s, 2.5, 1.01));
    assert!(inside(s, 0.5, 0.5));
    assert!(!inside(s, 0.4, 0.5));
    assert!(inside(s, 4.5, 0.5));
    assert!(!inside(s, 4.6, 0.5));
}

#[test]
fn a_horizontal_thick_line_covers_its_row_with_half_pixels_at_the_ends() {
    let s = thick_line(0, 3, 7, 3, 1.0);
    let cov = rasterize(s, 10, 10);
    assert!(approx_eq(coverage_at(&cov, 0, 3), 0.5));
    assert!(approx_eq(coverage_at(&cov, 1, 3), 1.0));
    assert!(approx_eq(coverage_at(&cov, 6, 3), 1.0));
    assert!(approx_eq(coverage_at(&cov, 7, 3), 0.5));
    assert!(approx_eq(coverage_at(&cov, 8, 3), 0.0));
    assert!(approx_eq(coverage_at(&cov, 3, 2), 0.0));
    assert!(approx_eq(coverage_at(&cov, 3, 4), 0.0));
    assert!(approx_eq(ink(&cov), 7.0));
}

// Scenario Outline: The ink is the length, whatever the angle
macro_rules! ink_case {
    ($name:ident, $x1:expr, $y1:expr) => {
        #[test]
        fn $name() {
            let s = thick_line(2, 2, $x1, $y1, 1.0);
            let cov = rasterize(s, 20, 20);
            assert!(approx_eq(ink(&cov), 10.0));
        }
    };
}

ink_case!(ink_right, 12, 2);
ink_case!(ink_shallow_diagonal, 10, 8);
ink_case!(ink_steep_diagonal, 8, 10);
ink_case!(ink_down, 2, 12);

#[test]
fn except_that_the_grid_is_blind_along_the_diagonal() {
    let s = thick_line(2, 2, 9, 9, 1.0);
    let cov = rasterize(s, 20, 20);
    assert!(approx_eq(ink(&cov), 9.7188));
    assert!(approx_eq_eps(ink(&cov), 9.8995, 0.25));
}
