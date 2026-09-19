Feature: The cache and the atlas
  glyph_cache() holds bitmaps keyed by (glyph name, size, subpixel);
  cached_bitmap(cache, font, name, size, subpixel) renders on the first
  request and hands back the very same bitmap after, and cache_size counts
  them. atlas(width, height) is one big coverage buffer the bitmaps are
  packed into, shelf by shelf: bitmaps go left to right along a shelf whose
  height is its first bitmap's, and when one doesn't fit the shelf, a new
  shelf opens below the tallest so far. atlas_add(atlas, bitmap) copies the
  bitmap in and answers (x, y) of its top-left corner, or none when the
  atlas has no room.

  Scenario: A cache hit is the identical bitmap
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   cache ← glyph_cache()
    When  a ← cached_bitmap(cache, font, "H", 11, 0)
    And   b ← cached_bitmap(cache, font, "H", 11, 0)
    Then  cache_size(cache) = 1
    And   max_coverage_difference(a.coverage, b.coverage) = 0
    And   a.left = b.left
    And   ink(a.coverage) = 19.495859 ± 0.0001

  Scenario: A different quarter or size is a different entry
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   cache ← glyph_cache()
    When  a ← cached_bitmap(cache, font, "H", 11, 0)
    And   b ← cached_bitmap(cache, font, "H", 11, 1)
    And   c ← cached_bitmap(cache, font, "H", 12, 0)
    Then  cache_size(cache) = 3
    And   b.left = 1
    And   ink(b.coverage) = ink(a.coverage)

  Scenario: Shelf packing places bitmaps left to right, then opens a new shelf
    Given a ← atlas(32, 32)
    Then  atlas_add(a, bitmap(coverage_buffer(10, 8), 0, 0)) = (0, 0)
    And   atlas_add(a, bitmap(coverage_buffer(20, 8), 0, 0)) = (10, 0)
    And   atlas_add(a, bitmap(coverage_buffer(8, 8), 0, 0)) = (0, 8)
    And   atlas_add(a, bitmap(coverage_buffer(40, 5), 0, 0)) = none
    And   atlas_add(a, bitmap(coverage_buffer(30, 20), 0, 0)) = none
    And   atlas_add(a, bitmap(coverage_buffer(2, 2), 0, 0)) = (0, 16)
    And   atlas_add(a, bitmap(coverage_buffer(31, 2), 0, 0)) = (0, 18)

  Scenario: A taller bitmap that fits the width stays on the shelf and raises it
    Given a ← atlas(32, 32)
    Then  atlas_add(a, bitmap(coverage_buffer(10, 8), 0, 0)) = (0, 0)
    And   atlas_add(a, bitmap(coverage_buffer(12, 12), 0, 0)) = (10, 0)
    And   atlas_add(a, bitmap(coverage_buffer(10, 4), 0, 0)) = (22, 0)
    And   atlas_add(a, bitmap(coverage_buffer(5, 5), 0, 0)) = (0, 12)

  Scenario: The atlas holds the bitmap's coverage where it said
    Given font ← load_font(read_file("reference/chapter-16/roboto.json"))
    And   a ← atlas(32, 32)
    When  h ← glyph_bitmap(font, "H", 11, 0)
    And   at ← atlas_add(a, h)
    And   at2 ← atlas_add(a, glyph_bitmap(font, "a", 11, 0))
    Then  at = (0, 0)
    And   at2 = (7, 0)
    And   coverage_at(a.coverage, 1, 3) = coverage_at(h.coverage, 1, 3)
    And   coverage_at(a.coverage, 8, 3) = coverage_at(glyph_bitmap(font, "a", 11, 0).coverage, 1, 3)
