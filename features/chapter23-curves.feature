Feature: Fields for curves
  solve_cubic(a, b, c, d) is the real roots of a t³ + b t² + c t + d = 0 in
  increasing order: when |a| < 10⁻¹² it solves b t² + c t + d = 0 instead
  (and when |b| < 10⁻¹² too, c t + d = 0, with no roots when |c| < 10⁻¹²).
  The cubic's roots come from the depressed cubic by Cardano's formula
  when there's one and by the cosine formula when there are three.
  distance_to_quadratic(p, c): with a0 = P0 - p, a1 = 2 (P1 - P0) and
  a2 = P0 - 2 P1 + P2, the nearest point is at t = 0, t = 1, or a root in
  (0, 1) of solve_cubic(2 dot(a2, a2), 3 dot(a1, a2), dot(a1, a1) +
  2 dot(a0, a2), dot(a0, a1)); the answer is the least distance from p to
  point_at(c, t) over those t. distance_to_cubic(p, c) is the distance to
  point_at(c, nearest_t_cubic(p, c)): start from both ends, t = 0 and
  t = 1, and from nine seeds t = i / 8 for i from 0 to 8 take eight
  Newton steps each on f(t) = dot(B(t) - p, B'(t)), with f'(t) =
  dot(B'(t), B'(t)) + dot(B(t) - p, B''(t)), t ← clamp(t - f / f', 0, 1),
  stopping early when f' = 0; the t whose point is nearest wins, the ends
  first, then the seeds in order, ties kept. brute_distance(c, p) is
  the ground truth by search: the distances at t = i / 128 for i from 0 to
  128, and for every sample no farther than its neighbours (the ends have
  one) 40 rounds of ternary search between its neighbours' t, the least
  of all. weyl_points(n, x0, y0, w, h) is n points spread over a box the
  same way in every language: point k, for k from 1 to n, is (x0 + w
  frac(k a), y0 + h frac(k b)), with a = 0.7548776662466927, b =
  0.5698402909980532 and frac(v) = v - floor(v). max_curve_error(c, pts)
  is the greatest |distance - brute_distance| over the points, with the
  quadratic or the cubic distance as c has three or four points.

  Scenario: Cubic roots, and the cases that aren't cubic
    Then  solve_cubic(1, -6, 11, -6) = [1, 2, 3]
    And   solve_cubic(1, 0, 0, -8) = [2]
    And   solve_cubic(2, 0, -2, 0) = [-1, 0, 1]
    And   solve_cubic(0, 1, -3, 2) = [1, 2]
    And   solve_cubic(0, 0, 2, -1) = [0.5]
    And   solve_cubic(0, 0, 0, 1) = []

  Scenario: The nearest point of a quadratic
    Given flat ← quadratic(point(0, 0), point(5, 0), point(10, 0))
    And   arch ← quadratic(point(10, 80), point(50, -20), point(90, 80))
    Then  distance_to_quadratic(point(5, 3), flat) = 3
    And   distance_to_quadratic(point(13, 4), flat) = 5
    And   distance_to_quadratic(point(50, 20), arch) = 10
    And   distance_to_quadratic(point(50, 60), arch) = 26.532998

  Scenario: The nearest point of a cubic can be an end that Newton walks away from
    Given c ← cubic(point(30, 50), point(10, 40), point(10, 70), point(10, 100))
    Then  distance_to_cubic(point(70, 80), c) = 50
    And   nearest_t_cubic(point(70, 80), c) = 0

  Scenario: The points are the same everywhere
    Given pts ← weyl_points(2, 0, 0, 100, 100)
    Then  pts[0] = point(75.48776662466927, 56.98402909980532)
    And   pts[1] = point(50.97553324933854, 13.968058199610638)

  Scenario: Both fields match a brute-force search over 10,000 points
    Given pts ← weyl_points(10000, 0, 0, 100, 100)
    Then  max_curve_error(quadratic(point(10, 80), point(50, -20), point(90, 80)), pts) ≤ 0.000001
    And   max_curve_error(cubic(point(10, 80), point(30, -10), point(70, 120), point(90, 20)), pts) ≤ 0.000001

  Scenario: A cubic that loops back past the point
    Given c ← cubic(point(83.1679, 49.0113), point(3.7744, 16.9556), point(9.872, 71.7692), point(90.0182, 19.9317))
    Then  distance_to_cubic(point(52.2111, 45.0896), c) = 5.379229 ± 0.00001
    And   brute_distance(c, point(52.2111, 45.0896)) = 5.379229 ± 0.00001
    And   distance_to_curve(c, point(52.2111, 45.0896)) ≥ 5.4
