import test from 'node:test';
import { strict as assert } from 'node:assert';
import { promises as fs } from 'node:fs';
import { readFileSync } from 'node:fs';

// ===========================
// Color class
// ===========================
class Color {
  constructor(red, green, blue) {
    this.red = red;
    this.green = green;
    this.blue = blue;
  }

  static equals(a, b, tolerance = 0.0001) {
    return Math.abs(a.red - b.red) <= tolerance &&
           Math.abs(a.green - b.green) <= tolerance &&
           Math.abs(a.blue - b.blue) <= tolerance;
  }

  add(other) {
    return new Color(this.red + other.red, this.green + other.green, this.blue + other.blue);
  }

  subtract(other) {
    return new Color(this.red - other.red, this.green - other.green, this.blue - other.blue);
  }

  scale(factor) {
    return new Color(this.red * factor, this.green * factor, this.blue * factor);
  }

  multiply(other) {
    return new Color(this.red * other.red, this.green * other.green, this.blue * other.blue);
  }
}

// ===========================
// sRGB transfer functions
// ===========================
function decode(v) {
  return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

function encode(l) {
  return l <= 0.0031308 ? l * 12.92 : 1.055 * Math.pow(l, 1 / 2.4) - 0.055;
}

function clamp(value) {
  return Math.max(0, Math.min(1, value));
}

function round(x) {
  return Math.floor(x + 0.5);
}

// ===========================
// Canvas class
// ===========================
class Canvas {
  constructor(width, height) {
    this.width = width;
    this.height = height;
    // Store pixels as a flat array: pixel[y * width + x]
    this.pixels = Array(width * height).fill(null).map(() => new Color(0, 0, 0));
  }

  write_pixel(x, y, color) {
    if (x >= 0 && x < this.width && y >= 0 && y < this.height) {
      this.pixels[y * this.width + x] = color;
    }
  }

  pixel_at(x, y) {
    if (x >= 0 && x < this.width && y >= 0 && y < this.height) {
      return this.pixels[y * this.width + x];
    }
    return new Color(0, 0, 0);
  }

  fill(color) {
    this.pixels.fill(color);
  }
}

// ===========================
// PPM output
// ===========================
function color_to_bytes(c) {
  const clamped = new Color(clamp(c.red), clamp(c.green), clamp(c.blue));
  const encoded = new Color(encode(clamped.red), encode(clamped.green), encode(clamped.blue));
  const scaled = encoded.scale(255);
  return [
    round(scaled.red),
    round(scaled.green),
    round(scaled.blue)
  ];
}

function canvas_to_ppm(canvas) {
  let lines = ['P3', `${canvas.width} ${canvas.height}`, '255'];
  let currentLine = '';

  for (let y = 0; y < canvas.height; y++) {
    currentLine = '';
    for (let x = 0; x < canvas.width; x++) {
      const pixel = canvas.pixel_at(x, y);
      const [r, g, b] = color_to_bytes(pixel);

      for (const byte of [r, g, b]) {
        const byteStr = byte.toString();
        if (currentLine.length + byteStr.length + 1 > 70) {
          lines.push(currentLine);
          currentLine = byteStr;
        } else {
          if (currentLine.length > 0) {
            currentLine += ' ';
          }
          currentLine += byteStr;
        }
      }
    }
    if (currentLine.length > 0) {
      lines.push(currentLine);
    }
  }

  return lines.join('\n') + '\n';
}

function ppm_pixel_correct(ppm, x, y) {
  const lines = ppm.split('\n');
  const [width, height] = lines[1].split(' ').map(Number);

  const tokens = [];
  for (let i = 3; i < lines.length; i++) {
    const parts = lines[i].trim().split(/\s+/);
    for (const part of parts) {
      if (part) tokens.push(parseInt(part));
    }
  }

  const pixelIndex = y * width + x;
  const idx = pixelIndex * 3;
  return [tokens[idx], tokens[idx + 1], tokens[idx + 2]];
}

function ppm_pixel(data, x, y) {
  if (typeof data === 'string') {
    return ppm_pixel_correct(data, x, y);
  } else {
    return ppm_pixel_from_bytes(data, x, y);
  }
}

function max_channel_difference(data1, data2) {
  const parsed1 = parse_ppm(data1);
  const parsed2 = parse_ppm(data2);

  // If dimensions don't match, return maximum difference
  if (parsed1.width !== parsed2.width || parsed1.height !== parsed2.height) {
    return 255;
  }

  let maxDiff = 0;
  for (let i = 0; i < parsed1.tokens.length; i++) {
    const diff = Math.abs(parsed1.tokens[i] - parsed2.tokens[i]);
    if (diff > maxDiff) maxDiff = diff;
  }
  return maxDiff;
}

function read_file(path) {
  return readFileSync(path, 'utf-8');
}

function distinct_values(data) {
  const { tokens } = parse_ppm(data);
  const unique = new Set(tokens);
  return unique.size;
}

// ===========================
// Global state for mix
// ===========================
let linearBlending = true;

function set_linear_blending(value) {
  linearBlending = value;
}

function mix(a, b, t, useLinear = linearBlending) {
  if (useLinear) {
    // Correct: linear interpolation in light space
    return new Color(
      a.red + (b.red - a.red) * t,
      a.green + (b.green - a.green) * t,
      a.blue + (b.blue - a.blue) * t
    );
  } else {
    // Wrong: browser way - interpolate in encoded space. Each end is
    // clamped to [0, 1] before it is encoded.
    const clampedA = new Color(clamp(a.red), clamp(a.green), clamp(a.blue));
    const clampedB = new Color(clamp(b.red), clamp(b.green), clamp(b.blue));
    const encA = new Color(encode(clampedA.red), encode(clampedA.green), encode(clampedA.blue));
    const encB = new Color(encode(clampedB.red), encode(clampedB.green), encode(clampedB.blue));
    const mixed = new Color(
      encA.red + (encB.red - encA.red) * t,
      encA.green + (encB.green - encA.green) * t,
      encA.blue + (encB.blue - encA.blue) * t
    );
    return new Color(decode(mixed.red), decode(mixed.green), decode(mixed.blue));
  }
}

// ===========================
// Render functions
// ===========================
function gray_match() {
  const c = new Canvas(300, 100);
  // Left third: checkerboard
  for (let y = 0; y < 100; y++) {
    for (let x = 0; x < 100; x++) {
      const color = (x + y) % 2 === 0 ? new Color(1, 1, 1) : new Color(0, 0, 0);
      c.write_pixel(x, y, color);
    }
  }
  // Middle third: decode(128/255)
  const g = decode(128 / 255);
  for (let y = 0; y < 100; y++) {
    for (let x = 100; x < 200; x++) {
      c.write_pixel(x, y, new Color(g, g, g));
    }
  }
  // Right third: 0.5
  for (let y = 0; y < 100; y++) {
    for (let x = 200; x < 300; x++) {
      c.write_pixel(x, y, new Color(0.5, 0.5, 0.5));
    }
  }
  return c;
}

function quarter_match() {
  const c = new Canvas(200, 100);
  // Left half: pattern (white when x + y is multiple of 4)
  for (let y = 0; y < 100; y++) {
    for (let x = 0; x < 100; x++) {
      const color = (x + y) % 4 === 0 ? new Color(1, 1, 1) : new Color(0, 0, 0);
      c.write_pixel(x, y, color);
    }
  }
  // Right half: solid 0.25
  for (let y = 0; y < 100; y++) {
    for (let x = 100; x < 200; x++) {
      c.write_pixel(x, y, new Color(0.25, 0.25, 0.25));
    }
  }
  return c;
}

function ramp() {
  const c = new Canvas(256, 32);
  for (let x = 0; x < 256; x++) {
    const g = x / 255;
    for (let y = 0; y < 32; y++) {
      c.write_pixel(x, y, new Color(g, g, g));
    }
  }
  return c;
}

function clamp_pair() {
  const c = new Canvas(200, 100);
  // Left patch: color(2, 0.5, 0.5)
  const left = new Color(2, 0.5, 0.5);
  for (let y = 0; y < 100; y++) {
    for (let x = 0; x < 100; x++) {
      c.write_pixel(x, y, left);
    }
  }
  // Right patch: color(1, 0.25, 0.25)
  const right = new Color(1, 0.25, 0.25);
  for (let y = 0; y < 100; y++) {
    for (let x = 100; x < 200; x++) {
      c.write_pixel(x, y, right);
    }
  }
  return c;
}

function plate_01() {
  const c = new Canvas(400, 180);
  const ramps = [
    { a: new Color(0, 0, 0), b: new Color(1, 1, 1) },
    { a: new Color(0.7, 0, 0), b: new Color(0, 0.3, 0.02) }
  ];

  for (let i = 0; i < 2; i++) {
    const { a, b } = ramps[i];
    const top = i * 90;
    for (let x = 0; x < 400; x++) {
      const t = x / 399;

      // Naive (browser) way
      set_linear_blending(false);
      const naive = mix(a, b, t);
      // Light way
      set_linear_blending(true);
      const light = mix(a, b, t);

      for (let y = top; y <= top + 39; y++) {
        c.write_pixel(x, y, naive);
      }
      for (let y = top + 45; y <= top + 84; y++) {
        c.write_pixel(x, y, light);
      }
    }
  }
  set_linear_blending(true); // Reset to default
  return c;
}

// ===========================
// Test suite
// ===========================

// Helper for comparing colors with tolerance
function assert_color_equal(actual, expected, tolerance = 0.0001, msg = '') {
  const check = Color.equals(actual, expected, tolerance);
  if (!check) {
    throw new Error(`${msg} Expected color(${expected.red}, ${expected.green}, ${expected.blue}), got color(${actual.red}, ${actual.green}, ${actual.blue})`);
  }
}

function assert_number_equal(actual, expected, tolerance = 0.0001, msg = '') {
  if (Math.abs(actual - expected) > tolerance) {
    throw new Error(`${msg} Expected ${expected} (±${tolerance}), got ${actual}`);
  }
}

// Helper for comparing a (min x, min y, max x, max y) bounds tuple with tolerance
function assert_bounds_equal(actual, expected, tolerance = 0.0001) {
  for (let i = 0; i < 4; i++) {
    assert_number_equal(actual[i], expected[i], tolerance, `bounds[${i}]:`);
  }
}

// Helper for comparing an (a, b) edge (a pair of points) with tolerance
function assert_edge_equal(actual, expected, tolerance = 0.0001) {
  assert(Tuple.equals(actual[0], expected[0], tolerance));
  assert(Tuple.equals(actual[1], expected[1], tolerance));
}

// Helper for comparing a (x, direction) crossing with tolerance on x
function assert_crossing_equal(actual, expected, tolerance = 0.0001) {
  assert_number_equal(actual[0], expected[0], tolerance);
  assert.strictEqual(actual[1], expected[1]);
}

// Helper for comparing an (x0, x1) span with tolerance
function assert_span_equal(actual, expected, tolerance = 0.0001) {
  assert_number_equal(actual[0], expected[0], tolerance);
  assert_number_equal(actual[1], expected[1], tolerance);
}

// Helper for comparing a list of (x0, x1) spans with tolerance
function assert_spans_equal(actual, expected, tolerance = 0.0001) {
  assert.strictEqual(actual.length, expected.length);
  for (let i = 0; i < actual.length; i++) {
    assert_span_equal(actual[i], expected[i], tolerance);
  }
}

// Helper for a ppm_pixel probe with the render scenarios' usual ± 1
function assert_pixel_approx(data, x, y, expected, tolerance = 1) {
  const px = ppm_pixel(data, x, y);
  for (let i = 0; i < 3; i++) {
    assert(Math.abs(px[i] - expected[i]) <= tolerance,
      `pixel(${x},${y})[${i}]: expected ${expected[i]} ± ${tolerance}, got ${px[i]}`);
  }
}

// Chapter 1 - Equality
test('Equality: Two numbers that differ by less than tolerance are equal', () => {
  assert_number_equal(1.0, 1.0000001, 0.00001);
});

test('Equality: Two numbers that differ by more than tolerance are not', () => {
  const val1 = 1.0;
  const val2 = 1.001;
  assert(Math.abs(val1 - val2) > 0.00001, 'Numbers should differ by more than tolerance');
});

test('Equality: Default tolerance is 0.0001', () => {
  assert_number_equal(0.1 + 0.2, 0.3);
  assert_number_equal(1.0, 1.00009);
  assert(Math.abs(1.0 - 1.0002) > 0.0001, 'Should differ');
});

// Chapter 1 - Colors
test('Colors: A color is a red, green, blue tuple', () => {
  const c = new Color(-0.5, 0.4, 1.7);
  assert.strictEqual(c.red, -0.5);
  assert.strictEqual(c.green, 0.4);
  assert.strictEqual(c.blue, 1.7);
});

test('Colors: Adding colors', () => {
  const c1 = new Color(0.9, 0.6, 0.75);
  const c2 = new Color(0.7, 0.1, 0.25);
  const result = c1.add(c2);
  assert_color_equal(result, new Color(1.6, 0.7, 1.0));
});

test('Colors: Subtracting colors', () => {
  const c1 = new Color(0.9, 0.6, 0.75);
  const c2 = new Color(0.7, 0.1, 0.25);
  const result = c1.subtract(c2);
  assert_color_equal(result, new Color(0.2, 0.5, 0.5));
});

test('Colors: Scaling a color by a number', () => {
  const c = new Color(0.2, 0.3, 0.4);
  assert_color_equal(c.scale(2), new Color(0.4, 0.6, 0.8));
  assert_color_equal(c.scale(0.5), new Color(0.1, 0.15, 0.2));
});

test('Colors: Multiplying two colors filters one through the other', () => {
  const c1 = new Color(1, 0.2, 0.4);
  const c2 = new Color(0.9, 1, 0.1);
  const result = c1.multiply(c2);
  assert_color_equal(result, new Color(0.9, 0.2, 0.04));
});

test('Colors: Colors compare component by component', () => {
  const c1 = new Color(0.1, 0.5, 1);
  const c2 = new Color(0.2, 0, 0);
  const result = c1.add(c2);
  assert_color_equal(result, new Color(0.3, 0.5, 1));
  assert(Math.abs(result.blue - 1.001) > 0.0001, 'Should not equal 1.001');
});

// Chapter 1 - Canvas
test('Canvas: A new canvas is black', () => {
  const c = new Canvas(10, 20);
  assert.strictEqual(c.width, 10);
  assert.strictEqual(c.height, 20);
  for (let i = 0; i < 10; i++) {
    for (let j = 0; j < 20; j++) {
      assert_color_equal(c.pixel_at(i, j), new Color(0, 0, 0));
    }
  }
});

test('Canvas: Writing a pixel', () => {
  const c = new Canvas(10, 20);
  const red = new Color(1, 0, 0);
  c.write_pixel(2, 3, red);
  assert_color_equal(c.pixel_at(2, 3), red);
});

test('Canvas: x is the column and y is the row', () => {
  const c = new Canvas(10, 20);
  c.write_pixel(2, 3, new Color(1, 0, 0));
  assert_color_equal(c.pixel_at(3, 2), new Color(0, 0, 0));
  assert_color_equal(c.pixel_at(2, 3), new Color(1, 0, 0));
});

test('Canvas: Writing outside the canvas is ignored', () => {
  const c = new Canvas(10, 20);
  c.write_pixel(-1, 5, new Color(1, 0, 0));
  c.write_pixel(10, 5, new Color(1, 0, 0));
  c.write_pixel(5, -1, new Color(1, 0, 0));
  c.write_pixel(5, 20, new Color(1, 0, 0));
  for (let i = 0; i < 10; i++) {
    for (let j = 0; j < 20; j++) {
      assert_color_equal(c.pixel_at(i, j), new Color(0, 0, 0));
    }
  }
});

test('Canvas: A pixel can be written more than once', () => {
  const c = new Canvas(10, 20);
  c.write_pixel(2, 3, new Color(1, 0, 0));
  c.write_pixel(2, 3, new Color(0, 1, 0));
  assert_color_equal(c.pixel_at(2, 3), new Color(0, 1, 0));
});

test('Canvas: Filling a canvas', () => {
  const c = new Canvas(10, 20);
  c.fill(new Color(0.1, 0.2, 0.3));
  for (let i = 0; i < 10; i++) {
    for (let j = 0; j < 20; j++) {
      assert_color_equal(c.pixel_at(i, j), new Color(0.1, 0.2, 0.3));
    }
  }
});

// Chapter 1 - sRGB
test('sRGB: Encoding light into a file value - 0.0', () => {
  assert_number_equal(encode(0.0), 0.0);
});

test('sRGB: Encoding light - 0.0025', () => {
  assert_number_equal(encode(0.0025), 0.0323, 0.0001);
});

test('sRGB: Encoding light - 0.0031308', () => {
  assert_number_equal(encode(0.0031308), 0.0405, 0.0001);
});

test('sRGB: Encoding light - 0.01', () => {
  assert_number_equal(encode(0.01), 0.0999, 0.0001);
});

test('sRGB: Encoding light - 0.1', () => {
  assert_number_equal(encode(0.1), 0.3492, 0.0001);
});

test('sRGB: Encoding light - 0.216', () => {
  assert_number_equal(encode(0.216), 0.5021, 0.0001);
});

test('sRGB: Encoding light - 0.25', () => {
  assert_number_equal(encode(0.25), 0.5371, 0.0001);
});

test('sRGB: Encoding light - 0.5', () => {
  assert_number_equal(encode(0.5), 0.7354, 0.0001);
});

test('sRGB: Encoding light - 0.75', () => {
  assert_number_equal(encode(0.75), 0.8808, 0.0001);
});

test('sRGB: Encoding light - 1.0', () => {
  assert_number_equal(encode(1.0), 1.0);
});

test('sRGB: Decoding file value to light - 0.0', () => {
  assert_number_equal(decode(0.0), 0.0);
});

test('sRGB: Decoding file value - 0.04', () => {
  assert_number_equal(decode(0.04), 0.0031, 0.0001);
});

test('sRGB: Decoding file value - 0.04045', () => {
  assert_number_equal(decode(0.04045), 0.0031, 0.0001);
});

test('sRGB: Decoding file value - 0.05', () => {
  assert_number_equal(decode(0.05), 0.0039, 0.0001);
});

test('sRGB: Decoding file value - 0.1', () => {
  assert_number_equal(decode(0.1), 0.0100, 0.0001);
});

test('sRGB: Decoding file value - 0.5', () => {
  assert_number_equal(decode(0.5), 0.2140, 0.0001);
});

test('sRGB: Decoding file value - 0.75', () => {
  assert_number_equal(decode(0.75), 0.5225, 0.0001);
});

test('sRGB: Decoding file value - 1.0', () => {
  assert_number_equal(decode(1.0), 1.0);
});

test('sRGB: Decode undoes encode', () => {
  const l = 0.2;
  assert_number_equal(decode(encode(l)), l, 0.000000001);
});

test('sRGB: Encode undoes decode', () => {
  const v = 0.7;
  assert_number_equal(encode(decode(v)), v, 0.000000001);
});

test('sRGB: The half gray that is not 128', () => {
  assert.strictEqual(round(encode(0.5) * 255), 188);
});

test('sRGB: What 128 actually is', () => {
  assert_number_equal(decode(128 / 255), 0.2159, 0.0001);
});

// Chapter 1 - PPM
test('PPM: The PPM header', () => {
  const c = new Canvas(5, 3);
  const ppm = canvas_to_ppm(c);
  const lines = ppm.split('\n');
  assert.strictEqual(lines[0], 'P3');
  assert.strictEqual(lines[1], '5 3');
  assert.strictEqual(lines[2], '255');
});

test('PPM: Pixel values are encoded, not scaled', () => {
  const c = new Canvas(3, 1);
  c.write_pixel(0, 0, new Color(1, 0, 0));
  c.write_pixel(1, 0, new Color(0, 0.5, 0));
  c.write_pixel(2, 0, new Color(0, 0, 0.216));
  const ppm = canvas_to_ppm(c);
  const lines = ppm.split('\n');
  assert.strictEqual(lines[3], '255 0 0 0 188 0 0 0 128');
});

test('PPM: Colors out of range are clamped', () => {
  const c = new Canvas(2, 1);
  c.write_pixel(0, 0, new Color(1.5, 0, -0.5));
  const ppm = canvas_to_ppm(c);
  const lines = ppm.split('\n');
  assert.strictEqual(lines[3], '255 0 0 0 0 0');
});

test('PPM: Every row starts a new line, and no line exceeds 70 characters', () => {
  const c = new Canvas(10, 2);
  c.fill(new Color(1, 0.8, 0.6));
  const ppm = canvas_to_ppm(c);
  const lines = ppm.split('\n');
  const expectedLine1 = '255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231';
  const expectedLine2 = '203 255 231 203 255 231 203 255 231 203 255 231 203';
  assert.strictEqual(lines[3], expectedLine1);
  assert.strictEqual(lines[4], expectedLine2);
  assert.strictEqual(lines[5], expectedLine1);
  assert.strictEqual(lines[6], expectedLine2);
  for (let i = 3; i < lines.length; i++) {
    if (lines[i].length > 0) {
      assert(lines[i].length <= 70, `Line ${i} exceeds 70 chars: ${lines[i].length}`);
    }
  }
});

test('PPM: A line of exactly 70 characters is allowed', () => {
  const c = new Canvas(8, 1);
  c.fill(new Color(1, 0.1, 0));
  c.write_pixel(7, 0, new Color(1, 1, 1));
  const ppm = canvas_to_ppm(c);
  const lines = ppm.split('\n');
  const expectedLine1 = '255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 255';
  const expectedLine2 = '255';
  assert.strictEqual(lines[3], expectedLine1);
  assert.strictEqual(lines[3].length, 70);
  assert.strictEqual(lines[4], expectedLine2);
});

test('PPM: The file ends with a newline character', () => {
  const c = new Canvas(5, 3);
  const ppm = canvas_to_ppm(c);
  assert(ppm.endsWith('\n'), 'PPM should end with newline');
});

test('PPM: Reading a pixel back out of the text', () => {
  const c = new Canvas(3, 2);
  c.write_pixel(2, 1, new Color(0, 0.5, 1));
  const ppm = canvas_to_ppm(c);
  const p1 = ppm_pixel_correct(ppm, 2, 1);
  const p2 = ppm_pixel_correct(ppm, 1, 1);
  assert.deepStrictEqual(p1, [0, 188, 255]);
  assert.deepStrictEqual(p2, [0, 0, 0]);
});

test('PPM: Counting the distinct values in a file', () => {
  const c = new Canvas(3, 1);
  c.write_pixel(0, 0, new Color(1, 0, 0));
  c.write_pixel(1, 0, new Color(0, 0.5, 0));
  c.write_pixel(2, 0, new Color(0, 0, 0.216));
  const ppm = canvas_to_ppm(c);
  assert.strictEqual(distinct_values(ppm), 4);
});

test('PPM: Comparing two files', () => {
  const c1 = new Canvas(2, 1);
  const c2 = new Canvas(2, 1);
  c2.write_pixel(0, 0, new Color(0.5, 0, 0));
  const ppm1 = canvas_to_ppm(c1);
  const ppm2 = canvas_to_ppm(c2);
  assert.strictEqual(max_channel_difference(ppm1, ppm1), 0);
  assert.strictEqual(max_channel_difference(ppm1, ppm2), 188);
});

test('PPM: Files of different sizes are as different as it gets', () => {
  const c1 = new Canvas(5, 3);
  const c2 = new Canvas(3, 5);
  const ppm1 = canvas_to_ppm(c1);
  const ppm2 = canvas_to_ppm(c2);
  assert.strictEqual(max_channel_difference(ppm1, ppm2), 255);
});

test('PPM: The same width with a different height is still a different size', () => {
  const c1 = new Canvas(5, 3);
  const c2 = new Canvas(5, 4);
  const ppm1 = canvas_to_ppm(c1);
  const ppm2 = canvas_to_ppm(c2);
  assert.strictEqual(max_channel_difference(ppm1, ppm2), 255);
});

// Chapter 1 - Gray Match
test('Gray Match: The gray match', () => {
  set_linear_blending(true);
  const c = gray_match();
  assert.strictEqual(c.width, 300);
  assert.strictEqual(c.height, 100);
  assert_color_equal(c.pixel_at(0, 0), new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(1, 0), new Color(0, 0, 0));
  assert_color_equal(c.pixel_at(0, 1), new Color(0, 0, 0));
  assert_color_equal(c.pixel_at(1, 1), new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(150, 50), new Color(0.2159, 0.2159, 0.2159), 0.0001);
  assert_color_equal(c.pixel_at(250, 50), new Color(0.5, 0.5, 0.5));

  let whiteCount = 0;
  for (let i = 0; i < 300; i++) {
    for (let j = 0; j < 100; j++) {
      const p = c.pixel_at(i, j);
      if (Color.equals(p, new Color(1, 1, 1))) whiteCount++;
    }
  }
  assert.strictEqual(whiteCount, 5000);
});

test('Gray Match: The gray match, as a file', () => {
  set_linear_blending(true);
  const c = gray_match();
  const ppm = canvas_to_ppm(c);
  const p1 = ppm_pixel_correct(ppm, 0, 0);
  const p2 = ppm_pixel_correct(ppm, 1, 0);
  const p3 = ppm_pixel_correct(ppm, 150, 50);
  const p4 = ppm_pixel_correct(ppm, 250, 50);
  assert.deepStrictEqual(p1, [255, 255, 255]);
  assert.deepStrictEqual(p2, [0, 0, 0]);
  assert.deepStrictEqual(p3, [128, 128, 128]);
  assert.deepStrictEqual(p4, [188, 188, 188]);

  const ref = read_file('reference/chapter-01/gray-match.ppm');
  const diff = max_channel_difference(ppm, ref);
  assert(diff <= 1, `Max difference should be <= 1, got ${diff}`);
});

test('Gray Match: One pixel in four', () => {
  set_linear_blending(true);
  const c = quarter_match();
  assert.strictEqual(c.width, 200);
  assert.strictEqual(c.height, 100);
  assert_color_equal(c.pixel_at(0, 0), new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(1, 0), new Color(0, 0, 0));
  assert_color_equal(c.pixel_at(2, 2), new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(3, 1), new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(150, 50), new Color(0.25, 0.25, 0.25));

  let whiteCount = 0;
  for (let i = 0; i < 200; i++) {
    for (let j = 0; j < 100; j++) {
      const p = c.pixel_at(i, j);
      if (Color.equals(p, new Color(1, 1, 1))) whiteCount++;
    }
  }
  assert.strictEqual(whiteCount, 2500);

  const ppm = canvas_to_ppm(c);
  const p = ppm_pixel_correct(ppm, 150, 50);
  assert.deepStrictEqual(p, [137, 137, 137]);

  const ref = read_file('reference/chapter-01/quarter-match.ppm');
  const diff = max_channel_difference(ppm, ref);
  assert(diff <= 1, `Max difference should be <= 1, got ${diff}`);
});

// Chapter 1 - Limits
test('Limits: A 256-step ramp', () => {
  set_linear_blending(true);
  const c = ramp();
  assert.strictEqual(c.width, 256);
  assert.strictEqual(c.height, 32);
  assert_color_equal(c.pixel_at(0, 0), new Color(0, 0, 0));
  assert_color_equal(c.pixel_at(128, 0), new Color(0.5020, 0.5020, 0.5020), 0.0001);
  assert_color_equal(c.pixel_at(255, 31), new Color(1, 1, 1));
});

test('Limits: Encoding stretches the dark end and squeezes the bright end', () => {
  set_linear_blending(true);
  const c = ramp();
  const ppm = canvas_to_ppm(c);
  const lines = ppm.split('\n');
  const expected = '0 0 0 13 13 13 22 22 22 28 28 28 34 34 34 38 38 38 42 42 42 46 46 46';
  assert.strictEqual(lines[3], expected);

  const p1 = ppm_pixel_correct(ppm, 75, 0);
  const p2 = ppm_pixel_correct(ppm, 76, 0);
  const p3 = ppm_pixel_correct(ppm, 254, 0);
  assert.deepStrictEqual(p1, [148, 148, 148]);
  assert.deepStrictEqual(p2, [148, 148, 148]);
  assert.deepStrictEqual(p3, [255, 255, 255]);

  const d = distinct_values(ppm);
  assert.strictEqual(d, 183);

  const ref = read_file('reference/chapter-01/ramp.ppm');
  const diff = max_channel_difference(ppm, ref);
  assert(diff <= 1, `Max difference should be <= 1, got ${diff}`);
});

test('Limits: Clamping changes the color, not only the brightness', () => {
  set_linear_blending(true);
  const c = clamp_pair();
  assert.strictEqual(c.width, 200);
  assert.strictEqual(c.height, 100);
  assert_color_equal(c.pixel_at(50, 50), new Color(2, 0.5, 0.5));
  assert_color_equal(c.pixel_at(150, 50), new Color(1, 0.25, 0.25));

  const ppm = canvas_to_ppm(c);
  const p1 = ppm_pixel_correct(ppm, 50, 50);
  const p2 = ppm_pixel_correct(ppm, 150, 50);
  assert.deepStrictEqual(p1, [255, 188, 188]);
  assert.deepStrictEqual(p2, [255, 137, 137]);

  const ref = read_file('reference/chapter-01/clamp-pair.ppm');
  const diff = max_channel_difference(ppm, ref);
  assert(diff <= 1, `Max difference should be <= 1, got ${diff}`);
});

// Chapter 1 - Mix
test('Mix: Linear blending is on by default', () => {
  set_linear_blending(true);
  assert.strictEqual(linearBlending, true);
});

test('Mix: Halfway between black and white', () => {
  set_linear_blending(true);
  const a = new Color(0, 0, 0);
  const b = new Color(1, 1, 1);
  const result = mix(a, b, 0.5);
  assert_color_equal(result, new Color(0.5, 0.5, 0.5));
});

test('Mix: The ends of a mix are its inputs', () => {
  set_linear_blending(true);
  const a = new Color(0.7, 0, 0);
  const b = new Color(0, 0.3, 0.02);
  assert_color_equal(mix(a, b, 0), a);
  assert_color_equal(mix(a, b, 1), b);
});

test('Mix: Red to green, in light', () => {
  set_linear_blending(true);
  const a = new Color(0.7, 0, 0);
  const b = new Color(0, 0.3, 0.02);
  assert_color_equal(mix(a, b, 0.5), new Color(0.35, 0.15, 0.01));
  assert_color_equal(mix(a, b, 0.25), new Color(0.525, 0.075, 0.005));
});

test('Mix: Halfway between black and white, the way browsers do it', () => {
  set_linear_blending(false);
  const a = new Color(0, 0, 0);
  const b = new Color(1, 1, 1);
  const result = mix(a, b, 0.5);
  assert_color_equal(result, new Color(0.2140, 0.2140, 0.2140), 0.0001);
  set_linear_blending(true);
});

test('Mix: Red to green, the way browsers do it', () => {
  set_linear_blending(false);
  const a = new Color(0.7, 0, 0);
  const b = new Color(0, 0.3, 0.02);
  const result = mix(a, b, 0.5);
  assert_color_equal(result, new Color(0.1527, 0.0693, 0.0067), 0.0001);
  set_linear_blending(true);
});

test("Mix: The light's way never clamps", () => {
  set_linear_blending(true);
  const a = new Color(1.5, 0.5, -0.2);
  const b = new Color(0, 0, 0);
  assert_color_equal(mix(a, b, 0), new Color(1.5, 0.5, -0.2));
  assert_color_equal(mix(a, b, 0.5), new Color(0.75, 0.25, -0.1));
});

test('Mix: The ends of a mix are its inputs either way', () => {
  set_linear_blending(false);
  const a = new Color(0.7, 0, 0);
  const b = new Color(0, 0.3, 0.02);
  assert_color_equal(mix(a, b, 0), a);
  assert_color_equal(mix(a, b, 1), b);
  set_linear_blending(true);
});

test('Mix: The switch can be passed instead of set', () => {
  set_linear_blending(true);
  const a = new Color(0, 0, 0);
  const b = new Color(1, 1, 1);
  assert_color_equal(mix(a, b, 0.5, true), new Color(0.5, 0.5, 0.5));
  assert_color_equal(mix(a, b, 0.5, false), new Color(0.2140, 0.2140, 0.2140), 0.0001);
  assert.strictEqual(linearBlending, true);
});

test("Mix: The browser's way clamps each end before encoding it", () => {
  set_linear_blending(false);
  const a = new Color(1.5, 0.5, -0.2);
  const b = new Color(0, 0, 0);
  assert_color_equal(mix(a, b, 0), new Color(1, 0.5, 0), 0.0001);
  assert_color_equal(mix(a, b, 0.5), new Color(0.2140, 0.1113, 0.0000), 0.0001);
  set_linear_blending(true);
});

// Chapter 1 - Plate
test('Plate: The plate', () => {
  set_linear_blending(true);
  const c = plate_01();
  assert.strictEqual(c.width, 400);
  assert.strictEqual(c.height, 180);

  const ppm = canvas_to_ppm(c);
  const p1 = ppm_pixel_correct(ppm, 0, 20);
  const p2 = ppm_pixel_correct(ppm, 399, 20);
  const p3 = ppm_pixel_correct(ppm, 200, 20);
  const p4 = ppm_pixel_correct(ppm, 200, 65);
  const p5 = ppm_pixel_correct(ppm, 200, 42);
  const p6 = ppm_pixel_correct(ppm, 0, 110);
  const p7 = ppm_pixel_correct(ppm, 399, 110);
  const p8 = ppm_pixel_correct(ppm, 200, 110);
  const p9 = ppm_pixel_correct(ppm, 200, 155);
  const p10 = ppm_pixel_correct(ppm, 200, 87);

  assert.deepStrictEqual(p1, [0, 0, 0]);
  assert.deepStrictEqual(p2, [255, 255, 255]);
  assert(Math.abs(p3[0] - 128) <= 1 && Math.abs(p3[1] - 128) <= 1 && Math.abs(p3[2] - 128) <= 1);
  assert(Math.abs(p4[0] - 188) <= 1 && Math.abs(p4[1] - 188) <= 1 && Math.abs(p4[2] - 188) <= 1);
  assert.deepStrictEqual(p5, [0, 0, 0]);
  assert.deepStrictEqual(p6, [218, 0, 0]);
  assert.deepStrictEqual(p7, [0, 149, 39]);
  assert(Math.abs(p8[0] - 109) <= 1 && Math.abs(p8[1] - 75) <= 1 && Math.abs(p8[2] - 19) <= 1);
  assert(Math.abs(p9[0] - 160) <= 1 && Math.abs(p9[1] - 108) <= 1 && Math.abs(p9[2] - 26) <= 1);
  assert.deepStrictEqual(p10, [0, 0, 0]);

  const ref = read_file('reference/chapter-01/plate-01.ppm');
  const diff = max_channel_difference(ppm, ref);
  assert(diff <= 1, `Max difference should be <= 1, got ${diff}`);
});

test('Plate: The switch was left on', () => {
  set_linear_blending(true);
  const c = plate_01();
  assert.strictEqual(linearBlending, true);
});

// Write output files
import { mkdirSync } from 'node:fs';
mkdirSync('out', { recursive: true });

test('Write output files', async () => {
  set_linear_blending(true);

  const c1 = gray_match();
  const ppm1 = canvas_to_ppm(c1);
  await fs.writeFile('out/gray-match.ppm', ppm1);

  const c2 = quarter_match();
  const ppm2 = canvas_to_ppm(c2);
  await fs.writeFile('out/quarter-match.ppm', ppm2);

  const c3 = ramp();
  const ppm3 = canvas_to_ppm(c3);
  await fs.writeFile('out/ramp.ppm', ppm3);

  const c4 = clamp_pair();
  const ppm4 = canvas_to_ppm(c4);
  await fs.writeFile('out/clamp-pair.ppm', ppm4);

  const c5 = plate_01();
  const ppm5 = canvas_to_ppm(c5);
  await fs.writeFile('out/plate-01.ppm', ppm5);
});

// ===========================
// Chapter 2 - Shapes
// ===========================
class Shape {
  // Base class
}

class Circle extends Shape {
  constructor(cx, cy, r) {
    super();
    this.cx = cx;
    this.cy = cy;
    this.r = r;
  }
}

class Rectangle extends Shape {
  constructor(x0, y0, x1, y1) {
    super();
    this.x0 = x0;
    this.y0 = y0;
    this.x1 = x1;
    this.y1 = y1;
  }
}

class HalfPlane extends Shape {
  constructor(px, py, nx, ny) {
    super();
    this.px = px;
    this.py = py;
    this.nx = nx;
    this.ny = ny;
  }
}

function circle(cx, cy, r) {
  return new Circle(cx, cy, r);
}

function rectangle(x0, y0, x1, y1) {
  return new Rectangle(x0, y0, x1, y1);
}

function half_plane(px, py, nx, ny) {
  return new HalfPlane(px, py, nx, ny);
}

function inside(shape, x, y) {
  if (shape instanceof Circle) {
    const dx = x - shape.cx;
    const dy = y - shape.cy;
    return dx * dx + dy * dy <= shape.r * shape.r;
  } else if (shape instanceof Rectangle) {
    return x >= shape.x0 && x <= shape.x1 && y >= shape.y0 && y <= shape.y1;
  } else if (shape instanceof HalfPlane) {
    const vx = x - shape.px;
    const vy = y - shape.py;
    return vx * shape.nx + vy * shape.ny >= 0;
  } else if (shape instanceof ThickLine) {
    // ThickLine is composed of four half-planes - must satisfy all four
    for (const hp of shape.half_planes) {
      const vx = x - hp.px;
      const vy = y - hp.py;
      if (vx * hp.nx + vy * hp.ny < 0) {
        return false;
      }
    }
    return true;
  } else if (shape instanceof Segment) {
    return inside_segment(shape, x, y);
  } else if (shape instanceof Union) {
    for (const s of shape.shapes) {
      if (inside(s, x, y)) return true;
    }
    return false;
  } else if (shape instanceof Transformed) {
    if (!shape.m_inv) return false;
    const p = shape.m_inv.multiply(point(x, y));
    return inside(shape.shape, p.x, p.y);
  } else if (shape instanceof FilledPath) {
    return shape.rule === 'nonzero'
      ? inside_nonzero(shape.path, x, y)
      : inside_evenodd(shape.path, x, y);
  }
  return false;
}

// ===========================
// Chapter 2 - P6 Binary PPM
// ===========================
function canvas_to_p6(canvas) {
  const header = `P6\n${canvas.width} ${canvas.height}\n255\n`;
  const headerBytes = new TextEncoder().encode(header);

  const pixelBytes = [];
  for (let y = 0; y < canvas.height; y++) {
    for (let x = 0; x < canvas.width; x++) {
      const pixel = canvas.pixel_at(x, y);
      const [r, g, b] = color_to_bytes(pixel);
      pixelBytes.push(r, g, b);
    }
  }

  const combined = new Uint8Array(headerBytes.length + pixelBytes.length);
  combined.set(headerBytes);
  combined.set(pixelBytes, headerBytes.length);

  return combined;
}

// Parse both P3 and P6 formats
function parse_ppm(data) {
  let text;
  let isP6 = false;
  let pixelStart = 0;

  if (typeof data === 'string') {
    text = data;
  } else if (data instanceof Uint8Array) {
    // Check if it's P6 format
    const header = new TextDecoder().decode(data.slice(0, 10));
    if (header.startsWith('P6')) {
      isP6 = true;
      // Find where pixel data starts: P6\n{w} {h}\n255\n
      let i = 0;
      let newlines = 0;
      for (; i < data.length && newlines < 3; i++) {
        if (data[i] === 10) newlines++; // newline is ASCII 10
      }
      pixelStart = i;
      text = new TextDecoder().decode(data.slice(0, pixelStart));
    } else {
      text = new TextDecoder().decode(data);
    }
  }

  const lines = text.split('\n');
  const [width, height] = lines[1].split(' ').map(Number);

  let tokens = [];
  if (isP6) {
    // Read binary pixels
    for (let i = pixelStart; i < data.length; i++) {
      tokens.push(data[i]);
    }
  } else {
    // Parse text tokens
    for (let i = 3; i < lines.length; i++) {
      const parts = lines[i].trim().split(/\s+/);
      for (const part of parts) {
        if (part) tokens.push(parseInt(part));
      }
    }
  }

  return { width, height, tokens };
}

// Helper functions for dual-format support
function ppm_pixel_from_string(ppm, x, y) {
  return ppm_pixel_correct(ppm, x, y);
}

function ppm_pixel_from_bytes(data, x, y) {
  const { width, tokens } = parse_ppm(data);
  const pixelIndex = y * width + x;
  const idx = pixelIndex * 3;
  return [tokens[idx], tokens[idx + 1], tokens[idx + 2]];
}

// ===========================
// Chapter 2 - Coverage Buffer
// ===========================
class CoverageBuffer {
  constructor(width, height) {
    this.width = width;
    this.height = height;
    this.coverage = Array(width * height).fill(0);
  }

  coverage_at(x, y) {
    if (x >= 0 && x < this.width && y >= 0 && y < this.height) {
      return this.coverage[y * this.width + x];
    }
    return 0;
  }

  set_coverage(x, y, value) {
    if (x >= 0 && x < this.width && y >= 0 && y < this.height) {
      this.coverage[y * this.width + x] = value;
    }
  }

  ink() {
    let sum = 0;
    for (let i = 0; i < this.coverage.length; i++) {
      sum += this.coverage[i];
    }
    return sum;
  }
}

function coverage_buffer(width, height) {
  return new CoverageBuffer(width, height);
}

function coverage_at(buffer, x, y) {
  return buffer.coverage_at(x, y);
}

function set_coverage(buffer, x, y, value) {
  buffer.set_coverage(x, y, value);
}

function ink(buffer) {
  return buffer.ink();
}

// ===========================
// Chapter 2 - Magnify
// ===========================
function magnify(canvas, k) {
  const result = new Canvas(canvas.width * k, canvas.height * k);
  for (let y = 0; y < canvas.height; y++) {
    for (let x = 0; x < canvas.width; x++) {
      const pixel = canvas.pixel_at(x, y);
      for (let dy = 0; dy < k; dy++) {
        for (let dx = 0; dx < k; dx++) {
          result.write_pixel(x * k + dx, y * k + dy, pixel);
        }
      }
    }
  }
  return result;
}

// ===========================
// Chapter 2 - Coverage Functions
// ===========================
function center_inside(shape, x, y) {
  const cx = x + 0.5;
  const cy = y + 0.5;
  return inside(shape, cx, cy) ? 1 : 0;
}

function coverage(shape, x, y) {
  // 8x8 grid of sample points
  let count = 0;
  for (let j = 0; j < 8; j++) {
    for (let i = 0; i < 8; i++) {
      const px = x + (i + 0.5) / 8;
      const py = y + (j + 0.5) / 8;
      if (inside(shape, px, py)) {
        count++;
      }
    }
  }
  return count / 64;
}

function rasterize_centers(shape, width, height) {
  const buf = coverage_buffer(width, height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const cov = center_inside(shape, x, y);
      set_coverage(buf, x, y, cov);
    }
  }
  return buf;
}

