// features/chapter23-transform.feature

use renderer::{
    approx_eq, bits_of, coverage_of, distance_transform, edt_1d, far_value, field_at,
    field_from_coverage, field_range, transform_bitmap,
};

#[test]
fn one_row() {
    let big = far_value(5, 1);
    assert_eq!(big, 26.0);
    assert_eq!(edt_1d(&[0.0, big, big, 0.0, big]), vec![0.0, 1.0, 1.0, 0.0, 1.0]);
    assert_eq!(edt_1d(&[big, big, big, big, 0.0]), vec![16.0, 9.0, 4.0, 1.0, 0.0]);
    assert_eq!(edt_1d(&[4.0, big, 0.0, big, big]), vec![4.0, 1.0, 0.0, 1.0, 4.0]);
}

#[test]
fn columns_then_rows() {
    let bits = [
        false, false, false, false, false, false, false, false, false, false, false, false, true,
        false, false, false, false, false, false, false, false, false, false, false, false,
    ];
    assert_eq!(
        distance_transform(&bits, 5, 5),
        vec![
            8.0, 5.0, 4.0, 5.0, 8.0, 5.0, 2.0, 1.0, 2.0, 5.0, 4.0, 1.0, 0.0, 1.0, 4.0, 5.0, 2.0,
            1.0, 2.0, 5.0, 8.0, 5.0, 4.0, 5.0, 8.0,
        ]
    );
    assert_eq!(
        distance_transform(&[false, false, false, false, false, false], 3, 2),
        vec![13.0, 13.0, 13.0, 13.0, 13.0, 13.0]
    );
}

#[test]
fn the_transform_matches_trying_every_pixel_exactly() {
    let bits = bits_of(&transform_bitmap());
    assert_eq!(distance_transform(&bits, 64, 64), renderer::brute_distance_transform(&bits, 64, 64));
}

#[test]
fn any_coverage_becomes_a_field() {
    let cov = transform_bitmap();
    let f = field_from_coverage(&cov);
    assert_eq!(
        field_from_coverage(&coverage_of(4, 1, &[0.0, 0.4, 0.6, 1.0])).values,
        vec![1.5, 0.5, -0.5, -1.5]
    );
    assert!(approx_eq(field_at(&f, 0, 0), 27.784271));
    let (lo, hi) = field_range(&f);
    assert!(approx_eq(lo, -2.5));
    assert!(approx_eq(hi, 31.702484));
}
