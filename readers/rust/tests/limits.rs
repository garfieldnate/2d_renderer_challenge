// features/chapter01-limits.feature

use renderer::{
    canvas_to_ppm, clamp_pair, color, colors_eq, distinct_values, max_channel_difference,
    pixel_at, ppm_lines, ppm_pixel, ramp, read_file,
};

#[test]
fn a_256_step_ramp() {
    let c = ramp();
    assert_eq!(c.width, 256);
    assert_eq!(c.height, 32);
    assert!(colors_eq(pixel_at(&c, 0, 0), color(0.0, 0.0, 0.0)));
    assert!(colors_eq(pixel_at(&c, 128, 0), color(0.5020, 0.5020, 0.5020)));
    assert!(colors_eq(pixel_at(&c, 255, 31), color(1.0, 1.0, 1.0)));
}

#[test]
fn encoding_stretches_the_dark_end_and_squeezes_the_bright_end() {
    let c = ramp();
    let ppm = canvas_to_ppm(&c);
    let lines = ppm_lines(&ppm);
    assert_eq!(
        lines[3],
        "0 0 0 13 13 13 22 22 22 28 28 28 34 34 34 38 38 38 42 42 42 46 46 46"
    );
    assert_eq!(ppm_pixel(&ppm, 75, 0), (148, 148, 148));
    assert_eq!(ppm_pixel(&ppm, 76, 0), (148, 148, 148));
    assert_eq!(ppm_pixel(&ppm, 254, 0), (255, 255, 255));
    assert_eq!(distinct_values(&ppm), 183);

    let reference = read_file("reference/chapter-01/ramp.ppm");
    assert!(max_channel_difference(&ppm, &reference) <= 1);
}

#[test]
fn clamping_changes_the_color_not_only_the_brightness() {
    let c = clamp_pair();
    assert_eq!(c.width, 200);
    assert_eq!(c.height, 100);
    assert!(colors_eq(pixel_at(&c, 50, 50), color(2.0, 0.5, 0.5)));
    assert!(colors_eq(pixel_at(&c, 150, 50), color(1.0, 0.25, 0.25)));

    let ppm = canvas_to_ppm(&c);
    assert_eq!(ppm_pixel(&ppm, 50, 50), (255, 188, 188));
    assert_eq!(ppm_pixel(&ppm, 150, 50), (255, 137, 137));

    let reference = read_file("reference/chapter-01/clamp-pair.ppm");
    assert!(max_channel_difference(&ppm, &reference) <= 1);
}