function rasterize(shape, width, height) {
  const buf = coverage_buffer(width, height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const cov = coverage(shape, x, y);
      set_coverage(buf, x, y, cov);
    }
  }
  return buf;
}

// ===========================
// Chapter 2 - Paint Through Coverage
// ===========================
function paint_through(canvas, coverage_buf, color) {
  for (let y = 0; y < canvas.height; y++) {
    for (let x = 0; x < canvas.width; x++) {
      const cov = coverage_at(coverage_buf, x, y);
      if (cov > 0) {
        const current = canvas.pixel_at(x, y);
        // paint_through always mixes on light, regardless of the global
        // linear-blending switch.
        const blended = mix(current, color, cov, true);
        canvas.write_pixel(x, y, blended);
      }
    }
  }
}

// ===========================
// Chapter 2 - Render Functions
// ===========================
function disc_centers() {
  const c = new Canvas(40, 40);
  c.fill(new Color(0.02, 0.02, 0.025));
  const shape = circle(20, 20, 16);
  const cov = rasterize_centers(shape, 40, 40);
  const ink_color = new Color(0.9, 0.55, 0.1);
  paint_through(c, cov, ink_color);
  return magnify(c, 8);
}

function disc_coverage() {
  const c = new Canvas(40, 40);
  c.fill(new Color(0.02, 0.02, 0.025));
  const shape = circle(20, 20, 16);
  const cov = rasterize(shape, 40, 40);
  const ink_color = new Color(0.9, 0.55, 0.1);
  paint_through(c, cov, ink_color);
  return magnify(c, 8);
}

