// features/chapter19-itemize.feature

use renderer::itemize;

fn script_of(cp: i64) -> String {
    renderer::script_of(cp)
}

#[test]
fn letters_have_a_script_spaces_and_punctuation_dont() {
    assert_eq!(script_of(65), "latin");
    assert_eq!(script_of(233), "latin");
    assert_eq!(script_of(1603), "arabic");
    assert_eq!(script_of(32), "common");
    assert_eq!(script_of(44), "common");
    assert_eq!(script_of(51), "common");
}

#[test]
fn a_latin_run_and_an_arabic_run_the_punctuation_going_with_the_run_before_it() {
    let items = itemize("Book: \u{0643}\u{0650}\u{062A}\u{0627}\u{0628}.");
    assert_eq!(items.len(), 2);
    assert_eq!(items[0].start, 0);
    assert_eq!(items[0].end, 6);
    assert_eq!(items[0].text, "Book: ");
    assert_eq!(items[0].script, "latin");
    assert_eq!(items[0].direction, "ltr");
    assert_eq!(items[1].start, 6);
    assert_eq!(items[1].end, 12);
    assert_eq!(items[1].text, "\u{0643}\u{0650}\u{062A}\u{0627}\u{0628}.");
    assert_eq!(items[1].script, "arabic");
    assert_eq!(items[1].direction, "rtl");
}

#[test]
fn one_script_is_one_item_and_common_characters_alone_are_latin() {
    let kitab = "\u{0643}\u{0650}\u{062A}\u{0627}\u{0628}";
    assert_eq!(itemize(kitab).len(), 1);
    assert_eq!(itemize(kitab)[0].direction, "rtl");

    assert_eq!(itemize("  12 ").len(), 1);
    assert_eq!(itemize("  12 ")[0].script, "latin");
    assert_eq!(itemize("  12 ")[0].end, 5);

    assert_eq!(itemize("").len(), 0);

    let mixed = format!("a{kitab}b");
    assert_eq!(itemize(&mixed).len(), 3);
    assert_eq!(itemize(&mixed)[2].text, "b");
    assert_eq!(itemize(&mixed)[2].start, 6);
}
