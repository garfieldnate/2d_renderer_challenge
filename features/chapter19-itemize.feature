Feature: Itemizing: runs of one script and one direction
  A string is not one run. Before anything is shaped it is cut into items,
  each in one script and one direction, because each script has its own
  font and its own rules and Arabic reads right to left. script_of(codepoint)
  answers "arabic" for the Arabic block (U+0600 to U+06FF), "latin" for
  the Latin letters A to Z, a to z and U+00C0 to U+024F, and "common" for
  everything else: spaces, digits and punctuation, which have no script of
  their own. itemize(text) cuts where the script changes; a common
  character joins the run before it, common characters at the very start
  join the first run, and text of nothing but common characters is one
  latin run. Each item has start, end (exclusive), text, script, and a
  direction: "rtl" for arabic, "ltr" otherwise.

  Scenario: Letters have a script; spaces and punctuation don't
    Then  script_of(65) = "latin"
    And   script_of(233) = "latin"
    And   script_of(1603) = "arabic"
    And   script_of(32) = "common"
    And   script_of(44) = "common"
    And   script_of(51) = "common"

  Scenario: A Latin run and an Arabic run, the punctuation going with the run before it
    When  items ← itemize("Book: كِتاب.")
    Then  length(items) = 2
    And   items[0].start = 0
    And   items[0].end = 6
    And   items[0].text = "Book: "
    And   items[0].script = "latin"
    And   items[0].direction = "ltr"
    And   items[1].start = 6
    And   items[1].end = 12
    And   items[1].text = "كِتاب."
    And   items[1].script = "arabic"
    And   items[1].direction = "rtl"

  Scenario: One script is one item, and common characters alone are Latin
    Then  length(itemize("كِتاب")) = 1
    And   itemize("كِتاب")[0].direction = "rtl"
    And   length(itemize("  12 ")) = 1
    And   itemize("  12 ")[0].script = "latin"
    And   itemize("  12 ")[0].end = 5
    And   length(itemize("")) = 0
    And   length(itemize("aكِتابb")) = 3
    And   itemize("aكِتابb")[2].text = "b"
    And   itemize("aكِتابb")[2].start = 6