function painted_twice() {
  const c = new Canvas(80, 40);
  c.fill(new Color(0.02, 0.02, 0.025));
  const shape = circle(20, 20, 16);
  const cov = rasterize(shape, 40, 40);
  const ink_color = new Color(0.9, 0.55, 0.1);

  // Paint left side once
  const left_cov = coverage_buffer(80, 40);
  for (let y = 0; y < 40; y++) {
    for (let x = 0; x < 40; x++) {
      set_coverage(left_cov, x, y, coverage_at(cov, x, y));
    }
  }
  paint_through(c, left_cov, ink_color);

  // Paint right side twice
  const right_cov = coverage_buffer(80, 40);
  for (let y = 0; y < 40; y++) {
    for (let x = 0; x < 40; x++) {
      set_coverage(right_cov, x + 40, y, coverage_at(cov, x, y));
    }
  }
  paint_through(c, right_cov, ink_color);
  paint_through(c, right_cov, ink_color);

  return magnify(c, 6);
}

function plate_02() {
  const c = new Canvas(80, 40);
  c.fill(new Color(0.02, 0.02, 0.025));
  const shape = circle(20, 20, 16);
  const left = rasterize_centers(shape, 40, 40);
  const right = rasterize(shape, 40, 40);

  const both = coverage_buffer(80, 40);
  for (let y = 0; y < 40; y++) {
    for (let x = 0; x < 40; x++) {
      set_coverage(both, x, y, coverage_at(left, x, y));
      set_coverage(both, x + 40, y, coverage_at(right, x, y));
    }
  }

  paint_through(c, both, new Color(0.9, 0.55, 0.1));
  return magnify(c, 6);
}

// ===========================
// Chapter 2 Tests
// ===========================

// Chapter 2 - Shapes
test('Shapes: A point inside a circle', () => {
  const s = circle(8, 8, 5);
  assert.strictEqual(inside(s, 8, 8), true);
  assert.strictEqual(inside(s, 12, 8), true);
  assert.strictEqual(inside(s, 13, 8), true);
  assert.strictEqual(inside(s, 13.01, 8), false);
  assert.strictEqual(inside(s, 11.6, 11.6), false);
});

test('Shapes: A point inside a rectangle', () => {
  const s = rectangle(1.25, 2.0, 4.75, 5.0);
  assert.strictEqual(inside(s, 3, 3), true);
  assert.strictEqual(inside(s, 1.25, 2.0), true);
  assert.strictEqual(inside(s, 4.75, 5.0), true);
  assert.strictEqual(inside(s, 1.2, 3), false);
  assert.strictEqual(inside(s, 3, 5.1), false);
});

test('Shapes: A point inside a half-plane', () => {
  const s = half_plane(2.5, 0, 1, 0);
  assert.strictEqual(inside(s, 2.5, 7), true);
  assert.strictEqual(inside(s, 3, -4), true);
  assert.strictEqual(inside(s, 2.4, 0), false);
});

test('Shapes: The normal picks the side', () => {
  const s = half_plane(2.5, 0, -1, 0);
  assert.strictEqual(inside(s, 2.4, 0), true);
  assert.strictEqual(inside(s, 3, 0), false);
});

// Chapter 2 - P6
test('P6: The header, then the bytes', () => {
  const c = new Canvas(2, 1);
  c.write_pixel(0, 0, new Color(1, 0, 0));
  c.write_pixel(1, 0, new Color(0, 0.5, 0));
  const p6 = canvas_to_p6(c);

  const header = new TextDecoder().decode(p6.slice(0, 11));
  assert.strictEqual(header, 'P6\n2 1\n255\n');
  assert.strictEqual(p6.length, 17);
  assert.strictEqual(p6[11], 255);  // byte 12 (1-indexed) = p6[11] (0-indexed)
  assert.strictEqual(p6[12], 0);    // byte 13 (1-indexed) = p6[12] (0-indexed)
  assert.strictEqual(p6[15], 188);  // byte 16 (1-indexed) = p6[15] (0-indexed)
});

test('P6: The same pixel comes back out of either format', () => {
  const c = new Canvas(2, 1);
  c.write_pixel(1, 0, new Color(0, 0.5, 0));
  const p3 = canvas_to_ppm(c);
  const p6 = canvas_to_p6(c);
  
  assert.deepStrictEqual(ppm_pixel(p6, 1, 0), [0, 188, 0]);
  assert.deepStrictEqual(ppm_pixel(p3, 1, 0), [0, 188, 0]);
  assert.strictEqual(max_channel_difference(p3, p6), 0);
  assert.strictEqual(distinct_values(p6), 2);
});

test('P6: Rows go top to bottom', () => {
  const c = new Canvas(1, 2);
  c.write_pixel(0, 0, new Color(1, 0, 0));
  c.write_pixel(0, 1, new Color(0, 0, 1));
  const p6 = canvas_to_p6(c);
  assert.strictEqual(p6[11], 255); // byte 12
  assert.strictEqual(p6[16], 255); // byte 17
  assert.deepStrictEqual(ppm_pixel(p6, 0, 0), [255, 0, 0]);
  assert.deepStrictEqual(ppm_pixel(p6, 0, 1), [0, 0, 255]);
});

test('P6: The binary writer clamps too', () => {
  const c = new Canvas(2, 1);
  c.write_pixel(0, 0, new Color(1.5, 0, -0.5));
  const p6 = canvas_to_p6(c);
  assert.strictEqual(p6[11], 255); // byte 12
  assert.strictEqual(p6[12], 0);   // byte 13
  assert.strictEqual(p6[13], 0);   // byte 14
  assert.deepStrictEqual(ppm_pixel(p6, 0, 0), [255, 0, 0]);
});

test('P6: Pixel bytes that look like whitespace are still pixel bytes', () => {
  const c = new Canvas(2, 1);
  c.write_pixel(0, 0, new Color(0.00304, 0.01444, 0.00304));
  c.write_pixel(1, 0, new Color(1, 1, 1));
  const p6 = canvas_to_p6(c);
  assert.strictEqual(p6.length, 17);
  assert.strictEqual(p6[11], 10); // byte 12
  assert.strictEqual(p6[12], 32); // byte 13
  assert.deepStrictEqual(ppm_pixel(p6, 0, 0), [10, 32, 10]);
  assert.deepStrictEqual(ppm_pixel(p6, 1, 0), [255, 255, 255]);
  assert.strictEqual(max_channel_difference(canvas_to_ppm(c), p6), 0);
});

test('P6: Sizes still have to match', () => {
  const c1 = new Canvas(2, 1);
  const c2 = new Canvas(1, 2);
  const p6a = canvas_to_p6(c1);
  const p6b = canvas_to_p6(c2);
  assert.strictEqual(max_channel_difference(p6a, p6b), 255);
});

// Chapter 2 - Magnify
test('Magnify: Every pixel becomes a block', () => {
  const c = new Canvas(2, 1);
  c.write_pixel(0, 0, new Color(1, 0, 0));
  c.write_pixel(1, 0, new Color(0, 0.5, 0));
  const m = magnify(c, 3);
  
  assert.strictEqual(m.width, 6);
  assert.strictEqual(m.height, 3);
  assert_color_equal(m.pixel_at(0, 0), new Color(1, 0, 0));
  assert_color_equal(m.pixel_at(2, 2), new Color(1, 0, 0));
  assert_color_equal(m.pixel_at(3, 0), new Color(0, 0.5, 0));
  assert_color_equal(m.pixel_at(5, 2), new Color(0, 0.5, 0));
  
  let count = 0;
  for (let y = 0; y < 3; y++) {
    for (let x = 0; x < 6; x++) {
      if (Color.equals(m.pixel_at(x, y), new Color(1, 0, 0))) count++;
    }
  }
  assert.strictEqual(count, 9);
});

test('Magnify: Magnifying by one changes nothing', () => {
  const c = new Canvas(2, 1);
  c.write_pixel(1, 0, new Color(0, 0.5, 0));
  const m = magnify(c, 1);
  assert.strictEqual(max_channel_difference(canvas_to_p6(c), canvas_to_p6(m)), 0);
});

// Chapter 2 - Coverage Buffer
test('Coverage: A new coverage buffer is empty', () => {
  const cov = coverage_buffer(4, 3);
  assert.strictEqual(cov.width, 4);
  assert.strictEqual(cov.height, 3);
  assert.strictEqual(coverage_at(cov, 2, 1), 0);
  assert.strictEqual(ink(cov), 0);
});

test('Coverage: Setting coverage', () => {
  const cov = coverage_buffer(4, 3);
  set_coverage(cov, 2, 1, 0.75);
  assert.strictEqual(coverage_at(cov, 2, 1), 0.75);
  assert.strictEqual(coverage_at(cov, 1, 2), 0);
  assert.strictEqual(ink(cov), 0.75);
});

test('Coverage: Setting coverage outside the buffer is ignored, and reading it gives 0', () => {
  const cov = coverage_buffer(4, 3);
  set_coverage(cov, -1, 1, 1);
  set_coverage(cov, 4, 1, 1);
  set_coverage(cov, 1, 3, 1);
  assert.strictEqual(ink(cov), 0);
  assert.strictEqual(coverage_at(cov, -1, 1), 0);
  assert.strictEqual(coverage_at(cov, 4, 1), 0);
  assert.strictEqual(coverage_at(cov, 1, 3), 0);
});

test('Coverage: The center of pixel (x, y) is (x + 0.5, y + 0.5)', () => {
  const s = half_plane(2.5, 0, 1, 0);
  assert.strictEqual(center_inside(s, 2, 4), 1);
  assert.strictEqual(center_inside(s, 1, 4), 0);
  const t = half_plane(2.6, 0, 1, 0);
  assert.strictEqual(center_inside(t, 2, 4), 0);
});

test('Coverage: The center question is not "at least half"', () => {
  const s = half_plane(2.55, 0, 1, 0);
  assert.strictEqual(center_inside(s, 2, 4), 0);
  assert.strictEqual(coverage(s, 2, 4), 0.5);
});

test('Coverage: A buffer need not be square', () => {
  const s = rectangle(0, 0, 2, 1);
  const cov = rasterize_centers(s, 4, 2);
  assert.strictEqual(cov.width, 4);
  assert.strictEqual(cov.height, 2);
  assert.strictEqual(coverage_at(cov, 1, 0), 1);
  assert.strictEqual(coverage_at(cov, 0, 1), 0);
  assert.strictEqual(ink(cov), 2);
});

test('Coverage: A rectangle, by asking each center', () => {
  const s = rectangle(1.25, 2.0, 4.75, 5.0);
  const cov = rasterize_centers(s, 8, 8);
  assert.strictEqual(coverage_at(cov, 1, 4), 1);
  assert.strictEqual(coverage_at(cov, 4, 1), 0);
  assert.strictEqual(coverage_at(cov, 4, 4), 1);
  assert.strictEqual(coverage_at(cov, 0, 3), 0);
  assert.strictEqual(coverage_at(cov, 5, 3), 0);
  assert.strictEqual(coverage_at(cov, 2, 1), 0);
  assert.strictEqual(coverage_at(cov, 2, 5), 0);
  assert.strictEqual(ink(cov), 12);
});

test('Coverage: A disc, by asking each center', () => {
  const s = circle(8, 8, 5);
  const cov = rasterize_centers(s, 16, 16);
  assert.strictEqual(cov.width, 16);
  assert.strictEqual(cov.height, 16);
  assert.strictEqual(coverage_at(cov, 8, 8), 1);
  assert.strictEqual(coverage_at(cov, 3, 8), 1);
  assert.strictEqual(coverage_at(cov, 12, 8), 1);
  assert.strictEqual(coverage_at(cov, 2, 8), 0);
  assert.strictEqual(coverage_at(cov, 13, 8), 0);
  assert.strictEqual(coverage_at(cov, 4, 4), 1);
  assert.strictEqual(coverage_at(cov, 3, 4), 0);
  assert.strictEqual(ink(cov), 80);
});

// Chapter 2 - Better Coverage
test('Coverage method: The sixty-four sample points', () => {
  const s = half_plane(2.5, 0, 1, 0);
  assert.strictEqual(coverage(s, 2, 4), 0.5);
  assert.strictEqual(coverage(s, 1, 4), 0);
  assert.strictEqual(coverage(s, 3, 4), 1);
});

test('Coverage method: A rectangle is covered exactly, when its edges land on sample boundaries', () => {
  const s = rectangle(1.25, 2.0, 4.75, 5.0);
  const cov = rasterize(s, 8, 8);
  assert.strictEqual(coverage_at(cov, 0, 2), 0);
  assert.strictEqual(coverage_at(cov, 1, 2), 0.75);
  assert.strictEqual(coverage_at(cov, 2, 2), 1);
  assert.strictEqual(coverage_at(cov, 3, 2), 1);
  assert.strictEqual(coverage_at(cov, 4, 2), 0.75);
  assert.strictEqual(coverage_at(cov, 5, 2), 0);
  assert.strictEqual(coverage_at(cov, 2, 1), 0);
  assert.strictEqual(coverage_at(cov, 2, 5), 0);
  assert_number_equal(ink(cov), 10.5, 0.01);
});

test('Coverage method: Neither need the buffer be square here', () => {
  const s = rectangle(0, 0, 2, 1);
  const cov = rasterize(s, 4, 2);
  assert.strictEqual(cov.width, 4);
  assert.strictEqual(cov.height, 2);
  assert.strictEqual(coverage_at(cov, 1, 0), 1);
  assert.strictEqual(coverage_at(cov, 2, 0), 0);
  assert.strictEqual(coverage_at(cov, 0, 1), 0);
  assert.strictEqual(ink(cov), 2);
});

test('Coverage method: A half-plane through a pixel center covers half of it', () => {
  const s = half_plane(2.5, 4.5, 0.6, 0.8);
  assert_number_equal(coverage(s, 2, 4), 0.5, 0.01);
});

test('Coverage method: Except when the grid conspires', () => {
  const s = half_plane(2.5, 4.5, 1, 1);
  assert_number_equal(coverage(s, 2, 4), 0.5625, 0.01);
});

test('Coverage method: A disc is only ever approximately covered', () => {
  const s = circle(8, 8, 5);
  const cov = rasterize(s, 16, 16);
  assert.strictEqual(coverage_at(cov, 8, 8), 1);
  assert_number_equal(coverage_at(cov, 3, 8), 0.96875, 0.01);
  assert_number_equal(coverage_at(cov, 12, 8), 0.96875, 0.01);
  assert_number_equal(coverage_at(cov, 4, 4), 0.5625, 0.01);
  assert.strictEqual(coverage_at(cov, 3, 4), 0);
  assert_number_equal(ink(cov), 78.5, 0.1);
});

// Chapter 2 - Paint Through
test('Paint: Half coverage is half the paint', () => {
  const c = new Canvas(1, 1);
  const cov = coverage_buffer(1, 1);
  set_coverage(cov, 0, 0, 0.5);
  paint_through(c, cov, new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(0, 0), new Color(0.5, 0.5, 0.5));
});

test('Paint: Paint over something that isn\'t black', () => {
  const c = new Canvas(1, 1);
  const cov = coverage_buffer(1, 1);
  c.fill(new Color(0.2, 0.2, 0.2));
  set_coverage(cov, 0, 0, 0.25);
  paint_through(c, cov, new Color(1, 0, 0));
  assert_color_equal(c.pixel_at(0, 0), new Color(0.4, 0.15, 0.15), 0.001);
});

test('Paint: Zero leaves it alone and one replaces it', () => {
  const c = new Canvas(2, 1);
  const cov = coverage_buffer(2, 1);
  c.fill(new Color(0.2, 0.2, 0.2));
  set_coverage(cov, 1, 0, 1);
  paint_through(c, cov, new Color(1, 0, 0));
  assert_color_equal(c.pixel_at(0, 0), new Color(0.2, 0.2, 0.2));
  assert_color_equal(c.pixel_at(1, 0), new Color(1, 0, 0));
});

test('Paint: The arithmetic is on light, whatever the switch says', () => {
  set_linear_blending(false);
  const c = new Canvas(1, 1);
  const cov = coverage_buffer(1, 1);
  set_coverage(cov, 0, 0, 0.5);
  paint_through(c, cov, new Color(1, 1, 1));
  const ppm = canvas_to_ppm(c);
  assert_color_equal(c.pixel_at(0, 0), new Color(0.5, 0.5, 0.5));
  assert.deepStrictEqual(ppm_pixel(ppm, 0, 0), [188, 188, 188]);
  set_linear_blending(true);
});

test('Paint: The disc by centers', () => {
  const c = disc_centers();
  const ref = read_file('reference/chapter-02/disc-centers.ppm');
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 320);
  assert.strictEqual(c.height, 320);
  const p1 = ppm_pixel(p6, 160, 160);
  const p2 = ppm_pixel(p6, 124, 36);
  const p3 = ppm_pixel(p6, 132, 36);
  assert(Math.abs(p1[0] - 243) <= 1 && Math.abs(p1[1] - 196) <= 1 && Math.abs(p1[2] - 89) <= 1);
  assert(Math.abs(p2[0] - 39) <= 1 && Math.abs(p2[1] - 39) <= 1 && Math.abs(p2[2] - 44) <= 1);
  assert(Math.abs(p3[0] - 243) <= 1 && Math.abs(p3[1] - 196) <= 1 && Math.abs(p3[2] - 89) <= 1);
  assert.strictEqual(distinct_values(p6), 5);
  assert(max_channel_difference(p6, ref) <= 1);
});

test('Paint: The disc by coverage', () => {
  const c = disc_coverage();
  const ref = read_file('reference/chapter-02/disc-coverage.ppm');
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 320);
  assert.strictEqual(c.height, 320);
  const p1 = ppm_pixel(p6, 160, 160);
  const p2 = ppm_pixel(p6, 124, 36);
  assert(Math.abs(p1[0] - 243) <= 1 && Math.abs(p1[1] - 196) <= 1 && Math.abs(p1[2] - 89) <= 1);
  assert(Math.abs(p2[0] - 157) <= 1 && Math.abs(p2[1] - 127) <= 1 && Math.abs(p2[2] - 64) <= 1);
  assert(max_channel_difference(p6, ref) <= 1);
});

// Chapter 2 - Twice
test('Twice: Half coverage, painted twice, is three quarters', () => {
  const c = new Canvas(1, 1);
  const cov = coverage_buffer(1, 1);
  set_coverage(cov, 0, 0, 0.5);
  paint_through(c, cov, new Color(1, 1, 1));
  paint_through(c, cov, new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(0, 0), new Color(0.75, 0.75, 0.75));
});

test('Twice: The disc, once and twice', () => {
  const c = painted_twice();
  const ref = read_file('reference/chapter-02/painted-twice.ppm');
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 480);
  assert.strictEqual(c.height, 240);
  const p1 = ppm_pixel(p6, 120, 120);
  const p2 = ppm_pixel(p6, 360, 120);
  const p3 = ppm_pixel(p6, 93, 27);
  const p4 = ppm_pixel(p6, 333, 27);
  assert(Math.abs(p1[0] - 243) <= 1 && Math.abs(p1[1] - 196) <= 1 && Math.abs(p1[2] - 89) <= 1);
  assert(Math.abs(p2[0] - 243) <= 1 && Math.abs(p2[1] - 196) <= 1 && Math.abs(p2[2] - 89) <= 1);
  assert(Math.abs(p3[0] - 157) <= 1 && Math.abs(p3[1] - 127) <= 1 && Math.abs(p3[2] - 64) <= 1);
  assert(Math.abs(p4[0] - 194) <= 1 && Math.abs(p4[1] - 156) <= 1 && Math.abs(p4[2] - 74) <= 1);
  assert(max_channel_difference(p6, ref) <= 1);
});

// Chapter 2 - Plate
test('Plate: The plate', () => {
  const c = plate_02();
  const ref = read_file('reference/chapter-02/plate-02.ppm');
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 480);
  assert.strictEqual(c.height, 240);
  const p1 = ppm_pixel(p6, 120, 120);
  const p2 = ppm_pixel(p6, 360, 120);
  const p3 = ppm_pixel(p6, 93, 27);
  const p4 = ppm_pixel(p6, 333, 27);
  assert(Math.abs(p1[0] - 243) <= 1 && Math.abs(p1[1] - 196) <= 1 && Math.abs(p1[2] - 89) <= 1);
  assert(Math.abs(p2[0] - 243) <= 1 && Math.abs(p2[1] - 196) <= 1 && Math.abs(p2[2] - 89) <= 1);
  assert(Math.abs(p3[0] - 39) <= 1 && Math.abs(p3[1] - 39) <= 1 && Math.abs(p3[2] - 44) <= 1);
  assert(Math.abs(p4[0] - 157) <= 1 && Math.abs(p4[1] - 127) <= 1 && Math.abs(p4[2] - 64) <= 1);
  assert(max_channel_difference(p6, ref) <= 1);
});

// Write Chapter 2 output files
test('Write chapter 2 output files', async () => {
  const c1 = disc_centers();
  const p6a = canvas_to_p6(c1);
  await fs.writeFile('out/disc-centers.ppm', p6a);

  const c2 = disc_coverage();
  const p6b = canvas_to_p6(c2);
  await fs.writeFile('out/disc-coverage.ppm', p6b);

  const c3 = painted_twice();
  const p6c = canvas_to_p6(c3);
  await fs.writeFile('out/painted-twice.ppm', p6c);

  const c4 = plate_02();
  const p6d = canvas_to_p6(c4);
  await fs.writeFile('out/plate-02.ppm', p6d);
});

