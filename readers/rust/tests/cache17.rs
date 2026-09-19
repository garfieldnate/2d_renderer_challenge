// features/chapter17-cache.feature

use renderer::{
    approx_eq_eps, atlas, atlas_add, bitmap, cache_size, cached_bitmap, coverage_at,
    coverage_buffer, glyph_bitmap, glyph_cache, ink, load_font, read_file,
};

fn font() -> renderer::Font {
    load_font(read_file("reference/chapter-16/roboto.json"))
}

#[test]
fn a_cache_hit_is_the_identical_bitmap() {
    let f = font();
    let mut cache = glyph_cache();
    let a = cached_bitmap(&mut cache, &f, "H", 11.0, 0);
    let b = cached_bitmap(&mut cache, &f, "H", 11.0, 0);
    assert_eq!(cache_size(&cache), 1);
    assert_eq!(renderer::max_coverage_difference(&a.coverage, &b.coverage), 0.0);
    assert_eq!(a.left, b.left);
    assert!(approx_eq_eps(ink(&a.coverage), 19.495859, 0.0001));
}

#[test]
fn a_different_quarter_or_size_is_a_different_entry() {
    let f = font();
    let mut cache = glyph_cache();
    let a = cached_bitmap(&mut cache, &f, "H", 11.0, 0);
    let b = cached_bitmap(&mut cache, &f, "H", 11.0, 1);
    let _c = cached_bitmap(&mut cache, &f, "H", 12.0, 0);
    assert_eq!(cache_size(&cache), 3);
    assert_eq!(b.left, 1);
    assert!((ink(&b.coverage) - ink(&a.coverage)).abs() < 0.0001);
}

#[test]
fn shelf_packing_places_bitmaps_left_to_right_then_opens_a_new_shelf() {
    let mut a = atlas(32, 32);
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(10, 8), 0, 0)), Some((0, 0)));
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(20, 8), 0, 0)), Some((10, 0)));
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(8, 8), 0, 0)), Some((0, 8)));
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(40, 5), 0, 0)), None);
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(30, 20), 0, 0)), None);
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(2, 2), 0, 0)), Some((0, 16)));
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(31, 2), 0, 0)), Some((0, 18)));
}

#[test]
fn a_taller_bitmap_that_fits_the_width_stays_on_the_shelf_and_raises_it() {
    let mut a = atlas(32, 32);
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(10, 8), 0, 0)), Some((0, 0)));
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(12, 12), 0, 0)), Some((10, 0)));
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(10, 4), 0, 0)), Some((22, 0)));
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(5, 5), 0, 0)), Some((0, 12)));
}

#[test]
fn a_bitmap_the_atlas_can_never_hold_leaves_the_shelf_alone() {
    let mut a = atlas(32, 32);
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(10, 8), 0, 0)), Some((0, 0)));
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(40, 5), 0, 0)), None);
    assert_eq!(atlas_add(&mut a, &bitmap(coverage_buffer(10, 8), 0, 0)), Some((10, 0)));
}

#[test]
fn the_atlas_holds_the_bitmaps_coverage_where_it_said() {
    let f = font();
    let mut a = atlas(32, 32);
    let h = glyph_bitmap(&f, "H", 11.0, 0);
    let at = atlas_add(&mut a, &h);
    let ga = glyph_bitmap(&f, "a", 11.0, 0);
    let at2 = atlas_add(&mut a, &ga);
    assert_eq!(at, Some((0, 0)));
    assert_eq!(at2, Some((7, 0)));
    assert_eq!(coverage_at(&a.coverage, 1, 3), coverage_at(&h.coverage, 1, 3));
    assert_eq!(coverage_at(&a.coverage, 8, 3), coverage_at(&ga.coverage, 1, 3));
}
