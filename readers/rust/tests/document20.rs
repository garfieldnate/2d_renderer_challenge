// features/chapter20-document.feature

use renderer::{attribute, children, find_by_id, parse_xml};

#[test]
fn an_element_is_its_local_name_its_attributes_and_its_children() {
    let root = parse_xml("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 10 10'><g id='a' fill='red'><rect width='2'/><!-- a note --><circle r='1'/></g></svg>");
    assert_eq!(root.name, "svg");
    assert_eq!(attribute(&root, "viewBox"), Some("0 0 10 10"));
    assert_eq!(children(&root).len(), 1);
    assert_eq!(children(&root)[0].name, "g");
    assert_eq!(attribute(&children(&root)[0], "fill"), Some("red"));
    assert_eq!(attribute(&children(&root)[0], "stroke"), None);
    assert_eq!(children(&children(&root)[0]).len(), 2);
    assert_eq!(children(&children(&root)[0])[1].name, "circle");
}

#[test]
fn a_prefixed_element_has_the_same_local_name() {
    let root = parse_xml("<s:svg xmlns:s='http://www.w3.org/2000/svg'><s:path d='M0 0'/></s:svg>");
    assert_eq!(root.name, "svg");
    assert_eq!(children(&root)[0].name, "path");
    assert_eq!(attribute(&children(&root)[0], "d"), Some("M0 0"));
}

#[test]
fn an_id_is_found_anywhere_in_the_document_even_ahead_of_where_it_is_used() {
    let root = parse_xml("<svg><rect fill='url(#g)' width='4' height='4'/><defs><linearGradient id='g'><stop offset='0'/></linearGradient></defs></svg>");
    assert_eq!(find_by_id(&root, "g").unwrap().name, "linearGradient");
    assert!(find_by_id(&root, "nothing").is_none());
}
