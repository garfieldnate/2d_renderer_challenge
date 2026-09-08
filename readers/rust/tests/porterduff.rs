// features/chapter09-porterduff.feature

use renderer::{color, composite, from_color, opaque, over, pixel, pixels_eq, CLEAR};

#[test]
fn each_operator_is_its_two_coefficients() {
    let src = from_color(color(1.0, 0.0, 0.0), 0.6);
    let dst = from_color(color(0.0, 0.0, 1.0), 0.4);

    let cases: [(&str, f64, f64, f64, f64); 12] = [
        ("clear", 0.0, 0.0, 0.0, 0.0),
        ("src", 0.6, 0.0, 0.0, 0.6),
        ("dst", 0.0, 0.0, 0.4, 0.4),
        ("src-over", 0.6, 0.0, 0.16, 0.76),
        ("dst-over", 0.36, 0.0, 0.4, 0.76),
        ("src-in", 0.24, 0.0, 0.0, 0.24),
        ("dst-in", 0.0, 0.0, 0.24, 0.24),
        ("src-out", 0.36, 0.0, 0.0, 0.36),
        ("dst-out", 0.0, 0.0, 0.16, 0.16),
        ("src-atop", 0.24, 0.0, 0.16, 0.4),
        ("dst-atop", 0.36, 0.0, 0.24, 0.6),
        ("xor", 0.36, 0.0, 0.16, 0.52),
    ];

    for (op, r, g, b, a) in cases {
        let got = composite(op, src, dst);
        assert!(pixels_eq(got, pixel(r, g, b, a)), "op {op}: expected {r},{g},{b},{a}, got {got:?}");
    }
}

#[test]
fn src_over_is_over_and_dst_over_is_over_swapped() {
    let src = from_color(color(1.0, 0.0, 0.0), 0.6);
    let dst = from_color(color(0.0, 0.0, 1.0), 0.4);
    assert!(pixels_eq(composite("src-over", src, dst), over(src, dst)));
    assert!(pixels_eq(composite("dst-over", src, dst), over(dst, src)));
}

#[test]
fn clear_empties_the_pixel_and_dst_keeps_it() {
    let src = opaque(color(1.0, 0.0, 0.0));
    let dst = opaque(color(0.0, 0.0, 1.0));
    assert!(pixels_eq(composite("clear", src, dst), CLEAR));
    assert!(pixels_eq(composite("dst", src, dst), dst));
    assert!(pixels_eq(composite("src", src, dst), src));
}
