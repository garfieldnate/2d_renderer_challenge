// features/chapter20-paint.feature

use renderer::{
    approx_eq, color, colors_eq, colors_eq_eps, gradient_stops, identity, linear_gradient, paint_at, paint_server,
    parse_xml, point, scaling, stop, transformed_paint, translation, Color, Stop,
};

fn assert_color(actual: Color, expected: Color) {
    assert!(colors_eq(actual, expected), "expected {expected:?}, got {actual:?}");
}

fn assert_stop(actual: Stop, expected: Stop) {
    assert!(approx_eq(actual.offset, expected.offset), "expected {expected:?}, got {actual:?}");
    assert_color(actual.color, expected.color);
}

const BOX: (f64, f64, f64, f64) = (10.0, 0.0, 30.0, 10.0);

#[test]
fn a_paint_seen_through_a_matrix() {
    let g = linear_gradient(
        point(0.0, 0.0),
        point(1.0, 0.0),
        vec![stop(0.0, color(0.0, 0.0, 0.0)), stop(1.0, color(1.0, 1.0, 1.0))],
        "pad",
    );
    assert_color(paint_at(&transformed_paint(g.clone(), scaling(10.0, 1.0)), 5.0, 0.0), color(0.5, 0.5, 0.5));
    assert_color(
        paint_at(&transformed_paint(g, translation(10.0, 0.0) * scaling(10.0, 1.0)), 12.5, 3.0),
        color(0.25, 0.25, 0.25),
    );
}

#[test]
fn stops_are_fractions_never_going_backwards_and_only_stop_children_count() {
    let root = parse_xml("<linearGradient><stop offset='50%' style='stop-color: red'/><stop offset='20%' stop-color='blue'/><circle/><stop offset='1.5' stop-color='lime'/></linearGradient>");
    let stops = gradient_stops(&root);
    assert_eq!(stops.len(), 3);
    assert_stop(stops[0], stop(0.5, color(1.0, 0.0, 0.0)));
    assert_stop(stops[1], stop(0.5, color(0.0, 0.0, 1.0)));
    assert_stop(stops[2], stop(1.0, color(0.0, 1.0, 0.0)));
}

#[test]
fn objectboundingbox_spreads_the_gradient_across_the_shapes_bounds() {
    let root = parse_xml("<svg><linearGradient id='a'><stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/></linearGradient></svg>");
    let p = paint_server(&root, "url(#a)", BOX, identity()).unwrap();
    assert_color(paint_at(&p, 10.0, 5.0), color(0.0, 0.0, 0.0));
    assert_color(paint_at(&p, 15.0, 5.0), color(0.25, 0.25, 0.25));
    assert_color(paint_at(&p, 20.0, 5.0), color(0.5, 0.5, 0.5));
    assert_color(paint_at(&p, 30.0, 5.0), color(1.0, 1.0, 1.0));
    assert_color(
        paint_at(&paint_server(&root, "url(#a)", BOX, scaling(2.0, 2.0)).unwrap(), 40.0, 10.0),
        color(0.5, 0.5, 0.5),
    );
}

#[test]
fn userspaceonuse_leaves_the_coordinates_in_user_space() {
    let root = parse_xml("<svg><linearGradient id='u' gradientUnits='userSpaceOnUse' x1='0' y1='0' x2='100' y2='0'><stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/></linearGradient></svg>");
    assert_color(paint_at(&paint_server(&root, "url(#u)", BOX, identity()).unwrap(), 50.0, 5.0), color(0.5, 0.5, 0.5));
    assert_color(
        paint_at(&paint_server(&root, "url(#u)", BOX, scaling(2.0, 2.0)).unwrap(), 100.0, 0.0),
        color(0.5, 0.5, 0.5),
    );
}

#[test]
fn gradienttransform_applies_inside_the_bounding_boxs_square() {
    let root = parse_xml("<svg><linearGradient id='t' gradientTransform='rotate(90)'><stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/></linearGradient></svg>");
    let p = paint_server(&root, "url(#t)", BOX, identity()).unwrap();
    assert_color(paint_at(&p, 20.0, 2.5), color(0.25, 0.25, 0.25));
    assert_color(paint_at(&p, 11.0, 5.0), color(0.5, 0.5, 0.5));
}

#[test]
fn spreadmethod_is_the_extend_mode() {
    let root = parse_xml("<svg><linearGradient id='r' x2='0.25' spreadMethod='reflect'><stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/></linearGradient><linearGradient id='p' x2='25%' spreadMethod='repeat'><stop offset='0' stop-color='black'/><stop offset='1' stop-color='white'/></linearGradient></svg>");
    let r = paint_server(&root, "url(#r)", BOX, identity()).unwrap();
    let p = paint_server(&root, "url(#p)", BOX, identity()).unwrap();
    assert_color(paint_at(&r, 17.5, 5.0), color(0.5, 0.5, 0.5));
    assert_color(paint_at(&r, 20.0, 5.0), color(0.0, 0.0, 0.0));
    assert_color(paint_at(&r, 22.5, 5.0), color(0.5, 0.5, 0.5));
    assert_color(paint_at(&p, 19.9, 5.0), color(0.98, 0.98, 0.98));
    assert_color(paint_at(&p, 20.1, 5.0), color(0.02, 0.02, 0.02));
}

#[test]
fn a_radial_gradient_centred_and_focal() {
    let root = parse_xml("<svg><radialGradient id='c'><stop offset='0' stop-color='white'/><stop offset='1' stop-color='black'/></radialGradient><radialGradient id='f' fx='0.25'><stop offset='0' stop-color='white'/><stop offset='1' stop-color='black'/></radialGradient></svg>");
    let c = paint_server(&root, "url(#c)", BOX, identity()).unwrap();
    let f = paint_server(&root, "url(#f)", BOX, identity()).unwrap();
    assert_color(paint_at(&c, 20.0, 5.0), color(1.0, 1.0, 1.0));
    assert_color(paint_at(&c, 25.0, 5.0), color(0.5, 0.5, 0.5));
    assert_color(paint_at(&c, 20.0, 0.0), color(0.0, 0.0, 0.0));
    assert_color(paint_at(&f, 15.0, 5.0), color(1.0, 1.0, 1.0));
    let v = paint_at(&f, 17.5, 5.0);
    assert!(colors_eq_eps(v, color(0.8333, 0.8333, 0.8333), 0.0001), "{v:?}");
}

#[test]
fn when_theres_nothing_to_paint_with_and_when_theres_one_colour() {
    let root = parse_xml("<svg><linearGradient id='one'><stop offset='0.3' stop-color='red'/></linearGradient><linearGradient id='empty'/><linearGradient id='same' x2='0'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient><clipPath id='k'/><linearGradient id='a'><stop offset='0'/><stop offset='1' stop-color='white'/></linearGradient></svg>");
    assert_color(paint_at(&paint_server(&root, "url(#one)", BOX, identity()).unwrap(), 0.0, 0.0), color(1.0, 0.0, 0.0));
    assert_color(paint_at(&paint_server(&root, "url(#same)", BOX, identity()).unwrap(), 15.0, 5.0), color(0.0, 0.0, 1.0));
    assert!(paint_server(&root, "url(#empty)", BOX, identity()).is_none());
    assert!(paint_server(&root, "url(#k)", BOX, identity()).is_none());
    assert!(paint_server(&root, "url(#missing)", BOX, identity()).is_none());
    assert!(paint_server(&root, "url(#a)", (0.0, 0.0, 10.0, 0.0), identity()).is_none());
}
