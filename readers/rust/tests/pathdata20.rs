// features/chapter20-pathdata.feature

use renderer::{approx_eq, attribute, find_by_id, parse_xml, path_commands, read_file};

fn assert_args(actual: &[f64], expected: &[f64]) {
    assert_eq!(actual.len(), expected.len(), "expected {expected:?}, got {actual:?}");
    for (a, e) in actual.iter().zip(expected) {
        assert!(approx_eq(*a, *e), "expected {expected:?}, got {actual:?}");
    }
}

#[test]
fn absolute_commands_come_back_as_they_were() {
    let cmds = path_commands("M10 20 L30 40 Z");
    assert_eq!(cmds.len(), 3);
    assert_eq!(cmds[0].op, "M");
    assert_args(&cmds[0].args, &[10.0, 20.0]);
    assert_eq!(cmds[1].op, "L");
    assert_args(&cmds[1].args, &[30.0, 40.0]);
    assert_eq!(cmds[2].op, "Z");
    assert_args(&cmds[2].args, &[]);
}

#[test]
fn relative_commands_are_made_absolute_and_z_returns_to_the_subpaths_start() {
    let cmds = path_commands("m10 20 l5 5 z l1 1");
    assert_args(&cmds[0].args, &[10.0, 20.0]);
    assert_eq!(cmds[1].op, "L");
    assert_args(&cmds[1].args, &[15.0, 25.0]);
    assert_eq!(cmds[2].op, "Z");
    assert_eq!(cmds[3].op, "L");
    assert_args(&cmds[3].args, &[11.0, 21.0]);
}

#[test]
fn h_and_v_become_l() {
    let cmds = path_commands("M0 0 H10 V10 h-5 v-5");
    assert_eq!(cmds.len(), 5);
    assert_eq!(cmds[1].op, "L");
    assert_args(&cmds[1].args, &[10.0, 0.0]);
    assert_args(&cmds[2].args, &[10.0, 10.0]);
    assert_args(&cmds[3].args, &[5.0, 10.0]);
    assert_args(&cmds[4].args, &[5.0, 5.0]);
}

#[test]
fn a_repeated_argument_group_repeats_the_command_and_after_m_the_repeats_are_l() {
    let cmds = path_commands("M10 10 20 20 30 10");
    assert_eq!(cmds.len(), 3);
    assert_eq!(cmds[1].op, "L");
    assert_args(&cmds[1].args, &[20.0, 20.0]);
    assert_eq!(cmds[2].op, "L");
    assert_args(&cmds[2].args, &[30.0, 10.0]);
    assert_args(&path_commands("m10 10 20 20 30 10")[2].args, &[60.0, 40.0]);
    assert_eq!(path_commands("M0 0 L1 1 2 2 3 3").len(), 4);
}

#[test]
fn s_reflects_the_previous_cubics_second_control_point() {
    let cmds = path_commands("M0 0 C10 0 20 10 20 20 S30 40 40 40");
    assert_eq!(cmds[2].op, "C");
    assert_args(&cmds[2].args, &[20.0, 30.0, 30.0, 40.0, 40.0, 40.0]);
    assert_args(
        &path_commands("M0 0 C10 0 20 10 20 20 S30 40 40 40 S50 30 60 20")[3].args,
        &[50.0, 40.0, 50.0, 30.0, 60.0, 20.0],
    );
}

#[test]
fn s_after_anything_but_a_cubic_starts_its_curve_at_the_current_point() {
    let cmds = path_commands("M0 0 L5 5 S10 0 20 0");
    assert_eq!(cmds[2].op, "C");
    assert_args(&cmds[2].args, &[5.0, 5.0, 10.0, 0.0, 20.0, 0.0]);
}

#[test]
fn t_reflects_the_previous_quadratics_control_point_again_and_again() {
    let cmds = path_commands("M0 0 Q10 0 10 10 T20 20 T30 30");
    assert_eq!(cmds[2].op, "Q");
    assert_args(&cmds[2].args, &[10.0, 20.0, 20.0, 20.0]);
    assert_args(&cmds[3].args, &[30.0, 20.0, 30.0, 30.0]);
    assert_args(&path_commands("M0 0 L5 5 T10 10")[2].args, &[5.0, 5.0, 10.0, 10.0]);
    assert_args(&path_commands("M0 0 C1 1 2 2 3 3 T10 10")[2].args, &[3.0, 3.0, 10.0, 10.0]);
}

#[test]
fn arc_flags_are_packed_without_separators() {
    let cmds = path_commands("M0 0a1 1 0 0110 0");
    assert_eq!(cmds.len(), 2);
    assert_eq!(cmds[1].op, "A");
    assert_args(&cmds[1].args, &[1.0, 1.0, 0.0, 0.0, 1.0, 10.0, 0.0]);
    assert_args(&path_commands("M0 0 a-5 -5 30 1 0 10 0")[1].args, &[5.0, 5.0, 30.0, 1.0, 0.0, 10.0, 0.0]);
}

#[test]
fn nothing_needs_a_separator_where_a_sign_or_a_point_can_do_the_job() {
    let cmds = path_commands("M1,2l3-4-5.5.5e1");
    assert_eq!(cmds.len(), 3);
    assert_args(&cmds[1].args, &[4.0, -2.0]);
    assert_args(&cmds[2].args, &[-1.5, 3.0]);
}

#[test]
fn the_path_must_start_with_a_moveto() {
    assert_eq!(path_commands("L10 10").len(), 0);
    assert_eq!(path_commands("").len(), 0);
    assert_eq!(path_commands("M0 0 z m1 1").len(), 3);
    assert_eq!(path_commands("M0 0 z m1 1")[2].op, "M");
}

#[test]
fn at_an_error_the_commands_so_far_are_the_answer() {
    assert_eq!(path_commands("M10 10 L20 20 L30 x 40").len(), 2);
    assert_eq!(path_commands("M 10,10 L 20,20 30").len(), 2);
    assert_eq!(path_commands("M0 0 L5 5 Z 6 6").len(), 3);
    assert_eq!(path_commands("M0 0 L5 5 X 6 6").len(), 2);
    assert_eq!(path_commands("M0 0 a1 1 0 2 0 5 5").len(), 1);
}

#[test]
fn the_tigers_first_path() {
    let text = String::from_utf8(read_file("reference/chapter-20/tiger.svg")).unwrap();
    let root = parse_xml(&text);
    let cmds = path_commands(attribute(find_by_id(&root, "path8").unwrap(), "d").unwrap());
    assert_eq!(cmds.len(), 5);
    assert_args(&cmds[0].args, &[-122.3, 84.285]);
    assert_eq!(cmds[1].op, "C");
    assert_args(&cmds[1].args, &[-122.3, 84.285, -122.2, 86.179, -123.03, 86.16]);
    assert_args(&cmds[2].args, &[-123.85, 86.141, -140.3, 38.066, -160.83, 40.309]);
    assert_args(&cmds[3].args, &[-160.83, 40.309, -143.05, 32.956, -122.3, 84.285]);
    assert_eq!(cmds[4].op, "Z");
}
