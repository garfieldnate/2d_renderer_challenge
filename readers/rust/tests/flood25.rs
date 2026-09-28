// features/chapter25-flood.feature

use renderer::{
    anti_alias_mask, bytes_at, canvas, color, fill, fill_stats, flood_mask, ink, naive_depth,
    ring_canvas, select_color, write_pixel,
};

#[test]
fn the_rings_pixels() {
    let c = ring_canvas();
    assert_eq!(bytes_at(&c, 80, 80), (246, 243, 234));
    assert_eq!(bytes_at(&c, 80, 20), (63, 63, 80));
    assert_eq!(bytes_at(&c, 142, 80), (246, 243, 234));
}

#[test]
fn tolerance_decides_how_much_of_the_antialiased_edge_the_bucket_takes() {
    let c = ring_canvas();
    assert_eq!(ink(&flood_mask(&c, 80, 80, 0, 4, &mut fill_stats())), 10324.0);
    assert_eq!(ink(&flood_mask(&c, 80, 80, 32, 4, &mut fill_stats())), 10484.0);
    assert_eq!(ink(&flood_mask(&c, 80, 80, 160, 4, &mut fill_stats())), 10700.0);
    assert_eq!(ink(&flood_mask(&c, 80, 80, 254, 4, &mut fill_stats())), 25600.0);
    assert_eq!(ink(&anti_alias_mask(&flood_mask(&c, 80, 80, 32, 4, &mut fill_stats()))), 10648.0);
    assert_eq!(ink(&select_color(&c, 80, 80, 0)), 23636.0);
}

#[test]
fn eight_way_connectivity_leaks_through_a_diagonal() {
    let mut c = canvas(3, 3);
    fill(&mut c, color(1.0, 1.0, 1.0));
    write_pixel(&mut c, 1, 0, color(0.0, 0.0, 0.0));
    write_pixel(&mut c, 0, 1, color(0.0, 0.0, 0.0));
    assert_eq!(ink(&flood_mask(&c, 0, 0, 0, 4, &mut fill_stats())), 1.0);
    assert_eq!(ink(&flood_mask(&c, 0, 0, 0, 8, &mut fill_stats())), 7.0);
}

#[test]
fn recursion_goes_as_deep_as_the_region_is_big_the_scanline_stack_doesnt() {
    let mut fs = fill_stats();
    let m = flood_mask(&canvas(200, 200), 0, 0, 0, 4, &mut fs);
    assert_eq!(ink(&m), 40000.0);
    assert_eq!(fs.pushes, 200);
    assert_eq!(fs.deepest, 1);
    assert_eq!(naive_depth(4, 3), 12);
    assert_eq!(naive_depth(200, 200), 40000);
}
