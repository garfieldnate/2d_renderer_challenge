Feature: Path data
  path_commands(d) turns a d attribute into a list of commands, each with
  an op and its args, in absolute coordinates and in six ops only: M, L,
  C, Q, A and Z. A lower-case command is relative to the current point
  and comes back absolute. H and V come back as L. S comes back as C, its
  first control point the reflection of the previous command's second
  control point through the current point when the previous command was a
  C or an S, and the current point otherwise; T comes back as Q the same
  way, reflecting the previous Q or T's control point. A command letter
  may be followed by several argument groups, and each group after the
  first repeats the command, except that the repeats of M are L (and of m,
  l). Z takes no arguments and puts the current point back at the start of
  the subpath, which is the point of the last M. An A's args are rx, ry,
  the x-axis rotation in degrees, the large-arc flag, the sweep flag, and
  the end point; the radii come back as their absolute values and the
  flags are read with read_flag. The first command must be M or m. At the
  first thing that can't be read, including a group cut short, the
  commands so far are the answer.

  Scenario: Absolute commands come back as they were
    When  cmds ← path_commands("M10 20 L30 40 Z")
    Then  length(cmds) = 3
    And   cmds[0].op = "M"
    And   cmds[0].args = (10, 20)
    And   cmds[1].op = "L"
    And   cmds[1].args = (30, 40)
    And   cmds[2].op = "Z"
    And   cmds[2].args = ()

  Scenario: Relative commands are made absolute, and Z returns to the subpath's start
    When  cmds ← path_commands("m10 20 l5 5 z l1 1")
    Then  cmds[0].args = (10, 20)
    And   cmds[1].op = "L"
    And   cmds[1].args = (15, 25)
    And   cmds[2].op = "Z"
    And   cmds[3].op = "L"
    And   cmds[3].args = (11, 21)

  Scenario: H and V become L
    When  cmds ← path_commands("M0 0 H10 V10 h-5 v-5")
    Then  length(cmds) = 5
    And   cmds[1].op = "L"
    And   cmds[1].args = (10, 0)
    And   cmds[2].args = (10, 10)
    And   cmds[3].args = (5, 10)
    And   cmds[4].args = (5, 5)

  Scenario: A repeated argument group repeats the command, and after M the repeats are L
    When  cmds ← path_commands("M10 10 20 20 30 10")
    Then  length(cmds) = 3
    And   cmds[1].op = "L"
    And   cmds[1].args = (20, 20)
    And   cmds[2].op = "L"
    And   cmds[2].args = (30, 10)
    And   path_commands("m10 10 20 20 30 10")[2].args = (60, 40)
    And   length(path_commands("M0 0 L1 1 2 2 3 3")) = 4

  Scenario: S reflects the previous cubic's second control point
    When  cmds ← path_commands("M0 0 C10 0 20 10 20 20 S30 40 40 40")
    Then  cmds[2].op = "C"
    And   cmds[2].args = (20, 30, 30, 40, 40, 40)
    And   path_commands("M0 0 C10 0 20 10 20 20 S30 40 40 40 S50 30 60 20")[3].args = (50, 40, 50, 30, 60, 20)

  Scenario: S after anything but a cubic starts its curve at the current point
    When  cmds ← path_commands("M0 0 L5 5 S10 0 20 0")
    Then  cmds[2].op = "C"
    And   cmds[2].args = (5, 5, 10, 0, 20, 0)

  Scenario: T reflects the previous quadratic's control point, again and again
    When  cmds ← path_commands("M0 0 Q10 0 10 10 T20 20 T30 30")
    Then  cmds[2].op = "Q"
    And   cmds[2].args = (10, 20, 20, 20)
    And   cmds[3].args = (30, 20, 30, 30)
    And   path_commands("M0 0 L5 5 T10 10")[2].args = (5, 5, 10, 10)
    And   path_commands("M0 0 C1 1 2 2 3 3 T10 10")[2].args = (3, 3, 10, 10)

  Scenario: Arc flags are packed without separators
    When  cmds ← path_commands("M0 0a1 1 0 0110 0")
    Then  length(cmds) = 2
    And   cmds[1].op = "A"
    And   cmds[1].args = (1, 1, 0, 0, 1, 10, 0)
    And   path_commands("M0 0 a-5 -5 30 1 0 10 0")[1].args = (5, 5, 30, 1, 0, 10, 0)

  Scenario: Nothing needs a separator where a sign or a point can do the job
    When  cmds ← path_commands("M1,2l3-4-5.5.5e1")
    Then  length(cmds) = 3
    And   cmds[1].args = (4, -2)
    And   cmds[2].args = (-1.5, 3)

  Scenario: The path must start with a moveto
    Then  length(path_commands("L10 10")) = 0
    And   length(path_commands("")) = 0
    And   length(path_commands("M0 0 z m1 1")) = 3
    And   path_commands("M0 0 z m1 1")[2].op = "M"

  Scenario: At an error, the commands so far are the answer
    Then  length(path_commands("M10 10 L20 20 L30 x 40")) = 2
    And   length(path_commands("M 10,10 L 20,20 30")) = 2
    And   length(path_commands("M0 0 L5 5 Z 6 6")) = 3
    And   length(path_commands("M0 0 L5 5 X 6 6")) = 2
    And   length(path_commands("M0 0 a1 1 0 2 0 5 5")) = 1

  Scenario: The tiger's first path
    Given root ← parse_xml(read_file("reference/chapter-20/tiger.svg"))
    When  cmds ← path_commands(attribute(find_by_id(root, "path8"), "d"))
    Then  length(cmds) = 5
    And   cmds[0].args = (-122.3, 84.285)
    And   cmds[1].op = "C"
    And   cmds[1].args = (-122.3, 84.285, -122.2, 86.179, -123.03, 86.16)
    And   cmds[2].args = (-123.85, 86.141, -140.3, 38.066, -160.83, 40.309)
    And   cmds[3].args = (-160.83, 40.309, -143.05, 32.956, -122.3, 84.285)
    And   cmds[4].op = "Z"
