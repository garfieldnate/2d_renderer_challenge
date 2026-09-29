// features/chapter23-atlas.feature

use renderer::{
    approx_eq, bake_msdf, bake_mtsdf, bake_sdf, circle_curves, color_edges, field_at, glyph_name,
    is_corner, line_curve, load_font, median3, point, pseudo_distance, read_file, sample_field,
    vector,
};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn the_box_a_glyph_is_baked_into() {
    let f = font();
    let name = glyph_name(&f, 69);
    let b = bake_sdf(&f, &name, 16.0, 3.0);
    assert_eq!(b.left, -2);
    assert_eq!(b.top, -15);
    assert_eq!(b.width, 14);
    assert_eq!(b.height, 18);
    assert_eq!(field_at(&b.channels[0], 0, 0), 3.0);
    assert!(approx_eq(field_at(&b.channels[0], 4, 9), -0.401566));
}

#[test]
fn a_space_has_no_edges_so_every_texel_is_as_far_out_as_the_clamp_allows() {
    let f = font();
    let b = bake_mtsdf(&f, "space", 16.0, 3.0);
    assert_eq!(b.left, -3);
    assert_eq!(b.top, -3);
    assert_eq!(b.width, 6);
    assert_eq!(b.height, 6);
    assert_eq!(field_at(&b.channels[0], 0, 0), 3.0);
    assert_eq!(field_at(&b.channels[1], 2, 3), 3.0);
    assert_eq!(field_at(&b.channels[2], 5, 5), 3.0);
    assert_eq!(field_at(&b.channels[3], 2, 3), 3.0);
}

#[test]
fn what_a_corner_is() {
    assert!(is_corner(vector(1.0, 0.0), vector(0.0, 1.0)));
    assert!(is_corner(vector(1.0, 0.0), vector(-1.0, 0.0)));
    assert!(!is_corner(vector(1.0, 0.0), vector(0.995004165, 0.099833417)));
    assert!(is_corner(vector(1.0, 0.0), vector(0.980066578, 0.198669331)));
}

#[test]
fn colouring_edges() {
    let sq = vec![
        line_curve(point(0.0, 0.0), point(10.0, 0.0)),
        line_curve(point(10.0, 0.0), point(10.0, 10.0)),
        line_curve(point(10.0, 10.0), point(0.0, 10.0)),
        line_curve(point(0.0, 10.0), point(0.0, 0.0)),
    ];
    let tri = vec![
        line_curve(point(0.0, 0.0), point(10.0, 0.0)),
        line_curve(point(10.0, 0.0), point(5.0, 8.0)),
        line_curve(point(5.0, 8.0), point(0.0, 0.0)),
    ];
    let house = vec![
        line_curve(point(0.0, 0.0), point(10.0, 0.0)),
        line_curve(point(10.0, 0.0), point(10.0, 10.0)),
        line_curve(point(10.0, 10.0), point(5.0, 15.0)),
        line_curve(point(5.0, 15.0), point(0.0, 10.0)),
        line_curve(point(0.0, 10.0), point(0.0, 0.0)),
    ];
    let drop = vec![
        renderer::quadratic(point(0.0, 0.0), point(20.0, -20.0), point(30.0, 0.0)),
        renderer::quadratic(point(30.0, 0.0), point(40.0, 20.0), point(20.0, 20.0)),
        renderer::quadratic(point(20.0, 20.0), point(0.0, 20.0), point(0.0, 0.0)),
    ];
    assert_eq!(color_edges(&sq).1, vec![6, 5, 6, 5]);
    assert_eq!(color_edges(&tri).1, vec![6, 5, 3]);
    assert_eq!(color_edges(&house).1, vec![6, 5, 6, 5, 3]);
    assert_eq!(color_edges(&drop).1, vec![6, 7, 5]);
    assert_eq!(color_edges(&circle_curves(50.0, 50.0, 40.0)).1, vec![7, 7, 7, 7, 7, 7, 7, 7]);
}

#[test]
fn pseudo_distance_runs_straight_on_past_an_end() {
    let e = line_curve(point(0.0, 0.0), point(10.0, 0.0));
    assert_eq!(pseudo_distance(point(5.0, 3.0), &e, 0.5, 3.0), -3.0);
    assert_eq!(pseudo_distance(point(5.0, -3.0), &e, 0.5, 3.0), 3.0);
    assert_eq!(pseudo_distance(point(14.0, 3.0), &e, 1.0, 5.0), -3.0);
    assert_eq!(pseudo_distance(point(-4.0, -3.0), &e, 0.0, 5.0), 3.0);
}

#[test]
fn a_texels_own_value_is_at_its_center() {
    let f = renderer::field_of(3, 2, vec![0.0, 4.0, 8.0, 2.0, 6.0, 10.0]);
    assert_eq!(sample_field(&f, 1.5, 0.5), 4.0);
    assert_eq!(sample_field(&f, 1.0, 0.5), 2.0);
    assert_eq!(sample_field(&f, 1.5, 1.0), 5.0);
    assert_eq!(sample_field(&f, 0.0, 0.0), 0.0);
    assert_eq!(sample_field(&f, 9.0, 9.0), 10.0);
}

#[test]
fn the_median() {
    assert_eq!(median3(1.0, 5.0, 3.0), 3.0);
    assert_eq!(median3(-2.0, 4.0, -1.0), -1.0);
    assert_eq!(median3(7.0, 7.0, 2.0), 7.0);
}

#[test]
fn three_channels_at_one_texel() {
    let f = font();
    let name = glyph_name(&f, 69);
    let m = bake_msdf(&f, &name, 16.0, 3.0);
    assert!(approx_eq(field_at(&m.channels[0], 4, 9), -0.320313));
    assert!(approx_eq(field_at(&m.channels[1], 4, 9), -0.242188));
    assert!(approx_eq(field_at(&m.channels[2], 4, 9), -0.320313));
}
