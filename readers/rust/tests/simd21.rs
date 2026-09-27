// features/chapter21-simd.feature

use renderer::{color, composite_span, composite_span4, layer, layer_pixel, layers_equal, pixel, pixels_eq, set_layer_pixel};

#[test]
fn a_coverage_of_0_is_an_exact_no_op_and_1_is_an_exact_copy() {
    let mut l = layer(4, 1);
    set_layer_pixel(&mut l, 0, 0, pixel(0.1, 0.2, 0.3, 0.5));
    set_layer_pixel(&mut l, 1, 0, pixel(0.1, 0.2, 0.3, 0.5));
    set_layer_pixel(&mut l, 2, 0, pixel(0.1, 0.2, 0.3, 0.5));
    composite_span(&mut l, 0, 0, &[0.0, 1.0, 0.5], color(0.8, 0.4, 0.2));
    assert!(pixels_eq(layer_pixel(&l, 0, 0), pixel(0.1, 0.2, 0.3, 0.5)));
    assert!(pixels_eq(layer_pixel(&l, 1, 0), pixel(0.8, 0.4, 0.2, 1.0)));
    assert!(pixels_eq(layer_pixel(&l, 2, 0), pixel(0.45, 0.3, 0.25, 0.75)));
    assert!(pixels_eq(layer_pixel(&l, 3, 0), pixel(0.0, 0.0, 0.0, 0.0)));
}

#[test]
fn four_at_a_time_gives_the_same_numbers_the_leftover_pixels_included() {
    let mut a = layer(12, 1);
    let mut b = layer(12, 1);
    set_layer_pixel(&mut a, 4, 0, pixel(0.1, 0.2, 0.3, 0.5));
    set_layer_pixel(&mut b, 4, 0, pixel(0.1, 0.2, 0.3, 0.5));
    set_layer_pixel(&mut a, 10, 0, pixel(0.05, 0.1, 0.02, 0.2));
    set_layer_pixel(&mut b, 10, 0, pixel(0.05, 0.1, 0.02, 0.2));
    let ks = [0.0, 1.0, 0.5, 0.25, 0.1, 0.9, 0.0, 1.0, 0.3, 0.7, 0.05];
    composite_span(&mut a, 0, 1, &ks, color(0.8, 0.4, 0.2));
    composite_span4(&mut b, 0, 1, &ks, color(0.8, 0.4, 0.2));
    assert!(layers_equal(&a, &b));
    assert!(pixels_eq(layer_pixel(&b, 4, 0), pixel(0.275, 0.25, 0.275, 0.625)));
    assert!(pixels_eq(layer_pixel(&b, 11, 0), pixel(0.04, 0.02, 0.01, 0.05)));
    assert!(pixels_eq(layer_pixel(&b, 0, 0), pixel(0.0, 0.0, 0.0, 0.0)));
}
