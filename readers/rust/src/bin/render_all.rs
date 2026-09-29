//! Renders every named figure and plate in the book to `out/`, as the
//! chapter that introduced them writes them: chapter 1's are P3 (the
//! book's writer at the time), chapter 2's are P6 (the writer it upgrades
//! to). `cargo run --release --bin render_all` from the package root.

use std::fs;
use std::path::Path;

use renderer::{
    atlas_corners, blend_strip, break_demo, canvas_to_p6, canvas_to_ppm, caps_demo, clamp_pair,
    clip_demo, composite_demo, dash_strip, disc_centers, disc_coverage, drift_demo,
    drops, error_map, even_marks, extend_strip, fan_bresenham, fan_both_orders, fan_coverage,
    fan_wu, fields_vs_paths, fillets, flip_trap, flower, fold_demo, forms_demo, glyph_plate,
    gray_match, joins_plate, kern_demo, lcd_plate, ligature_demo, mixed_demo, needles,
    offsets_plate, opacity_plate, painted_twice, plate_01, plate_02, plate_03, plate_04, plate_05,
    plate_06, plate_07, plate_08, plate_09, plate_10, plate_11, plate_12, plate_13, plate_14,
    plate_15, plate_16, plate_17, plate_18, plate_19, plate_22, plate_23,
    porter_duff_table, primitive_fields, quarter_match, ramp, seal, seam, sizes, smoothing_demo,
    soft_square, spiral, spiral_dashes, spiral_smooth, star_centers, star_coverage, star_exact,
    subpixel_strip, three_filters, three_gradients, title, trap_shrink, transform_demo,
    two_filters, two_strokes, word_demo,
    aspect_demo, harbor, rose, tiger, work_map, render_svg_with, stats, read_file,
    msaa_demo, plate_24, spill_map, tiger_assembly,
    brush_demo, dither_strip, halo_demo, paint_by_script, plate_25,
    book_cover, book_cover_glow, render_svg,
};
use std::time::Instant;

fn write_p3(dir: &Path, name: &str, ppm: String) {
    fs::write(dir.join(name), ppm).unwrap_or_else(|e| panic!("could not write {name}: {e}"));
}

fn write_p6(dir: &Path, name: &str, bytes: Vec<u8>) {
    fs::write(dir.join(name), bytes).unwrap_or_else(|e| panic!("could not write {name}: {e}"));
}

