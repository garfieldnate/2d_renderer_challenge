// features/chapter10-dither.feature

use renderer::{approx_eq, canvas, canvas_to_p6, canvas_to_p6_dithered, color, dither_threshold, fill, distinct_values, to_byte, to_byte_dithered, BAYER4};

#[test]
fn the_bayer_matrix_and_its_thresholds() {
    let b = BAYER4;
    assert_eq!(b[0][0], 0);
    assert_eq!(b[0][1], 8);
    assert_eq!(b[1][0], 12);
    assert!(approx_eq(dither_threshold(0, 0), 0.0));
    assert!(approx_eq(dither_threshold(1, 0), 0.5));
    assert!(approx_eq(dither_threshold(0, 1), 0.75));
}

#[test]
fn one_light_value_dithers_to_the_two_bytes_around_it() {
    assert_eq!(to_byte_dithered(0.5, 0, 0), 187);
    assert_eq!(to_byte_dithered(0.5, 1, 0), 188);
    assert_eq!(to_byte(0.5), 188);
}

#[test]
fn a_flat_patch_is_one_byte_plain_but_two_dithered() {
    let mut c = canvas(16, 16);
    fill(&mut c, color(0.5, 0.5, 0.5));
    assert_eq!(distinct_values(canvas_to_p6(&c)), 1);
    assert_eq!(distinct_values(canvas_to_p6_dithered(&c)), 2);
}
