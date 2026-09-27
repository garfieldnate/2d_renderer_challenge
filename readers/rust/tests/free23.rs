// features/chapter23-free.feature

use renderer::{
    combine, cubic_field, field_coverage, field_difference, field_intersection, field_of,
    field_offset, field_stroke, field_union, field_xor, fill_path, ink, max_coverage_difference,
    plate_glyph, plate_glyph_field, plate_star, polygon_field, s_curve, star, stroke_curve_to_path,
    stroke_to_path, transform_path, translation,
};

#[test]
fn one_line_each() {
    let a = field_of(3, 1, vec![-2.0, 1.0, 3.0]);
    let b = field_of(3, 1, vec![1.0, -4.0, 2.0]);
    assert_eq!(field_union(&a, &b).values, vec![-2.0, -4.0, 2.0]);
    assert_eq!(field_intersection(&a, &b).values, vec![1.0, 1.0, 3.0]);
    assert_eq!(field_difference(&a, &b).values, vec![-1.0, 4.0, 3.0]);
    assert_eq!(field_xor(&a, &b).values, vec![-1.0, -1.0, 2.0]);
    assert_eq!(field_offset(&a, 2.0).values, vec![-4.0, -1.0, 1.0]);
    assert_eq!(field_stroke(&a, 2.0).values, vec![1.0, 0.0, 2.0]);
}

#[test]
fn a_stroke_by_field_and_chapter_13s_round_stroke() {
    let sp = transform_path(&star(), translation(19.5, 19.5));
    let by_path = fill_path(&stroke_to_path(&sp, 10.0, "round", "round", 4.0), "nonzero", 200, 200);
    let by_field = field_coverage(&field_stroke(&polygon_field(&sp, "nonzero", 200, 200), 10.0));
    assert!(max_coverage_difference(&by_path, &by_field) <= 0.42);
    assert!(renderer::approx_eq(ink(&by_path), 5906.224083));
    assert!(renderer::approx_eq(ink(&by_field), 5901.860165));
}

#[test]
fn a_curves_stroke_by_field_and_chapter_14s() {
    let by_path =
        fill_path(&stroke_curve_to_path(&s_curve(), 20.0, "round", 0.05), "nonzero", 200, 200);
    let by_field = field_coverage(&field_stroke(&cubic_field(&s_curve(), 200, 200), 20.0));
    assert!(max_coverage_difference(&by_path, &by_field) <= 0.08);
    assert!(renderer::approx_eq_eps(ink(&by_field) - ink(&by_path), 4.120488, 0.001));
}

#[test]
fn chapter_22s_plate_by_field() {
    let by_path =
        fill_path(&combine(&plate_glyph(), "nonzero", &plate_star(), "evenodd", "xor"), "nonzero", 200, 200);
    let by_field =
        field_coverage(&field_xor(&plate_glyph_field(), &polygon_field(&plate_star(), "evenodd", 200, 200)));
    assert!(max_coverage_difference(&by_path, &by_field) <= 0.42);
    assert!(renderer::approx_eq_eps(ink(&by_field) - ink(&by_path), 2.279815, 0.001));
}
