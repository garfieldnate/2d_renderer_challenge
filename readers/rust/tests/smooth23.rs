// features/chapter23-smooth.feature

use renderer::{approx_eq, field_at, field_smooth_union, fillet_field, smooth_min};

#[test]
fn far_apart_its_min_close_together_its_less() {
    assert_eq!(smooth_min(1.0, 5.0, 2.0), 1.0);
    assert_eq!(smooth_min(3.0, 3.0, 4.0), 2.0);
    assert!(approx_eq(smooth_min(2.0, 3.0, 4.0), 1.4375));
    assert_eq!(smooth_min(2.0, 3.0, 0.0), 2.0);
}

#[test]
fn the_fillet_fills_the_crease() {
    let sharp = fillet_field(0.0);
    let filleted = fillet_field(32.0);
    assert!(approx_eq(field_at(&sharp, 98, 63), 3.044846));
    assert!(approx_eq(field_at(&filleted, 98, 63), -3.320843));
    assert_eq!(field_at(&sharp, 60, 70), field_at(&filleted, 60, 70));
    assert_eq!(
        field_smooth_union(&fillet_field(0.0), &fillet_field(0.0), 0.0).values,
        fillet_field(0.0).values
    );
}
