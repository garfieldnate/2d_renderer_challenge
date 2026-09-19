// features/chapter16-composites.feature

use renderer::{
    component_matrix, glyph_bounds, glyph_outline, identity, load_font, matrices_eq, point,
    read_file, tuples_eq,
};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

fn assert_bounds(actual: (f64, f64, f64, f64), expected: (f64, f64, f64, f64)) {
    assert!(
        renderer::approx_eq(actual.0, expected.0)
            && renderer::approx_eq(actual.1, expected.1)
            && renderer::approx_eq(actual.2, expected.2)
            && renderer::approx_eq(actual.3, expected.3),
        "bounds: expected {expected:?}, got {actual:?}"
    );
}

#[test]
fn a_component_transform_is_a_matrix() {
    assert!(tuples_eq(
        component_matrix([1.0, 0.0, 0.0, 1.0, 340.0, 0.0]) * point(5.0, 5.0),
        point(345.0, 5.0)
    ));
    assert!(tuples_eq(
        component_matrix([2.0, 0.0, 0.0, 1.0, 10.0, 0.0]) * point(3.0, 4.0),
        point(16.0, 4.0)
    ));
    assert!(tuples_eq(
        component_matrix([1.0, 0.5, 0.0, 1.0, 0.0, 0.0]) * point(2.0, 4.0),
        point(2.0, 5.0)
    ));
    assert!(tuples_eq(
        component_matrix([1.0, 0.0, 0.5, 1.0, 0.0, 0.0]) * point(2.0, 4.0),
        point(4.0, 4.0)
    ));
    assert!(matrices_eq(&component_matrix([1.0, 0.0, 0.0, 1.0, 0.0, 0.0]), &identity()));
}

#[test]
fn eacute_is_an_e_and_an_acute_moved_right() {
    let f = font();
    let g = &f.glyphs["eacute"];
    assert_eq!(g.contours.len(), 0);
    assert_eq!(g.components.len(), 2);
    assert_eq!(g.components[0].glyph, "e");
    assert_eq!(g.components[1].glyph, "acute");
    assert_eq!(g.components[1].transform, [1.0, 0.0, 0.0, 1.0, 340.0, 0.0]);

    assert_eq!(glyph_outline(&f, "eacute").len(), 3);
    assert_eq!(glyph_outline(&f, "e").len(), 2);
    assert_eq!(glyph_outline(&f, "acute").len(), 1);
}

#[test]
fn a_composites_bounds_are_the_union_of_its_transformed_components() {
    let f = font();
    assert_bounds(glyph_bounds(&f, "e"), (93.0, -20.0, 1011.0, 1102.0));
    assert_bounds(glyph_bounds(&f, "acute"), (123.0, 1240.0, 540.0, 1534.0));
    assert_bounds(glyph_bounds(&f, "eacute"), (93.0, -20.0, 1011.0, 1534.0));
    assert_bounds(glyph_bounds(&f, "aring"), (109.0, -20.0, 1002.0, 1627.0));
    assert_bounds(glyph_bounds(&f, "space"), (0.0, 0.0, 0.0, 0.0));
}

#[test]
fn bounds_are_tight_not_the_control_box() {
    let f = font();
    assert_bounds(glyph_bounds(&f, "o"), (91.0, -20.0, 1076.0, 1102.0));
    assert_bounds(glyph_bounds(&f, "H"), (169.0, 0.0, 1288.0, 1456.0));
}

#[test]
fn a_font_can_be_written_by_hand_and_a_bumps_bounds_stop_where_the_curve_does() {
    let tiny = load_font(
        r#"{"units_per_em": 1000, "ascender": 800, "descender": -200, "line_gap": 0, "cmap": {"98": "bump"}, "glyphs": {"bump": {"advance": 300, "contours": [[[0, 0, true], [100, 200, false], [200, 0, true]]], "components": []}, "twice": {"advance": 600, "contours": [], "components": [{"glyph": "bump", "transform": [1, 0, 0, 1, 0, 0]}, {"glyph": "bump", "transform": [1, 0, 0.5, 2, 300, 0]}]}}}"#,
    );
    assert_eq!(renderer::glyph_count(&tiny), 2);
    assert_eq!(renderer::glyph_name(&tiny, 98), "bump");
    assert_eq!(glyph_outline(&tiny, "bump").len(), 1);
    assert_eq!(glyph_outline(&tiny, "bump")[0].len(), 2);
    assert_bounds(glyph_bounds(&tiny, "bump"), (0.0, 0.0, 200.0, 100.0));
    assert_bounds(glyph_bounds(&tiny, "twice"), (0.0, 0.0, 500.0, 200.0));
}
