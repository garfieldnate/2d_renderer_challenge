// features/chapter03-wu.feature

use renderer::{
    approx_eq, canvas, canvas_to_p6, color, colors_eq, line_wu, lit_pixels, max_channel_difference,
    pixel_at, total_ink,
};

#[test]
fn a_half_step_lights_two_pixels_equally() {
    let mut c = canvas(10, 10);
    line_wu(&mut c, 0, 0, 4, 2, color(1.0, 1.0, 1.0));
    assert!(colors_eq(pixel_at(&c, 0, 0), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 1, 0), color(0.5, 0.5, 0.5)));
    assert!(colors_eq(pixel_at(&c, 1, 1), color(0.5, 0.5, 0.5)));
    assert!(colors_eq(pixel_at(&c, 2, 1), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 2, 2), color(0.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_at(&c, 4, 2), color(1.0, 1.0, 1.0)));
    assert!(approx_eq(total_ink(&c), 5.0));
}

#[test]
fn a_diagonal_has_uniform_weights() {
    let mut c = canvas(10, 10);
    line_wu(&mut c, 0, 0, 5, 5, color(1.0, 1.0, 1.0));
    assert_eq!(
        lit_pixels(&c),
        vec![(0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5)]
    );
    assert!(colors_eq(pixel_at(&c, 3, 3), color(1.0, 1.0, 1.0)));
    assert!(approx_eq(total_ink(&c), 6.0));
}

#[test]
fn a_horizontal_line_has_weight_1_on_its_row_and_0_on_the_neighbors() {
    let mut c = canvas(10, 10);
    line_wu(&mut c, 0, 3, 7, 3, color(1.0, 1.0, 1.0));
    assert_eq!(
        lit_pixels(&c),
        vec![
            (0, 3),
            (1, 3),
            (2, 3),
            (3, 3),
            (4, 3),
            (5, 3),
            (6, 3),
            (7, 3)
        ]
    );
    assert!(colors_eq(pixel_at(&c, 3, 3), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 3, 2), color(0.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_at(&c, 3, 4), color(0.0, 0.0, 0.0)));
    assert!(approx_eq(total_ink(&c), 8.0));
}

#[test]
fn a_steep_line_weights_across_columns() {
    let mut c = canvas(10, 10);
    line_wu(&mut c, 1, 1, 3, 7, color(1.0, 1.0, 1.0));
    assert!(colors_eq(pixel_at(&c, 1, 1), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(
        pixel_at(&c, 1, 2),
        color(0.6667, 0.6667, 0.6667)
    ));
    assert!(colors_eq(
        pixel_at(&c, 2, 2),
        color(0.3333, 0.3333, 0.3333)
    ));
    assert!(colors_eq(pixel_at(&c, 2, 4), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 3, 7), color(1.0, 1.0, 1.0)));
    assert!(approx_eq(total_ink(&c), 7.0));
}

#[test]
fn the_weights_dont_depend_on_which_end_you_start_from() {
    let mut c1 = canvas(10, 10);
    let mut c2 = canvas(10, 10);
    line_wu(&mut c1, 1, 1, 3, 7, color(1.0, 1.0, 1.0));
    line_wu(&mut c2, 3, 7, 1, 1, color(1.0, 1.0, 1.0));
    assert_eq!(
        max_channel_difference(canvas_to_p6(&c1), canvas_to_p6(&c2)),
        0
    );
}

#[test]
fn a_line_that_starts_above_the_canvas() {
    let mut c = canvas(10, 10);
    line_wu(&mut c, 0, -1, 8, 3, color(1.0, 1.0, 1.0));
    assert!(colors_eq(pixel_at(&c, 1, 0), color(0.5, 0.5, 0.5)));
    assert!(colors_eq(pixel_at(&c, 2, 0), color(1.0, 1.0, 1.0)));
    assert!(approx_eq(total_ink(&c), 7.5));
}

#[test]
fn a_wu_line_of_one_point() {
    let mut c = canvas(10, 10);
    line_wu(&mut c, 3, 3, 3, 3, color(1.0, 1.0, 1.0));
    assert_eq!(lit_pixels(&c), vec![(3, 3)]);
    assert!(colors_eq(pixel_at(&c, 3, 3), color(1.0, 1.0, 1.0)));
}

#[test]
fn sevenths() {
    let mut c = canvas(10, 10);
    line_wu(&mut c, 0, 0, 7, 3, color(1.0, 1.0, 1.0));
    assert!(colors_eq(
        pixel_at(&c, 1, 0),
        color(0.5714, 0.5714, 0.5714)
    ));
    assert!(colors_eq(
        pixel_at(&c, 1, 1),
        color(0.4286, 0.4286, 0.4286)
    ));
    assert!(colors_eq(
        pixel_at(&c, 2, 0),
        color(0.1429, 0.1429, 0.1429)
    ));
    assert!(colors_eq(
        pixel_at(&c, 2, 1),
        color(0.8571, 0.8571, 0.8571)
    ));
    assert!(approx_eq(total_ink(&c), 8.0));
}

// Scenario Outline: The ink depends on the angle
macro_rules! ink_case {
    ($name:ident, $x1:expr, $y1:expr, $ink:expr) => {
        #[test]
        fn $name() {
            let mut c = canvas(20, 20);
            line_wu(&mut c, 2, 2, $x1, $y1, color(1.0, 1.0, 1.0));
            assert!(approx_eq(total_ink(&c), $ink));
        }
    };
}

ink_case!(ink_axis_aligned_right, 12, 2, 11.0);
ink_case!(ink_shallow_diagonal, 10, 8, 9.0);
ink_case!(ink_steep_diagonal, 8, 10, 9.0);
ink_case!(ink_axis_aligned_down, 2, 12, 11.0);
