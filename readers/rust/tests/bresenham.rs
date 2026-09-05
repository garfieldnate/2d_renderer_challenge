// features/chapter03-bresenham.feature

use renderer::{canvas, canvas_to_p6, color, line_bresenham, lit_pixels, max_channel_difference};

#[test]
fn a_diagonal() {
    let mut c = canvas(10, 10);
    line_bresenham(&mut c, 0, 0, 5, 5, color(1.0, 1.0, 1.0));
    assert_eq!(
        lit_pixels(&c),
        vec![(0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (5, 5)]
    );
}

#[test]
fn a_horizontal_line_lights_one_row_and_nothing_else() {
    let mut c = canvas(10, 10);
    line_bresenham(&mut c, 0, 3, 7, 3, color(1.0, 1.0, 1.0));
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
}

#[test]
fn a_shallow_line_steps_along_x() {
    let mut c = canvas(10, 10);
    line_bresenham(&mut c, 0, 0, 7, 3, color(1.0, 1.0, 1.0));
    assert_eq!(
        lit_pixels(&c),
        vec![
            (0, 0),
            (1, 0),
            (2, 1),
            (3, 1),
            (4, 2),
            (5, 2),
            (6, 3),
            (7, 3)
        ]
    );
}

#[test]
fn a_steep_line_steps_along_y() {
    let mut c = canvas(10, 10);
    line_bresenham(&mut c, 1, 1, 3, 7, color(1.0, 1.0, 1.0));
    assert_eq!(
        lit_pixels(&c),
        vec![(1, 1), (1, 2), (2, 3), (2, 4), (2, 5), (3, 6), (3, 7)]
    );
}

#[test]
fn the_pixels_dont_depend_on_which_end_you_start_from() {
    let mut c1 = canvas(10, 10);
    let mut c2 = canvas(10, 10);
    line_bresenham(&mut c1, 1, 1, 3, 7, color(1.0, 1.0, 1.0));
    line_bresenham(&mut c2, 3, 7, 1, 1, color(1.0, 1.0, 1.0));
    assert_eq!(lit_pixels(&c1), lit_pixels(&c2));
    assert_eq!(
        max_channel_difference(canvas_to_p6(&c1), canvas_to_p6(&c2)),
        0
    );
}

#[test]
fn a_line_going_up_and_to_the_right() {
    let mut c = canvas(10, 10);
    line_bresenham(&mut c, 0, 6, 7, 3, color(1.0, 1.0, 1.0));
    assert_eq!(
        lit_pixels(&c),
        vec![
            (6, 3),
            (7, 3),
            (4, 4),
            (5, 4),
            (2, 5),
            (3, 5),
            (0, 6),
            (1, 6)
        ]
    );
}

#[test]
fn at_an_exact_half_the_line_stays_on_its_row_one_step_longer() {
    let mut c = canvas(10, 10);
    line_bresenham(&mut c, 0, 0, 4, 2, color(1.0, 1.0, 1.0));
    assert_eq!(lit_pixels(&c), vec![(0, 0), (1, 0), (2, 1), (3, 1), (4, 2)]);
}

#[test]
fn a_line_of_one_point() {
    let mut c = canvas(10, 10);
    line_bresenham(&mut c, 3, 3, 3, 3, color(1.0, 1.0, 1.0));
    assert_eq!(lit_pixels(&c), vec![(3, 3)]);
}

#[test]
fn a_line_may_run_off_the_canvas() {
    let mut c = canvas(10, 10);
    line_bresenham(&mut c, 0, 0, 12, 6, color(1.0, 1.0, 1.0));
    assert_eq!(lit_pixels(&c).len(), 10);
}