// ===========================
// Chapter 3 - Lines
// ===========================

function lit_pixels(canvas) {
  const pixels = [];
  for (let y = 0; y < canvas.height; y++) {
    for (let x = 0; x < canvas.width; x++) {
      const pixel = canvas.pixel_at(x, y);
      if (pixel.red > 0 || pixel.green > 0 || pixel.blue > 0) {
        pixels.push([x, y]);
      }
    }
  }
  return pixels;
}

function line_bresenham(canvas, x0, y0, x1, y1, color) {
  let steep = Math.abs(y1 - y0) > Math.abs(x1 - x0);

  // Swap x0/y0 and x1/y1 if steep
  if (steep) {
    [x0, y0] = [y0, x0];
    [x1, y1] = [y1, x1];
  }

  // Ensure we go left to right
  if (x0 > x1) {
    [x0, x1] = [x1, x0];
    [y0, y1] = [y1, y0];
  }

  const dx = x1 - x0;
  const dy = Math.abs(y1 - y0);
  const ystep = y0 < y1 ? 1 : -1;
  let err = Math.floor(dx / 2);
  let y = y0;

  for (let x = x0; x <= x1; x++) {
    if (steep) {
      canvas.write_pixel(y, x, color);
    } else {
      canvas.write_pixel(x, y, color);
    }

    err = err - dy;
    if (err < 0) {
      y = y + ystep;
      err = err + dx;
    }
  }
}

function plot(canvas, x, y, color, weight) {
  if (weight === 0) return;
  if (x < 0 || x >= canvas.width || y < 0 || y >= canvas.height) return;

  const current = canvas.pixel_at(x, y);
  // Wu's weights are applied in light, regardless of the global
  // linear-blending switch (same rule as paint_through).
  const blended = mix(current, color, weight, true);
  canvas.write_pixel(x, y, blended);
}

function line_wu(canvas, x0, y0, x1, y1, color) {
  let steep = Math.abs(y1 - y0) > Math.abs(x1 - x0);

  // Swap x0/y0 and x1/y1 if steep
  if (steep) {
    [x0, y0] = [y0, x0];
    [x1, y1] = [y1, x1];
  }

  // Ensure we go left to right
  if (x0 > x1) {
    [x0, x1] = [x1, x0];
    [y0, y1] = [y1, y0];
  }

  const dx = x1 - x0;
  const slope = dx === 0 ? 0 : (y1 - y0) / dx;

  for (let x = x0; x <= x1; x++) {
    const y = y0 + (x - x0) * slope;
    const yi = Math.floor(y);
    const f = y - yi;

    if (steep) {
      plot(canvas, yi, x, color, 1 - f);
      plot(canvas, yi + 1, x, color, f);
    } else {
      plot(canvas, x, yi, color, 1 - f);
      plot(canvas, x, yi + 1, color, f);
    }
  }
}

function total_ink(canvas) {
  let sum = 0;
  for (let y = 0; y < canvas.height; y++) {
    for (let x = 0; x < canvas.width; x++) {
      const pixel = canvas.pixel_at(x, y);
      sum += pixel.red;
    }
  }
  return sum;
}

class ThickLine extends Shape {
  constructor(x0, y0, x1, y1, width) {
    super();
    // Convert pixel coordinates to centers
    let px0 = x0 + 0.5;
    let py0 = y0 + 0.5;
    let px1 = x1 + 0.5;
    let py1 = y1 + 0.5;

    // Direction vector
    const dx = px1 - px0;
    const dy = py1 - py0;
    const len = Math.sqrt(dx * dx + dy * dy);

    const half_width = width / 2;

    let dsx, dsy;
    if (len > 0) {
      dsx = dx / len;
      dsy = dy / len;
    } else {
      // A line of no length has no direction, so it gets (1, 0) and its
      // two ends are pushed apart by half the width each, which makes it
      // a width-by-width square.
      dsx = 1;
      dsy = 0;
      px0 -= half_width * dsx;
      py0 -= half_width * dsy;
      px1 += half_width * dsx;
      py1 += half_width * dsy;
    }
    const nsx = -dsy;
    const nsy = dsx;

    // Four half-planes: start cap, end cap, two sides
    this.half_planes = [
      // Start cap: through start point, facing along direction
      new HalfPlane(px0, py0, dsx, dsy),
      // End cap: through end point, facing back along -direction
      new HalfPlane(px1, py1, -dsx, -dsy),
      // Side 1: offset along normal, facing inward
      new HalfPlane(px0 + nsx * half_width, py0 + nsy * half_width, -nsx, -nsy),
      // Side 2: offset along -normal, facing inward
      new HalfPlane(px0 - nsx * half_width, py0 - nsy * half_width, nsx, nsy)
    ];
  }
}

function thick_line(x0, y0, x1, y1, width) {
  return new ThickLine(x0, y0, x1, y1, width);
}

function ray_ends() {
  const ends = [];
  for (let k = 0; k < 12; k++) {
    const a = (k * 30) * Math.PI / 180;
    const x = round(80 + 72 * Math.cos(a));
    const y = round(80 + 72 * Math.sin(a));
    ends.push([x, y]);
  }
  return ends;
}

function fan_bresenham() {
  const c = new Canvas(160, 160);
  c.fill(new Color(0.02, 0.02, 0.025));
  const ends = ray_ends();
  const ink_color = new Color(0.92, 0.92, 0.88);
  for (const [x, y] of ends) {
    line_bresenham(c, 80, 80, x, y, ink_color);
  }
  return c;
}

function fan_wu() {
  const c = new Canvas(160, 160);
  c.fill(new Color(0.02, 0.02, 0.025));
  const ends = ray_ends();
  const ink_color = new Color(0.92, 0.92, 0.88);
  for (const [x, y] of ends) {
    line_wu(c, 80, 80, x, y, ink_color);
  }
  return c;
}

function fan_coverage() {
  const c = new Canvas(160, 160);
  c.fill(new Color(0.02, 0.02, 0.025));
  const ends = ray_ends();
  const ink_color = new Color(0.92, 0.92, 0.88);
  for (const [x, y] of ends) {
    const cov = rasterize(thick_line(80, 80, x, y, 1), 160, 160);
    paint_through(c, cov, ink_color);
  }
  return magnify(c, 2);
}

function plate_03() {
  const both = new Canvas(320, 160);
  const a = fan_bresenham();
  const b = fan_wu();
  for (let y = 0; y < 160; y++) {
    for (let x = 0; x < 160; x++) {
      both.write_pixel(x, y, a.pixel_at(x, y));
      both.write_pixel(x + 160, y, b.pixel_at(x, y));
    }
  }
  return magnify(both, 2);
}

// ===========================
// Chapter 3 Tests
// ===========================

// Chapter 3 - Bresenham
test('Bresenham: lit_pixels reads like a page', () => {
  const c = new Canvas(10, 10);
  c.write_pixel(5, 0, new Color(1, 1, 1));
  c.write_pixel(0, 2, new Color(1, 1, 1));
  c.write_pixel(2, 2, new Color(0.5, 0, 0));
  assert.deepStrictEqual(lit_pixels(c), [[5, 0], [0, 2], [2, 2]]);
});

test('Bresenham: A diagonal', () => {
  const c = new Canvas(10, 10);
  line_bresenham(c, 0, 0, 5, 5, new Color(1, 1, 1));
  const pixels = lit_pixels(c);
  assert.deepStrictEqual(pixels, [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [5, 5]]);
});

test('Bresenham: A horizontal line lights one row and nothing else', () => {
  const c = new Canvas(10, 10);
  line_bresenham(c, 0, 3, 7, 3, new Color(1, 1, 1));
  const pixels = lit_pixels(c);
  assert.deepStrictEqual(pixels, [[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3]]);
});

test('Bresenham: A shallow line steps along x', () => {
  const c = new Canvas(10, 10);
  line_bresenham(c, 0, 0, 7, 3, new Color(1, 1, 1));
  const pixels = lit_pixels(c);
  assert.deepStrictEqual(pixels, [[0, 0], [1, 0], [2, 1], [3, 1], [4, 2], [5, 2], [6, 3], [7, 3]]);
});

test('Bresenham: A steep line steps along y', () => {
  const c = new Canvas(10, 10);
  line_bresenham(c, 1, 1, 3, 7, new Color(1, 1, 1));
  const pixels = lit_pixels(c);
  assert.deepStrictEqual(pixels, [[1, 1], [1, 2], [2, 3], [2, 4], [2, 5], [3, 6], [3, 7]]);
});

test('Bresenham: The pixels don\'t depend on which end you start from', () => {
  const c1 = new Canvas(10, 10);
  const c2 = new Canvas(10, 10);
  line_bresenham(c1, 1, 1, 3, 7, new Color(1, 1, 1));
  line_bresenham(c2, 3, 7, 1, 1, new Color(1, 1, 1));
  const pixels1 = lit_pixels(c1);
  const pixels2 = lit_pixels(c2);
  assert.deepStrictEqual(pixels1, pixels2);
  const p6a = canvas_to_p6(c1);
  const p6b = canvas_to_p6(c2);
  assert.strictEqual(max_channel_difference(p6a, p6b), 0);
});

test('Bresenham: A line going up and to the right', () => {
  const c = new Canvas(10, 10);
  line_bresenham(c, 0, 6, 7, 3, new Color(1, 1, 1));
  const pixels = lit_pixels(c);
  // Reading order: top row first, left to right
  assert.deepStrictEqual(pixels, [[6, 3], [7, 3], [4, 4], [5, 4], [2, 5], [3, 5], [0, 6], [1, 6]]);
});

test('Bresenham: At an exact half the line stays on its row one step longer', () => {
  const c = new Canvas(10, 10);
  line_bresenham(c, 0, 0, 4, 2, new Color(1, 1, 1));
  const pixels = lit_pixels(c);
  assert.deepStrictEqual(pixels, [[0, 0], [1, 0], [2, 1], [3, 1], [4, 2]]);
});

test('Bresenham: A line of one point', () => {
  const c = new Canvas(10, 10);
  line_bresenham(c, 3, 3, 3, 3, new Color(1, 1, 1));
  const pixels = lit_pixels(c);
  assert.deepStrictEqual(pixels, [[3, 3]]);
});

test('Bresenham: A line may run off the canvas', () => {
  const c = new Canvas(10, 10);
  line_bresenham(c, 0, 0, 12, 6, new Color(1, 1, 1));
  const pixels = lit_pixels(c);
  assert.strictEqual(pixels.length, 10);
});

// Chapter 3 - Wu
test('Wu: A half step lights two pixels equally', () => {
  const c = new Canvas(10, 10);
  line_wu(c, 0, 0, 4, 2, new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(0, 0), new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(1, 0), new Color(0.5, 0.5, 0.5));
  assert_color_equal(c.pixel_at(1, 1), new Color(0.5, 0.5, 0.5));
  assert_color_equal(c.pixel_at(2, 1), new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(2, 2), new Color(0, 0, 0));
  assert_color_equal(c.pixel_at(4, 2), new Color(1, 1, 1));
  assert_number_equal(total_ink(c), 5, 0.001);
});

test('Wu: The weights are applied in light, whatever the switch says', () => {
  set_linear_blending(false);
  const c = new Canvas(10, 10);
  line_wu(c, 0, 0, 4, 2, new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(1, 0), new Color(0.5, 0.5, 0.5));
  assert_color_equal(c.pixel_at(1, 1), new Color(0.5, 0.5, 0.5));
  set_linear_blending(true);
});

test('Wu: A diagonal has uniform weights', () => {
  const c = new Canvas(10, 10);
  line_wu(c, 0, 0, 5, 5, new Color(1, 1, 1));
  const pixels = lit_pixels(c);
  assert.deepStrictEqual(pixels, [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4], [5, 5]]);
  assert_color_equal(c.pixel_at(3, 3), new Color(1, 1, 1));
  assert_number_equal(total_ink(c), 6, 0.001);
});

test('Wu: A horizontal line has weight 1 on its row and 0 on the neighbors', () => {
  const c = new Canvas(10, 10);
  line_wu(c, 0, 3, 7, 3, new Color(1, 1, 1));
  const pixels = lit_pixels(c);
  assert.deepStrictEqual(pixels, [[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3]]);
  assert_color_equal(c.pixel_at(3, 3), new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(3, 2), new Color(0, 0, 0));
  assert_color_equal(c.pixel_at(3, 4), new Color(0, 0, 0));
  assert_number_equal(total_ink(c), 8, 0.001);
});

test('Wu: A steep line weights across columns', () => {
  const c = new Canvas(10, 10);
  line_wu(c, 1, 1, 3, 7, new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(1, 1), new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(1, 2), new Color(0.6667, 0.6667, 0.6667), 0.001);
  assert_color_equal(c.pixel_at(2, 2), new Color(0.3333, 0.3333, 0.3333), 0.001);
  assert_color_equal(c.pixel_at(2, 4), new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(3, 7), new Color(1, 1, 1));
  assert_number_equal(total_ink(c), 7, 0.001);
});

test('Wu: The weights don\'t depend on which end you start from', () => {
  const c1 = new Canvas(10, 10);
  const c2 = new Canvas(10, 10);
  line_wu(c1, 1, 1, 3, 7, new Color(1, 1, 1));
  line_wu(c2, 3, 7, 1, 1, new Color(1, 1, 1));
  const p6a = canvas_to_p6(c1);
  const p6b = canvas_to_p6(c2);
  assert.strictEqual(max_channel_difference(p6a, p6b), 0);
});

test('Wu: A line that starts above the canvas', () => {
  const c = new Canvas(10, 10);
  line_wu(c, 0, -1, 8, 3, new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(1, 0), new Color(0.5, 0.5, 0.5));
  assert_color_equal(c.pixel_at(2, 0), new Color(1, 1, 1));
  assert_number_equal(total_ink(c), 7.5, 0.001);
});

test('Wu: A Wu line of one point', () => {
  const c = new Canvas(10, 10);
  line_wu(c, 3, 3, 3, 3, new Color(1, 1, 1));
  assert.deepStrictEqual(lit_pixels(c), [[3, 3]]);
  assert_color_equal(c.pixel_at(3, 3), new Color(1, 1, 1));
});

test('Wu: Sevenths', () => {
  const c = new Canvas(10, 10);
  line_wu(c, 0, 0, 7, 3, new Color(1, 1, 1));
  assert_color_equal(c.pixel_at(1, 0), new Color(0.5714, 0.5714, 0.5714), 0.0001);
  assert_color_equal(c.pixel_at(1, 1), new Color(0.4286, 0.4286, 0.4286), 0.0001);
  assert_color_equal(c.pixel_at(2, 0), new Color(0.1429, 0.1429, 0.1429), 0.0001);
  assert_color_equal(c.pixel_at(2, 1), new Color(0.8571, 0.8571, 0.8571), 0.0001);
  assert_number_equal(total_ink(c), 8, 0.001);
});

test('Wu: The ink depends on the angle (12, 2)', () => {
  const c = new Canvas(20, 20);
  line_wu(c, 2, 2, 12, 2, new Color(1, 1, 1));
  assert_number_equal(total_ink(c), 11, 0.001);
});

test('Wu: The ink depends on the angle (10, 8)', () => {
  const c = new Canvas(20, 20);
  line_wu(c, 2, 2, 10, 8, new Color(1, 1, 1));
  assert_number_equal(total_ink(c), 9, 0.001);
});

test('Wu: The ink depends on the angle (8, 10)', () => {
  const c = new Canvas(20, 20);
  line_wu(c, 2, 2, 8, 10, new Color(1, 1, 1));
  assert_number_equal(total_ink(c), 9, 0.001);
});

test('Wu: The ink depends on the angle (2, 12)', () => {
  const c = new Canvas(20, 20);
  line_wu(c, 2, 2, 2, 12, new Color(1, 1, 1));
  assert_number_equal(total_ink(c), 11, 0.001);
});

// Chapter 3 - Thick Line / Quad
test('Quad: Inside a thick line', () => {
  const s = thick_line(0, 0, 4, 0, 1);
  assert.strictEqual(inside(s, 2.5, 0.5), true);
  assert.strictEqual(inside(s, 2.5, 1.0), true);
  assert.strictEqual(inside(s, 2.5, 1.01), false);
  assert.strictEqual(inside(s, 0.5, 0.5), true);
  assert.strictEqual(inside(s, 0.4, 0.5), false);
  assert.strictEqual(inside(s, 4.5, 0.5), true);
  assert.strictEqual(inside(s, 4.6, 0.5), false);
});

test('Quad: A horizontal thick line covers its row, with half pixels at the ends', () => {
  const s = thick_line(0, 3, 7, 3, 1);
  const cov = rasterize(s, 10, 10);
  assert_number_equal(coverage_at(cov, 0, 3), 0.5, 0.01);
  assert_number_equal(coverage_at(cov, 1, 3), 1, 0.01);
  assert_number_equal(coverage_at(cov, 6, 3), 1, 0.01);
  assert_number_equal(coverage_at(cov, 7, 3), 0.5, 0.01);
  assert_number_equal(coverage_at(cov, 8, 3), 0, 0.01);
  assert_number_equal(coverage_at(cov, 3, 2), 0, 0.01);
  assert_number_equal(coverage_at(cov, 3, 4), 0, 0.01);
  assert_number_equal(ink(cov), 7, 0.01);
});

test('Quad: A line of no length is a square', () => {
  const s = thick_line(3, 3, 3, 3, 1);
  const cov = rasterize(s, 8, 8);
  assert_number_equal(coverage_at(cov, 3, 3), 1, 0.01);
  assert_number_equal(ink(cov), 1, 0.01);
});

test('Quad: A wider line', () => {
  const s = thick_line(0, 3, 7, 3, 3);
  const cov = rasterize(s, 10, 10);
  assert_number_equal(coverage_at(cov, 3, 2), 1, 0.01);
  assert_number_equal(coverage_at(cov, 3, 3), 1, 0.01);
  assert_number_equal(coverage_at(cov, 3, 4), 1, 0.01);
  assert_number_equal(coverage_at(cov, 3, 1), 0, 0.01);
  assert_number_equal(coverage_at(cov, 3, 5), 0, 0.01);
  assert_number_equal(coverage_at(cov, 0, 3), 0.5, 0.01);
  assert_number_equal(ink(cov), 21, 0.01);
});

test('Quad: An off-axis line runs through pixel centers, not corners', () => {
  const s = thick_line(2, 2, 11, 5, 1);
  const cov = rasterize(s, 16, 10);
  assert_number_equal(coverage_at(cov, 2, 2), 0.484375, 0.001);
  assert_number_equal(coverage_at(cov, 11, 5), 0.484375, 0.001);
  assert_number_equal(coverage_at(cov, 6, 3), 0.6875, 0.001);
  assert_number_equal(coverage_at(cov, 7, 3), 0.359375, 0.001);
  assert_number_equal(coverage_at(cov, 2, 1), 0, 0.001);
  assert_number_equal(ink(cov), 9.4063, 0.0001);
});

test('Quad: The ink is the length (12, 2)', () => {
  const s = thick_line(2, 2, 12, 2, 1);
  const cov = rasterize(s, 20, 20);
  assert_number_equal(ink(cov), 10, 0.01);
});

test('Quad: The ink is the length (10, 8)', () => {
  const s = thick_line(2, 2, 10, 8, 1);
  const cov = rasterize(s, 20, 20);
  assert_number_equal(ink(cov), 10, 0.01);
});

test('Quad: The ink is the length (8, 10)', () => {
  const s = thick_line(2, 2, 8, 10, 1);
  const cov = rasterize(s, 20, 20);
  assert_number_equal(ink(cov), 10, 0.01);
});

test('Quad: The ink is the length (2, 12)', () => {
  const s = thick_line(2, 2, 2, 12, 1);
  const cov = rasterize(s, 20, 20);
  assert_number_equal(ink(cov), 10, 0.01);
});

test('Quad: The grid is blind along the diagonal', () => {
  const s = thick_line(2, 2, 9, 9, 1);
  const cov = rasterize(s, 20, 20);
  const ik = ink(cov);
  assert_number_equal(ik, 9.7188, 0.001);
  assert(Math.abs(ik - 9.8995) <= 0.25, `ink should be 9.8995 ± 0.25, got ${ik}`);
});

// Chapter 3 - Plate
test('Plate: The ray endpoints', () => {
  const ends = ray_ends();
  const expected = [[152, 80], [142, 116], [116, 142], [80, 152], [44, 142], [18, 116], [8, 80], [18, 44], [44, 18], [80, 8], [116, 18], [142, 44]];
  assert.deepStrictEqual(ends, expected);
});

test('Plate: Bresenham\'s fan', () => {
  const c = fan_bresenham();
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 160);
  assert.strictEqual(c.height, 160);
  const p1 = ppm_pixel(p6, 80, 80);
  const p2 = ppm_pixel(p6, 120, 80);
  const p3 = ppm_pixel(p6, 10, 10);
  const p4 = ppm_pixel(p6, 100, 91);
  const p5 = ppm_pixel(p6, 100, 92);
  assert(Math.abs(p1[0] - 246) <= 1 && Math.abs(p1[1] - 246) <= 1 && Math.abs(p1[2] - 241) <= 1);
  assert(Math.abs(p2[0] - 246) <= 1 && Math.abs(p2[1] - 246) <= 1 && Math.abs(p2[2] - 241) <= 1);
  assert(Math.abs(p3[0] - 39) <= 1 && Math.abs(p3[1] - 39) <= 1 && Math.abs(p3[2] - 44) <= 1);
  assert(Math.abs(p4[0] - 39) <= 1 && Math.abs(p4[1] - 39) <= 1 && Math.abs(p4[2] - 44) <= 1);
  assert(Math.abs(p5[0] - 246) <= 1 && Math.abs(p5[1] - 246) <= 1 && Math.abs(p5[2] - 241) <= 1);
});

