// features/chapter24-shader.feature

use renderer::{color, point, radial_gradient, shade_tile, stop};

#[test]
fn a_gradient_asked_in_any_order_is_the_same_gradient() {
    let g = radial_gradient(
        point(20.0, 20.0),
        0.0,
        point(40.0, 30.0),
        50.0,
        vec![stop(0.0, color(1.0, 0.0, 0.0)), stop(1.0, color(0.0, 0.0, 1.0))],
        "pad",
    );
    let a = shade_tile(&g, 1, 2, None);
    let b = shade_tile(&g, 1, 2, Some(5));
    assert_eq!(a, b);
    assert!(renderer::colors_eq(a[0], color(0.735942, 0.0, 0.264058)));
    assert!(renderer::colors_eq(a[255], color(0.539754, 0.0, 0.460246)));
}
