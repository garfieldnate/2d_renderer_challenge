// features/chapter12-mask.feature

use renderer::{coverage_at, fill_path, multiply_coverage, point, polygon, soft_mask};

#[test]
fn a_soft_mask_fades_from_its_center_to_its_edge() {
    let m = soft_mask(6.0, 6.0, 5.0, 12, 12);
    assert!((coverage_at(&m, 5, 5) - 0.8586).abs() < 0.0001);
    assert!((coverage_at(&m, 1, 6) - 0.0945).abs() < 0.0001);
    assert!((coverage_at(&m, 0, 0) - 0.0).abs() < 0.0001);
}

#[test]
fn a_shape_multiplied_by_a_soft_mask_keeps_its_interior_and_fades_its_rim() {
    let shape = fill_path(
        &polygon(&[point(0.0, 0.0), point(12.0, 0.0), point(12.0, 12.0), point(0.0, 12.0)]),
        "nonzero",
        12,
        12,
    );
    let m = soft_mask(6.0, 6.0, 5.0, 12, 12);
    let masked = multiply_coverage(&shape, &m);
    assert!((coverage_at(&masked, 5, 5) - 0.8586).abs() < 0.0001);
    assert!((coverage_at(&masked, 0, 0) - 0.0).abs() < 0.0001);
}