test('Plate: Wu\'s fan', () => {
  const c = fan_wu();
  const p6 = canvas_to_p6(c);
  const p1 = ppm_pixel(p6, 80, 80);
  const p2 = ppm_pixel(p6, 120, 80);
  const p3 = ppm_pixel(p6, 100, 91);
  const p4 = ppm_pixel(p6, 100, 92);
  assert(Math.abs(p1[0] - 246) <= 1 && Math.abs(p1[1] - 246) <= 1 && Math.abs(p1[2] - 241) <= 1);
  assert(Math.abs(p2[0] - 246) <= 1 && Math.abs(p2[1] - 246) <= 1 && Math.abs(p2[2] - 241) <= 1);
  assert(Math.abs(p3[0] - 163) <= 1 && Math.abs(p3[1] - 163) <= 1 && Math.abs(p3[2] - 161) <= 1);
  assert(Math.abs(p4[0] - 199) <= 1 && Math.abs(p4[1] - 199) <= 1 && Math.abs(p4[2] - 196) <= 1);
});

test('Plate: The fan as twelve thin rectangles', () => {
  const c = fan_coverage();
  const ref = read_file('reference/chapter-03/fan-coverage.ppm');
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 320);
  assert.strictEqual(c.height, 320);
  const p1 = ppm_pixel(p6, 160, 160);
  const p2 = ppm_pixel(p6, 10, 10);
  const p3 = ppm_pixel(p6, 240, 160);
  const p4 = ppm_pixel(p6, 240, 158);
  const p5 = ppm_pixel(p6, 200, 183);
  const p6pix = ppm_pixel(p6, 200, 185);
  assert(Math.abs(p1[0] - 246) <= 1 && Math.abs(p1[1] - 246) <= 1 && Math.abs(p1[2] - 241) <= 1);
  assert(Math.abs(p2[0] - 39) <= 1 && Math.abs(p2[1] - 39) <= 1 && Math.abs(p2[2] - 44) <= 1);
  assert(Math.abs(p3[0] - 246) <= 1 && Math.abs(p3[1] - 246) <= 1 && Math.abs(p3[2] - 241) <= 1);
  assert(Math.abs(p4[0] - 39) <= 1 && Math.abs(p4[1] - 39) <= 1 && Math.abs(p4[2] - 44) <= 1);
  assert(Math.abs(p5[0] - 177) <= 1 && Math.abs(p5[1] - 177) <= 1 && Math.abs(p5[2] - 174) <= 1);
  assert(Math.abs(p6pix[0] - 209) <= 1 && Math.abs(p6pix[1] - 209) <= 1 && Math.abs(p6pix[2] - 205) <= 1);
  assert(max_channel_difference(p6, ref) <= 1);
});

test('Plate: Plate 3', () => {
  const c = plate_03();
  const ref = read_file('reference/chapter-03/plate-03.ppm');
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 640);
  assert.strictEqual(c.height, 320);
  const p1 = ppm_pixel(p6, 160, 160);
  const p2 = ppm_pixel(p6, 480, 160);
  const p3 = ppm_pixel(p6, 10, 10);
  const p4 = ppm_pixel(p6, 200, 183);
  const p5 = ppm_pixel(p6, 200, 185);
  const p6pix = ppm_pixel(p6, 520, 183);
  const p7 = ppm_pixel(p6, 520, 185);
  assert(Math.abs(p1[0] - 246) <= 1 && Math.abs(p1[1] - 246) <= 1 && Math.abs(p1[2] - 241) <= 1);
  assert(Math.abs(p2[0] - 246) <= 1 && Math.abs(p2[1] - 246) <= 1 && Math.abs(p2[2] - 241) <= 1);
  assert(Math.abs(p3[0] - 39) <= 1 && Math.abs(p3[1] - 39) <= 1 && Math.abs(p3[2] - 44) <= 1);
  assert(Math.abs(p4[0] - 39) <= 1 && Math.abs(p4[1] - 39) <= 1 && Math.abs(p4[2] - 44) <= 1);
  assert(Math.abs(p5[0] - 246) <= 1 && Math.abs(p5[1] - 246) <= 1 && Math.abs(p5[2] - 241) <= 1);
  assert(Math.abs(p6pix[0] - 163) <= 1 && Math.abs(p6pix[1] - 163) <= 1 && Math.abs(p6pix[2] - 161) <= 1);
  assert(Math.abs(p7[0] - 199) <= 1 && Math.abs(p7[1] - 199) <= 1 && Math.abs(p7[2] - 196) <= 1);
  assert(max_channel_difference(p6, ref) <= 1);
});

// ===========================
// Chapter 4: Points, Vectors, Transforms
// ===========================

// Tuple class for points and vectors
class Tuple {
  constructor(x, y, w) {
    this.x = x;
    this.y = y;
    this.w = w;
  }

  static equals(a, b, tolerance = 0.0001) {
    return Math.abs(a.x - b.x) <= tolerance &&
           Math.abs(a.y - b.y) <= tolerance &&
           Math.abs(a.w - b.w) <= tolerance;
  }

  add(other) {
    return new Tuple(this.x + other.x, this.y + other.y, this.w + other.w);
  }

  subtract(other) {
    return new Tuple(this.x - other.x, this.y - other.y, this.w - other.w);
  }

  negate() {
    return new Tuple(-this.x, -this.y, -this.w);
  }

  multiply(scalar) {
    return new Tuple(this.x * scalar, this.y * scalar, this.w * scalar);
  }

  divide(scalar) {
    return new Tuple(this.x / scalar, this.y / scalar, this.w / scalar);
  }

  magnitude() {
    return Math.sqrt(this.x * this.x + this.y * this.y);
  }

  normalize() {
    const mag = this.magnitude();
    if (mag === 0) return new Tuple(0, 0, 0);
    return this.divide(mag);
  }
}

function point(x, y) {
  return new Tuple(x, y, 1);
}

function vector(x, y) {
  return new Tuple(x, y, 0);
}

function magnitude(v) {
  return v.magnitude();
}

function normalize(v) {
  return v.normalize();
}

function dot(a, b) {
  return a.x * b.x + a.y * b.y;
}

function cross(a, b) {
  return a.x * b.y - a.y * b.x;
}

// Matrix3 class
class Matrix3 {
  constructor(...args) {
    if (args.length === 9) {
      // row-major order: 9 numbers
      this.m = args.slice();
    } else if (args.length === 3 && Array.isArray(args[0])) {
      // 3 arrays of 3 numbers each (rows)
      this.m = [];
      for (let r = 0; r < 3; r++) {
        for (let c = 0; c < 3; c++) {
          this.m.push(args[r][c]);
        }
      }
    } else {
      throw new Error('Invalid matrix constructor arguments');
    }
  }

  get(r, c) {
    return this.m[r * 3 + c];
  }

  set(r, c, value) {
    this.m[r * 3 + c] = value;
  }

  static equals(a, b, tolerance = 0.0001) {
    for (let i = 0; i < 9; i++) {
      if (Math.abs(a.m[i] - b.m[i]) > tolerance) {
        return false;
      }
    }
    return true;
  }

  multiply(other) {
    if (other instanceof Matrix3) {
      const out = new Matrix3(0, 0, 0, 0, 0, 0, 0, 0, 0);
      for (let r = 0; r < 3; r++) {
        for (let c = 0; c < 3; c++) {
          let sum = 0;
          for (let i = 0; i < 3; i++) {
            sum += this.get(r, i) * other.get(i, c);
          }
          out.set(r, c, sum);
        }
      }
      return out;
    } else if (other instanceof Tuple) {
      // Matrix multiplied by tuple
      const x = this.get(0, 0) * other.x + this.get(0, 1) * other.y + this.get(0, 2) * other.w;
      const y = this.get(1, 0) * other.x + this.get(1, 1) * other.y + this.get(1, 2) * other.w;
      const w = this.get(2, 0) * other.x + this.get(2, 1) * other.y + this.get(2, 2) * other.w;
      return new Tuple(x, y, w);
    } else {
      throw new Error('Cannot multiply matrix by this type');
    }
  }
}

// Allow a * b syntax for matrices
Matrix3.prototype[Symbol.for('matrix.multiply')] = function(other) {
  return this.multiply(other);
};

function matrix3(...args) {
  return new Matrix3(...args);
}

function identity() {
  return new Matrix3(1, 0, 0, 0, 1, 0, 0, 0, 1);
}

function translation(tx, ty) {
  return new Matrix3(1, 0, tx, 0, 1, ty, 0, 0, 1);
}

function scaling(sx, sy) {
  return new Matrix3(sx, 0, 0, 0, sy, 0, 0, 0, 1);
}

function rotation(r) {
  const c = Math.cos(r);
  const s = Math.sin(r);
  return new Matrix3(c, -s, 0, s, c, 0, 0, 0, 1);
}

function shearing(xy, yx) {
  return new Matrix3(1, xy, 0, yx, 1, 0, 0, 0, 1);
}

function transpose(m) {
  const out = new Matrix3(0, 0, 0, 0, 0, 0, 0, 0, 0);
  for (let r = 0; r < 3; r++) {
    for (let c = 0; c < 3; c++) {
      out.set(r, c, m.get(c, r));
    }
  }
  return out;
}

function minor(m, r, c) {
  // Get the 2x2 determinant when row r and column c are deleted
  const rows = [];
  const cols = [];
  for (let i = 0; i < 3; i++) {
    if (i !== r) rows.push(i);
    if (i !== c) cols.push(i);
  }
  const a = m.get(rows[0], cols[0]);
  const b = m.get(rows[0], cols[1]);
  const c_val = m.get(rows[1], cols[0]);
  const d = m.get(rows[1], cols[1]);
  return a * d - b * c_val;
}

function cofactor(m, r, c) {
  const min = minor(m, r, c);
  return ((r + c) % 2 === 1) ? -min : min;
}

function determinant(m) {
  return m.get(0, 0) * cofactor(m, 0, 0) +
         m.get(0, 1) * cofactor(m, 0, 1) +
         m.get(0, 2) * cofactor(m, 0, 2);
}

function is_invertible(m) {
  return determinant(m) !== 0;
}

function inverse(m) {
  const d = determinant(m);
  if (d === 0) {
    // Return an empty/null matrix or throw
    return null;
  }
  const out = new Matrix3(0, 0, 0, 0, 0, 0, 0, 0, 0);
  for (let r = 0; r < 3; r++) {
    for (let c = 0; c < 3; c++) {
      const cf = cofactor(m, r, c);
      out.set(c, r, cf / d);  // Note: c, r is the transpose
    }
  }
  return out;
}

function approx_scale(m) {
  const det = m.get(0, 0) * m.get(1, 1) - m.get(0, 1) * m.get(1, 0);
  return Math.sqrt(Math.abs(det));
}

// Shape classes for Chapter 4
class Segment extends Shape {
  constructor(a, b, width) {
    super();
    this.a = a;
    this.b = b;
    this.width = width;
  }
}

class Union extends Shape {
  constructor(shapes) {
    super();
    this.shapes = shapes;
  }
}

class Transformed extends Shape {
  constructor(shape, m) {
    super();
    this.shape = shape;
    this.m = m;
    this.m_inv = inverse(m);
  }
}

function segment(a, b, width) {
  return new Segment(a, b, width);
}

function union(shapes) {
  return new Union(shapes);
}

function transformed(shape, m) {
  return new Transformed(shape, m);
}

function outline(points, m, width) {
  const segs = [];
  const transformed_points = points.map(p => m.multiply(p));
  for (let i = 0; i < transformed_points.length; i++) {
    const p0 = transformed_points[i];
    const p1 = transformed_points[(i + 1) % transformed_points.length];
    segs.push(segment(p0, p1, width));
  }
  return union(segs);
}

function transform_points(points, m) {
  return points.map(p => m.multiply(p));
}

// Update inside() to handle Chapter 4 shapes
function inside_segment(shape, x, y) {
  // A segment is implemented as four half-planes (same as chapter 3's thick_line)
  // but using real coordinates instead of pixel indices.
  const a = shape.a;
  const b = shape.b;
  const px0 = a.x;
  const py0 = a.y;
  const px1 = b.x;
  const py1 = b.y;

  // Direction vector
  const dx = px1 - px0;
  const dy = py1 - py0;
  const len = Math.sqrt(dx * dx + dy * dy);

  const half_width = shape.width / 2;

  let dsx, dsy;
  let a_adj_x = px0;
  let a_adj_y = py0;
  let b_adj_x = px1;
  let b_adj_y = py1;

  if (len > 0) {
    dsx = dx / len;
    dsy = dy / len;
  } else {
    // A line of no length gets direction (1, 0) and pushed apart by half_width
    dsx = 1;
    dsy = 0;
    a_adj_x -= half_width * dsx;
    a_adj_y -= half_width * dsy;
    b_adj_x += half_width * dsx;
    b_adj_y += half_width * dsy;
  }

  const nsx = -dsy;
  const nsy = dsx;

  // Test point against all four half-planes
  // Start cap: through start point, normal along direction
  let vx = x - a_adj_x;
  let vy = y - a_adj_y;
  if (vx * dsx + vy * dsy < 0) return false;

  // End cap: through end point, normal back along -direction
  vx = x - b_adj_x;
  vy = y - b_adj_y;
  if (vx * (-dsx) + vy * (-dsy) < 0) return false;

  // Side 1: offset along normal, normal faces inward (-nsx, -nsy)
  vx = x - (a_adj_x + nsx * half_width);
  vy = y - (a_adj_y + nsy * half_width);
  if (vx * (-nsx) + vy * (-nsy) < 0) return false;

  // Side 2: offset along -normal, normal faces inward (nsx, nsy)
  vx = x - (a_adj_x - nsx * half_width);
  vy = y - (a_adj_y - nsy * half_width);
  if (vx * nsx + vy * nsy < 0) return false;

  return true;
}

// Rendering helpers for Chapter 4
function fan_points() {
  const pts = [point(0, 0)];
  for (let k = 0; k < 12; k++) {
    const a = k * Math.PI / 6;
    pts.push(point(36 * Math.cos(a), 36 * Math.sin(a)));
  }
  return pts;
}

function fan_transformed(m) {
  const c = new Canvas(160, 160);
  c.fill(new Color(0.02, 0.02, 0.025));
  const pts = fan_points().map(p => m.multiply(p));
  const segs = [];
  for (let k = 1; k <= 12; k++) {
    segs.push(segment(pts[0], pts[k], 1));
  }
  const shape = union(segs);
  paint_through(c, rasterize(shape, 160, 160), new Color(0.92, 0.92, 0.88));
  return c;
}

function letter_f() {
  return [
    point(-20, -30), point(20, -30), point(20, -20), point(-10, -20),
    point(-10, -5), point(12, -5), point(12, 5), point(-10, 5),
    point(-10, 30), point(-20, 30)
  ];
}

function side_by_side(a, b) {
  const c = new Canvas(a.width + b.width, a.height);
  for (let y = 0; y < a.height; y++) {
    for (let x = 0; x < a.width; x++) {
      c.write_pixel(x, y, a.pixel_at(x, y));
    }
    for (let x = 0; x < b.width; x++) {
      c.write_pixel(a.width + x, y, b.pixel_at(x, y));
    }
  }
  return c;
}

function fan_both_orders() {
  const turn = rotation(Math.PI / 6);
  const move = translation(104.5, 76.5);
  return side_by_side(fan_transformed(move.multiply(turn)), fan_transformed(turn.multiply(move)));
}

function f_both_orders() {
  const turn = rotation(Math.PI / 6);
  const move = translation(104.5, 76.5);
  const home = translation(44.5, 44.5);
  const ink = new Color(0.92, 0.92, 0.88);
  const dim = new Color(0.16, 0.16, 0.17);

  const ghost = new Canvas(160, 160);
  ghost.fill(new Color(0.02, 0.02, 0.025));
  paint_through(ghost, rasterize(outline(letter_f(), home, 1), 160, 160), dim);

  const a = new Canvas(160, 160);
  for (let y = 0; y < 160; y++) {
    for (let x = 0; x < 160; x++) {
      a.write_pixel(x, y, ghost.pixel_at(x, y));
    }
  }
  paint_through(a, rasterize(outline(letter_f(), move.multiply(turn), 1), 160, 160), ink);

  const b = new Canvas(160, 160);
  for (let y = 0; y < 160; y++) {
    for (let x = 0; x < 160; x++) {
      b.write_pixel(x, y, ghost.pixel_at(x, y));
    }
  }
  paint_through(b, rasterize(outline(letter_f(), turn.multiply(move), 1), 160, 160), ink);

  return side_by_side(a, b);
}

function plate_04() {
  return magnify(f_both_orders(), 2);
}

// Chapter 4 Tests
test('Chapter 4: A point has w = 1', () => {
  const p = point(4, -4);
  assert.strictEqual(p.x, 4);
  assert.strictEqual(p.y, -4);
  assert.strictEqual(p.w, 1);
});

test('Chapter 4: A vector has w = 0', () => {
  const v = vector(4, -4);
  assert.strictEqual(v.x, 4);
  assert.strictEqual(v.y, -4);
  assert.strictEqual(v.w, 0);
});

test('Chapter 4: The difference of two points is a vector', () => {
  const a = point(3, 2);
  const b = point(5, 6);
  assert(Tuple.equals(b.subtract(a), vector(2, 4)));
  assert(Tuple.equals(a.subtract(b), vector(-2, -4)));
});

test('Chapter 4: A point plus a vector is a point', () => {
  const p = point(3, -2);
  const v = vector(-2, 3);
  assert(Tuple.equals(p.add(v), point(1, 1)));
  assert(Tuple.equals(p.subtract(v), point(5, -5)));
});

test('Chapter 4: A vector plus a vector is a vector', () => {
  const a = vector(3, -2);
  const b = vector(-2, 3);
  assert(Tuple.equals(a.add(b), vector(1, 1)));
  assert(Tuple.equals(a.subtract(b), vector(5, -5)));
});

test('Chapter 4: Negating, scaling and dividing a vector', () => {
  const v = vector(1, -2);
  assert(Tuple.equals(v.negate(), vector(-1, 2)));
  assert(Tuple.equals(v.multiply(3.5), vector(3.5, -7)));
  assert(Tuple.equals(v.multiply(0.5), vector(0.5, -1)));
  assert(Tuple.equals(v.divide(2), vector(0.5, -1)));
});

test('Chapter 4: The magnitude of a vector', () => {
  assert.strictEqual(magnitude(vector(1, 0)), 1);
  assert.strictEqual(magnitude(vector(0, 1)), 1);
  assert.strictEqual(magnitude(vector(3, 4)), 5);
  assert.strictEqual(magnitude(vector(-3, -4)), 5);
  assert(Math.abs(magnitude(vector(-1, -2)) - 2.2361) <= 0.0001);
});

test('Chapter 4: Normalizing a vector', () => {
  assert(Tuple.equals(normalize(vector(4, 0)), vector(1, 0)));
  assert(Tuple.equals(normalize(vector(1, 2)), vector(0.4472, 0.8944), 0.0001));
  assert(Math.abs(magnitude(normalize(vector(1, 2))) - 1) <= 0.0001);
});

test('Chapter 4: The dot product of two vectors', () => {
  const a = vector(1, 2);
  const b = vector(2, 3);
  assert.strictEqual(dot(a, b), 8);
  assert.strictEqual(dot(a, vector(-2, 1)), 0);
});

test('Chapter 4: magnitude and dot look at x and y only', () => {
  assert.strictEqual(magnitude(point(3, 4)), 5);
  assert.strictEqual(dot(point(1, 2), point(2, 3)), 8);
});

test('Chapter 4: The cross product of two vectors', () => {
  const a = vector(1, 0);
  const b = vector(0, 1);
  assert.strictEqual(cross(a, b), 1);
  assert.strictEqual(cross(b, a), -1);
  assert.strictEqual(cross(a, a), 0);
  assert.strictEqual(cross(vector(2, 3), vector(4, 5)), -2);
});

test('Chapter 4: The cross product and line insideness', () => {
  const a = point(0, 0);
  const b = point(10, 0);
  assert.strictEqual(cross(b.subtract(a), point(5, 3).subtract(a)), 30);
  assert.strictEqual(cross(b.subtract(a), point(5, -3).subtract(a)), -30);
  assert.strictEqual(cross(b.subtract(a), point(20, 0).subtract(a)), 0);
});

test('Chapter 4: Constructing and inspecting a matrix', () => {
  const m = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  assert.strictEqual(m.get(0, 0), 1);
  assert.strictEqual(m.get(0, 2), 3);
  assert.strictEqual(m.get(1, 0), 4);
  assert.strictEqual(m.get(1, 1), 5);
  assert.strictEqual(m.get(2, 0), 7);
  assert.strictEqual(m.get(2, 2), 9);
});

test('Chapter 4: Matrix equality with identical matrices', () => {
  const a = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  const b = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  assert(Matrix3.equals(a, b));
});

test('Chapter 4: Matrix equality with different matrices', () => {
  const a = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  const b = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 8);
  assert(!Matrix3.equals(a, b));
});

test('Chapter 4: Multiplying two matrices', () => {
  const a = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  const b = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
  const expected = matrix3(4, 8, 8, 13, 17, 17, 22, 26, 26);
  assert(Matrix3.equals(a.multiply(b), expected));
});

test('Chapter 4: Matrix multiplication is not commutative', () => {
  const a = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  const b = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
  assert(!Matrix3.equals(a.multiply(b), b.multiply(a)));
});

test('Chapter 4: A matrix multiplied by a point', () => {
  const a = matrix3(1, 2, 3, 4, 5, 6, 0, 0, 1);
  const p = point(1, 2);
  assert(Tuple.equals(a.multiply(p), point(8, 20)));
});

test('Chapter 4: A matrix multiplied by a vector ignores the last column', () => {
  const a = matrix3(1, 2, 3, 4, 5, 6, 0, 0, 1);
  const v = vector(1, 2);
  assert(Tuple.equals(a.multiply(v), vector(5, 14)));
});

