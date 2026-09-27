// features/chapter20-style.feature

use renderer::{
    approx_eq, children, color, colors_eq, computed_style, initial_style, parse_color, parse_xml, Color, SvgPaint,
};

fn assert_color(actual: Option<Color>, expected: Color) {
    match actual {
        Some(c) => assert!(colors_eq(c, expected), "expected {expected:?}, got {c:?}"),
        None => panic!("expected {expected:?}, got none"),
    }
}

fn assert_paint_color(actual: &SvgPaint, expected: Color) {
    match actual {
        SvgPaint::Color(c) => assert!(colors_eq(*c, expected), "expected {expected:?}, got {c:?}"),
        other => panic!("expected {expected:?}, got {other:?}"),
    }
}

#[test]
fn three_spellings_of_one_colour_decoded_to_light() {
    assert_color(parse_color("#f80"), color(1.0, 0.2462, 0.0));
    assert_color(parse_color("#FF8800"), color(1.0, 0.2462, 0.0));
    assert_color(parse_color("rgb(255, 136, 0)"), color(1.0, 0.2462, 0.0));
    assert_color(parse_color("#808080"), color(0.2159, 0.2159, 0.2159));
}

#[test]
fn percentages_clamping_names_and_what_isnt_a_colour() {
    assert_color(parse_color("rgb(50%, 0%, 100%)"), color(0.2140, 0.0, 1.0));
    assert_color(parse_color("rgb(300,-5,0)"), color(1.0, 0.0, 0.0));
    assert_color(parse_color("orange"), color(1.0, 0.3763, 0.0));
    assert_color(parse_color("RED"), color(1.0, 0.0, 0.0));
    assert_color(parse_color(" blue "), color(0.0, 0.0, 1.0));
    assert_color(parse_color("gray"), parse_color("#808080").unwrap());
    assert!(parse_color("#12345").is_none());
    assert!(parse_color("currentColor").is_none());
    assert!(parse_color("rgb(1,2)").is_none());
}

#[test]
fn the_initial_style() {
    let s = initial_style();
    assert_paint_color(&s.fill, color(0.0, 0.0, 0.0));
    assert_eq!(s.stroke, SvgPaint::None);
    assert!(approx_eq(s.stroke_width, 1.0));
    assert_eq!(s.fill_rule, "nonzero");
    assert!(approx_eq(s.opacity, 1.0));
    assert!(approx_eq(s.stroke_miterlimit, 4.0));
    assert_eq!(s.stroke_linecap, "butt");
    assert_eq!(s.stroke_linejoin, "miter");
    assert!(s.stroke_dasharray.is_none());
    assert!(s.clip_path.is_none());
}

#[test]
fn inherited_properties_come_down_from_the_parent_opacity_doesnt() {
    let root = parse_xml("<g fill='#808080' stroke-width='3px' opacity='0.5'><rect/></g>");
    let gs = computed_style(&root, &initial_style());
    let rs = computed_style(&children(&root)[0], &gs);
    assert_paint_color(&gs.fill, color(0.2159, 0.2159, 0.2159));
    assert!(approx_eq(gs.stroke_width, 3.0));
    assert!(approx_eq(gs.opacity, 0.5));
    assert_paint_color(&rs.fill, color(0.2159, 0.2159, 0.2159));
    assert!(approx_eq(rs.stroke_width, 3.0));
    assert!(approx_eq(rs.opacity, 1.0));
}

#[test]
fn a_style_declaration_beats_a_presentation_attribute_whatever_the_order() {
    let root = parse_xml("<g><rect style='fill: lime' fill='red'/></g>");
    let rs = computed_style(&children(&root)[0], &computed_style(&root, &initial_style()));
    assert_paint_color(&rs.fill, color(0.0, 1.0, 0.0));
}

#[test]
fn inherit_a_value_that_doesnt_parse_and_a_url_reference() {
    let root = parse_xml("<g opacity='0.5' style='stroke: blue; fill-opacity: 0.25'><rect opacity='inherit' stroke-width='-2' fill-rule='odd' stroke='#nope' fill='url(#sky)'/></g>");
    let gs = computed_style(&root, &initial_style());
    let rs = computed_style(&children(&root)[0], &gs);
    assert!(approx_eq(rs.opacity, 0.5));
    assert!(approx_eq(rs.stroke_width, 1.0));
    assert_eq!(rs.fill_rule, "nonzero");
    assert_paint_color(&rs.stroke, color(0.0, 0.0, 1.0));
    assert!(approx_eq(rs.fill_opacity, 0.25));
    assert_eq!(rs.fill, SvgPaint::Url("url(#sky)".to_string()));
}

#[test]
fn dash_arrays_rules_caps_and_joins() {
    let root = parse_xml("<path stroke-dasharray='5, 3 2' stroke-linecap='round' stroke-linejoin='bevel' fill-rule='evenodd' stroke-miterlimit='10' stroke-dashoffset='1.5' fill='none'/>");
    let s = computed_style(&root, &initial_style());
    let dashes = s.stroke_dasharray.clone().expect("a dash array");
    assert_eq!(dashes.len(), 3);
    assert!(approx_eq(dashes[0], 5.0) && approx_eq(dashes[1], 3.0) && approx_eq(dashes[2], 2.0));
    assert_eq!(s.stroke_linecap, "round");
    assert_eq!(s.stroke_linejoin, "bevel");
    assert_eq!(s.fill_rule, "evenodd");
    assert!(approx_eq(s.stroke_miterlimit, 10.0));
    assert!(approx_eq(s.stroke_dashoffset, 1.5));
    assert_eq!(s.fill, SvgPaint::None);
}
