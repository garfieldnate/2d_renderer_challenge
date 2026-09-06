// features/chapter06-spans.feature
import { close, line_to, move_to, path, polygon } from "../src/path.ts";
import { star } from "../src/scenes.ts";
import { coverage_at, coverage_buffer, ink } from "../src/coverage.ts";
import { crossings_on_row, edge_table, fill_span, spans, spans_from_crossings } from "../src/sweep.ts";
import { point } from "../src/tuple.ts";
import { assert_eq } from "../src/assert.ts";

function assert_pairs(a: [number, number][], b: [number, number][], eps = 0.0001): void {
  if (a.length !== b.length) {
    throw new Error(`expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
  }
  for (let i = 0; i < a.length; i++) {
    if (Math.abs(a[i][0] - b[i][0]) > eps || Math.abs(a[i][1] - b[i][1]) > eps) {
      throw new Error(`expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
    }
  }
}

Deno.test("Crossings on a row, sorted by x", () => {
  const p = polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6));
  const xs = crossings_on_row(edge_table(p), 3.5);
  assert_pairs(xs, [[2, -1], [6, 1]]);
  assert_pairs(crossings_on_row(edge_table(p), 1.5), []);
  assert_pairs(crossings_on_row(edge_table(p), 6), []);
  assert_eq(crossings_on_row(edge_table(p), 2).length, 2, 0);
});

Deno.test("The star's crossings through its middle", () => {
  const p = star();
  const xs = crossings_on_row(edge_table(p), 80.5);
  assert_eq(xs.length, 4, 0);
  assert_pairs([xs[0]], [[43.6988, -1]]);
  assert_pairs([xs[1]], [[57.7556, -1]]);
  assert_pairs([xs[2]], [[103.2444, 1]]);
  assert_pairs([xs[3]], [[117.3012, 1]]);
});

Deno.test("Spans from crossings under each rule", () => {
  const xs: [number, number][] = [[1, 1], [3, 1], [5, -1], [7, -1]];
  assert_pairs(spans_from_crossings(xs, "nonzero"), [[1, 7]]);
  assert_pairs(spans_from_crossings(xs, "evenodd"), [[1, 3], [5, 7]]);
  assert_pairs(spans_from_crossings([], "nonzero"), []);
});

Deno.test("The spans of an axis-aligned rectangle are exact", () => {
  const p = polygon(point(1.25, 2), point(4.75, 2), point(4.75, 5), point(1.25, 5));
  assert_pairs(spans(p, "nonzero", 1), []);
  assert_pairs(spans(p, "nonzero", 2), [[1.25, 4.75]]);
  assert_pairs(spans(p, "nonzero", 4), [[1.25, 4.75]]);
  assert_pairs(spans(p, "nonzero", 5), []);
});

Deno.test("A rectangle whose edges sit on sample heights", () => {
  const p = polygon(point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5));
  assert_pairs(spans(p, "nonzero", 1), []);
  assert_pairs(spans(p, "nonzero", 2), [[1.5, 4.5]]);
  assert_pairs(spans(p, "nonzero", 4), [[1.5, 4.5]]);
  assert_pairs(spans(p, "nonzero", 5), []);
});

for (const [row, x0, x1] of [[0, 0.25, 9.75], [1, 0.75, 9.25], [4, 2.25, 7.75], [9, 4.75, 5.25]]) {
  Deno.test(`A triangle's spans narrow by one per row: row ${row}`, () => {
    const p = polygon(point(0, 0), point(10, 0), point(5, 10));
    assert_pairs(spans(p, "nonzero", row), [[x0, x1]]);
  });
}

Deno.test("The row past the triangle's apex has no span", () => {
  const p = polygon(point(0, 0), point(10, 0), point(5, 10));
  assert_pairs(spans(p, "nonzero", 10), []);
});

Deno.test("A flat top is not a span of its own", () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 5), point(0, 5));
  assert_eq(edge_table(p).length, 2, 0);
  assert_pairs(spans(p, "nonzero", 0), [[0, 10]]);
  assert_pairs(spans(p, "nonzero", 4), [[0, 10]]);
  assert_pairs(spans(p, "nonzero", 5), []);
});

Deno.test("A ring is two spans under even-odd and one under nonzero", () => {
  const p = path();
  move_to(p, point(0, 0));
  line_to(p, point(10, 0));
  line_to(p, point(10, 10));
  line_to(p, point(0, 10));
  close(p);
  move_to(p, point(3, 3));
  line_to(p, point(7, 3));
  line_to(p, point(7, 7));
  line_to(p, point(3, 7));
  close(p);
  assert_pairs(spans(p, "nonzero", 5), [[0, 10]]);
  assert_pairs(spans(p, "evenodd", 5), [[0, 3], [7, 10]]);
});

Deno.test("The star's spans through its middle", () => {
  const p = star();
  assert_pairs(spans(p, "nonzero", 80), [[43.6988, 117.3012]]);
  assert_pairs(spans(p, "evenodd", 80), [[43.6988, 57.7556], [103.2444, 117.3012]]);
});

Deno.test("fill_span fills the pixels whose centers are in the span", () => {
  const cov = coverage_buffer(8, 3);
  fill_span(cov, 1, 1.25, 4.75);
  assert_eq(coverage_at(cov, 0, 1), 0, 0);
  assert_eq(coverage_at(cov, 1, 1), 1, 0);
  assert_eq(coverage_at(cov, 4, 1), 1, 0);
  assert_eq(coverage_at(cov, 5, 1), 0, 0);
  assert_eq(coverage_at(cov, 2, 0), 0, 0);
  assert_eq(ink(cov), 4);
});

Deno.test("The span is half-open at its right end", () => {
  const cov = coverage_buffer(8, 3);
  fill_span(cov, 1, 1.5, 4.5);
  assert_eq(coverage_at(cov, 1, 1), 1, 0);
  assert_eq(coverage_at(cov, 3, 1), 1, 0);
  assert_eq(coverage_at(cov, 4, 1), 0, 0);
  assert_eq(ink(cov), 3);
});

Deno.test("A span may run off either side of the buffer", () => {
  const a = coverage_buffer(8, 3);
  const b = coverage_buffer(8, 3);
  const c = coverage_buffer(8, 3);
  fill_span(a, 1, -3, 2.5);
  fill_span(b, 1, 6.5, 20);
  fill_span(c, 1, 2.5, 2.5);
  assert_eq(ink(a), 2);
  assert_eq(coverage_at(a, 1, 1), 1, 0);
  assert_eq(ink(b), 2);
  assert_eq(coverage_at(b, 6, 1), 1, 0);
  assert_eq(ink(c), 0);
});
