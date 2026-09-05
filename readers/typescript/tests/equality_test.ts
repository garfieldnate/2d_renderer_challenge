// features/chapter01-equality.feature
import { assert_eq, assert_ne } from "../src/assert.ts";

Deno.test("Two numbers that differ by less than the tolerance are equal", () => {
  assert_eq(1.0, 1.0000001, 0.00001);
});

Deno.test("Two numbers that differ by more than the tolerance are not", () => {
  assert_ne(1.0, 1.001, 0.00001);
});

Deno.test("The default tolerance is 0.0001", () => {
  assert_eq(0.1 + 0.2, 0.3);
  assert_eq(1.0, 1.00009);
  assert_ne(1.0, 1.0002);
});
