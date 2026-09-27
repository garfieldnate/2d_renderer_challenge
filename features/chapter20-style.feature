Feature: Colours and the style cascade
  parse_color(s) reads a colour and answers it in linear light, because the
  file's numbers are sRGB and the canvas stores light: each byte b becomes
  decode(b / 255). It reads #rgb (each digit doubled), #rrggbb, rgb(r, g,
  b) with numbers from 0 to 255 or percentages of 255, each clamped to that
  range, and the seventeen names in the table in the text, with hex digits
  and names in either case and whitespace around the value ignored.
  Anything else is none. computed_style(el, parent) is the element's value
  for every property in the table: an inherited property starts at the
  parent's value and any other at its initial value; then each presentation
  attribute the element has overrides that; then each declaration in its
  style attribute ("name: value; name: value") overrides those, whatever
  order they were written in. The value inherit takes the parent's value,
  inherited property or not. A value that doesn't parse is ignored, as if
  it hadn't been written. Numbers may carry px, which means nothing. fill
  and stroke are none, a colour, or a url(#id) reference kept as the text
  "url(#id)"; stroke-dasharray is none or a list of numbers.
  initial_style() is every property at its initial value, the parent of
  the root.

  Scenario: Three spellings of one colour, decoded to light
    Then  parse_color("#f80") = color(1, 0.2462, 0)
    And   parse_color("#FF8800") = color(1, 0.2462, 0)
    And   parse_color("rgb(255, 136, 0)") = color(1, 0.2462, 0)
    And   parse_color("#808080") = color(0.2159, 0.2159, 0.2159)

  Scenario: Percentages, clamping, names, and what isn't a colour
    Then  parse_color("rgb(50%, 0%, 100%)") = color(0.2140, 0, 1)
    And   parse_color("rgb(300,-5,0)") = color(1, 0, 0)
    And   parse_color("orange") = color(1, 0.3763, 0)
    And   parse_color("RED") = color(1, 0, 0)
    And   parse_color(" blue ") = color(0, 0, 1)
    And   parse_color("gray") = parse_color("#808080")
    And   parse_color("#12345") = none
    And   parse_color("currentColor") = none
    And   parse_color("rgb(1,2)") = none

  Scenario: The initial style
    When  s ← initial_style()
    Then  s.fill = color(0, 0, 0)
    And   s.stroke = none
    And   s.stroke_width = 1
    And   s.fill_rule = "nonzero"
    And   s.opacity = 1
    And   s.stroke_miterlimit = 4
    And   s.stroke_linecap = "butt"
    And   s.stroke_linejoin = "miter"
    And   s.stroke_dasharray = none
    And   s.clip_path = none

  Scenario: Inherited properties come down from the parent, opacity doesn't
    Given root ← parse_xml("<g fill='#808080' stroke-width='3px' opacity='0.5'><rect/></g>")
    When  gs ← computed_style(root, initial_style())
    And   rs ← computed_style(children(root)[0], gs)
    Then  gs.fill = color(0.2159, 0.2159, 0.2159)
    And   gs.stroke_width = 3
    And   gs.opacity = 0.5
    And   rs.fill = color(0.2159, 0.2159, 0.2159)
    And   rs.stroke_width = 3
    And   rs.opacity = 1

  Scenario: A style declaration beats a presentation attribute, whatever the order
    Given root ← parse_xml("<g><rect style='fill: lime' fill='red'/></g>")
    When  rs ← computed_style(children(root)[0], computed_style(root, initial_style()))
    Then  rs.fill = color(0, 1, 0)

  Scenario: inherit, a value that doesn't parse, and a url reference
    Given root ← parse_xml("<g opacity='0.5' style='stroke: blue; fill-opacity: 0.25'><rect opacity='inherit' stroke-width='-2' fill-rule='odd' stroke='#nope' fill='url(#sky)'/></g>")
    When  gs ← computed_style(root, initial_style())
    And   rs ← computed_style(children(root)[0], gs)
    Then  rs.opacity = 0.5
    And   rs.stroke_width = 1
    And   rs.fill_rule = "nonzero"
    And   rs.stroke = color(0, 0, 1)
    And   rs.fill_opacity = 0.25
    And   rs.fill = "url(#sky)"

  Scenario: Dash arrays, rules, caps and joins
    Given root ← parse_xml("<path stroke-dasharray='5, 3 2' stroke-linecap='round' stroke-linejoin='bevel' fill-rule='evenodd' stroke-miterlimit='10' stroke-dashoffset='1.5' fill='none'/>")
    When  s ← computed_style(root, initial_style())
    Then  s.stroke_dasharray = (5, 3, 2)
    And   s.stroke_linecap = "round"
    And   s.stroke_linejoin = "bevel"
    And   s.fill_rule = "evenodd"
    And   s.stroke_miterlimit = 10
    And   s.stroke_dashoffset = 1.5
    And   s.fill = none