test('Chapter 4: Multiplying by the identity matrix', () => {
  const a = matrix3(0, 1, 2, 1, 2, 4, 2, 4, 8);
  const p = point(1, 2);
  assert(Matrix3.equals(a.multiply(identity()), a));
  assert(Matrix3.equals(identity().multiply(a), a));
  assert(Tuple.equals(identity().multiply(p), p));
});

test('Chapter 4: Transposing a matrix', () => {
  const a = matrix3(0, 9, 3, 9, 8, 0, 1, 8, 5);
  const expected = matrix3(0, 9, 1, 9, 8, 8, 3, 0, 5);
  assert(Matrix3.equals(transpose(a), expected));
});

test('Chapter 4: Transposing the identity matrix', () => {
  assert(Matrix3.equals(transpose(identity()), identity()));
});

test('Chapter 4: The determinant of a 3x3 matrix', () => {
  const a = matrix3(1, 2, 6, -5, 8, -4, 2, 6, 4);
  assert.strictEqual(determinant(a), -196);
});

test('Chapter 4: The determinant of transforms', () => {
  assert.strictEqual(determinant(identity()), 1);
  assert.strictEqual(determinant(scaling(2, 3)), 6);
  assert(Math.abs(determinant(rotation(0.7)) - 1) <= 0.0001);
  assert.strictEqual(determinant(translation(4, 9)), 1);
  assert.strictEqual(determinant(scaling(-1, 1)), -1);
});

test('Chapter 4: Invertibility is an exact test against zero', () => {
  assert.strictEqual(is_invertible(scaling(0.0001, 1)), true);
  assert.strictEqual(determinant(scaling(0.0001, 1)), 0.0001);
  const p = inverse(scaling(0.0001, 1)).multiply(point(0.0001, 3));
  assert(Tuple.equals(p, point(1, 3)));
});

test('Chapter 4: Testing an invertible matrix', () => {
  const a = matrix3(3, 0, 2, 2, 0, -2, 0, 1, 1);
  assert.strictEqual(determinant(a), 10);
  assert.strictEqual(is_invertible(a), true);
});

test('Chapter 4: Testing a non-invertible matrix', () => {
  const a = matrix3(1, 2, 3, 2, 4, 6, 0, 0, 1);
  assert.strictEqual(determinant(a), 0);
  assert.strictEqual(is_invertible(a), false);
});

test('Chapter 4: Calculating the inverse of a matrix', () => {
  const a = matrix3(3, 0, 2, 2, 0, -2, 0, 1, 1);
  const b = inverse(a);
  assert(Math.abs(b.get(0, 0) - 0.2) <= 0.0001);
  assert(Math.abs(b.get(1, 2) - 1) <= 0.0001);
  assert(Math.abs(b.get(2, 1) - (-0.3)) <= 0.0001);
  const expected = matrix3(0.2, 0.2, 0, -0.2, 0.3, 1, 0.2, -0.3, 0);
  assert(Matrix3.equals(b, expected));
  assert(Matrix3.equals(a.multiply(b), identity()));
});

test('Chapter 4: Multiplying a product by its inverse', () => {
  const a = matrix3(1, 2, 3, 4, 5, 6, 7, 8, 9);
  const b = matrix3(2, -1, 0, 1, 3, 1, 0, 1, 2);
  const c = a.multiply(b);
  assert(Matrix3.equals(c.multiply(inverse(b)), a));
});

test('Chapter 4: The inverse of a transform is a transform', () => {
  const a = translation(5, -3).multiply(rotation(Math.PI / 6)).multiply(scaling(2, 3));
  const b = inverse(a);
  assert(Math.abs(b.get(2, 0) - 0) <= 0.0001);
  assert(Math.abs(b.get(2, 1) - 0) <= 0.0001);
  assert(Math.abs(b.get(2, 2) - 1) <= 0.0001);
  assert(Math.abs(b.get(0, 0) - 0.4330) <= 0.0001);
  assert(Math.abs(b.get(0, 2) - (-1.4151)) <= 0.0001);
  assert(Math.abs(b.get(1, 2) - 1.6994) <= 0.0001);
  assert(Matrix3.equals(b.multiply(a), identity()));
});

test('Chapter 4: Multiplying by a translation matrix', () => {
  const t = translation(5, -3);
  const p = point(-3, 4);
  assert(Tuple.equals(t.multiply(p), point(2, 1)));
});

test('Chapter 4: The inverse of a translation', () => {
  const t = translation(5, -3);
  const p = point(-3, 4);
  assert(Tuple.equals(inverse(t).multiply(p), point(-8, 7)));
});

test('Chapter 4: Translation does not affect vectors', () => {
  const t = translation(5, -3);
  const v = vector(-3, 4);
  assert(Tuple.equals(t.multiply(v), v));
});

test('Chapter 4: A scaling matrix applied to a point', () => {
  const s = scaling(2, 3);
  const p = point(-4, 6);
  assert(Tuple.equals(s.multiply(p), point(-8, 18)));
});

test('Chapter 4: A scaling matrix applied to a vector', () => {
  const s = scaling(2, 3);
  const v = vector(-4, 6);
  assert(Tuple.equals(s.multiply(v), vector(-8, 18)));
});

test('Chapter 4: The inverse of a scaling', () => {
  const s = scaling(2, 3);
  const v = vector(-4, 6);
  assert(Tuple.equals(inverse(s).multiply(v), vector(-2, 2)));
});

test('Chapter 4: Reflection is scaling by a negative', () => {
  const s = scaling(-1, 1);
  const p = point(2, 3);
  assert(Tuple.equals(s.multiply(p), point(-2, 3)));
});

test('Chapter 4: A positive rotation turns x toward y', () => {
  const p = point(1, 0);
  assert(Tuple.equals(rotation(Math.PI / 4).multiply(p), point(0.7071, 0.7071), 0.0001));
  assert(Tuple.equals(rotation(Math.PI / 2).multiply(p), point(0, 1), 0.0001));
  assert(Tuple.equals(rotation(Math.PI).multiply(p), point(-1, 0), 0.0001));
});

test('Chapter 4: The inverse of a rotation', () => {
  const p = point(1, 0);
  assert(Tuple.equals(inverse(rotation(Math.PI / 4)).multiply(p), point(0.7071, -0.7071), 0.0001));
  assert(Tuple.equals(rotation(-Math.PI / 4).multiply(p), point(0.7071, -0.7071), 0.0001));
});

test('Chapter 4: A rotation preserves length', () => {
  const v = vector(3, 4);
  assert(Math.abs(magnitude(rotation(1.2).multiply(v)) - 5) <= 0.0001);
  assert(Math.abs(magnitude(rotation(-2.8).multiply(v)) - 5) <= 0.0001);
});

test('Chapter 4: Shearing moves x in proportion to y', () => {
  const s = shearing(1, 0);
  const p = point(2, 3);
  assert(Tuple.equals(s.multiply(p), point(5, 3)));
});

test('Chapter 4: Shearing moves y in proportion to x', () => {
  const s = shearing(0, 1);
  const p = point(2, 3);
  assert(Tuple.equals(s.multiply(p), point(2, 5)));
});

test('Chapter 4: Individual transformations applied in sequence', () => {
  const p = point(1, 0);
  const a = rotation(Math.PI / 2);
  const b = scaling(5, 5);
  const c = translation(10, 5);
  const p2 = a.multiply(p);
  const p3 = b.multiply(p2);
  const p4 = c.multiply(p3);
  assert(Tuple.equals(p2, point(0, 1), 0.0001));
  assert(Tuple.equals(p3, point(0, 5), 0.0001));
  assert(Tuple.equals(p4, point(10, 10), 0.0001));
});

test('Chapter 4: Chained transformations applied in reverse order', () => {
  const p = point(1, 0);
  const a = rotation(Math.PI / 2);
  const b = scaling(5, 5);
  const c = translation(10, 5);
  const t = c.multiply(b).multiply(a);
  assert(Tuple.equals(t.multiply(p), point(10, 10), 0.0001));
});

test('Chapter 4: Different multiplication order is a different transform', () => {
  const p = point(1, 0);
  const a = rotation(Math.PI / 2);
  const b = scaling(5, 5);
  const c = translation(10, 5);
  const t = a.multiply(b).multiply(c);
  assert(Tuple.equals(t.multiply(p), point(-25, 55), 0.0001));
});

test('Chapter 4: Rotating about a point that is not the origin', () => {
  const t = translation(4, 4).multiply(rotation(Math.PI / 2)).multiply(translation(-4, -4));
  assert(Tuple.equals(t.multiply(point(6, 4)), point(4, 6), 0.0001));
  assert(Tuple.equals(t.multiply(point(4, 4)), point(4, 4), 0.0001));
});

test('Chapter 4: The identity, translation and rotation do not stretch', () => {
  assert.strictEqual(approx_scale(identity()), 1);
  assert.strictEqual(approx_scale(translation(7, 9)), 1);
  assert(Math.abs(approx_scale(rotation(1.1)) - 1) <= 0.0001);
});

test('Chapter 4: A uniform scale is reported exactly', () => {
  assert.strictEqual(approx_scale(scaling(2, 2)), 2);
  assert.strictEqual(approx_scale(scaling(0.5, 0.5)), 0.5);
  assert(Math.abs(approx_scale(scaling(3, 3).multiply(rotation(0.7))) - 3) <= 0.0001);
  assert(Math.abs(approx_scale(translation(5, 5).multiply(scaling(3, 3))) - 3) <= 0.0001);
});

test('Chapter 4: A reflection is not a negative scale', () => {
  assert.strictEqual(approx_scale(scaling(-2, 2)), 2);
});

test('Chapter 4: A non-uniform scale is the geometric mean', () => {
  assert.strictEqual(approx_scale(scaling(4, 1)), 2);
  assert(Math.abs(approx_scale(scaling(4, 1).multiply(rotation(0.4))) - 2) <= 0.0001);
  assert.strictEqual(approx_scale(scaling(9, 1)), 3);
});

test('Chapter 4: A shear that preserves area reports 1', () => {
  assert.strictEqual(approx_scale(shearing(1, 0)), 1);
  assert(Math.abs(approx_scale(shearing(0.5, 0.5)) - 0.8660) <= 0.0001);
});

test('Chapter 4: A collapsed transform reports 0', () => {
  assert.strictEqual(approx_scale(scaling(0, 1)), 0);
  assert.strictEqual(approx_scale(matrix3(1, 2, 0, 2, 4, 0, 0, 0, 1)), 0);
});

test('Chapter 4: A segment between pixel centers', () => {
  const s = segment(point(2.5, 2.5), point(11.5, 5.5), 1);
  const cov = rasterize(s, 16, 10);
  assert(Math.abs(coverage_at(cov, 2, 2) - 0.484375) <= 0.0001);
  assert(Math.abs(coverage_at(cov, 6, 3) - 0.6875) <= 0.0001);
  assert(Math.abs(coverage_at(cov, 7, 3) - 0.359375) <= 0.0001);
});

test('Chapter 4: A segment need not start on a pixel center', () => {
  const s = segment(point(1, 3.5), point(7, 3.5), 1);
  const cov = rasterize(s, 10, 10);
  assert.strictEqual(coverage_at(cov, 0, 3), 0);
  assert.strictEqual(coverage_at(cov, 1, 3), 1);
  assert.strictEqual(coverage_at(cov, 6, 3), 1);
  assert.strictEqual(coverage_at(cov, 7, 3), 0);
  assert.strictEqual(coverage_at(cov, 3, 2), 0);
});

test('Chapter 4: A segment of no length is a square', () => {
  const s = segment(point(3.5, 3.5), point(3.5, 3.5), 1);
  const cov = rasterize(s, 8, 8);
  assert.strictEqual(coverage_at(cov, 3, 3), 1);
});

test('Chapter 4: A union of nothing is inside nowhere', () => {
  const s = union([]);
  assert.strictEqual(inside(s, 0, 0), false);
  assert.strictEqual(ink(rasterize(s, 4, 4)), 0);
});

test('Chapter 4: A union is inside when any part is', () => {
  const s = union([circle(2, 2, 1), rectangle(5, 0, 7, 4)]);
  assert.strictEqual(inside(s, 2, 2), true);
  assert.strictEqual(inside(s, 6, 1), true);
  assert.strictEqual(inside(s, 4, 2), false);
});

test('Chapter 4: A circle seen through a scale is an ellipse', () => {
  const s = transformed(circle(0, 0, 4), scaling(2, 1));
  assert.strictEqual(inside(s, 7.9, 0), true);
  assert.strictEqual(inside(s, 8.1, 0), false);
  assert.strictEqual(inside(s, 0, 3.9), true);
  assert.strictEqual(inside(s, 0, 4.1), false);
  assert(Math.abs(inside(s, 5.6, 1.4) ? 1 : 0) === 1);
  assert(Math.abs(inside(s, 5.6, 2.9) ? 1 : 0) === 0);
});

test('Chapter 4: Transformed circle through translation and scale', () => {
  const s = transformed(circle(0, 0, 4), translation(10, 10).multiply(scaling(2, 1)));
  assert.strictEqual(inside(s, 10, 10), true);
  assert.strictEqual(inside(s, 17.9, 10), true);
  assert.strictEqual(inside(s, 18.1, 10), false);
  assert.strictEqual(inside(s, 10, 13.9), true);
  assert.strictEqual(inside(s, 10, 14.1), false);
});

test('Chapter 4: A shape through a collapsed transform is empty', () => {
  const s = transformed(circle(0, 0, 4), scaling(0, 1));
  assert.strictEqual(inside(s, 0, 0), false);
});

test('Chapter 4: The fan as points', () => {
  const pts = fan_points();
  assert.strictEqual(pts.length, 13);
  assert(Tuple.equals(pts[0], point(0, 0)));
  assert(Tuple.equals(pts[1], point(36, 0)));
  assert(Tuple.equals(pts[4], point(0, 36)));
  assert(Tuple.equals(pts[7], point(-36, 0)));
  assert(Tuple.equals(pts[2], point(31.1769, 18), 0.0001));
});

test('Chapter 4: Rotate then translate: fan turns about its center', () => {
  const m = translation(104.5, 76.5).multiply(rotation(Math.PI / 6));
  const pts = transform_points(fan_points(), m);
  assert(Tuple.equals(pts[0], point(104.5, 76.5), 0.0001));
  assert(Tuple.equals(pts[1], point(135.6769, 94.5), 0.0001));
  assert(Tuple.equals(pts[4], point(86.5, 107.6769), 0.0001));
});

test('Chapter 4: Translate then rotate: fan swings about canvas corner', () => {
  const m = rotation(Math.PI / 6).multiply(translation(104.5, 76.5));
  const pts = transform_points(fan_points(), m);
  assert(Tuple.equals(pts[0], point(52.2497, 118.5009), 0.0001));
  assert(Tuple.equals(pts[1], point(83.4266, 136.5009), 0.0001));
});

test('Chapter 4: The letter F', () => {
  const f = letter_f();
  assert.strictEqual(f.length, 10);
  assert(Tuple.equals(f[0], point(-20, -30)));
  assert(Tuple.equals(f[1], point(20, -30)));
  assert(Tuple.equals(f[5], point(12, -5)));
  assert(Tuple.equals(f[9], point(-20, 30)));
});

test('Chapter 4: The F at home', () => {
  const f = transform_points(letter_f(), translation(44.5, 44.5));
  assert(Tuple.equals(f[0], point(24.5, 14.5), 0.0001));
  assert(Tuple.equals(f[1], point(64.5, 14.5), 0.0001));
  assert(Tuple.equals(f[9], point(24.5, 74.5), 0.0001));
});

test('Chapter 4: The F, rotated then translated', () => {
  const m = translation(104.5, 76.5).multiply(rotation(Math.PI / 6));
  const f = transform_points(letter_f(), m);
  assert(Tuple.equals(f[0], point(102.1795, 40.5192), 0.0001));
  assert(Tuple.equals(f[1], point(136.8205, 60.5192), 0.0001));
  assert(Tuple.equals(f[5], point(117.3923, 78.1699), 0.0001));
  assert(Tuple.equals(f[9], point(72.1795, 92.4808), 0.0001));
});

test('Chapter 4: The F, translated then rotated', () => {
  const m = rotation(Math.PI / 6).multiply(translation(104.5, 76.5));
  const f = transform_points(letter_f(), m);
  assert(Tuple.equals(f[0], point(49.9291, 82.5202), 0.0001));
  assert(Tuple.equals(f[1], point(84.5702, 102.5202), 0.0001));
  assert(Tuple.equals(f[5], point(65.142, 120.1708), 0.0001));
  assert(Tuple.equals(f[9], point(19.9291, 134.4817), 0.0001));
});

test('Chapter 4: side_by_side puts the first canvas on the left', () => {
  const a = new Canvas(2, 3);
  const b = new Canvas(4, 3);
  a.fill(new Color(1, 0, 0));
  b.fill(new Color(0, 0, 1));
  const c = side_by_side(a, b);
  assert.strictEqual(c.width, 6);
  assert.strictEqual(c.height, 3);
  assert_color_equal(c.pixel_at(0, 0), new Color(1, 0, 0));
  assert_color_equal(c.pixel_at(1, 2), new Color(1, 0, 0));
  assert_color_equal(c.pixel_at(2, 0), new Color(0, 0, 1));
  assert_color_equal(c.pixel_at(5, 2), new Color(0, 0, 1));
});

test('Chapter 4: The fan, both orders', () => {
  const c = fan_both_orders();
  const ref = read_file('reference/chapter-04/fan-both-orders.ppm');
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 320);
  assert.strictEqual(c.height, 160);
  const test_pixels = [
    [104, 76], [124, 76], [104, 56], [125, 88], [116, 97], [141, 76],
    [10, 10], [212, 118], [232, 118], [233, 130], [224, 139], [200, 139],
    [310, 10]
  ];
  for (const [x, y] of test_pixels) {
    const pix = ppm_pixel(p6, x, y);
    assert(pix, `Pixel at ${x},${y} should exist`);
  }
  assert(max_channel_difference(p6, ref) <= 1);
});

test('Chapter 4: Plate 04', () => {
  const c = plate_04();
  const ref = read_file('reference/chapter-04/plate-04.ppm');
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 640);
  assert.strictEqual(c.height, 320);
  const test_pixels = [
    [48, 28], [80, 28], [48, 100], [10, 10], [200, 150], [268, 129],
    [215, 145], [239, 101], [174, 173], [368, 28], [500, 60],
    [453, 207], [431, 229], [445, 249], [368, 273]
  ];
  for (const [x, y] of test_pixels) {
    const pix = ppm_pixel(p6, x, y);
    assert(pix, `Pixel at ${x},${y} should exist`);
  }
  assert(max_channel_difference(p6, ref) <= 1);
});

// Write Chapter 3 output files
test('Write chapter 3 output files', async () => {
  const cb = fan_bresenham();
  const p6b_bres = canvas_to_p6(cb);
  await fs.writeFile('out/fan-bresenham.ppm', p6b_bres);

  const cw = fan_wu();
  const p6w = canvas_to_p6(cw);
  await fs.writeFile('out/fan-wu.ppm', p6w);

  const c1 = fan_coverage();
  const p6a = canvas_to_p6(c1);
  await fs.writeFile('out/fan-coverage.ppm', p6a);

  const c2 = plate_03();
  const p6b = canvas_to_p6(c2);
  await fs.writeFile('out/plate-03.ppm', p6b);
});

// Write Chapter 4 output files
test('Write chapter 4 output files', async () => {
  const c1 = fan_both_orders();
  const p6a = canvas_to_p6(c1);
  await fs.writeFile('out/fan-both-orders.ppm', p6a);

  const c2 = plate_04();
  const p6b = canvas_to_p6(c2);
  await fs.writeFile('out/plate-04.ppm', p6b);
});

// ===========================
// Chapter 5: Paths and Insideness
// ===========================

// A path is a list of subpaths. A subpath is { points: [Tuple, ...], closed: bool }.
class Path {
  constructor() {
    this.subpaths = [];
  }
}

function path() {
  return new Path();
}

function move_to(p, pt) {
  p.subpaths.push({ points: [pt], closed: false });
}

function line_to(p, pt) {
  if (p.subpaths.length === 0) {
    move_to(p, pt);
    return;
  }
  const last = p.subpaths[p.subpaths.length - 1];
  if (last.closed) {
    // A line_to right after a close starts a new subpath at the point the
    // closed subpath began, because that's where close left the pen.
    const start = last.points[0];
    p.subpaths.push({ points: [start, pt], closed: false });
    return;
  }
  last.points.push(pt);
}

function close(p) {
  if (p.subpaths.length === 0) return;
  p.subpaths[p.subpaths.length - 1].closed = true;
}

function subpaths(p) {
  return p.subpaths;
}

function edges(p) {
  // Every subpath is treated as closed for filling, whether or not close()
  // was called: the edge from the last point back to the first is always
  // included. A subpath of one point contributes no edges.
  const result = [];
  for (const sp of p.subpaths) {
    const pts = sp.points;
    if (pts.length < 2) continue;
    for (let i = 0; i < pts.length; i++) {
      const a = pts[i];
      const b = pts[(i + 1) % pts.length];
      result.push([a, b]);
    }
  }
  return result;
}

function bounds(p) {
  let minx = Infinity, miny = Infinity, maxx = -Infinity, maxy = -Infinity;
  let any = false;
  for (const sp of p.subpaths) {
    for (const pt of sp.points) {
      any = true;
      if (pt.x < minx) minx = pt.x;
      if (pt.y < miny) miny = pt.y;
      if (pt.x > maxx) maxx = pt.x;
      if (pt.y > maxy) maxy = pt.y;
    }
  }
  if (!any) return [0, 0, 0, 0];
  return [minx, miny, maxx, maxy];
}

function polygon(...points) {
  const p = path();
  points.forEach((pt, i) => {
    if (i === 0) move_to(p, pt); else line_to(p, pt);
  });
  close(p);
  return p;
}

