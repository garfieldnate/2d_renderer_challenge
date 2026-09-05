//! Renders every named figure and plate in the book to `out/`, as the
//! chapter that introduced them writes them: chapter 1's are P3 (the
//! book's writer at the time), chapter 2's are P6 (the writer it upgrades
//! to). `cargo run --release --bin render_all` from the package root.

use std::fs;
use std::path::Path;

use renderer::{
    canvas_to_p6, canvas_to_ppm, clamp_pair, disc_centers, disc_coverage, fan_bresenham,
    fan_coverage, fan_wu, gray_match, painted_twice, plate_01, plate_02, plate_03, quarter_match,
    ramp,
};

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

    println!("wrote 13 renders to out/");
}
