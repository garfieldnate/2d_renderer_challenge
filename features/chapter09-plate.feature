Feature: Plate 9
  The renders of chapter 9. porter_duff_table() lays the twelve operators in a
  4-by-3 grid, a blue square as destination and an orange circle as source,
  each tile flattened over paper; plate_09() is it magnified. blend_strip()
  shows the sixteen blend modes. seam() is the conflation trap: two opaque
  triangles that share the diagonal, drawn so a shape that should be solid
  carries a darker seam where both antialiased edges land on the same pixels.

  Scenario: The Porter-Duff table places each operator
    Given c ← porter_duff_table()
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 256
    And   c.height = 192
    And   ppm_pixel(p6, 20, 20) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 102, 38) = (249, 196, 89) ± 1
    And   ppm_pixel(p6, 148, 20) = (124, 188, 237) ± 1
    And   ppm_pixel(p6, 232, 38) = (249, 196, 89) ± 1
    And   ppm_pixel(p6, 40, 102) = (124, 188, 237) ± 1
    And   ppm_pixel(p6, 79, 79) = (39, 39, 44) ± 1
    And   ppm_pixel(p6, 102, 96) = (249, 196, 89) ± 1
    And   ppm_pixel(p6, 230, 160) = (39, 39, 44) ± 1

  Scenario: The conflation seam is 0.75, not 1.0
    Given half ← from_color(color(1, 1, 1), 0.5)
    And   black ← opaque(color(0, 0, 0))
    When  once ← composite("src-over", half, black)
    And   twice ← composite("src-over", half, once)
    Then  once = pixel(0.5, 0.5, 0.5, 1)
    And   twice = pixel(0.75, 0.75, 0.75, 1)

  Scenario: The seam shows in the render
    Given c ← seam()
    And   ref ← read_file("reference/chapter-09/seam.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 320
    And   c.height = 320
    And   ppm_pixel(p6, 40, 160) = (249, 196, 89) ± 1
    And   ppm_pixel(p6, 160, 160) = (220, 173, 81) ± 1
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: Plate 9
    Given c ← plate_09()
    And   ref ← read_file("reference/chapter-09/plate-09.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 512
    And   c.height = 384
    And   max_channel_difference(p6, ref) ≤ 1

  Scenario: The blend-mode strip
    Given c ← blend_strip()
    And   ref ← read_file("reference/chapter-09/blend-modes.ppm")
    When  p6 ← canvas_to_p6(c)
    Then  c.width = 256
    And   c.height = 256
    And   max_channel_difference(p6, ref) ≤ 1