function circle_path(cx, cy, r, n) {
  const pts = [];
  for (let i = 0; i < n; i++) {
    const a = i * 2 * Math.PI / n;
    pts.push(point(cx + r * Math.cos(a), cy + r * Math.sin(a)));
  }
  return polygon(...pts);
}

function crossings(p, x, y) {
  let count = 0;
  for (const [a, b] of edges(p)) {
    const spans = (a.y <= y && y < b.y) || (b.y <= y && y < a.y);
    if (!spans) continue;
    const t = (y - a.y) / (b.y - a.y);
    const cx = a.x + t * (b.x - a.x);
    if (cx > x) count++;
  }
  return count;
}

function winding_at(p, x, y) {
  const q = point(x, y);
  let w = 0;
  for (const [a, b] of edges(p)) {
    if (a.y <= y) {
      if (b.y > y && cross(b.subtract(a), q.subtract(a)) > 0) w += 1;
    } else {
      if (b.y <= y && cross(b.subtract(a), q.subtract(a)) < 0) w -= 1;
    }
  }
  return w;
}

function inside_nonzero(p, x, y) {
  return winding_at(p, x, y) !== 0;
}

function inside_evenodd(p, x, y) {
  return Math.abs(winding_at(p, x, y)) % 2 === 1;
}

// A path filled under a rule ("nonzero" or "evenodd") is a shape.
class FilledPath extends Shape {
  constructor(path, rule) {
    super();
    this.path = path;
    this.rule = rule;
  }
}

function filled(p, rule) {
  return new FilledPath(p, rule);
}

function rasterize_within(shape, box, width, height) {
  const buf = coverage_buffer(width, height);
  const [minx, miny, maxx, maxy] = box;
  const x0 = Math.max(0, Math.floor(minx));
  const x1 = Math.min(width, Math.ceil(maxx));
  const y0 = Math.max(0, Math.floor(miny));
  const y1 = Math.min(height, Math.ceil(maxy));
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      set_coverage(buf, x, y, coverage(shape, x, y));
    }
  }
  return buf;
}

// Chapter 5 renders
function star() {
  const p = path();
  for (let k = 0; k < 5; k++) {
    const a = (-90 + 144 * k) * Math.PI / 180;
    const q = point(80.5 + 70 * Math.cos(a), 80.5 + 70 * Math.sin(a));
    if (k === 0) move_to(p, q); else line_to(p, q);
  }
  close(p);
  return p;
}

function star_panel(rule, method) {
  const c = new Canvas(160, 160);
  c.fill(new Color(0.02, 0.02, 0.025));
  const s = filled(star(), rule);
  const cov = method === 'centers'
    ? rasterize_centers(s, 160, 160)
    : rasterize_within(s, bounds(star()), 160, 160);
  paint_through(c, cov, new Color(0.9, 0.55, 0.1));
  return c;
}

function star_centers() {
  return side_by_side(star_panel('nonzero', 'centers'), star_panel('evenodd', 'centers'));
}

function star_coverage() {
  return side_by_side(star_panel('nonzero', 'coverage'), star_panel('evenodd', 'coverage'));
}

function plate_05() {
  const top = star_centers();
  const bottom = star_coverage();
  const both = new Canvas(320, 320);
  for (let y = 0; y < 160; y++) {
    for (let x = 0; x < 320; x++) {
      both.write_pixel(x, y, top.pixel_at(x, y));
      both.write_pixel(x, y + 160, bottom.pixel_at(x, y));
    }
  }
  return magnify(both, 2);
}

// --- features/chapter05-paths.feature ---

test('Chapter 5: An empty path', () => {
  const p = path();
  assert.strictEqual(subpaths(p).length, 0);
  assert.strictEqual(edges(p).length, 0);
  assert_bounds_equal(bounds(p), [0, 0, 0, 0]);
});

test('Chapter 5: A triangle, closed', () => {
  const p = path();
  move_to(p, point(1, 1));
  line_to(p, point(9, 1));
  line_to(p, point(5, 8));
  close(p);
  assert.strictEqual(subpaths(p).length, 1);
  assert.strictEqual(subpaths(p)[0].closed, true);
  assert.strictEqual(subpaths(p)[0].points.length, 3);
  assert(Tuple.equals(subpaths(p)[0].points[2], point(5, 8)));
  assert.strictEqual(edges(p).length, 3);
  assert_edge_equal(edges(p)[2], [point(5, 8), point(1, 1)]);
  assert_bounds_equal(bounds(p), [1, 1, 9, 8]);
});

test('Chapter 5: A triangle left open still has three edges', () => {
  const p = path();
  move_to(p, point(1, 1));
  line_to(p, point(9, 1));
  line_to(p, point(5, 8));
  assert.strictEqual(subpaths(p)[0].closed, false);
  assert.strictEqual(edges(p).length, 3);
  assert_edge_equal(edges(p)[2], [point(5, 8), point(1, 1)]);
});

test('Chapter 5: move_to starts a second subpath', () => {
  const p = path();
  move_to(p, point(0, 0));
  line_to(p, point(10, 0));
  line_to(p, point(10, 10));
  line_to(p, point(0, 10));
  close(p);
  move_to(p, point(3, 3));
  line_to(p, point(3, 7));
  line_to(p, point(7, 7));
  line_to(p, point(7, 3));
  close(p);
  assert.strictEqual(subpaths(p).length, 2);
  assert(Tuple.equals(subpaths(p)[1].points[0], point(3, 3)));
  assert.strictEqual(edges(p).length, 8);
  assert_bounds_equal(bounds(p), [0, 0, 10, 10]);
});

test('Chapter 5: line_to after a close starts a new subpath where the closed one began', () => {
  const p = path();
  move_to(p, point(1, 1));
  line_to(p, point(4, 1));
  line_to(p, point(4, 4));
  close(p);
  line_to(p, point(9, 9));
  assert.strictEqual(subpaths(p).length, 2);
  assert.strictEqual(subpaths(p)[1].closed, false);
  assert.strictEqual(subpaths(p)[1].points.length, 2);
  assert(Tuple.equals(subpaths(p)[1].points[0], point(1, 1)));
  assert(Tuple.equals(subpaths(p)[1].points[1], point(9, 9)));
});

test('Chapter 5: line_to with nothing to extend behaves as move_to', () => {
  const p = path();
  line_to(p, point(2, 3));
  assert.strictEqual(subpaths(p).length, 1);
  assert.strictEqual(subpaths(p)[0].points.length, 1);
  assert(Tuple.equals(subpaths(p)[0].points[0], point(2, 3)));
});

test('Chapter 5: A subpath of one point has no edges, and closing nothing does nothing', () => {
  const p = path();
  close(p);
  move_to(p, point(1, 1));
  move_to(p, point(2, 2));
  assert.strictEqual(subpaths(p).length, 2);
  assert.strictEqual(edges(p).length, 0);
  assert_bounds_equal(bounds(p), [1, 1, 2, 2]);
});

test('Chapter 5: A subpath of two points has two edges and encloses nothing', () => {
  const p = path();
  move_to(p, point(1, 1));
  line_to(p, point(9, 9));
  assert.strictEqual(edges(p).length, 2);
  assert.strictEqual(winding_at(p, 3, 5), 0);
});

test('Chapter 5: polygon is a closed subpath through its points', () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10));
  assert.strictEqual(subpaths(p).length, 1);
  assert.strictEqual(subpaths(p)[0].closed, true);
  assert.strictEqual(edges(p).length, 4);
});

test('Chapter 5: circle_path is a polygon standing in for a circle', () => {
  const p = circle_path(10, 10, 5, 8);
  assert.strictEqual(subpaths(p)[0].points.length, 8);
  assert(Tuple.equals(subpaths(p)[0].points[0], point(15, 10)));
  assert(Tuple.equals(subpaths(p)[0].points[1], point(13.5355, 13.5355), 0.0001));
  assert(Tuple.equals(subpaths(p)[0].points[2], point(10, 15)));
  assert_bounds_equal(bounds(p), [5, 5, 15, 15]);
});

// --- features/chapter05-winding.feature ---

test('Chapter 5: Crossings from inside and outside a square', () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10));
  assert.strictEqual(crossings(p, 5, 5), 1);
  assert.strictEqual(crossings(p, 15, 5), 0);
  assert.strictEqual(crossings(p, -1, 5), 2);
});

test('Chapter 5: A clockwise square winds once', () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10));
  assert.strictEqual(winding_at(p, 5, 5), 1);
  assert.strictEqual(winding_at(p, 15, 5), 0);
  assert.strictEqual(winding_at(p, -1, 5), 0);
  assert.strictEqual(winding_at(p, 5, -1), 0);
  assert.strictEqual(winding_at(p, 5, 11), 0);
});

test('Chapter 5: The same square the other way round winds minus once', () => {
  const p = polygon(point(0, 0), point(0, 10), point(10, 10), point(10, 0));
  assert.strictEqual(winding_at(p, 5, 5), -1);
  assert.strictEqual(crossings(p, 5, 5), 1);
});

test('Chapter 5: A ray through a vertex counts it once', () => {
  const p = polygon(point(5, 0), point(10, 5), point(5, 10), point(0, 5));
  assert.strictEqual(crossings(p, 2, 5), 1);
  assert.strictEqual(winding_at(p, 2, 5), 1);
  assert.strictEqual(crossings(p, -1, 5), 2);
  assert.strictEqual(winding_at(p, -1, 5), 0);
  assert.strictEqual(winding_at(p, 12, 5), 0);
  assert.strictEqual(winding_at(p, 5, 5), 1);
});

test('Chapter 5: The boundary belongs to the top and the left', () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10));
  assert.strictEqual(winding_at(p, 5, 0), 1);
  assert.strictEqual(winding_at(p, 0, 5), 1);
  assert.strictEqual(winding_at(p, 0, 0), 1);
  assert.strictEqual(winding_at(p, 5, 10), 0);
  assert.strictEqual(winding_at(p, 10, 5), 0);
  assert.strictEqual(winding_at(p, 10, 10), 0);
});

test('Chapter 5: Two rectangles that share an edge cover it once', () => {
  const p = path();
  move_to(p, point(0, 0));
  line_to(p, point(5, 0));
  line_to(p, point(5, 10));
  line_to(p, point(0, 10));
  close(p);
  move_to(p, point(5, 0));
  line_to(p, point(10, 0));
  line_to(p, point(10, 10));
  line_to(p, point(5, 10));
  close(p);
  assert.strictEqual(winding_at(p, 2, 5), 1);
  assert.strictEqual(winding_at(p, 5, 5), 1);
  assert.strictEqual(winding_at(p, 8, 5), 1);
});

test('Chapter 5: A diamond wound twice has winding number 2', () => {
  const p = path();
  move_to(p, point(5, 0));
  line_to(p, point(10, 5));
  line_to(p, point(5, 10));
  line_to(p, point(0, 5));
  line_to(p, point(5, 0));
  line_to(p, point(10, 5));
  line_to(p, point(5, 10));
  line_to(p, point(0, 5));
  close(p);
  assert.strictEqual(edges(p).length, 8);
  assert.strictEqual(winding_at(p, 5, 5), 2);
  assert.strictEqual(crossings(p, 5, 5), 2);
  assert.strictEqual(winding_at(p, 12, 5), 0);
});

test('Chapter 5: The polygon circle', () => {
  const p = circle_path(10, 10, 5, 8);
  assert.strictEqual(winding_at(p, 10, 10), 1);
  assert.strictEqual(winding_at(p, 14.9, 10), 1);
  assert.strictEqual(winding_at(p, 15, 10), 0);
  assert.strictEqual(winding_at(p, 10, 5.1), 1);
  assert.strictEqual(winding_at(p, 10, 4.9), 0);
});

test("Chapter 5: The pentagram's center winds twice", () => {
  const p = star();
  assert.strictEqual(winding_at(p, 80.5, 80.5), 2);
  assert.strictEqual(crossings(p, 80.5, 80.5), 2);
  assert.strictEqual(winding_at(p, 80.5, 20), 1);
  assert.strictEqual(winding_at(p, 30, 60), 1);
  assert.strictEqual(crossings(p, 30, 60), 3);
  assert.strictEqual(winding_at(p, 80.5, 120), 0);
  assert.strictEqual(crossings(p, 80.5, 120), 2);
  assert.strictEqual(winding_at(p, 10, 10), 0);
});

// --- features/chapter05-rules.feature ---

test('Chapter 5: A single loop is inside under both rules', () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 10), point(0, 10));
  assert.strictEqual(inside_nonzero(p, 5, 5), true);
  assert.strictEqual(inside_evenodd(p, 5, 5), true);
  assert.strictEqual(inside_nonzero(p, 15, 5), false);
  assert.strictEqual(inside_evenodd(p, 15, 5), false);
});

test('Chapter 5: An inner loop the other way round is a hole under both rules', () => {
  const p = path();
  move_to(p, point(0, 0));
  line_to(p, point(10, 0));
  line_to(p, point(10, 10));
  line_to(p, point(0, 10));
  close(p);
  move_to(p, point(3, 3));
  line_to(p, point(3, 7));
  line_to(p, point(7, 7));
  line_to(p, point(7, 3));
  close(p);
  assert.strictEqual(winding_at(p, 5, 5), 0);
  assert.strictEqual(winding_at(p, 1, 1), 1);
  assert.strictEqual(inside_nonzero(p, 5, 5), false);
  assert.strictEqual(inside_evenodd(p, 5, 5), false);
  assert.strictEqual(inside_nonzero(p, 1, 1), true);
});

test('Chapter 5: An inner loop the same way round is a hole only under even-odd', () => {
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
  assert.strictEqual(winding_at(p, 5, 5), 2);
  assert.strictEqual(inside_nonzero(p, 5, 5), true);
  assert.strictEqual(inside_evenodd(p, 5, 5), false);
});

test('Chapter 5: A loop wound twice vanishes under even-odd', () => {
  const p = path();
  move_to(p, point(5, 0));
  line_to(p, point(10, 5));
  line_to(p, point(5, 10));
  line_to(p, point(0, 5));
  line_to(p, point(5, 0));
  line_to(p, point(10, 5));
  line_to(p, point(5, 10));
  line_to(p, point(0, 5));
  close(p);
  assert.strictEqual(inside_nonzero(p, 5, 5), true);
  assert.strictEqual(inside_evenodd(p, 5, 5), false);
});

test("Chapter 5: The pentagram's center is inside under nonzero and outside under even-odd", () => {
  const p = star();
  assert.strictEqual(inside_nonzero(p, 80.5, 80.5), true);
  assert.strictEqual(inside_evenodd(p, 80.5, 80.5), false);
  assert.strictEqual(inside_nonzero(p, 80.5, 20), true);
  assert.strictEqual(inside_evenodd(p, 80.5, 20), true);
  assert.strictEqual(inside_nonzero(p, 80.5, 120), false);
  assert.strictEqual(inside_evenodd(p, 80.5, 120), false);
});

test('Chapter 5: A filled path is a shape', () => {
  const s = filled(polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6)), 'nonzero');
  const cov = rasterize(s, 8, 8);
  assert.strictEqual(inside(s, 3, 3), true);
  assert.strictEqual(inside(s, 7, 3), false);
  assert.strictEqual(coverage_at(cov, 3, 3), 1);
  assert.strictEqual(coverage_at(cov, 1, 3), 0);
  assert.strictEqual(coverage_at(cov, 6, 3), 0);
  assert.strictEqual(ink(cov), 16);
});

test('Chapter 5: A filled path takes the rule seriously', () => {
  const p = star();
  const a = filled(p, 'nonzero');
  const b = filled(p, 'evenodd');
  const ca = rasterize(a, 160, 160);
  const cb = rasterize(b, 160, 160);
  assert.strictEqual(coverage_at(ca, 80, 80), 1);
  assert.strictEqual(coverage_at(cb, 80, 80), 0);
  assert.strictEqual(coverage_at(ca, 80, 20), 1);
  assert.strictEqual(coverage_at(cb, 80, 20), 1);
  assert_number_equal(coverage_at(ca, 80, 10), 0.0625);
  assert_number_equal(coverage_at(cb, 80, 10), 0.0625);
  assert_number_equal(ink(ca), 5499.9375);
  assert_number_equal(ink(cb), 3800.375);
});

test('Chapter 5: Rasterizing within the bounds gives the same coverage', () => {
  const p = star();
  const s = filled(p, 'evenodd');
  const full = rasterize(s, 160, 160);
  const within = rasterize_within(s, bounds(p), 160, 160);
  assert.strictEqual(ink(within), ink(full));
  assert.strictEqual(coverage_at(within, 80, 20), coverage_at(full, 80, 20));
  assert.strictEqual(coverage_at(within, 13, 58), coverage_at(full, 13, 58));
  assert.strictEqual(coverage_at(within, 10, 10), 0);
});

test('Chapter 5: The box is inclusive of the pixels it touches, and clipped to the buffer', () => {
  const s = filled(polygon(point(1.5, 1.5), point(6.5, 1.5), point(6.5, 6.5), point(1.5, 6.5)), 'nonzero');
  const cov = rasterize_within(s, [1.5, 1.5, 6.5, 6.5], 8, 8);
  const big = rasterize_within(s, [-5, -5, 20, 20], 8, 8);
  assert_number_equal(coverage_at(cov, 1, 1), 0.25);
  assert_number_equal(coverage_at(cov, 6, 6), 0.25);
  assert.strictEqual(coverage_at(cov, 3, 3), 1);
  assert_number_equal(ink(cov), 25);
  assert_number_equal(ink(big), 25);
});

// --- features/chapter05-plate.feature ---

test('Chapter 5: The pentagram', () => {
  const p = star();
  assert.strictEqual(subpaths(p).length, 1);
  assert.strictEqual(edges(p).length, 5);
  assert(Tuple.equals(subpaths(p)[0].points[0], point(80.5, 10.5), 0.0001));
  assert(Tuple.equals(subpaths(p)[0].points[1], point(121.645, 137.1312), 0.0001));
  assert(Tuple.equals(subpaths(p)[0].points[2], point(13.926, 58.8688), 0.0001));
  assert(Tuple.equals(subpaths(p)[0].points[3], point(147.074, 58.8688), 0.0001));
  assert(Tuple.equals(subpaths(p)[0].points[4], point(39.355, 137.1312), 0.0001));
  assert_bounds_equal(bounds(p), [13.926, 10.5, 147.074, 137.1312]);
});

test('Chapter 5: The star by the center question', () => {
  const c = star_centers();
  const ref = read_file('reference/chapter-05/star-centers.ppm');
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 320);
  assert.strictEqual(c.height, 160);
  assert_pixel_approx(p6, 80, 80, [243, 196, 89]);
  assert_pixel_approx(p6, 240, 80, [39, 39, 44]);
  assert_pixel_approx(p6, 80, 20, [243, 196, 89]);
  assert_pixel_approx(p6, 240, 20, [243, 196, 89]);
  assert_pixel_approx(p6, 30, 60, [243, 196, 89]);
  assert_pixel_approx(p6, 190, 60, [243, 196, 89]);
  assert_pixel_approx(p6, 80, 120, [39, 39, 44]);
  assert_pixel_approx(p6, 80, 10, [39, 39, 44]);
  assert_pixel_approx(p6, 10, 10, [39, 39, 44]);
  assert(max_channel_difference(p6, ref) <= 1);
});

test('Chapter 5: The star by coverage', () => {
  const c = star_coverage();
  const ref = read_file('reference/chapter-05/star-coverage.ppm');
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 320);
  assert.strictEqual(c.height, 160);
  assert_pixel_approx(p6, 80, 80, [243, 196, 89]);
  assert_pixel_approx(p6, 240, 80, [39, 39, 44]);
  assert_pixel_approx(p6, 80, 20, [243, 196, 89]);
  assert_pixel_approx(p6, 240, 20, [243, 196, 89]);
  assert_pixel_approx(p6, 80, 120, [39, 39, 44]);
  assert_pixel_approx(p6, 80, 10, [77, 65, 48]);
  assert_pixel_approx(p6, 240, 10, [77, 65, 48]);
  assert_pixel_approx(p6, 80, 11, [199, 160, 76]);
  assert_pixel_approx(p6, 14, 58, [101, 83, 52]);
  assert_pixel_approx(p6, 174, 58, [101, 83, 52]);
  assert_pixel_approx(p6, 10, 10, [39, 39, 44]);
  assert(max_channel_difference(p6, ref) <= 1);
});

test('Chapter 5: Plate 5', () => {
  const c = plate_05();
  const ref = read_file('reference/chapter-05/plate-05.ppm');
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 640);
  assert.strictEqual(c.height, 640);
  assert_pixel_approx(p6, 160, 160, [243, 196, 89]);
  assert_pixel_approx(p6, 480, 160, [39, 39, 44]);
  assert_pixel_approx(p6, 160, 480, [243, 196, 89]);
  assert_pixel_approx(p6, 480, 480, [39, 39, 44]);
  assert_pixel_approx(p6, 160, 40, [243, 196, 89]);
  assert_pixel_approx(p6, 480, 360, [243, 196, 89]);
  assert_pixel_approx(p6, 160, 20, [39, 39, 44]);
  assert_pixel_approx(p6, 160, 341, [77, 65, 48]);
  assert_pixel_approx(p6, 480, 341, [77, 65, 48]);
  assert_pixel_approx(p6, 348, 437, [101, 83, 52]);
  assert_pixel_approx(p6, 20, 20, [39, 39, 44]);
  assert(max_channel_difference(p6, ref) <= 1);
});

// Write Chapter 5 output files
test('Write chapter 5 output files', async () => {
  const c1 = star_centers();
  await fs.writeFile('out/star-centers.ppm', canvas_to_p6(c1));

  const c2 = star_coverage();
  await fs.writeFile('out/star-coverage.ppm', canvas_to_p6(c2));

  const c3 = plate_05();
  await fs.writeFile('out/plate-05.ppm', canvas_to_p6(c3));
});

// ===========================
// Chapter 6: Filling a Polygon
// ===========================

