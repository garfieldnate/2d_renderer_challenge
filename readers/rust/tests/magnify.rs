// features/chapter02-magnify.feature

use renderer::{canvas, canvas_to_p6, color, colors_eq, magnify, max_channel_difference, pixel_at, write_pixel};

#[test]
fn every_pixel_becomes_a_block() {
    let mut c = canvas(2, 1);
    write_pixel(&mut c, 0, 0, color(1.0, 0.0, 0.0));
    write_pixel(&mut c, 1, 0, color(0.0, 0.5, 0.0));
    let m = magnify(&c, 3);

    assert_eq!(m.width, 6);
    assert_eq!(m.height, 3);
    assert!(colors_eq(pixel_at(&m, 0, 0), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_at(&m, 2, 2), color(1.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_at(&m, 3, 0), color(0.0, 0.5, 0.0)));
    assert!(colors_eq(pixel_at(&m, 5, 2), color(0.0, 0.5, 0.0)));
    assert_eq!(renderer::count_pixels(&m, color(1.0, 0.0, 0.0)), 9);
}

#[test]
fn magnifying_by_one_changes_nothing() {
    let mut c = canvas(2, 1);
    write_pixel(&mut c, 1, 0, color(0.0, 0.5, 0.0));
    let m = magnify(&c, 1);
    assert_eq!(max_channel_difference(canvas_to_p6(&c), canvas_to_p6(&m)), 0);
}
