// features/chapter01-canvas.feature

use renderer::{all_pixels_are, canvas, color, colors_eq, fill, pixel_at, write_pixel};

#[test]
fn a_new_canvas_is_black() {
    let c = canvas(10, 20);
    assert_eq!(c.width, 10);
    assert_eq!(c.height, 20);
    assert!(all_pixels_are(&c, color(0.0, 0.0, 0.0)));
}

#[test]
fn writing_a_pixel() {
    let mut c = canvas(10, 20);
    let red = color(1.0, 0.0, 0.0);
    write_pixel(&mut c, 2, 3, red);
    assert!(colors_eq(pixel_at(&c, 2, 3), red));
}

#[test]
fn x_is_the_column_and_y_is_the_row() {
    let mut c = canvas(10, 20);
    write_pixel(&mut c, 2, 3, color(1.0, 0.0, 0.0));
    assert!(colors_eq(pixel_at(&c, 3, 2), color(0.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_at(&c, 2, 3), color(1.0, 0.0, 0.0)));
}

#[test]
fn writing_outside_the_canvas_is_ignored() {
    let mut c = canvas(10, 20);
    write_pixel(&mut c, -1, 5, color(1.0, 0.0, 0.0));
    write_pixel(&mut c, 10, 5, color(1.0, 0.0, 0.0));
    write_pixel(&mut c, 5, -1, color(1.0, 0.0, 0.0));
    write_pixel(&mut c, 5, 20, color(1.0, 0.0, 0.0));
    assert!(all_pixels_are(&c, color(0.0, 0.0, 0.0)));
}

#[test]
fn a_pixel_can_be_written_more_than_once() {
    let mut c = canvas(10, 20);
    write_pixel(&mut c, 2, 3, color(1.0, 0.0, 0.0));
    write_pixel(&mut c, 2, 3, color(0.0, 1.0, 0.0));
    assert!(colors_eq(pixel_at(&c, 2, 3), color(0.0, 1.0, 0.0)));
}

#[test]
fn filling_a_canvas() {
    let mut c = canvas(10, 20);
    fill(&mut c, color(0.1, 0.2, 0.3));
    assert!(all_pixels_are(&c, color(0.1, 0.2, 0.3)));
}
