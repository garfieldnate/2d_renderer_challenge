Feature: The twelve Porter-Duff operators
  composite(op, src, dst) is one formula, Fa * src + Fb * dst on every channel,
  where Fa and Fb are the fraction of the source and of the destination that
  survive. Each operator is only its choice of those two coefficients. With a
  source of red at alpha 0.6 and a destination of blue at alpha 0.4, the twelve
  operators come out as below. src-over is over; dst-over is over with the
  arguments swapped.

  Scenario Outline: Each operator is its two coefficients
    Given src ← from_color(color(1, 0, 0), 0.6)
    And   dst ← from_color(color(0, 0, 1), 0.4)
    Then  composite("<op>", src, dst) = pixel(<r>, <g>, <b>, <a>)

    Examples:
      | op        | r    | g | b    | a    |
      | clear     | 0    | 0 | 0    | 0    |
      | src       | 0.6  | 0 | 0    | 0.6  |
      | dst       | 0    | 0 | 0.4  | 0.4  |
      | src-over  | 0.6  | 0 | 0.16 | 0.76 |
      | dst-over  | 0.36 | 0 | 0.4  | 0.76 |
      | src-in    | 0.24 | 0 | 0    | 0.24 |
      | dst-in    | 0    | 0 | 0.24 | 0.24 |
      | src-out   | 0.36 | 0 | 0    | 0.36 |
      | dst-out   | 0    | 0 | 0.16 | 0.16 |
      | src-atop  | 0.24 | 0 | 0.16 | 0.4  |
      | dst-atop  | 0.36 | 0 | 0.24 | 0.6  |
      | xor       | 0.36 | 0 | 0.16 | 0.52 |

  Scenario: src-over is over, and dst-over is over with the arguments swapped
    Given src ← from_color(color(1, 0, 0), 0.6)
    And   dst ← from_color(color(0, 0, 1), 0.4)
    Then  composite("src-over", src, dst) = over(src, dst)
    And   composite("dst-over", src, dst) = over(dst, src)

  Scenario: clear empties the pixel and dst keeps it
    Given src ← opaque(color(1, 0, 0))
    And   dst ← opaque(color(0, 0, 1))
    Then  composite("clear", src, dst) = CLEAR
    And   composite("dst", src, dst) = dst
    And   composite("src", src, dst) = src
