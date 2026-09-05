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
  const blended = mix(current, color, weight);
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
