Feature: Source-over
  over(src, dst) is src composited over dst: src + (1 - src.a) * dst, every
  channel including alpha. It is exactly what paint_through has done since
  chapter 2, with an opaque destination. An opaque source hides whatever is
  behind it; a transparent source changes nothing; over an opaque destination
  the result stays opaque.

  Scenario: A translucent source over an opaque destination
    Given src ← from_color(color(1, 0, 0), 0.5)
    And   dst ← opaque(color(0, 0, 1))
    Then  over(src, dst) = pixel(0.5, 0, 0.5, 1)

  Scenario: An opaque source hides the destination
    Given src ← opaque(color(1, 0, 0))
    And   dst ← opaque(color(0, 0, 1))
    Then  over(src, dst) = src

  Scenario: A transparent source changes nothing
    Given dst ← from_color(color(0, 0, 1), 0.4)
    Then  over(CLEAR, dst) = dst

  Scenario: Over nothing leaves the source alone
    Given src ← from_color(color(1, 0, 0), 0.6)
    Then  over(src, CLEAR) = src

  Scenario: Two translucent pixels stack their alphas
    Given src ← from_color(color(1, 0, 0), 0.6)
    And   dst ← from_color(color(0, 0, 1), 0.4)
    Then  over(src, dst) = pixel(0.6, 0, 0.16, 0.76)
