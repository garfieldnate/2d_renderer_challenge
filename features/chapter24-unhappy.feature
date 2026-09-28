Feature: The unhappy path
  A GPU tile keeps its blocks in fast memory that holds STACK_DEPTH
  blocks, 2, the tile's own block included. fine_tile adds 1 to fs.spills
  for every push made when the stack already holds STACK_DEPTH blocks:
  that group's block lives in slow memory instead, found by an allocation
  pass a real renderer has to run between coarse and fine. The picture
  doesn't change; the cost does. max_group_depth(commands) is the deepest
  nesting of Push in the list.

  Scenario: Groups nested two deep spill, one deep don't
    Given harbor ← Scene(encode_svg(read_file("reference/chapter-20/harbor.svg"), 480, 320), 480, 320)
    And   rose ← Scene(encode_svg(read_file("reference/chapter-20/rose.svg"), 400, 400), 400, 400)
    And   fh ← FineStats()
    And   fr ← FineStats()
    When  a ← run_pipeline(harbor, none, fh)
    And   b ← run_pipeline(rose, none, fr)
    Then  STACK_DEPTH = 2
    And   fh.spills = 0
    And   fr.spills = 200
    And   fr.tiles = 625
    And   max_group_depth(rose.commands) = 2
    And   max_group_depth(harbor.commands) = 1
