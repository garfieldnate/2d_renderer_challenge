// features/chapter24-pipeline.feature

use renderer::{
    bin_stage, canvas_to_p6, coarse_stage, command_count, deposit_count, encode_svg,
    flatten_stage, lcg_shuffle, max_channel_difference, read_file, render_svg, render_svg_gpu,
    cull_groups, PipeCmd, Scene,
};

#[test]
fn the_same_shuffle_everywhere() {
    assert_eq!(lcg_shuffle(10, 1), vec![1, 2, 8, 9, 5, 6, 7, 4, 3, 0]);
    assert_eq!(lcg_shuffle(5, 7), vec![0, 2, 3, 4, 1]);
}

#[test]
fn an_empty_group_costs_a_tile_nothing() {
    let input: Vec<PipeCmd<i64, ()>> = vec![
        PipeCmd::Push(1.0, None),
        PipeCmd::Pop,
        PipeCmd::Fill(1),
        PipeCmd::Push(0.5, None),
        PipeCmd::Push(1.0, None),
        PipeCmd::Pop,
        PipeCmd::Fill(2),
        PipeCmd::Pop,
    ];
    let expected: Vec<PipeCmd<i64, ()>> = vec![
        PipeCmd::Fill(1),
        PipeCmd::Push(0.5, None),
        PipeCmd::Fill(2),
        PipeCmd::Pop,
    ];
    assert_eq!(cull_groups(input), expected);
}

#[test]
fn the_tigers_scene_stage_by_stage() {
    let text = read_file("reference/chapter-20/tiger.svg");
    let text = String::from_utf8(text).unwrap();
    let sc = Scene(encode_svg(&text, 450, 450), 450, 450);
    let segs = flatten_stage(&sc);
    let bins = bin_stage(&sc, &segs);
    let lists = coarse_stage(&sc, &bins);
    assert_eq!(sc.commands.len(), 305);
    assert_eq!(sc.draws.len(), 305);
    assert_eq!(segs.len(), 37051);
    assert_eq!(deposit_count(&bins), 119876);
    assert_eq!(command_count(&lists), 4004);
}

fn read_text(path: &str) -> String {
    String::from_utf8(read_file(path)).unwrap()
}

#[test]
fn every_document_drawn_tile_by_tile_in_any_order_is_chapter_20s() {
    let cases = [
        ("reference/chapter-20/tiger.svg", "reference/chapter-20/tiger.ppm", 450usize, 450usize),
        ("reference/chapter-20/harbor.svg", "reference/chapter-20/harbor.ppm", 480, 320),
        ("reference/chapter-20/rose.svg", "reference/chapter-20/rose.ppm", 400, 400),
    ];
    for (svg, ppm, w, h) in cases {
        let text = read_text(svg);
        let in_order = canvas_to_p6(&render_svg_gpu(&text, w, h, None));
        let shuffled = canvas_to_p6(&render_svg_gpu(&text, w, h, Some(99)));
        let reference = read_file(ppm);
        assert_eq!(max_channel_difference(&in_order, &reference), 0, "mismatch for {svg}");
        assert_eq!(in_order, shuffled, "shuffled order differs for {svg}");
    }
}

#[test]
fn a_clip_on_a_shape_that_isnt_grouped() {
    let svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><clipPath id='c'><circle cx='32' cy='32' r='20'/></clipPath><rect x='4' y='4' width='56' height='40' fill='#c83' clip-path='url(#c)'/></svg>";
    let gpu = canvas_to_p6(&render_svg_gpu(svg, 64, 64, Some(3)));
    let direct = canvas_to_p6(&render_svg(svg, 64, 64));
    assert_eq!(max_channel_difference(&gpu, &direct), 0);
}