fn main() {
    let out = Path::new("out");
    fs::create_dir_all(out).expect("could not create out/");

    // Chapter 1: the book's reference images were still P3.
    write_p3(out, "gray-match.ppm", canvas_to_ppm(&gray_match()));
    write_p3(out, "quarter-match.ppm", canvas_to_ppm(&quarter_match()));
    write_p3(out, "ramp.ppm", canvas_to_ppm(&ramp()));
    write_p3(out, "clamp-pair.ppm", canvas_to_ppm(&clamp_pair()));
    write_p3(out, "plate-01.ppm", canvas_to_ppm(&plate_01()));

    // Chapter 2: P6 from here on.
    write_p6(out, "disc-centers.ppm", canvas_to_p6(&disc_centers()));
    write_p6(out, "disc-coverage.ppm", canvas_to_p6(&disc_coverage()));
    write_p6(out, "painted-twice.ppm", canvas_to_p6(&painted_twice()));
    write_p6(out, "plate-02.ppm", canvas_to_p6(&plate_02()));

    // Chapter 3: same P6 writer.
    write_p6(out, "fan-bresenham.ppm", canvas_to_p6(&fan_bresenham()));
    write_p6(out, "fan-wu.ppm", canvas_to_p6(&fan_wu()));
    write_p6(out, "fan-coverage.ppm", canvas_to_p6(&fan_coverage()));
    write_p6(out, "plate-03.ppm", canvas_to_p6(&plate_03()));

    // Chapter 4: same P6 writer again.
    write_p6(out, "fan-both-orders.ppm", canvas_to_p6(&fan_both_orders()));
    write_p6(out, "plate-04.ppm", canvas_to_p6(&plate_04()));

    // Chapter 5: paths and insideness.
    write_p6(out, "star-centers.ppm", canvas_to_p6(&star_centers()));
    write_p6(out, "star-coverage.ppm", canvas_to_p6(&star_coverage()));
    write_p6(out, "plate-05.ppm", canvas_to_p6(&plate_05()));

    // Chapter 6: the scanline sweep.
    write_p6(out, "spiral.ppm", canvas_to_p6(&spiral()));
    write_p6(out, "plate-06.ppm", canvas_to_p6(&plate_06()));

    // Chapter 7: analytic antialiasing.
    write_p6(out, "needles.ppm", canvas_to_p6(&needles()));
    write_p6(out, "soft-square.ppm", canvas_to_p6(&soft_square()));
    write_p6(out, "star-exact.ppm", canvas_to_p6(&star_exact()));
    write_p6(out, "spiral-smooth.ppm", canvas_to_p6(&spiral_smooth()));
    write_p6(out, "plate-07.ppm", canvas_to_p6(&plate_07()));

    // Chapter 8: curves.
    write_p6(out, "drops.ppm", canvas_to_p6(&drops()));
    write_p6(out, "flower.ppm", canvas_to_p6(&flower()));
    write_p6(out, "plate-08.ppm", canvas_to_p6(&plate_08()));

    // Chapter 9: compositing.
    write_p6(out, "porter-duff.ppm", canvas_to_p6(&porter_duff_table()));
    write_p6(out, "blend-modes.ppm", canvas_to_p6(&blend_strip()));
    write_p6(out, "seam.ppm", canvas_to_p6(&seam()));
    write_p6(out, "plate-09.ppm", canvas_to_p6(&plate_09()));

    // Chapter 10: paint servers and gradients.
    write_p6(out, "three-gradients.ppm", canvas_to_p6(&three_gradients()));
    write_p6(out, "extend-modes.ppm", canvas_to_p6(&extend_strip()));
    write_p6(out, "plate-10.ppm", canvas_to_p6(&plate_10()));

    // Chapter 11: images and resampling.
    write_p6(out, "two-filters.ppm", canvas_to_p6(&two_filters()));
    write_p6(out, "three-filters.ppm", canvas_to_p6(&three_filters()));
    write_p6(out, "plate-11.ppm", canvas_to_p6(&plate_11()));

    // Chapter 12: clipping, masks and groups.
    write_p6(out, "opacity.ppm", canvas_to_p6(&opacity_plate()));
    write_p6(out, "clip-demo.ppm", canvas_to_p6(&clip_demo()));
    write_p6(out, "plate-12.ppm", canvas_to_p6(&plate_12()));

    // Chapter 13: stroking is filling.
    write_p6(out, "joins.ppm", canvas_to_p6(&joins_plate()));
    write_p6(out, "caps.ppm", canvas_to_p6(&caps_demo()));
    write_p6(out, "plate-13.ppm", canvas_to_p6(&plate_13()));

    // Chapter 14: offsetting curves.
    write_p6(out, "two-strokes.ppm", canvas_to_p6(&two_strokes()));
    write_p6(out, "fold.ppm", canvas_to_p6(&fold_demo()));
    write_p6(out, "offsets.ppm", canvas_to_p6(&offsets_plate()));
    write_p6(out, "plate-14.ppm", canvas_to_p6(&plate_14()));

    // Chapter 15: dashes.
    write_p6(out, "even-marks.ppm", canvas_to_p6(&even_marks()));
    write_p6(out, "dash-strip.ppm", canvas_to_p6(&dash_strip()));
    write_p6(out, "spiral-dashes.ppm", canvas_to_p6(&spiral_dashes()));
    write_p6(out, "plate-15.ppm", canvas_to_p6(&plate_15()));

    // Chapter 16: glyphs.
    write_p6(out, "glyph.ppm", canvas_to_p6(&glyph_plate()));
    write_p6(out, "plate-16.ppm", canvas_to_p6(&plate_16()));
    write_p6(out, "composite.ppm", canvas_to_p6(&composite_demo()));
    write_p6(out, "sizes.ppm", canvas_to_p6(&sizes()));
    write_p6(out, "flip.ppm", canvas_to_p6(&flip_trap()));

    // Chapter 17: rasterizing type well.
    write_p6(out, "subpixels.ppm", canvas_to_p6(&subpixel_strip()));
    write_p6(out, "smoothing.ppm", canvas_to_p6(&smoothing_demo()));
    write_p6(out, "lcd.ppm", canvas_to_p6(&lcd_plate()));
    write_p6(out, "plate-17.ppm", canvas_to_p6(&plate_17()));

    // Chapter 18: setting a line of text.
    write_p6(out, "kerning.ppm", canvas_to_p6(&kern_demo()));
    write_p6(out, "breaking.ppm", canvas_to_p6(&break_demo()));
    write_p6(out, "drift.ppm", canvas_to_p6(&drift_demo()));
    write_p6(out, "plate-18.ppm", canvas_to_p6(&plate_18()));

    // Chapter 19: shaping, a field guide.
    write_p6(out, "ligature.ppm", canvas_to_p6(&ligature_demo()));
    write_p6(out, "forms.ppm", canvas_to_p6(&forms_demo()));
    write_p6(out, "word.ppm", canvas_to_p6(&word_demo()));
    write_p6(out, "mixed.ppm", canvas_to_p6(&mixed_demo()));
    write_p6(out, "plate-19.ppm", canvas_to_p6(&plate_19()));

    // Chapter 20: rendering SVG.
    let t = Instant::now();
    write_p6(out, "aspect_demo.ppm", canvas_to_p6(&aspect_demo()));
    println!("aspect_demo: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "harbor.ppm", canvas_to_p6(&harbor()));
    println!("harbor: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "rose.ppm", canvas_to_p6(&rose()));
    println!("rose: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "tiger.ppm", canvas_to_p6(&tiger()));
    println!("tiger: {:.2?}", t.elapsed());

    // Chapter 21: making it fast.
    let t = Instant::now();
    write_p6(out, "work_map.ppm", canvas_to_p6(&work_map()));
    println!("work_map: {:.2?}", t.elapsed());

    // Chapter 21's table: every mode on all three documents.
    for (name, w, h) in [("tiger", 450, 450), ("harbor", 480, 320), ("rose", 400, 400)] {
        let text = String::from_utf8(read_file(&format!("reference/chapter-20/{name}.svg"))).unwrap();
        for mode in ["whole", "bounded", "tiled"] {
            let mut st = stats();
            let t = Instant::now();
            render_svg_with(&text, w, h, mode, &mut st);
            println!(
                "{name:7} {mode:8} cells {:>10} blends {:>9} copies {:>7} time {:.1?}",
                st.cells, st.blends, st.copies, t.elapsed()
            );
        }
    }

    // Chapter 22: boolean path operations.
    let t = Instant::now();
    write_p6(out, "plate-22.ppm", canvas_to_p6(&plate_22()));
    println!("plate-22: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "seal.ppm", canvas_to_p6(&seal()));
    println!("seal: {:.2?}", t.elapsed());

    // Chapter 23: distance fields.
    let t = Instant::now();
    write_p6(out, "primitive-fields.ppm", canvas_to_p6(&primitive_fields()));
    println!("primitive-fields: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "error-map.ppm", canvas_to_p6(&error_map()));
    println!("error-map: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "fields-vs-paths.ppm", canvas_to_p6(&fields_vs_paths()));
    println!("fields-vs-paths: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "fillets.ppm", canvas_to_p6(&fillets()));
    println!("fillets: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "transform-demo.ppm", canvas_to_p6(&transform_demo()));
    println!("transform-demo: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "atlas-corners.ppm", canvas_to_p6(&atlas_corners()));
    println!("atlas-corners: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "trap-shrink.ppm", canvas_to_p6(&trap_shrink()));
    println!("trap-shrink: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "plate-23.ppm", canvas_to_p6(&plate_23()));
    println!("plate-23: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "title.ppm", canvas_to_p6(&title()));
    println!("title: {:.2?}", t.elapsed());

    // Chapter 24: doing it the GPU's way.
    let t = Instant::now();
    write_p6(out, "plate-24.ppm", canvas_to_p6(&plate_24()));
    println!("plate-24: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "msaa-demo.ppm", canvas_to_p6(&msaa_demo()));
    println!("msaa-demo: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "spill-map.ppm", canvas_to_p6(&spill_map()));
    println!("spill-map: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "tiger-assembly.ppm", canvas_to_p6(&tiger_assembly()));
    println!("tiger-assembly: {:.2?}", t.elapsed());

    // Chapter 25: the raster editor detour.
    let t = Instant::now();
    write_p6(out, "plate-25.ppm", canvas_to_p6(&plate_25()));
    println!("plate-25: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "dither-strip.ppm", canvas_to_p6(&dither_strip()));
    println!("dither-strip: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "halo-demo.ppm", canvas_to_p6(&halo_demo()));
    println!("halo-demo: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "brush-demo.ppm", canvas_to_p6(&brush_demo()));
    println!("brush-demo: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "paint-by-script.ppm", canvas_to_p6(&paint_by_script()));
    println!("paint-by-script: {:.2?}", t.elapsed());

    // Epilogue: one last picture.
    let t = Instant::now();
    let cover_svg = String::from_utf8(read_file("reference/epilogue/cover.svg")).unwrap();
    write_p6(out, "cover-art.ppm", canvas_to_p6(&render_svg(&cover_svg, 480, 680)));
    println!("cover-art: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "cover.ppm", canvas_to_p6(&book_cover()));
    println!("cover: {:.2?}", t.elapsed());
    let t = Instant::now();
    write_p6(out, "cover-glow.ppm", canvas_to_p6(&book_cover_glow()));
    println!("cover-glow: {:.2?}", t.elapsed());

    println!("wrote 98 renders to out/");
}
