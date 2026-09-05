// features/chapter01-ppm.feature

use renderer::{
    canvas, canvas_to_ppm, color, distinct_values, max_channel_difference, ppm_lines, ppm_pixel,
    write_pixel,
};

#[test]
fn the_ppm_header() {
    let c = canvas(5, 3);
    let ppm = canvas_to_ppm(&c);
    let lines = ppm_lines(&ppm);
    assert_eq!(&lines[0..3], &["P3", "5 3", "255"]);
}

#[test]
fn pixel_values_are_encoded_not_scaled() {
    let mut c = canvas(3, 1);
    write_pixel(&mut c, 0, 0, color(1.0, 0.0, 0.0));
    write_pixel(&mut c, 1, 0, color(0.0, 0.5, 0.0));
    write_pixel(&mut c, 2, 0, color(0.0, 0.0, 0.216));
    let ppm = canvas_to_ppm(&c);
    let lines = ppm_lines(&ppm);
    assert_eq!(lines[3], "255 0 0 0 188 0 0 0 128");
}

#[test]
fn colors_out_of_range_are_clamped_not_wrapped() {
    let mut c = canvas(2, 1);
    write_pixel(&mut c, 0, 0, color(1.5, 0.0, -0.5));
    let ppm = canvas_to_ppm(&c);
    let lines = ppm_lines(&ppm);
    assert_eq!(lines[3], "255 0 0 0 0 0");
}

#[test]
fn every_row_starts_a_new_line_and_no_line_exceeds_70_characters() {
    let mut c = canvas(10, 2);
    renderer::fill(&mut c, color(1.0, 0.8, 0.6));
    let ppm = canvas_to_ppm(&c);
    let lines = ppm_lines(&ppm);
    let expected = [
        "255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231",
        "203 255 231 203 255 231 203 255 231 203 255 231 203",
        "255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231",
        "203 255 231 203 255 231 203 255 231 203 255 231 203",
    ];
    assert_eq!(&lines[3..7], &expected);
    for line in &lines {
        assert!(line.len() <= 70, "line too long ({}): {:?}", line.len(), line);
    }
}

#[test]
fn a_line_of_exactly_70_characters_is_allowed() {
    let mut c = canvas(8, 1);
    renderer::fill(&mut c, color(1.0, 0.1, 0.0));
    write_pixel(&mut c, 7, 0, color(1.0, 1.0, 1.0));
    let ppm = canvas_to_ppm(&c);
    let lines = ppm_lines(&ppm);
    let expected =
        ["255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 255", "255"];
    assert_eq!(&lines[3..5], &expected);
    assert_eq!(lines[3].len(), 70);
}

#[test]
fn the_file_ends_with_a_newline() {
    let c = canvas(5, 3);
    let ppm = canvas_to_ppm(&c);
    assert!(ppm.ends_with('\n'));
}

#[test]
fn reading_a_pixel_back_out_of_the_text() {
    let mut c = canvas(3, 2);
    write_pixel(&mut c, 2, 1, color(0.0, 0.5, 1.0));
    let ppm = canvas_to_ppm(&c);
    assert_eq!(ppm_pixel(&ppm, 2, 1), (0, 188, 255));
    assert_eq!(ppm_pixel(&ppm, 1, 1), (0, 0, 0));
}

#[test]
fn counting_the_distinct_values_in_a_file() {
    let mut c = canvas(3, 1);
    write_pixel(&mut c, 0, 0, color(1.0, 0.0, 0.0));
    write_pixel(&mut c, 1, 0, color(0.0, 0.5, 0.0));
    write_pixel(&mut c, 2, 0, color(0.0, 0.0, 0.216));
    let ppm = canvas_to_ppm(&c);
    assert_eq!(distinct_values(&ppm), 4);
}

#[test]
fn comparing_two_files() {
    let c1 = canvas(2, 1);
    let mut c2 = canvas(2, 1);
    write_pixel(&mut c2, 0, 0, color(0.5, 0.0, 0.0));
    let ppm1 = canvas_to_ppm(&c1);
    let ppm2 = canvas_to_ppm(&c2);
    assert_eq!(max_channel_difference(&ppm1, &ppm1), 0);
    assert_eq!(max_channel_difference(&ppm1, &ppm2), 188);
}

#[test]
fn files_of_different_sizes_are_as_different_as_it_gets() {
    let c1 = canvas(5, 3);
    let c2 = canvas(3, 5);
    let ppm1 = canvas_to_ppm(&c1);
    let ppm2 = canvas_to_ppm(&c2);
    assert_eq!(max_channel_difference(&ppm1, &ppm2), 255);
}

#[test]
fn the_same_width_with_a_different_height_is_still_a_different_size() {
    let c1 = canvas(5, 3);
    let c2 = canvas(5, 4);
    let ppm1 = canvas_to_ppm(&c1);
    let ppm2 = canvas_to_ppm(&c2);
    assert_eq!(max_channel_difference(&ppm1, &ppm2), 255);
}
