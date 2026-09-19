Feature: The pattern
  A dash pattern is a list of lengths, on, off, on, off. normalize_pattern
  turns it into the list the walk uses: an odd number of entries is repeated
  so on and off alternate the same way every cycle, and a pattern with a
  negative entry, or whose entries add up to nothing, is no pattern at all
  and comes back empty, which dash treats as draw the path solid. A
  zero-length entry is legal: a dash of length zero is a single point, which
  chapter 13 strokes into a dot under a round cap and nothing under a butt.

  Scenario: An odd pattern is repeated so on and off alternate the same way each cycle
    Then  normalize_pattern([5]) = [5, 5]
    And   normalize_pattern([5, 2, 1]) = [5, 2, 1, 5, 2, 1]
    And   normalize_pattern([4, 2]) = [4, 2]

  Scenario: A pattern that adds up to nothing, or has a negative entry, is no pattern
    Given seg ← path()
    When  move_to(seg, point(0, 0))
    And   line_to(seg, point(100, 0))
    Then  normalize_pattern([0, 0]) = []
    And   normalize_pattern([]) = []
    And   normalize_pattern([5, -5]) = []
    And   normalize_pattern([6, -2]) = []
    And   length(subpaths(dash(seg, [0, 0], 0))) = 1
    And   subpaths(dash(seg, [0, 0], 0))[0].points[1] = point(100, 0)
    And   length(subpaths(dash(seg, [], 0))) = 1
    And   length(subpaths(dash(seg, [6, -2], 0))) = 1

  Scenario: A repeated odd pattern walks as its doubled self
    Given seg ← path()
    When  move_to(seg, point(0, 0))
    And   line_to(seg, point(30, 0))
    And   d ← dash(seg, [5, 2, 1], 0)
    Then  length(subpaths(d)) = 6
    And   subpaths(d)[0].points[1] = point(5, 0)
    And   subpaths(d)[1].points[0] = point(7, 0)
    And   subpaths(d)[1].points[1] = point(8, 0)
    And   subpaths(d)[2].points[0] = point(13, 0)
    And   subpaths(d)[3].points[0] = point(16, 0)
    And   subpaths(d)[3].points[1] = point(21, 0)

  Scenario: A zero-length dash is a point, and with a round cap a dot
    Given seg ← path()
    When  move_to(seg, point(0, 0))
    And   line_to(seg, point(12, 0))
    And   d ← dash(seg, [0, 6], 0)
    Then  length(subpaths(d)) = 2
    And   length(subpaths(d)[0].points) = 1
    And   subpaths(d)[0].points[0] = point(0, 0)
    And   subpaths(d)[1].points[0] = point(6, 0)
    And   length(subpaths(stroke_to_path(d, 4, "round", "round", 4.0))) = 2
    And   bounds(stroke_to_path(d, 4, "round", "round", 4.0)) = (-2, -2, 8, 2)
    And   length(subpaths(stroke_to_path(d, 4, "butt", "round", 4.0))) = 0
