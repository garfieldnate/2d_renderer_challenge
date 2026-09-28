// features/chapter24-unhappy.feature

use renderer::{encode_svg, max_group_depth, read_file, run_pipeline, FineStats, Scene, STACK_DEPTH};

fn read_text(path: &str) -> String {
    String::from_utf8(read_file(path)).unwrap()
}

#[test]
fn groups_nested_two_deep_spill_one_deep_dont() {
    let harbor = Scene(encode_svg(&read_text("reference/chapter-20/harbor.svg"), 480, 320), 480, 320);
    let rose = Scene(encode_svg(&read_text("reference/chapter-20/rose.svg"), 400, 400), 400, 400);
    let mut fh = FineStats();
    let mut fr = FineStats();
    let _a = run_pipeline(&harbor, None, &mut fh);
    let _b = run_pipeline(&rose, None, &mut fr);
    assert_eq!(STACK_DEPTH, 2);
    assert_eq!(fh.spills, 0);
    assert_eq!(fr.spills, 200);
    assert_eq!(fr.tiles, 625);
    assert_eq!(max_group_depth(&rose.commands), 2);
    assert_eq!(max_group_depth(&harbor.commands), 1);
}
