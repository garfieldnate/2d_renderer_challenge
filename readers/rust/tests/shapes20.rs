// features/chapter20-shapes.feature

use renderer::{approx_eq, commands_bounds, parse_xml, shape_commands};

fn sc(xml: &str) -> Vec<renderer::Command> {
    shape_commands(&parse_xml(xml))
}

fn assert_args(actual: &[f64], expected: &[f64]) {
    assert_eq!(actual.len(), expected.len(), "expected {expected:?}, got {actual:?}");
    for (a, e) in actual.iter().zip(expected) {
        assert!(approx_eq(*a, *e), "expected {expected:?}, got {actual:?}");
    }
}

#[test]
fn a_rectangle_is_four_corners_clockwise_on_screen_closed() {
    let cmds = sc("<rect x='1' y='2' width='10' height='5'/>");
    assert_eq!(cmds.len(), 5);
    assert_args(&cmds[0].args, &[1.0, 2.0]);
    assert_args(&cmds[1].args, &[11.0, 2.0]);
    assert_args(&cmds[2].args, &[11.0, 7.0]);
    assert_args(&cmds[3].args, &[1.0, 7.0]);
    assert_eq!(cmds[4].op, "Z");
}

#[test]
fn rounded_corners_are_quarter_arcs_between_the_sides() {
    let cmds = sc("<rect width='10' height='6' rx='2'/>");
    assert_eq!(cmds.len(), 10);
    assert_args(&cmds[0].args, &[2.0, 0.0]);
    assert_args(&cmds[1].args, &[8.0, 0.0]);
    assert_eq!(cmds[2].op, "A");
    assert_args(&cmds[2].args, &[2.0, 2.0, 0.0, 0.0, 1.0, 10.0, 2.0]);
    assert_args(&cmds[8].args, &[2.0, 2.0, 0.0, 0.0, 1.0, 2.0, 0.0]);
}

#[test]
fn a_corner_radius_is_at_most_half_a_side_and_one_radius_stands_for_both() {
    let cmds = sc("<rect width='10' height='6' rx='20' ry='1'/>");
    assert_args(&cmds[0].args, &[5.0, 0.0]);
    assert_args(&cmds[2].args, &[5.0, 1.0, 0.0, 0.0, 1.0, 10.0, 1.0]);
    assert_args(&sc("<rect width='10' height='6' ry='3'/>")[2].args, &[3.0, 3.0, 0.0, 0.0, 1.0, 10.0, 3.0]);
    assert_eq!(sc("<rect width='10' height='6' ry='-3'/>").len(), 5);
}

#[test]
fn a_circle_and_an_ellipse_are_four_quarter_arcs_from_the_right_hand_point() {
    let cmds = sc("<ellipse cx='5' cy='5' rx='4' ry='2'/>");
    assert_eq!(cmds.len(), 6);
    assert_args(&cmds[0].args, &[9.0, 5.0]);
    assert_args(&cmds[1].args, &[4.0, 2.0, 0.0, 0.0, 1.0, 5.0, 7.0]);
    assert_args(&cmds[2].args, &[4.0, 2.0, 0.0, 0.0, 1.0, 1.0, 5.0]);
    assert_args(&cmds[3].args, &[4.0, 2.0, 0.0, 0.0, 1.0, 5.0, 3.0]);
    assert_args(&cmds[4].args, &[4.0, 2.0, 0.0, 0.0, 1.0, 9.0, 5.0]);
    assert_eq!(cmds[5].op, "Z");
    let b = commands_bounds(&sc("<circle cx='5' cy='5' r='4'/>"));
    assert!(approx_eq(b.0, 1.0) && approx_eq(b.1, 1.0) && approx_eq(b.2, 9.0) && approx_eq(b.3, 9.0), "{b:?}");
}

#[test]
fn lines_polylines_and_polygons() {
    assert_eq!(sc("<line x1='1' y1='2' x2='3' y2='4'/>").len(), 2);
    assert_args(&sc("<line x1='1' y1='2' x2='3' y2='4'/>")[1].args, &[3.0, 4.0]);
    assert_eq!(sc("<polyline points='0,0 10,0 10,10 5'/>").len(), 3);
    assert_eq!(sc("<polygon points='0 0 10 0 10 10'/>").len(), 4);
    assert_eq!(sc("<polygon points='0 0 10 0 10 10'/>")[3].op, "Z");
}

#[test]
fn shapes_that_dont_render_have_no_commands() {
    assert_eq!(sc("<rect width='0' height='6'/>").len(), 0);
    assert_eq!(sc("<circle r='0'/>").len(), 0);
    assert_eq!(sc("<ellipse rx='3'/>").len(), 0);
    assert_eq!(sc("<polygon points=''/>").len(), 0);
    assert_eq!(sc("<text/>").len(), 0);
}
