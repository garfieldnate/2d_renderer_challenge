//! Chapter 21 § 21.5: `composite_span` against `composite_span4` on the
//! same run of coverages. `cargo run --release --example span_bench`.

use renderer::{color, composite_span, composite_span4, layer, layers_equal};
use std::time::Instant;

fn main() {
    let n = 4096;
    let ks: Vec<f64> = (0..n).map(|i| ((i * 37) % 101) as f64 / 100.0).collect();
    let c = color(0.8, 0.4, 0.2);
    let reps = 20_000;
    let mut a = layer(n, 1);
    let mut b = layer(n, 1);
    let t = Instant::now();
    for _ in 0..reps {
        composite_span(&mut a, 0, 0, &ks, c);
    }
    let scalar = t.elapsed();
    let t = Instant::now();
    for _ in 0..reps {
        composite_span4(&mut b, 0, 0, &ks, c);
    }
    let wide = t.elapsed();
    println!("{} pixels x {reps}: scalar {scalar:.2?}, four-wide {wide:.2?}, equal {}", n, layers_equal(&a, &b));
}
