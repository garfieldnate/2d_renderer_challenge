// features/chapter10-extend.feature

use renderer::{approx_eq, extend};

#[test]
fn the_three_modes_fold_a_parameter_back_in() {
    let cases: [(f64, f64, f64, f64); 6] = [
        (0.3, 0.3, 0.3, 0.3),
        (-0.25, 0.0, 0.75, 0.25),
        (1.0, 1.0, 0.0, 1.0),
        (1.25, 1.0, 0.25, 0.75),
        (1.75, 1.0, 0.75, 0.25),
        (2.25, 1.0, 0.25, 0.25),
    ];
    for (t, pad, repeat, reflect) in cases {
        assert!(approx_eq(extend(t, "pad"), pad), "pad({t}): expected {pad}, got {}", extend(t, "pad"));
        assert!(
            approx_eq(extend(t, "repeat"), repeat),
            "repeat({t}): expected {repeat}, got {}",
            extend(t, "repeat")
        );
        assert!(
            approx_eq(extend(t, "reflect"), reflect),
            "reflect({t}): expected {reflect}, got {}",
            extend(t, "reflect")
        );
    }
}
