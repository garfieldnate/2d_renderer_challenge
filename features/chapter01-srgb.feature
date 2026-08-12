Feature: sRGB transfer functions
  The numbers in an image file are not proportional to light. These two
  functions convert between the two, and every later chapter depends on
  the canvas storing light rather than file values.

  Scenario Outline: Encoding light into file values
    Given l ← <light>
    Then  encode(l) = <value> ± 0.0001

    Examples:
      | light  | value  |
      | 0.0    | 0.0    |
      | 0.0025 | 0.0323 |
      | 0.216  | 0.5021 |
      | 0.5    | 0.7354 |
      | 1.0    | 1.0    |

  Scenario Outline: Decoding file values into light
    Given v ← <value>
    Then  decode(v) = <light> ± 0.0001

    Examples:
      | value  | light  |
      | 0.0    | 0.0    |
      | 0.5020 | 0.2159 |
      | 1.0    | 1.0    |

  Scenario: Decode undoes encode
    Given l ← 0.2
    Then  decode(encode(l)) = 0.2 ± 0.000000001

  Scenario: The half-gray that isn't 128
    Then  round(encode(0.5) * 255) = 188
