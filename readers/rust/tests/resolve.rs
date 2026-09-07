// features/chapter07-resolve.feature

use renderer::{accumulate, accumulator, apply_rule, approx_eq, coverage_at, point, resolve};

#[test]
fn apply_rule_turns_a_winding_number_into_coverage() {
    assert!(approx_eq(apply_rule(0.0, "nonzero"), 0.0));
    assert!(approx_eq(apply_rule(1.0, "nonzero"), 1.0));
    assert!(approx_eq(apply_rule(0.25, "nonzero"), 0.25));
    assert!(approx_eq(apply_rule(-0.25, "nonzero"), 0.25));
    assert!(approx_eq(apply_rule(1.5, "nonzero"), 1.0));
    assert!(approx_eq(apply_rule(2.0, "nonzero"), 1.0));
    assert!(approx_eq(apply_rule(0.25, "evenodd"), 0.25));
    assert!(approx_eq(apply_rule(0.75, "evenodd"), 0.75));
    assert!(approx_eq(apply_rule(1.25, "evenodd"), 0.75));
    assert!(approx_eq(apply_rule(1.5, "evenodd"), 0.5));
    assert!(approx_eq(apply_rule(2.0, "evenodd"), 0.0));
    assert!(approx_eq(apply_rule(3.25, "evenodd"), 0.75));
    assert!(approx_eq(apply_rule(-1.5, "evenodd"), 0.5));
}

#[test]
fn resolve_turns_one_deposited_edge_into_a_half_covered_column() {
    let mut acc = accumulator(4, 3);
    accumulate(&mut acc, point(1.5, 3.0), point(1.5, 0.0));
    let cov = resolve(&acc, "nonzero");
    assert!(approx_eq(coverage_at(&cov, 0, 0), 0.0));
    assert!(approx_eq(coverage_at(&cov, 1, 0), 0.5));
    assert!(approx_eq(coverage_at(&cov, 2, 0), 1.0));
    assert!(approx_eq(coverage_at(&cov, 3, 0), 1.0));
}
