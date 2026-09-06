// features/chapter06-spans.feature

use renderer::{
    close, coverage_at, coverage_buffer, crossings_on_row, edge_table, fill_span, ink, line_to,
    move_to, path, point, polygon, spans, spans_from_crossings, star,
};

fn assert_pairs(actual: &[(f64, f64)], expected: &[(f64, f64)]) {
    assert_eq!(actual.len(), expected.len(), "expected {expected:?}, got {actual:?}");
    for (a, e) in actual.iter().zip(expected.iter()) {
        assert!(
            renderer::approx_eq(a.0, e.0) && renderer::approx_eq(a.1, e.1),
            "expected {expected:?}, got {actual:?}"
        );
    }
}

fn assert_crossings(actual: &[(f64, i64)], expected: &[(f64, i64)]) {
    assert_eq!(actual.len(), expected.len(), "expected {expected:?}, got {actual:?}");
    for (a, e) in actual.iter().zip(expected.iter()) {
        assert!(renderer::approx_eq(a.0, e.0) && a.1 == e.1, "expected {expected:?}, got {actual:?}");
    }
}

#[test]
fn crossings_on_a_row_sorted_by_x() {
    let p = polygon(&[point(2.0, 2.0), point(6.0, 2.0), point(6.0, 6.0), point(2.0, 6.0)]);
    let t = edge_table(&p);
    assert_crossings(&crossings_on_row(&t, 3.5), &[(2.0, -1), (6.0, 1)]);
    assert_crossings(&crossings_on_row(&t, 1.5), &[]);
    assert_crossings(&crossings_on_row(&t, 6.0), &[]);
    assert_eq!(crossings_on_row(&t, 2.0).len(), 2);
}

#[test]
fn the_stars_crossings_through_its_middle() {
    let p = star();
    let t = edge_table(&p);
    let xs = crossings_on_row(&t, 80.5);
    assert_crossings(&xs, &[(43.6988, -1), (57.7556, -1), (103.2444, 1), (117.3012, 1)]);
}

#[test]
fn spans_from_crossings_under_each_rule() {
    let xs = vec![(1.0, 1), (3.0, 1), (5.0, -1), (7.0, -1)];
    assert_pairs(&spans_from_crossings(&xs, "nonzero"), &[(1.0, 7.0)]);
    assert_pairs(&spans_from_crossings(&xs, "evenodd"), &[(1.0, 3.0), (5.0, 7.0)]);
    assert_pairs(&spans_from_crossings(&[], "nonzero"), &[]);
}

#[test]
fn the_spans_of_an_axis_aligned_rectangle_are_exact() {
    let p = polygon(&[point(1.25, 2.0), point(4.75, 2.0), point(4.75, 5.0), point(1.25, 5.0)]);
    assert_pairs(&spans(&p, "nonzero", 1), &[]);
    assert_pairs(&spans(&p, "nonzero", 2), &[(1.25, 4.75)]);
    assert_pairs(&spans(&p, "nonzero", 4), &[(1.25, 4.75)]);
    assert_pairs(&spans(&p, "nonzero", 5), &[]);
}

#[test]
fn a_rectangle_whose_edges_sit_on_sample_heights() {
    let p = polygon(&[point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5)]);
    assert_pairs(&spans(&p, "nonzero", 1), &[]);
    assert_pairs(&spans(&p, "nonzero", 2), &[(1.5, 4.5)]);
    assert_pairs(&spans(&p, "nonzero", 4), &[(1.5, 4.5)]);
    assert_pairs(&spans(&p, "nonzero", 5), &[]);
}

#[test]
fn a_triangles_spans_narrow_by_one_per_row() {
    let p = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(5.0, 10.0)]);
    let cases = [(0, 0.25, 9.75), (1, 0.75, 9.25), (4, 2.25, 7.75), (9, 4.75, 5.25)];
    for (row, x0, x1) in cases {
        assert_pairs(&spans(&p, "nonzero", row), &[(x0, x1)]);
    }
}

