// features/chapter21-spans.feature

use renderer::{
    color, draw_coverage, draw_tiled, fill_path, fill_path_tiled, layer, layer_pixel, layers_equal, pixel, pixels_eq,
    point, polygon, solid, stats,
};

fn sq(a: f64, b: f64) -> renderer::Path {
    polygon(&[point(a, a), point(b, a), point(b, b), point(a, b)])
}

#[test]
fn a_solid_opaque_colour_copies_its_solid_tiles_and_blends_its_edges() {
    let t = fill_path_tiled(&sq(4.0, 60.0), "nonzero", 64, 64, &mut stats());
    let mut st = stats();
    let mut l = layer(64, 64);
    draw_tiled(&mut l, &t, &solid(color(1.0, 0.0, 0.0)), 1.0, &mut st);
    assert_eq!(st.copies, 1024);
    assert_eq!(st.blends, 2112);
    assert!(pixels_eq(layer_pixel(&l, 30, 30), pixel(1.0, 0.0, 0.0, 1.0)));
    assert!(pixels_eq(layer_pixel(&l, 2, 2), pixel(0.0, 0.0, 0.0, 0.0)));
}

#[test]
fn the_copies_draw_exactly_what_blending_would_have() {
    let s = sq(4.5, 59.5);
    let mut a = layer(64, 64);
    let mut b = layer(64, 64);
    draw_tiled(&mut a, &fill_path_tiled(&s, "nonzero", 64, 64, &mut stats()), &solid(color(0.2, 0.6, 0.9)), 1.0, &mut stats());
    draw_coverage(&mut b, &fill_path(&s, "nonzero", 64, 64), &solid(color(0.2, 0.6, 0.9)), 1.0);
    assert!(layers_equal(&a, &b));
}

#[test]
fn at_half_alpha_nothing_is_copied() {
    let t = fill_path_tiled(&sq(4.0, 60.0), "nonzero", 64, 64, &mut stats());
    let mut st = stats();
    let mut l = layer(64, 64);
    draw_tiled(&mut l, &t, &solid(color(1.0, 0.0, 0.0)), 0.5, &mut st);
    assert_eq!(st.copies, 0);
    assert_eq!(st.blends, 3136);
    assert!(pixels_eq(layer_pixel(&l, 30, 30), pixel(0.5, 0.0, 0.0, 0.5)));
}
