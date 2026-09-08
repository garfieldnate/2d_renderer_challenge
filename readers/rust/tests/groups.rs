// features/chapter12-groups.feature

use renderer::{
    color, fill_path, layer, layer_pixel, opaque, paint_into, pixel, pixels_eq, point, polygon,
    pop_group_with_opacity, push_group, scale_opacity, set_layer_pixel,
};

#[test]
fn scale_opacity_lowers_a_layers_premultiplied_channels_together() {
    let mut g = layer(1, 1);
    set_layer_pixel(&mut g, 0, 0, opaque(color(1.0, 0.0, 0.0)));
    let h = scale_opacity(&g, 0.5);
    assert!(pixels_eq(layer_pixel(&h, 0, 0), pixel(0.5, 0.0, 0.0, 0.5)));
}

#[test]
fn a_group_at_opacity_1_is_drawing_its_children_directly() {
    let a = polygon(&[point(2.0, 2.0), point(12.0, 2.0), point(12.0, 12.0), point(2.0, 12.0)]);
    let b = polygon(&[point(6.0, 6.0), point(16.0, 6.0), point(16.0, 16.0), point(6.0, 16.0)]);
    let ca = fill_path(&a, "nonzero", 20, 20);
    let cb = fill_path(&b, "nonzero", 20, 20);

    let direct = paint_into(
        &paint_into(&layer(20, 20), &ca, color(1.0, 0.0, 0.0), 1.0),
        &cb,
        color(0.0, 0.0, 1.0),
        1.0,
    );
    let group = paint_into(
        &paint_into(&push_group(20, 20), &ca, color(1.0, 0.0, 0.0), 1.0),
        &cb,
        color(0.0, 0.0, 1.0),
        1.0,
    );
    let grouped = pop_group_with_opacity(&group, &layer(20, 20), 1.0);

    assert!(pixels_eq(layer_pixel(&grouped, 8, 8), layer_pixel(&direct, 8, 8)));
    assert!(pixels_eq(layer_pixel(&grouped, 3, 3), layer_pixel(&direct, 3, 3)));
    assert!(pixels_eq(layer_pixel(&grouped, 14, 14), layer_pixel(&direct, 14, 14)));
}

#[test]
fn below_opacity_1_a_group_and_per_child_opacity_part_ways_at_overlaps() {
    let a = polygon(&[point(2.0, 2.0), point(12.0, 2.0), point(12.0, 12.0), point(2.0, 12.0)]);
    let b = polygon(&[point(6.0, 6.0), point(16.0, 6.0), point(16.0, 16.0), point(6.0, 16.0)]);
    let ca = fill_path(&a, "nonzero", 20, 20);
    let cb = fill_path(&b, "nonzero", 20, 20);

    let perchild = paint_into(
        &paint_into(&layer(20, 20), &ca, color(1.0, 0.0, 0.0), 0.5),
        &cb,
        color(0.0, 0.0, 1.0),
        0.5,
    );
    let group = paint_into(
        &paint_into(&push_group(20, 20), &ca, color(1.0, 0.0, 0.0), 1.0),
        &cb,
        color(0.0, 0.0, 1.0),
        1.0,
    );
    let grouped = pop_group_with_opacity(&group, &layer(20, 20), 0.5);

    assert!(pixels_eq(layer_pixel(&grouped, 3, 3), layer_pixel(&perchild, 3, 3)));
    assert!(!pixels_eq(layer_pixel(&grouped, 8, 8), layer_pixel(&perchild, 8, 8)));
}