#[test]
fn the_row_past_the_triangles_apex_has_no_span() {
    let p = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(5.0, 10.0)]);
    assert_pairs(&spans(&p, "nonzero", 10), &[]);
}

#[test]
fn a_flat_top_is_not_a_span_of_its_own() {
    let p = polygon(&[point(0.0, 0.0), point(10.0, 0.0), point(10.0, 5.0), point(0.0, 5.0)]);
    assert_eq!(edge_table(&p).len(), 2);
    assert_pairs(&spans(&p, "nonzero", 0), &[(0.0, 10.0)]);
    assert_pairs(&spans(&p, "nonzero", 4), &[(0.0, 10.0)]);
    assert_pairs(&spans(&p, "nonzero", 5), &[]);
}

#[test]
fn a_ring_is_two_spans_under_even_odd_and_one_under_nonzero() {
    let mut p = path();
    move_to(&mut p, point(0.0, 0.0));
    line_to(&mut p, point(10.0, 0.0));
    line_to(&mut p, point(10.0, 10.0));
    line_to(&mut p, point(0.0, 10.0));
    close(&mut p);
    move_to(&mut p, point(3.0, 3.0));
    line_to(&mut p, point(7.0, 3.0));
    line_to(&mut p, point(7.0, 7.0));
    line_to(&mut p, point(3.0, 7.0));
    close(&mut p);

    assert_pairs(&spans(&p, "nonzero", 5), &[(0.0, 10.0)]);
    assert_pairs(&spans(&p, "evenodd", 5), &[(0.0, 3.0), (7.0, 10.0)]);
}

#[test]
fn the_stars_spans_through_its_middle() {
    let p = star();
    assert_pairs(&spans(&p, "nonzero", 80), &[(43.6988, 117.3012)]);
    assert_pairs(&spans(&p, "evenodd", 80), &[(43.6988, 57.7556), (103.2444, 117.3012)]);
}

#[test]
fn fill_span_fills_the_pixels_whose_centers_are_in_the_span() {
    let mut cov = coverage_buffer(8, 3);
    fill_span(&mut cov, 1, 1.25, 4.75);
    assert!(renderer::approx_eq(coverage_at(&cov, 0, 1), 0.0));
    assert!(renderer::approx_eq(coverage_at(&cov, 1, 1), 1.0));
    assert!(renderer::approx_eq(coverage_at(&cov, 4, 1), 1.0));
    assert!(renderer::approx_eq(coverage_at(&cov, 5, 1), 0.0));
    assert!(renderer::approx_eq(coverage_at(&cov, 2, 0), 0.0));
    assert!(renderer::approx_eq(ink(&cov), 4.0));
}

#[test]
fn the_span_is_half_open_at_its_right_end() {
    let mut cov = coverage_buffer(8, 3);
    fill_span(&mut cov, 1, 1.5, 4.5);
    assert!(renderer::approx_eq(coverage_at(&cov, 1, 1), 1.0));
    assert!(renderer::approx_eq(coverage_at(&cov, 3, 1), 1.0));
    assert!(renderer::approx_eq(coverage_at(&cov, 4, 1), 0.0));
    assert!(renderer::approx_eq(ink(&cov), 3.0));
}

#[test]
fn a_span_may_run_off_either_side_of_the_buffer() {
    let mut a = coverage_buffer(8, 3);
    let mut b = coverage_buffer(8, 3);
    let mut c = coverage_buffer(8, 3);
    fill_span(&mut a, 1, -3.0, 2.5);
    fill_span(&mut b, 1, 6.5, 20.0);
    fill_span(&mut c, 1, 2.5, 2.5);

    assert!(renderer::approx_eq(ink(&a), 2.0));
    assert!(renderer::approx_eq(coverage_at(&a, 1, 1), 1.0));
    assert!(renderer::approx_eq(ink(&b), 2.0));
    assert!(renderer::approx_eq(coverage_at(&b, 6, 1), 1.0));
    assert!(renderer::approx_eq(ink(&c), 0.0));
}