function edge_table(p) {
  const table = [];
  for (const [a, b] of edges(p)) {
    if (a.y === b.y) continue; // horizontal edges are dropped, not clamped
    let y_top, y_bottom, x_top, slope, direction;
    if (a.y < b.y) {
      y_top = a.y; y_bottom = b.y; x_top = a.x;
      slope = (b.x - a.x) / (b.y - a.y);
      direction = 1;
    } else {
      y_top = b.y; y_bottom = a.y; x_top = b.x;
      slope = (a.x - b.x) / (a.y - b.y);
      direction = -1;
    }
    table.push({ y_top, y_bottom, x_top, slope, direction });
  }
  table.sort((e1, e2) => (e1.y_top - e2.y_top) || (e1.x_top - e2.x_top));
  return table;
}

function x_at(edge, y) {
  return edge.x_top + (y - edge.y_top) * edge.slope;
}

function crossings_on_row(table, y) {
  const xs = [];
  for (const e of table) {
    if (e.y_top <= y && y < e.y_bottom) {
      xs.push([x_at(e, y), e.direction]);
    }
  }
  xs.sort((a, b) => a[0] - b[0]);
  return xs;
}

function spans_from_crossings(xs, rule) {
  const out = [];
  let w = 0;
  let start = null;
  for (const [x, d] of xs) {
    w += d;
    const isInside = rule === 'nonzero' ? w !== 0 : (Math.abs(w) % 2 === 1);
    if (isInside && start === null) start = x;
    if (!isInside && start !== null) { out.push([start, x]); start = null; }
  }
  return out;
}

function spans(p, rule, row) {
  const y = row + 0.5;
  return spans_from_crossings(crossings_on_row(edge_table(p), y), rule);
}

function fill_span(cov, row, x0, x1) {
  const first = Math.ceil(x0 - 0.5);
  const last = Math.ceil(x1 - 0.5) - 1;
  const lo = Math.max(first, 0);
  const hi = Math.min(last, cov.width - 1);
  for (let x = lo; x <= hi; x++) {
    set_coverage(cov, x, row, 1);
  }
}

function fill_path_aliased(p, rule, w, h) {
  const cov = coverage_buffer(w, h);
  const table = edge_table(p);
  let active = [];
  let next = 0;
  for (let row = 0; row < h; row++) {
    const y = row + 0.5;
    while (next < table.length && table[next].y_top <= y) {
      active.push(table[next]);
      next++;
    }
    active = active.filter(e => e.y_bottom > y);
    const xs = active.map(e => [x_at(e, y), e.direction]).sort((a, b) => a[0] - b[0]);
    for (const [x0, x1] of spans_from_crossings(xs, rule)) {
      fill_span(cov, row, x0, x1);
    }
  }
  return cov;
}

function max_coverage_difference(a, b) {
  if (a.width !== b.width || a.height !== b.height) return 1;
  let max = 0;
  for (let y = 0; y < a.height; y++) {
    for (let x = 0; x < a.width; x++) {
      const d = Math.abs(coverage_at(a, x, y) - coverage_at(b, x, y));
      if (d > max) max = d;
    }
  }
  return max;
}

function transform_path(p, m) {
  const q = path();
  for (const sp of p.subpaths) {
    q.subpaths.push({ points: sp.points.map(pt => m.multiply(pt)), closed: sp.closed });
  }
  return q;
}

// Chapter 6 renders
function unit_star() {
  return transform_path(star(), scaling(1 / 70, 1 / 70).multiply(translation(-80.5, -80.5)));
}

function spiral() {
  const c = new Canvas(320, 320);
  c.fill(new Color(0.02, 0.02, 0.025));
  const inks = [new Color(0.9, 0.55, 0.1), new Color(0.2, 0.55, 0.85), new Color(0.85, 0.25, 0.3)];
  const us = unit_star();
  for (let k = 0; k < 24; k++) {
    const a = k * 25 * Math.PI / 180;
    const r = 20 + 5 * k;
    const s = 6 + 1.25 * k;
    const m = translation(160.5 + r * Math.cos(a), 160.5 + r * Math.sin(a))
      .multiply(rotation(a))
      .multiply(scaling(s, s));
    const cov = fill_path_aliased(transform_path(us, m), 'nonzero', 320, 320);
    paint_through(c, cov, inks[k % 3]);
  }
  return c;
}

function plate_06() {
  return magnify(spiral(), 2);
}

// --- features/chapter06-edges.feature ---

test('Chapter 6: A rectangle has two edges in its table', () => {
  const p = polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6));
  const t = edge_table(p);
  assert.strictEqual(t.length, 2);
  assert.strictEqual(t[0].y_top, 2);
  assert.strictEqual(t[0].y_bottom, 6);
  assert.strictEqual(t[0].x_top, 2);
  assert.strictEqual(t[0].slope, 0);
  assert.strictEqual(t[0].direction, -1);
  assert.strictEqual(t[1].x_top, 6);
  assert.strictEqual(t[1].direction, 1);
});

test("Chapter 6: A triangle's edges carry their slopes", () => {
  const p = polygon(point(0, 0), point(10, 0), point(5, 10));
  const t = edge_table(p);
  assert.strictEqual(t.length, 2);
  assert.strictEqual(t[0].x_top, 0);
  assert_number_equal(t[0].slope, 0.5);
  assert.strictEqual(t[0].direction, -1);
  assert.strictEqual(t[1].x_top, 10);
  assert_number_equal(t[1].slope, -0.5);
  assert.strictEqual(t[1].direction, 1);
});

test('Chapter 6: The table is sorted by top, then by x at the top', () => {
  const p = path();
  move_to(p, point(2, 2));
  line_to(p, point(4, 1));
  line_to(p, point(6, 3));
  line_to(p, point(8, 1));
  line_to(p, point(9, 6));
  line_to(p, point(1, 6));
  close(p);
  const t = edge_table(p);
  assert.strictEqual(t.length, 5);
  assert.strictEqual(t[0].y_top, 1);
  assert.strictEqual(t[0].x_top, 4);
  assert.strictEqual(t[1].y_top, 1);
  assert.strictEqual(t[1].x_top, 4);
  assert.strictEqual(t[2].y_top, 1);
  assert.strictEqual(t[2].x_top, 8);
  assert.strictEqual(t[3].y_top, 1);
  assert.strictEqual(t[3].x_top, 8);
  assert.strictEqual(t[4].y_top, 2);
  assert.strictEqual(t[4].x_top, 2);
});

test('Chapter 6: A horizontal edge is dropped, not clamped', () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 5), point(0, 5));
  const t = edge_table(p);
  assert.strictEqual(t.length, 2);
  assert.strictEqual(t[0].x_top, 0);
  assert.strictEqual(t[1].x_top, 10);
});

test('Chapter 6: An edge knows where it crosses a height', () => {
  const p = polygon(point(0, 0), point(10, 0), point(5, 10));
  const t = edge_table(p);
  assert_number_equal(x_at(t[0], 4), 2);
  assert_number_equal(x_at(t[1], 4), 8);
  assert_number_equal(x_at(t[0], 0.5), 0.25);
});

test('Chapter 6: The edge table is the same whichever way the path was drawn', () => {
  const a = polygon(point(0, 0), point(10, 0), point(5, 10));
  const b = polygon(point(0, 0), point(5, 10), point(10, 0));
  const ta = edge_table(a);
  const tb = edge_table(b);
  assert_number_equal(ta[0].x_top, tb[0].x_top);
  assert_number_equal(ta[0].slope, tb[0].slope);
  assert.strictEqual(ta[0].direction, -1);
  assert.strictEqual(tb[0].direction, 1);
});

// --- features/chapter06-spans.feature ---

test('Chapter 6: Crossings on a row, sorted by x', () => {
  const p = polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6));
  const t = edge_table(p);
  const xs = crossings_on_row(t, 3.5);
  assert.strictEqual(xs.length, 2);
  assert_crossing_equal(xs[0], [2, -1]);
  assert_crossing_equal(xs[1], [6, 1]);
  assert.strictEqual(crossings_on_row(t, 1.5).length, 0);
  assert.strictEqual(crossings_on_row(t, 6).length, 0);
  assert.strictEqual(crossings_on_row(t, 2).length, 2);
});

test("Chapter 6: The star's crossings through its middle", () => {
  const t = edge_table(star());
  const xs = crossings_on_row(t, 80.5);
  assert.strictEqual(xs.length, 4);
  assert_crossing_equal(xs[0], [43.6988, -1]);
  assert_crossing_equal(xs[1], [57.7556, -1]);
  assert_crossing_equal(xs[2], [103.2444, 1]);
  assert_crossing_equal(xs[3], [117.3012, 1]);
});

test('Chapter 6: Spans from crossings under each rule', () => {
  const xs = [[1, 1], [3, 1], [5, -1], [7, -1]];
  assert_spans_equal(spans_from_crossings(xs, 'nonzero'), [[1, 7]]);
  assert_spans_equal(spans_from_crossings(xs, 'evenodd'), [[1, 3], [5, 7]]);
  assert_spans_equal(spans_from_crossings([], 'nonzero'), []);
});

test('Chapter 6: The spans of an axis-aligned rectangle are exact', () => {
  const p = polygon(point(1.25, 2), point(4.75, 2), point(4.75, 5), point(1.25, 5));
  assert_spans_equal(spans(p, 'nonzero', 1), []);
  assert_spans_equal(spans(p, 'nonzero', 2), [[1.25, 4.75]]);
  assert_spans_equal(spans(p, 'nonzero', 4), [[1.25, 4.75]]);
  assert_spans_equal(spans(p, 'nonzero', 5), []);
});

test('Chapter 6: A rectangle whose edges sit on sample heights', () => {
  const p = polygon(point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5));
  assert_spans_equal(spans(p, 'nonzero', 1), []);
  assert_spans_equal(spans(p, 'nonzero', 2), [[1.5, 4.5]]);
  assert_spans_equal(spans(p, 'nonzero', 4), [[1.5, 4.5]]);
  assert_spans_equal(spans(p, 'nonzero', 5), []);
});

for (const [row, x0, x1] of [[0, 0.25, 9.75], [1, 0.75, 9.25], [4, 2.25, 7.75], [9, 4.75, 5.25]]) {
  test(`Chapter 6: A triangle's spans narrow by one per row (row ${row})`, () => {
    const p = polygon(point(0, 0), point(10, 0), point(5, 10));
    assert_spans_equal(spans(p, 'nonzero', row), [[x0, x1]]);
  });
}

test("Chapter 6: The row past the triangle's apex has no span", () => {
  const p = polygon(point(0, 0), point(10, 0), point(5, 10));
  assert_spans_equal(spans(p, 'nonzero', 10), []);
});

test('Chapter 6: A flat top is not a span of its own', () => {
  const p = polygon(point(0, 0), point(10, 0), point(10, 5), point(0, 5));
  assert.strictEqual(edge_table(p).length, 2);
  assert_spans_equal(spans(p, 'nonzero', 0), [[0, 10]]);
  assert_spans_equal(spans(p, 'nonzero', 4), [[0, 10]]);
  assert_spans_equal(spans(p, 'nonzero', 5), []);
});

test('Chapter 6: A ring is two spans under even-odd and one under nonzero', () => {
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
  assert_spans_equal(spans(p, 'nonzero', 5), [[0, 10]]);
  assert_spans_equal(spans(p, 'evenodd', 5), [[0, 3], [7, 10]]);
});

test("Chapter 6: The star's spans through its middle", () => {
  const p = star();
  assert_spans_equal(spans(p, 'nonzero', 80), [[43.6988, 117.3012]]);
  assert_spans_equal(spans(p, 'evenodd', 80), [[43.6988, 57.7556], [103.2444, 117.3012]]);
});

test('Chapter 6: fill_span fills the pixels whose centers are in the span', () => {
  const cov = coverage_buffer(8, 3);
  fill_span(cov, 1, 1.25, 4.75);
  assert.strictEqual(coverage_at(cov, 0, 1), 0);
  assert.strictEqual(coverage_at(cov, 1, 1), 1);
  assert.strictEqual(coverage_at(cov, 4, 1), 1);
  assert.strictEqual(coverage_at(cov, 5, 1), 0);
  assert.strictEqual(coverage_at(cov, 2, 0), 0);
  assert.strictEqual(ink(cov), 4);
});

test('Chapter 6: The span is half-open at its right end', () => {
  const cov = coverage_buffer(8, 3);
  fill_span(cov, 1, 1.5, 4.5);
  assert.strictEqual(coverage_at(cov, 1, 1), 1);
  assert.strictEqual(coverage_at(cov, 3, 1), 1);
  assert.strictEqual(coverage_at(cov, 4, 1), 0);
  assert.strictEqual(ink(cov), 3);
});

test('Chapter 6: A span may run off either side of the buffer', () => {
  const a = coverage_buffer(8, 3);
  const b = coverage_buffer(8, 3);
  const c = coverage_buffer(8, 3);
  fill_span(a, 1, -3, 2.5);
  fill_span(b, 1, 6.5, 20);
  fill_span(c, 1, 2.5, 2.5);
  assert.strictEqual(ink(a), 2);
  assert.strictEqual(coverage_at(a, 1, 1), 1);
  assert.strictEqual(ink(b), 2);
  assert.strictEqual(coverage_at(b, 6, 1), 1);
  assert.strictEqual(ink(c), 0);
});

// --- features/chapter06-sweep.feature ---

test('Chapter 6: Two buffers that differ', () => {
  const a = coverage_buffer(3, 3);
  const b = coverage_buffer(3, 3);
  set_coverage(a, 1, 1, 1);
  set_coverage(b, 1, 1, 0.25);
  assert_number_equal(max_coverage_difference(a, b), 0.75);
  assert.strictEqual(max_coverage_difference(a, a), 0);
});

test('Chapter 6: Buffers of different sizes are as different as it gets', () => {
  const a = coverage_buffer(3, 3);
  const b = coverage_buffer(3, 4);
  assert.strictEqual(max_coverage_difference(a, b), 1);
});

test('Chapter 6: A rectangle', () => {
  const p = polygon(point(2, 2), point(6, 2), point(6, 6), point(2, 6));
  const cov = fill_path_aliased(p, 'nonzero', 8, 8);
  assert.strictEqual(coverage_at(cov, 2, 2), 1);
  assert.strictEqual(coverage_at(cov, 5, 5), 1);
  assert.strictEqual(coverage_at(cov, 6, 5), 0);
  assert.strictEqual(coverage_at(cov, 5, 6), 0);
  assert.strictEqual(coverage_at(cov, 1, 2), 0);
  assert.strictEqual(ink(cov), 16);
  assert.strictEqual(max_coverage_difference(cov, rasterize_centers(filled(p, 'nonzero'), 8, 8)), 0);
});

test('Chapter 6: A triangle', () => {
  const p = polygon(point(0, 0), point(10, 0), point(5, 10));
  const cov = fill_path_aliased(p, 'nonzero', 20, 20);
  assert.strictEqual(coverage_at(cov, 0, 0), 1);
  assert.strictEqual(coverage_at(cov, 9, 0), 1);
  assert.strictEqual(coverage_at(cov, 10, 0), 0);
  assert.strictEqual(coverage_at(cov, 4, 8), 1);
  assert.strictEqual(coverage_at(cov, 3, 8), 0);
  assert.strictEqual(coverage_at(cov, 5, 9), 0);
  assert.strictEqual(ink(cov), 50);
  assert.strictEqual(max_coverage_difference(cov, rasterize_centers(filled(p, 'nonzero'), 20, 20)), 0);
});

test('Chapter 6: The same triangle drawn the other way round', () => {
  const a = polygon(point(0, 0), point(10, 0), point(5, 10));
  const b = polygon(point(0, 0), point(5, 10), point(10, 0));
  const ca = fill_path_aliased(a, 'nonzero', 20, 20);
  const cb = fill_path_aliased(b, 'nonzero', 20, 20);
  assert.strictEqual(max_coverage_difference(ca, cb), 0);
});

test('Chapter 6: A polygon circle', () => {
  const p = circle_path(10.3, 9.7, 7, 12);
  const cov = fill_path_aliased(p, 'nonzero', 20, 20);
  assert.strictEqual(ink(cov), 145);
  assert.strictEqual(max_coverage_difference(cov, rasterize_centers(filled(p, 'nonzero'), 20, 20)), 0);
});

test('Chapter 6: The star, both rules, matches chapter 5 pixel for pixel', () => {
  const p = star();
  const nz = fill_path_aliased(p, 'nonzero', 160, 160);
  const eo = fill_path_aliased(p, 'evenodd', 160, 160);
  assert.strictEqual(ink(nz), 5480);
  assert.strictEqual(ink(eo), 3780);
  assert.strictEqual(coverage_at(nz, 80, 80), 1);
  assert.strictEqual(coverage_at(eo, 80, 80), 0);
  assert.strictEqual(max_coverage_difference(nz, rasterize_centers(filled(p, 'nonzero'), 160, 160)), 0);
  assert.strictEqual(max_coverage_difference(eo, rasterize_centers(filled(p, 'evenodd'), 160, 160)), 0);
});

test('Chapter 6: An edge that starts on a sample height is active there, and one that ends there is not', () => {
  const p = polygon(point(1.5, 2.5), point(4.5, 2.5), point(4.5, 5.5), point(1.5, 5.5));
  const cov = fill_path_aliased(p, 'nonzero', 8, 8);
  assert.strictEqual(coverage_at(cov, 2, 1), 0);
  assert.strictEqual(coverage_at(cov, 2, 2), 1);
  assert.strictEqual(coverage_at(cov, 2, 4), 1);
  assert.strictEqual(coverage_at(cov, 2, 5), 0);
  assert.strictEqual(coverage_at(cov, 1, 3), 1);
  assert.strictEqual(coverage_at(cov, 4, 3), 0);
  assert.strictEqual(ink(cov), 9);
  assert.strictEqual(max_coverage_difference(cov, rasterize_centers(filled(p, 'nonzero'), 8, 8)), 0);
});

test('Chapter 6: A polygon larger than the buffer fills it', () => {
  const p = polygon(point(-5, -5), point(30, -5), point(30, 30), point(-5, 30));
  const cov = fill_path_aliased(p, 'nonzero', 8, 8);
  assert.strictEqual(ink(cov), 64);
});

test('Chapter 6: An empty path fills nothing', () => {
  const p = path();
  const cov = fill_path_aliased(p, 'nonzero', 8, 8);
  assert.strictEqual(ink(cov), 0);
});

test('Chapter 6: transform_path takes every point through the matrix and keeps the flags', () => {
  const p = polygon(point(1.25, 2), point(4.75, 2), point(4.75, 5), point(1.25, 5));
  const q = transform_path(p, translation(10, 20));
  assert.strictEqual(subpaths(q).length, 1);
  assert.strictEqual(subpaths(q)[0].closed, true);
  assert(Tuple.equals(subpaths(q)[0].points[0], point(11.25, 22)));
  assert(Tuple.equals(subpaths(q)[0].points[2], point(14.75, 25)));
  assert(Tuple.equals(subpaths(p)[0].points[0], point(1.25, 2)));
});

test('Chapter 6: A transformed star fills where the transform put it', () => {
  const p = transform_path(star(), translation(10, 10).multiply(scaling(0.11, 0.11)).multiply(translation(-80.5, -80.5)));
  const nz = fill_path_aliased(p, 'nonzero', 20, 20);
  const eo = fill_path_aliased(p, 'evenodd', 20, 20);
  assert_bounds_equal(bounds(p), [2.6769, 2.3, 17.3231, 16.2294]);
  assert.strictEqual(ink(nz), 60);
  assert.strictEqual(ink(eo), 40);
  assert.strictEqual(max_coverage_difference(nz, rasterize_centers(filled(p, 'nonzero'), 20, 20)), 0);
});

// --- features/chapter06-plate.feature ---

test('Chapter 6: The unit star', () => {
  const p = unit_star();
  assert.strictEqual(edges(p).length, 5);
  assert(Tuple.equals(subpaths(p)[0].points[0], point(0, -1), 0.0001));
  assert(Tuple.equals(subpaths(p)[0].points[1], point(0.5878, 0.809), 0.0001));
  assert(Tuple.equals(subpaths(p)[0].points[2], point(-0.9511, -0.309), 0.0001));
  assert_bounds_equal(bounds(p), [-0.9511, -1, 0.9511, 0.809]);
});

test('Chapter 6: The spiral', () => {
  const c = spiral();
  const ref = read_file('reference/chapter-06/spiral.ppm');
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 320);
  assert.strictEqual(c.height, 320);
  assert_pixel_approx(p6, 180, 160, [243, 196, 89]);
  assert_pixel_approx(p6, 183, 171, [124, 196, 237]);
  assert_pixel_approx(p6, 179, 183, [237, 137, 149]);
  assert_pixel_approx(p6, 104, 139, [237, 137, 149]);
  assert_pixel_approx(p6, 230, 111, [124, 196, 237]);
  assert_pixel_approx(p6, 32, 137, [124, 196, 237]);
  assert_pixel_approx(p6, 34, 104, [237, 137, 149]);
  assert_pixel_approx(p6, 160, 160, [39, 39, 44]);
  assert_pixel_approx(p6, 5, 5, [39, 39, 44]);
  assert_pixel_approx(p6, 300, 20, [39, 39, 44]);
  assert(max_channel_difference(p6, ref) <= 1);
});

test('Chapter 6: Plate 6', () => {
  const c = plate_06();
  const ref = read_file('reference/chapter-06/plate-06.ppm');
  const p6 = canvas_to_p6(c);
  assert.strictEqual(c.width, 640);
  assert.strictEqual(c.height, 640);
  assert_pixel_approx(p6, 360, 320, [243, 196, 89]);
  assert_pixel_approx(p6, 68, 208, [237, 137, 149]);
  assert_pixel_approx(p6, 320, 320, [39, 39, 44]);
  assert(max_channel_difference(p6, ref) <= 1);
});

// Write Chapter 6 output files
test('Write chapter 6 output files', async () => {
  const c1 = spiral();
  await fs.writeFile('out/spiral.ppm', canvas_to_p6(c1));

  const c2 = plate_06();
  await fs.writeFile('out/plate-06.ppm', canvas_to_p6(c2));
});
