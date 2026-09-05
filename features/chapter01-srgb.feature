Feature: sRGB transfer functions
  The numbers in an image file are not proportional to light. decode turns
  a file value into light and encode turns light back into a file value.
  Both take and return numbers between 0 and 1.

  Scenario Outline: Encoding light into a file value
    Given l ← <light>
    Then  encode(l) = <value>

    Examples:
      | light     | value  |
      | 0.0       | 0.0    |
      | 0.0025    | 0.0323 |
      | 0.01      | 0.0999 |
      | 0.1       | 0.3492 |
      | 0.216     | 0.5021 |
      | 0.25      | 0.5371 |
      | 0.5       | 0.7354 |
      | 0.75      | 0.8808 |
      | 1.0       | 1.0    |

  Scenario Outline: Decoding a file value into light
    Given v ← <value>
    Then  decode(v) = <light>

    Examples:
      | value   | light  |
      | 0.0     | 0.0    |
      | 0.04    | 0.0031 |
      | 0.05    | 0.0039 |
      | 0.1     | 0.0100 |
      | 0.5     | 0.2140 |
      | 0.75    | 0.5225 |
      | 1.0     | 1.0    |

  Scenario: Decode undoes encode
    Given l ← 0.2
    Then  decode(encode(l)) = 0.2 ± 0.000000001

  Scenario: Encode undoes decode
    Given v ← 0.7
    Then  encode(decode(v)) = 0.7 ± 0.000000001

  Scenario: The half gray that isn't 128
    Then  round(encode(0.5) * 255) = 188

  Scenario: What 128 actually is
    Then  decode(128 / 255) = 0.2159
