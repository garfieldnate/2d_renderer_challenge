// features/chapter23-plate.feature

use renderer::{
    atlas_corners, canvas_to_p6, error_map, fields_vs_paths, fillets, max_channel_difference,
    plate_23, ppm_pixel, primitive_fields, read_file, title, trap_shrink, transform_demo,
};

fn assert_pixel(p6: &[u8], x: usize, y: usize, expected: (i64, i64, i64), tol: i64) {
    let actual = ppm_pixel(p6, x, y);
    assert!(
        (actual.0 - expected.0).abs() <= tol
            && (actual.1 - expected.1).abs() <= tol
            && (actual.2 - expected.2).abs() <= tol,
        "pixel ({x},{y}): expected {expected:?} +/- {tol}, got {actual:?}"
    );
}

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
    check_render(primitive_fields, "reference/chapter-23/primitive-fields.ppm", 640, 160);
    check_render(error_map, "reference/chapter-23/error-map.ppm", 480, 160);
    check_render(fields_vs_paths, "reference/chapter-23/fields-vs-paths.ppm", 600, 400);
    check_render(fillets, "reference/chapter-23/fillets.ppm", 640, 160);
    check_render(transform_demo, "reference/chapter-23/transform-demo.ppm", 576, 192);
    check_render(atlas_corners, "reference/chapter-23/atlas-corners.ppm", 1200, 400);
    check_render(trap_shrink, "reference/chapter-23/trap-shrink.ppm", 340, 160);
    check_render(title, "reference/chapter-23/title.ppm", 900, 220);
}

#[test]
fn what_the_renders_show() {
    let bands = canvas_to_p6(&primitive_fields());
    let errors = canvas_to_p6(&error_map());
    let both = canvas_to_p6(&fields_vs_paths());
    let fil = canvas_to_p6(&fillets());
    let atlas = canvas_to_p6(&atlas_corners());
    let shrunk = canvas_to_p6(&trap_shrink());

    assert_pixel(&bands, 80, 80, (57, 92, 101), 1);
    assert_pixel(&bands, 80, 30, (185, 188, 184), 1);
    assert_pixel(&bands, 560, 80, (145, 117, 62), 1);
    assert_pixel(&errors, 80, 80, (243, 196, 89), 1);
    assert_pixel(&errors, 240, 58, (180, 95, 149), 1);
    assert_pixel(&errors, 400, 58, (39, 39, 44), 1);
    assert_pixel(&both, 529, 114, (243, 196, 89), 1);
    assert_pixel(&both, 529, 314, (243, 196, 89), 1);
    assert_pixel(&both, 529, 75, (39, 39, 44), 1);
    assert_pixel(&fil, 98, 63, (39, 39, 44), 1);
    assert_pixel(&fil, 578, 63, (243, 196, 89), 1);
    assert_pixel(&atlas, 78, 83, (39, 39, 44), 1);
    assert_pixel(&atlas, 378, 83, (243, 196, 89), 1);
    assert_pixel(&shrunk, 85, 80, (39, 39, 44), 1);
    assert_pixel(&shrunk, 255, 80, (243, 196, 89), 1);
}

#[test]
fn plate_23_test() {
    let c = plate_23();
    let ref_ppm = read_file("reference/chapter-23/plate-23.ppm");
    let p6 = canvas_to_p6(&c);
    assert_eq!(c.width, 800);
    assert_eq!(c.height, 200);
    assert_pixel(&p6, 3, 3, (99, 82, 52), 1);
    assert_pixel(&p6, 206, 3, (39, 39, 44), 1);
    assert_pixel(&p6, 283, 45, (243, 196, 89), 1);
    assert_pixel(&p6, 606, 100, (45, 40, 48), 1);
    assert!(max_channel_difference(&p6, &ref_ppm) <= 1);
}
