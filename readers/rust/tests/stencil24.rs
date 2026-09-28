// features/chapter24-stencil.feature

use renderer::{
    cover, coverage_at, fan_anchor, plate_glyph, point, polygon, star, stencil_at, stencil_buffer,
    triangle_winding, winding_mismatches,
};

#[test]
fn one_triangle_either_way_round() {
    assert_eq!(triangle_winding(point(0.0, 0.0), point(4.0, 0.0), point(0.0, 4.0), 1.0, 1.0), 1);
    assert_eq!(triangle_winding(point(0.0, 0.0), point(0.0, 4.0), point(4.0, 0.0), 1.0, 1.0), -1);
    assert_eq!(triangle_winding(point(0.0, 0.0), point(4.0, 0.0), point(0.0, 4.0), 3.0, 3.0), 0);
}

#[test]
fn a_square_as_four_signed_triangles() {
    let sq = polygon(&[point(1.0, 1.0), point(5.0, 1.0), point(5.0, 5.0), point(1.0, 5.0)]);
    let s = stencil_buffer(&sq, 6, 6);
    assert_eq!(fan_anchor(&sq), point(1.0, 1.0));
    let expected: Vec<i64> = vec![
        0, 0, 0, 0, 0, 0, //
        0, 1, 1, 1, 1, 0, //
        0, 1, 1, 1, 1, 0, //
        0, 1, 1, 1, 1, 0, //
        0, 1, 1, 1, 1, 0, //
        0, 0, 0, 0, 0, 0,
    ];
    assert_eq!(s.values, expected);
    assert_eq!(s.fragments, 16);
}

#[test]
fn the_stencil_is_chapter_5s_winding_number_at_every_pixel() {
    let s = stencil_buffer(&star(), 160, 160);
    let g = stencil_buffer(&plate_glyph(), 200, 200);
    assert_eq!(winding_mismatches(&s, &star()), 0);
    assert_eq!(winding_mismatches(&g, &plate_glyph()), 0);
    assert_eq!(stencil_at(&s, 80, 80), 2);
    assert_eq!(stencil_at(&s, 80, 30), 1);
    assert_eq!(stencil_at(&s, 5, 5), 0);
    assert_eq!(s.fragments, 13660);
    assert_eq!(g.fragments, 22639);
}

#[test]
fn cover_keeps_what_the_rule_fills() {
    let s = stencil_buffer(&star(), 160, 160);
    assert_eq!(coverage_at(&cover(&s, "nonzero"), 80, 80), 1.0);
    assert_eq!(coverage_at(&cover(&s, "evenodd"), 80, 80), 0.0);
    assert_eq!(coverage_at(&cover(&s, "evenodd"), 80, 30), 1.0);
}
