// features/chapter23-compose.feature

use renderer::{approx_eq_eps, combine, min_of, peanut, point, sd_polygon};

#[test]
fn min_is_right_outside_and_wrong_inside() {
    let (a, b) = peanut();
    let u = combine(&a, "nonzero", &b, "nonzero", "union");

    assert!(approx_eq_eps(
        min_of(sd_polygon(point(85.0, 20.0), &a, "nonzero"), sd_polygon(point(85.0, 20.0), &b, "nonzero")),
        25.000200,
        0.001
    ));
    assert!(approx_eq_eps(sd_polygon(point(85.0, 20.0), &u, "nonzero"), 24.998, 0.001));

    assert!(approx_eq_eps(
        min_of(sd_polygon(point(85.0, 80.0), &a, "nonzero"), sd_polygon(point(85.0, 80.0), &b, "nonzero")),
        -14.992,
        0.001
    ));
    assert!(approx_eq_eps(sd_polygon(point(85.0, 80.0), &u, "nonzero"), -31.203, 0.001));

    assert!(approx_eq_eps(
        min_of(sd_polygon(point(60.0, 80.0), &a, "nonzero"), sd_polygon(point(60.0, 80.0), &b, "nonzero")),
        -39.979,
        0.001
    ));
    assert!(approx_eq_eps(sd_polygon(point(60.0, 80.0), &u, "nonzero"), -39.978, 0.001));
}
