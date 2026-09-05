// features/chapter02-p6.feature

use renderer::{
    canvas, canvas_to_p6, canvas_to_ppm, color, distinct_values, max_channel_difference,
    ppm_pixel, write_pixel,
};

#[test]
fn the_header_then_the_bytes() {
    let mut c = canvas(2, 1);
    write_pixel(&mut c, 0, 0, color(1.0, 0.0, 0.0));
    write_pixel(&mut c, 1, 0, color(0.0, 0.5, 0.0));
    let p6 = canvas_to_p6(&c);

    assert!(p6.starts_with(b"P6\n2 1\n255\n"));
    assert_eq!(p6.len(), 17);
    // Gherkin's "byte N" is 1-indexed.
    assert_eq!(p6[12 - 1], 255);
    assert_eq!(p6[13 - 1], 0);
    assert_eq!(p6[16 - 1], 188);
}

#[test]
fn the_same_pixel_comes_back_out_of_either_format() {
    let mut c = canvas(2, 1);
    write_pixel(&mut c, 1, 0, color(0.0, 0.5, 0.0));
    let p3 = canvas_to_ppm(&c);
    let p6 = canvas_to_p6(&c);

    assert_eq!(ppm_pixel(&p6, 1, 0), (0, 188, 0));
    assert_eq!(ppm_pixel(&p3, 1, 0), (0, 188, 0));
    assert_eq!(max_channel_difference(&p3, &p6), 0);
    assert_eq!(distinct_values(&p6), 2);
}

#[test]
fn sizes_still_have_to_match() {
    let c1 = canvas(2, 1);
    let c2 = canvas(1, 2);
    let p6a = canvas_to_p6(&c1);
    let p6b = canvas_to_p6(&c2);
    assert_eq!(max_channel_difference(&p6a, &p6b), 255);
}
