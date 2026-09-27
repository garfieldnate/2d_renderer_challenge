Feature: The document
  Your XML library parses the file; the chapter asks four small things of
  what it hands back. parse_xml(text) is the document's root element. An
  element's name is its local name, with any namespace taken off, so the
  root of an SVG file is "svg" whatever prefix or xmlns it was written
  with. attribute(el, name) is the attribute's text exactly as written, or
  none when the element doesn't have it. children(el) is the child
  elements in document order, and nothing else: text and comments between
  them are not children. find_by_id(root, id) searches the whole document,
  before or after the place that asks, and answers none when nothing has
  that id.

  Scenario: An element is its local name, its attributes and its children
    Given root ← parse_xml("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 10 10'><g id='a' fill='red'><rect width='2'/><!-- a note --><circle r='1'/></g></svg>")
    Then  root.name = "svg"
    And   attribute(root, "viewBox") = "0 0 10 10"
    And   length(children(root)) = 1
    And   children(root)[0].name = "g"
    And   attribute(children(root)[0], "fill") = "red"
    And   attribute(children(root)[0], "stroke") = none
    And   length(children(children(root)[0])) = 2
    And   children(children(root)[0])[1].name = "circle"

  Scenario: A prefixed element has the same local name
    Given root ← parse_xml("<s:svg xmlns:s='http://www.w3.org/2000/svg'><s:path d='M0 0'/></s:svg>")
    Then  root.name = "svg"
    And   children(root)[0].name = "path"
    And   attribute(children(root)[0], "d") = "M0 0"

  Scenario: An id is found anywhere in the document, even ahead of where it is used
    Given root ← parse_xml("<svg><rect fill='url(#g)' width='4' height='4'/><defs><linearGradient id='g'><stop offset='0'/></linearGradient></defs></svg>")
    Then  find_by_id(root, "g").name = "linearGradient"
    And   find_by_id(root, "nothing") = none
