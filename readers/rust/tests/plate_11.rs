// features/chapter11-plate.feature

use renderer::{canvas_to_p6, max_channel_difference, mip_chain, plate_11, ppm_pixel, read_file, sprite, three_filters, two_filters};

fn assert_pixel_within(p6: &[u8], x: usize, y: usize, expected: (i64, i64, i64), tol: i64) {
    let actual = ppm_pixel(p6, x, y);
    assert!(
        (actual.0 - expected.0).abs() <= tol
            && (actual.1 - expected.1).abs() <= tol
            && (actual.2 - expected.2).abs() <= tol,
        "pixel ({x},{y}): expected {expected:?} ± {tol}, got {actual:?}"
    );
}

#[test]
fn the_sprite_round_trips_through_a_ppm() {
    let s = sprite();
    assert_eq!(s.width, 8);
    assert_eq!(s.height, 8);
    assert_eq!(mip_chain(&s).len(), 4);
}

#[test]
fn two_filters_nearest_against_bilinear() {
    let c = two_filters();
    let reference = read_file("reference/chapter-11/two-filters.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 160);
    assert_pixel_within(&p6, 50, 50, (249, 247, 237), 1);
    assert_pixel_within(&p6, 10, 10, (69, 69, 80), 1);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn plate_11_test() {
    let c = plate_11();
    let reference = read_file("reference/chapter-11/plate-11.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 320);
    assert_eq!(c.height, 160);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}

#[test]
fn three_filters_adding_bicubic() {
    let c = three_filters();
    let reference = read_file("reference/chapter-11/three-filters.ppm");
    let p6 = canvas_to_p6(&c);

    assert_eq!(c.width, 384);
    assert_eq!(c.height, 128);
    assert!(max_channel_difference(&p6, &reference) <= 1);
}
