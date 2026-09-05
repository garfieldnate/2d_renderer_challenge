// features/chapter01-gray-match.feature

use renderer::{
    canvas_to_ppm, color, colors_eq, count_pixels, gray_match, max_channel_difference, pixel_at,
    ppm_pixel, quarter_match, read_file,
};

#[test]
fn the_gray_match() {
    let c = gray_match();
    assert_eq!(c.width, 300);
    assert_eq!(c.height, 100);
    assert!(colors_eq(pixel_at(&c, 0, 0), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 1, 0), color(0.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_at(&c, 0, 1), color(0.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_at(&c, 1, 1), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 150, 50), color(0.2159, 0.2159, 0.2159)));
    assert!(colors_eq(pixel_at(&c, 250, 50), color(0.5, 0.5, 0.5)));
    assert_eq!(count_pixels(&c, color(1.0, 1.0, 1.0)), 5000);
}

#[test]
fn the_gray_match_as_a_file() {
    let c = gray_match();
    let ppm = canvas_to_ppm(&c);
    assert_eq!(ppm_pixel(&ppm, 0, 0), (255, 255, 255));
    assert_eq!(ppm_pixel(&ppm, 1, 0), (0, 0, 0));
    assert_eq!(ppm_pixel(&ppm, 150, 50), (128, 128, 128));
    assert_eq!(ppm_pixel(&ppm, 250, 50), (188, 188, 188));

    let reference = read_file("reference/chapter-01/gray-match.ppm");
    assert!(max_channel_difference(&ppm, &reference) <= 1);
}

#[test]
fn one_pixel_in_four() {
    let c = quarter_match();
    assert_eq!(c.width, 200);
    assert_eq!(c.height, 100);
    assert!(colors_eq(pixel_at(&c, 0, 0), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 1, 0), color(0.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_at(&c, 2, 2), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 3, 1), color(1.0, 1.0, 1.0)));
    assert!(colors_eq(pixel_at(&c, 150, 50), color(0.25, 0.25, 0.25)));
    assert_eq!(count_pixels(&c, color(1.0, 1.0, 1.0)), 2500);

    let ppm = canvas_to_ppm(&c);
    assert_eq!(ppm_pixel(&ppm, 150, 50), (137, 137, 137));

    let reference = read_file("reference/chapter-01/quarter-match.ppm");
    assert!(max_channel_difference(&ppm, &reference) <= 1);
}
