// features/chapter24-plate.feature

use renderer::{canvas_to_p6, max_channel_difference, msaa_demo, plate_24, ppm_pixel, read_file, spill_map, tiger_assembly};

fn check_render(render: impl Fn() -> renderer::Canvas, file: &str, w: usize, h: usize) {
    let c = render();
    let ref_ppm = read_file(file);
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, w, "width for {file}");
    assert_eq!(c.height, h, "height for {file}");
    assert!(max_channel_difference(&p6, &ref_ppm) <= 1, "render mismatch for {file}");
}

#[test]
fn each_render_matches_its_reference() {
    check_render(plate_24, "reference/chapter-24/plate-24.ppm", 400, 200);
    check_render(msaa_demo, "reference/chapter-24/msaa-demo.ppm", 192, 480);
    check_render(spill_map, "reference/chapter-24/spill-map.ppm", 810, 400);
    check_render(tiger_assembly, "reference/chapter-24/tiger-assembly.ppm", 900, 900);
}

fn assert_pixel(p6: &[u8], x: usize, y: usize, expected: (i64, i64, i64), tol: i64) {
    let actual = ppm_pixel(p6, x, y);
    assert!(
        (actual.0 - expected.0).abs() <= tol && (actual.1 - expected.1).abs() <= tol && (actual.2 - expected.2).abs() <= tol,
        "pixel ({x},{y}): expected {expected:?} +/- {tol}, got {actual:?}"
    );
}

#[test]
fn what_the_plate_shows() {
    let p6 = canvas_to_p6(&plate_24());
    assert_pixel(&p6, 100, 100, (233, 187, 86), 1);
    assert_pixel(&p6, 100, 40, (173, 139, 69), 1);
    assert_pixel(&p6, 5, 5, (39, 39, 44), 1);
    assert_pixel(&p6, 241, 46, (202, 187, 140), 1);
    assert_pixel(&p6, 258, 46, (195, 157, 75), 1);
    assert_pixel(&p6, 258, 100, (184, 97, 152), 1);
}

#[test]
fn what_the_other_renders_show() {
    let msaa = canvas_to_p6(&msaa_demo());
    let spills = canvas_to_p6(&spill_map());
    assert_pixel(&msaa, 10, 10, (39, 39, 44), 1);
    assert_pixel(&msaa, 10, 90, (243, 196, 89), 1);
    assert_pixel(&spills, 415, 5, (39, 39, 44), 1);
    assert_pixel(&spills, 605, 50, (237, 124, 196), 1);
}
