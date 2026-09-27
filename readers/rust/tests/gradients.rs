// features/chapter10-gradients.feature

use renderer::{
    approx_eq, color, conic_gradient, conic_t, linear_gradient, linear_t, paint_at, point, radial_gradient,
    radial_t,
};

#[test]
fn a_linear_gradients_parameter_is_the_distance_along_its_axis() {
    let g = linear_gradient(point(10.0, 10.0), point(110.0, 10.0), vec![], "pad");
    assert!(approx_eq(linear_t(&g, 10.0, 10.0), 0.0));
    assert!(approx_eq(linear_t(&g, 35.0, 10.0), 0.25));
    assert!(approx_eq(linear_t(&g, 60.0, 10.0), 0.5));
    assert!(approx_eq(linear_t(&g, 110.0, 10.0), 1.0));
}

#[test]
fn distance_across_the_axis_does_not_change_the_parameter() {
    let g = linear_gradient(point(10.0, 10.0), point(110.0, 10.0), vec![], "pad");
    assert!(approx_eq(linear_t(&g, 60.0, 10.0), 0.5));
    assert!(approx_eq(linear_t(&g, 60.0, 50.0), 0.5));
}

#[test]
fn a_linear_gradients_colour_along_the_axis_is_the_parameter_itself() {
    use renderer::{colors_eq, stop};
    let g = linear_gradient(
        point(0.0, 0.0),
        point(100.0, 0.0),
        vec![stop(0.0, color(0.0, 0.0, 0.0)), stop(1.0, color(1.0, 1.0, 1.0))],
        "pad",
    );
    assert!(colors_eq(paint_at(&g, 25.0, 0.0), color(0.25, 0.25, 0.25)));
    assert!(colors_eq(paint_at(&g, 50.0, 0.0), color(0.5, 0.5, 0.5)));
}

#[test]
fn a_concentric_radial_gradients_parameter_is_distance_over_radius() {
    let g = radial_gradient(point(50.0, 50.0), 0.0, point(50.0, 50.0), 40.0, vec![], "pad");
    assert!(approx_eq(radial_t(&g, 50.0, 50.0).unwrap(), 0.0));
    assert!(approx_eq(radial_t(&g, 70.0, 50.0).unwrap(), 0.5));
    assert!(approx_eq(radial_t(&g, 90.0, 50.0).unwrap(), 1.0));
}

#[test]
fn a_focal_gradient_runs_from_the_focal_point_to_the_end_circle() {
    let g = radial_gradient(point(35.0, 50.0), 0.0, point(50.0, 50.0), 40.0, vec![], "pad");
    assert!(approx_eq(radial_t(&g, 35.0, 50.0).unwrap(), 0.0));
    assert!(approx_eq(radial_t(&g, 90.0, 50.0).unwrap(), 1.0));
}

#[test]
fn a_conic_gradient_sweeps_the_angle_around_its_center() {
    let g = conic_gradient(point(50.0, 50.0), -std::f64::consts::PI / 2.0, vec![], "pad");
    assert!(approx_eq(conic_t(&g, 50.0, 10.0), 0.0));
    assert!(approx_eq(conic_t(&g, 90.0, 50.0), 0.25));
    assert!(approx_eq(conic_t(&g, 50.0, 90.0), 0.5));
    assert!(approx_eq(conic_t(&g, 10.0, 50.0), 0.75));
}

#[test]
fn when_both_roots_are_valid_the_larger_one_wins() {
    let g = radial_gradient(point(0.0, 0.0), 10.0, point(30.0, 0.0), 12.0, vec![], "pad");
    assert!(renderer::approx_eq_eps(radial_t(&g, 5.0, 0.0).unwrap(), 0.535714, 0.0001));
    assert!(renderer::approx_eq_eps(radial_t(&g, 15.0, 0.0).unwrap(), 0.892857, 0.0001));
    assert!(renderer::approx_eq_eps(radial_t(&g, 20.0, 0.0).unwrap(), 1.071429, 0.0001));
}
