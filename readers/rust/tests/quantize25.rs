// features/chapter25-quantize.feature

use renderer::{
    approx_eq, bytes_of, canvas_bytes, canvas_to_bmp8, error_diffuse, indexed_canvas, mean_light,
    median_cut, nearest_index, ordered_dither, ramp_canvas, read_bmp8, ring_canvas, threshold,
};

#[test]
fn median_cut_test() {
    let cols: Vec<(i64, i64, i64)> = vec![
        (10, 10, 10),
        (10, 10, 10),
        (10, 10, 10),
        (200, 0, 0),
        (250, 0, 0),
        (0, 0, 90),
        (0, 0, 100),
        (0, 0, 110),
    ];
    assert_eq!(median_cut(&cols, 1), vec![(60, 4, 41)]);
    assert_eq!(median_cut(&cols, 2), vec![(5, 5, 55), (225, 0, 0)]);
    assert_eq!(median_cut(&cols, 4), vec![(10, 10, 10), (0, 0, 100), (200, 0, 0), (250, 0, 0)]);
    assert_eq!(
        median_cut(&cols, 20),
        vec![(10, 10, 10), (0, 0, 90), (0, 0, 100), (0, 0, 110), (200, 0, 0), (250, 0, 0)]
    );
    assert_eq!(
        median_cut(&canvas_bytes(&ring_canvas()), 4),
        vec![(63, 63, 80), (128, 127, 130), (226, 223, 215), (246, 243, 234)]
    );
}

#[test]
fn median_cuts_ties() {
    assert_eq!(median_cut(&[(0, 10, 0), (10, 0, 0)], 2), vec![(0, 10, 0), (10, 0, 0)]);
    assert_eq!(
        median_cut(&[(0, 0, 0), (10, 0, 0), (100, 0, 0), (110, 0, 0)], 3),
        vec![(0, 0, 0), (10, 0, 0), (105, 0, 0)]
    );
}

#[test]
fn the_nearest_entry() {
    let pal: Vec<(i64, i64, i64)> = vec![(0, 0, 0), (255, 255, 255), (255, 0, 0)];
    assert_eq!(nearest_index(&pal, (120, 120, 120)), 0);
    assert_eq!(nearest_index(&pal, (128, 128, 128)), 1);
    assert_eq!(nearest_index(&pal, (200, 40, 30)), 2);
    assert_eq!(nearest_index(&[(0, 0, 0), (0, 0, 0)], (1, 1, 1)), 0);
}

#[test]
fn two_inks_three_ways_error_diffusion_keeps_the_light() {
    let r = ramp_canvas(256, 32);
    let bw: Vec<(i64, i64, i64)> = vec![(0, 0, 0), (255, 255, 255)];
    assert_eq!(error_diffuse(&ramp_canvas(4, 1), &bw), vec![0, 0, 1, 1]);
    assert!(approx_eq(mean_light(&r), 0.5));
    assert!(approx_eq(mean_light(&indexed_canvas(&threshold(&r, &bw), &bw, 256, 32)), 0.5));
    assert!(approx_eq(mean_light(&indexed_canvas(&ordered_dither(&r, &bw), &bw, 256, 32)), 0.530273));
    assert!(approx_eq(mean_light(&indexed_canvas(&error_diffuse(&r, &bw), &bw, 256, 32)), 0.500732));
}

#[test]
fn three_inks() {
    let r = ramp_canvas(8, 2);
    let pal: Vec<(i64, i64, i64)> = vec![(0, 0, 0), (128, 128, 128), (255, 255, 255)];
    assert_eq!(threshold(&r, &pal), vec![0, 1, 1, 1, 1, 2, 2, 2, 0, 1, 1, 1, 1, 2, 2, 2]);
    assert_eq!(error_diffuse(&r, &pal), vec![0, 1, 1, 1, 2, 1, 2, 2, 0, 1, 1, 1, 2, 2, 2, 2]);
}

#[test]
fn an_8_bit_bmp_byte_by_byte() {
    let indices = vec![0usize, 1, 2, 1, 0, 2, 1, 1, 1, 0];
    let palette: Vec<(i64, i64, i64)> = vec![(10, 20, 30), (200, 100, 50), (0, 0, 255)];
    let bm = canvas_to_bmp8(&indices, &palette, 5, 2);
    assert_eq!(bm.len(), 1094);
    assert_eq!(bytes_of(&bm, 0, 14), vec![66, 77, 70, 4, 0, 0, 0, 0, 0, 0, 54, 4, 0, 0]);
    assert_eq!(
        bytes_of(&bm, 14, 54),
        vec![40, 0, 0, 0, 5, 0, 0, 0, 2, 0, 0, 0, 1, 0, 8, 0, 0, 0, 0, 0, 16, 0, 0, 0, 19, 11, 0, 0, 19, 11, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0]
    );
    assert_eq!(bytes_of(&bm, 54, 66), vec![30, 20, 10, 0, 50, 100, 200, 0, 255, 0, 0, 0]);
    assert_eq!(bytes_of(&bm, 1078, 1094), vec![2, 1, 1, 1, 0, 0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0]);
    assert_eq!(read_bmp8(&bm), (5, 2, palette, indices));
}
