Feature: viewBox and preserveAspectRatio
  The root svg's viewBox names the rectangle of user space that should
  fill the canvas, as four numbers: min-x, min-y, width, height.
  view_box_matrix(view_box, aspect, width, height) is the matrix that
  carries it onto a width by height viewport, with aspect the
  preserveAspectRatio attribute (none when absent, which means
  "xMidYMid meet"). With sx = width / box width and sy = height / box
  height: "none" is scaling(sx, sy) times translation(-min-x, -min-y).
  Otherwise the first word is xMin, xMid or xMax followed by YMin, YMid
  or YMax, and the optional second word is meet (the default) or slice;
  one scale s is used for both axes, the smaller of sx and sy for meet and
  the larger for slice, and the scaled box is placed at ox = (width - box
  width * s) * f and oy likewise, where f is 0 for Min, 0.5 for Mid and 1
  for Max: translation(ox, oy) times scaling(s, s) times translation(-min-x,
  -min-y). A slice spills off the canvas, which the canvas edge clips. No
  viewBox, one without four numbers, or one with a width or height of zero
  or less is the identity.

  Scenario: meet fits the whole box and centres it
    When  m ← view_box_matrix("0 0 60 80", "xMidYMid meet", 120, 90)
    Then  m * point(0, 0) = point(26.25, 0)
    And   m * point(60, 80) = point(93.75, 90)
    And   view_box_matrix("0 0 60 80", none, 120, 90) = m
    And   view_box_matrix("0 0 60 80", "xMidYMid", 120, 90) = m

  Scenario: The alignment words slide the box along the spare axis
    Then  view_box_matrix("0 0 60 80", "xMinYMid meet", 120, 90) * point(0, 0) = point(0, 0)
    And   view_box_matrix("0 0 60 80", "xMaxYMid meet", 120, 90) * point(0, 0) = point(52.5, 0)
    And   view_box_matrix("0 0 60 80", "xMaxYMid meet", 120, 90) * point(60, 80) = point(120, 90)

  Scenario: slice fills the viewport and spills
    Then  view_box_matrix("0 0 60 80", "xMidYMid slice", 120, 90) * point(0, 0) = point(0, -35)
    And   view_box_matrix("0 0 60 80", "xMidYMid slice", 120, 90) * point(60, 80) = point(120, 125)
    And   view_box_matrix("0 0 60 80", "xMidYMin slice", 120, 90) * point(0, 0) = point(0, 0)
    And   view_box_matrix("0 0 60 80", "xMaxYMax slice", 120, 90) * point(0, 0) = point(0, -70)

  Scenario: none stretches each axis on its own
    When  m ← view_box_matrix("0 0 60 80", "none", 120, 90)
    Then  m = scaling(2, 1.125)

  Scenario: The box's origin moves to the viewport's
    Then  view_box_matrix("10 20 60 80", "xMidYMid meet", 120, 90) * point(10, 20) = point(26.25, 0)
    And   view_box_matrix("-5,-5,10,10", none, 100, 100) * point(0, 0) = point(50, 50)

  Scenario: No usable viewBox is the identity
    Then  view_box_matrix(none, none, 50, 50) = identity()
    And   view_box_matrix("0 0 0 5", none, 50, 50) = identity()
    And   view_box_matrix("0 0 50", none, 50, 50) = identity()

  Scenario: One drawing, five ways to fit it
    Given c ← aspect_demo()
    And   ref ← read_file("reference/chapter-20/aspect_demo.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 660
    And   c.height = 110
    And   ppm_pixel(p6, 70, 39) = (232, 85, 58) ± 1
    And   ppm_pixel(p6, 240, 50) = (255, 255, 255) ± 1
    And   ppm_pixel(p6, 280, 50) = (255, 255, 255) ± 1
    And   ppm_pixel(p6, 335, 50) = (232, 85, 58) ± 1
    And   ppm_pixel(p6, 150, 95) = (59, 91, 122) ± 1
    And   ppm_pixel(p6, 590, 27) = (232, 85, 58) ± 1
    And   ppm_pixel(p6, 5, 5) = (39, 39, 44) ± 1
    And   max_channel_difference(p6, ref) ≤ 1
