Feature: The distance transform
  edt_1d(f) is, for every q, the least of (q - p)² + f[p] over every p,
  by Felzenszwalb and Huttenlocher's lower envelope of parabolas: v
  lists the parabolas on the envelope and z where each takes over,
  starting v[0] = 0, z[0] = -∞, z[1] = +∞, k = 0. For q from 1: s ←
  ((f[q] + q²) - (f[v[k]] + v[k]²)) / (2q - 2 v[k]); while s ≤ z[k], k ←
  k - 1 and compute s again; then k ← k + 1, v[k] ← q, z[k] ← s, z[k +
  1] ← +∞. Then, with k back at 0, for each q: while z[k + 1] < q, k ← k
  + 1; and d[q] = (q - v[k])² + f[v[k]]. far_value(w, h) is w² + h²,
  more than any squared distance on the grid. distance_transform(bits,
  w, h) takes a bitmap, row by row, and answers for every pixel the
  squared distance from its center to the nearest center that's on: f is
  0 where on and far_value where off; run edt_1d down every column, then
  along every row of the result. Where nothing is on, every answer is
  far_value. Every number is a whole number and the only division is
  compared, never kept, so the answer is exact.
  brute_distance_transform(bits, w, h) is the same by trying every pixel
  that's on, far_value when none is. bits_of(cov) is on where the
  coverage is at least 0.5. field_from_coverage(cov) turns any coverage
  buffer into a field: at a pixel that's off, the square root of its
  squared distance to the nearest on pixel, less 0.5; at one that's on,
  minus (the square root of its squared distance to the nearest off
  pixel, less 0.5). coverage_of(w, h, values) makes a coverage buffer
  from a list, row by row. transform_bitmap() is Roboto's g at 48 pixels
  to the em, origin (14, 44), filled by chapter 7 into a 64 by 64
  buffer.

  Scenario: One row
    Given big ← far_value(5, 1)
    Then  big = 26
    And   edt_1d([0, big, big, 0, big]) = [0, 1, 1, 0, 1]
    And   edt_1d([big, big, big, big, 0]) = [16, 9, 4, 1, 0]
    And   edt_1d([4, big, 0, big, big]) = [4, 1, 0, 1, 4]

  Scenario: Columns, then rows
    Given bits ← [false, false, false, false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false, false]
    Then  distance_transform(bits, 5, 5) = [8, 5, 4, 5, 8, 5, 2, 1, 2, 5, 4, 1, 0, 1, 4, 5, 2, 1, 2, 5, 8, 5, 4, 5, 8]
    And   distance_transform([false, false, false, false, false, false], 3, 2) = [13, 13, 13, 13, 13, 13]

  Scenario: The transform matches trying every pixel, exactly
    Given bits ← bits_of(transform_bitmap())
    Then  distance_transform(bits, 64, 64) = brute_distance_transform(bits, 64, 64)

  Scenario: Any coverage becomes a field
    Given cov ← transform_bitmap()
    When  f ← field_from_coverage(cov)
    Then  field_from_coverage(coverage_of(4, 1, [0, 0.4, 0.6, 1])).values = [1.5, 0.5, -0.5, -1.5]
    And   field_at(f, 0, 0) = 27.784271
    And   field_range(f) = (-2.5, 31.702484)
