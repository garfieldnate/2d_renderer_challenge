// features/chapter01-srgb.feature

use renderer::{approx_eq, approx_eq_eps, decode, encode, round};

// Scenario Outline: Encoding light into a file value
macro_rules! encode_case {
    ($name:ident, $light:expr, $value:expr) => {
        #[test]
        fn $name() {
            assert!(approx_eq(encode($light), $value));
        }
    };
}

encode_case!(encode_0_0, 0.0, 0.0);
encode_case!(encode_0_0025, 0.0025, 0.0323);
encode_case!(encode_0_0031308, 0.0031308, 0.0405);
encode_case!(encode_0_01, 0.01, 0.0999);
encode_case!(encode_0_1, 0.1, 0.3492);
encode_case!(encode_0_216, 0.216, 0.5021);
encode_case!(encode_0_25, 0.25, 0.5371);
encode_case!(encode_0_5, 0.5, 0.7354);
encode_case!(encode_0_75, 0.75, 0.8808);
encode_case!(encode_1_0, 1.0, 1.0);

// Scenario Outline: Decoding a file value into light
macro_rules! decode_case {
    ($name:ident, $value:expr, $light:expr) => {
        #[test]
        fn $name() {
            assert!(approx_eq(decode($value), $light));
        }
    };
}

decode_case!(decode_0_0, 0.0, 0.0);
decode_case!(decode_0_04, 0.04, 0.0031);
decode_case!(decode_0_04045, 0.04045, 0.0031);
decode_case!(decode_0_05, 0.05, 0.0039);
decode_case!(decode_0_1, 0.1, 0.0100);
decode_case!(decode_0_5, 0.5, 0.2140);
decode_case!(decode_0_75, 0.75, 0.5225);
decode_case!(decode_1_0, 1.0, 1.0);

#[test]
fn decode_undoes_encode() {
    let l = 0.2;
    assert!(approx_eq_eps(decode(encode(l)), 0.2, 0.000000001));
}

#[test]
fn encode_undoes_decode() {
    let v = 0.7;
    assert!(approx_eq_eps(encode(decode(v)), 0.7, 0.000000001));
}

#[test]
fn the_half_gray_that_isnt_128() {
    assert_eq!(round(encode(0.5) * 255.0), 188);
}

#[test]
fn what_128_actually_is() {
    assert!(approx_eq(decode(128.0 / 255.0), 0.2159));
}
