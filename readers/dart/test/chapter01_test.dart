import '../lib/renderer.dart';
import 'harness.dart';

void runChapter01Tests() {
  // features/chapter01-equality.feature
  feature('chapter01-equality');

  test('Two numbers that differ by less than the tolerance are equal', () {
    expectClose(1.0, 1.0000001, 0.00001);
  });

  test('Two numbers that differ by more than the tolerance are not', () {
    expectNotClose(1.0, 1.001, 0.00001);
  });

  test('The default tolerance is 0.0001', () {
    expectClose(0.1 + 0.2, 0.3);
    expectClose(1.0, 1.00009);
    expectNotClose(1.0, 1.0002);
  });

  // features/chapter01-colors.feature
  feature('chapter01-colors');

  test('A color is a red, green, blue tuple', () {
    final c = color(-0.5, 0.4, 1.7);
    expectClose(c.red, -0.5);
    expectClose(c.green, 0.4);
    expectClose(c.blue, 1.7);
  });

  test('Adding colors', () {
    final c1 = color(0.9, 0.6, 0.75);
    final c2 = color(0.7, 0.1, 0.25);
    expectColorClose(c1 + c2, color(1.6, 0.7, 1.0));
  });

  test('Subtracting colors', () {
    final c1 = color(0.9, 0.6, 0.75);
    final c2 = color(0.7, 0.1, 0.25);
    expectColorClose(c1 - c2, color(0.2, 0.5, 0.5));
  });

  test('Scaling a color by a number', () {
    final c = color(0.2, 0.3, 0.4);
    expectColorClose(c * 2, color(0.4, 0.6, 0.8));
    expectColorClose(c * 0.5, color(0.1, 0.15, 0.2));
  });

  test('Multiplying two colors filters one through the other', () {
    final c1 = color(1, 0.2, 0.4);
    final c2 = color(0.9, 1, 0.1);
    expectColorClose(c1 * c2, color(0.9, 0.2, 0.04));
  });

  test('Colors compare component by component, with the usual tolerance', () {
    final c1 = color(0.1, 0.5, 1);
    final c2 = color(0.2, 0, 0);
    expectColorClose(c1 + c2, color(0.3, 0.5, 1));
    expectFalse(colorsClose(c1 + c2, color(0.3, 0.5, 1.001)));
  });

  // features/chapter01-canvas.feature
  feature('chapter01-canvas');

  test('A new canvas is black', () {
    final c = canvas(10, 20);
    expectEqInt(c.width, 10);
    expectEqInt(c.height, 20);
    for (int y = 0; y < c.height; y++) {
      for (int x = 0; x < c.width; x++) {
        expectColorClose(pixel_at(c, x, y), color(0, 0, 0));
      }
    }
  });

  test('Writing a pixel', () {
    final c = canvas(10, 20);
    final red = color(1, 0, 0);
    write_pixel(c, 2, 3, red);
    expectColorClose(pixel_at(c, 2, 3), red);
  });

  test('x is the column and y is the row', () {
    final c = canvas(10, 20);
    write_pixel(c, 2, 3, color(1, 0, 0));
    expectColorClose(pixel_at(c, 3, 2), color(0, 0, 0));
    expectColorClose(pixel_at(c, 2, 3), color(1, 0, 0));
  });

  test('Writing outside the canvas is ignored', () {
    final c = canvas(10, 20);
    write_pixel(c, -1, 5, color(1, 0, 0));
    write_pixel(c, 10, 5, color(1, 0, 0));
    write_pixel(c, 5, -1, color(1, 0, 0));
    write_pixel(c, 5, 20, color(1, 0, 0));
    for (int y = 0; y < c.height; y++) {
      for (int x = 0; x < c.width; x++) {
        expectColorClose(pixel_at(c, x, y), color(0, 0, 0));
      }
    }
  });

  test('A pixel can be written more than once', () {
    final c = canvas(10, 20);
    write_pixel(c, 2, 3, color(1, 0, 0));
    write_pixel(c, 2, 3, color(0, 1, 0));
    expectColorClose(pixel_at(c, 2, 3), color(0, 1, 0));
  });

  test('Filling a canvas', () {
    final c = canvas(10, 20);
    fill(c, color(0.1, 0.2, 0.3));
    for (int y = 0; y < c.height; y++) {
      for (int x = 0; x < c.width; x++) {
        expectColorClose(pixel_at(c, x, y), color(0.1, 0.2, 0.3));
      }
    }
  });

  // features/chapter01-srgb.feature
  feature('chapter01-srgb');

  final encodeExamples = <List<double>>[
    [0.0, 0.0],
    [0.0025, 0.0323],
    [0.01, 0.0999],
    [0.1, 0.3492],
    [0.216, 0.5021],
    [0.25, 0.5371],
    [0.5, 0.7354],
    [0.75, 0.8808],
    [1.0, 1.0],
  ];
  for (final row in encodeExamples) {
    test('Encoding light into a file value: light=${row[0]}', () {
      expectClose(encode(row[0]), row[1]);
    });
  }

  final decodeExamples = <List<double>>[
    [0.0, 0.0],
    [0.04, 0.0031],
    [0.05, 0.0039],
    [0.1, 0.0100],
    [0.5, 0.2140],
    [0.75, 0.5225],
    [1.0, 1.0],
  ];
  for (final row in decodeExamples) {
    test('Decoding a file value into light: value=${row[0]}', () {
      expectClose(decode(row[0]), row[1]);
    });
  }

  test('Decode undoes encode', () {
    expectClose(decode(encode(0.2)), 0.2, 0.000000001);
  });

  test('Encode undoes decode', () {
    expectClose(encode(decode(0.7)), 0.7, 0.000000001);
  });

  test('The half gray that isn\'t 128', () {
    expectEqInt((encode(0.5) * 255).round(), 188);
  });

  test('What 128 actually is', () {
    expectClose(decode(128 / 255), 0.2159);
  });

  // features/chapter01-ppm.feature
  feature('chapter01-ppm');

  test('The PPM header', () {
    final c = canvas(5, 3);
    final ppm = canvas_to_ppm(c);
    expectEqualLines(ppm_lines(ppm, 1, 3), ['P3', '5 3', '255']);
  });

  test('Pixel values are encoded, not scaled', () {
    final c = canvas(3, 1);
    write_pixel(c, 0, 0, color(1, 0, 0));
    write_pixel(c, 1, 0, color(0, 0.5, 0));
    write_pixel(c, 2, 0, color(0, 0, 0.216));
    final ppm = canvas_to_ppm(c);
    expectEqStr(ppm_lines(ppm, 4, 4)[0], '255 0 0 0 188 0 0 0 128');
  });

  test('Colors out of range are clamped, not wrapped', () {
    final c = canvas(2, 1);
    write_pixel(c, 0, 0, color(1.5, 0, -0.5));
    final ppm = canvas_to_ppm(c);
    expectEqStr(ppm_lines(ppm, 4, 4)[0], '255 0 0 0 0 0');
  });

  test('Every row starts a new line, and no line exceeds 70 characters', () {
    final c = canvas(10, 2);
    fill(c, color(1, 0.8, 0.6));
    final ppm = canvas_to_ppm(c);
    expectEqualLines(ppm_lines(ppm, 4, 7), [
      '255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231',
      '203 255 231 203 255 231 203 255 231 203 255 231 203',
      '255 231 203 255 231 203 255 231 203 255 231 203 255 231 203 255 231',
      '203 255 231 203 255 231 203 255 231 203 255 231 203',
    ]);
    for (final line in ppm.text.split('\n')) {
      expectTrue(line.length <= 70, 'line too long: "$line" (${line.length})');
    }
  });

  test('A line of exactly 70 characters is allowed', () {
    final c = canvas(8, 1);
    fill(c, color(1, 0.1, 0));
    write_pixel(c, 7, 0, color(1, 1, 1));
    final ppm = canvas_to_ppm(c);
    expectEqualLines(ppm_lines(ppm, 4, 5), [
      '255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 89 0 255 255',
      '255',
    ]);
  });

  test('The file ends with a newline', () {
    final c = canvas(5, 3);
    final ppm = canvas_to_ppm(c);
    expectTrue(ppm_ends_with_newline(ppm));
  });

  test('Reading a pixel back out of the text', () {
    final c = canvas(3, 2);
    write_pixel(c, 2, 1, color(0, 0.5, 1));
    final ppm = canvas_to_ppm(c);
    expectRgb(ppm_pixel(ppm, 2, 1), 0, 188, 255);
    expectRgb(ppm_pixel(ppm, 1, 1), 0, 0, 0);
  });

  test('Counting the distinct values in a file', () {
    final c = canvas(3, 1);
    write_pixel(c, 0, 0, color(1, 0, 0));
    write_pixel(c, 1, 0, color(0, 0.5, 0));
    write_pixel(c, 2, 0, color(0, 0, 0.216));
    final ppm = canvas_to_ppm(c);
    expectEqInt(distinct_values(ppm), 4);
  });

  test('Comparing two files', () {
    final c1 = canvas(2, 1);
    final c2 = canvas(2, 1);
    write_pixel(c2, 0, 0, color(0.5, 0, 0));
    final ppm1 = canvas_to_ppm(c1);
    final ppm2 = canvas_to_ppm(c2);
    expectEqInt(max_channel_difference(ppm1, ppm1), 0);
    expectEqInt(max_channel_difference(ppm1, ppm2), 188);
  });

  test('Files of different sizes are as different as it gets', () {
    final c1 = canvas(5, 3);
    final c2 = canvas(3, 5);
    final ppm1 = canvas_to_ppm(c1);
    final ppm2 = canvas_to_ppm(c2);
    expectEqInt(max_channel_difference(ppm1, ppm2), 255);
  });

  test('The same width with a different height is still a different size', () {
    final c1 = canvas(5, 3);
    final c2 = canvas(5, 4);
    final ppm1 = canvas_to_ppm(c1);
    final ppm2 = canvas_to_ppm(c2);
    expectEqInt(max_channel_difference(ppm1, ppm2), 255);
  });

  // features/chapter01-gray-match.feature
  feature('chapter01-gray-match');

  test('The gray match', () {
    final c = gray_match();
    expectEqInt(c.width, 300);
    expectEqInt(c.height, 100);
    expectColorClose(pixel_at(c, 0, 0), color(1, 1, 1));
    expectColorClose(pixel_at(c, 1, 0), color(0, 0, 0));
    expectColorClose(pixel_at(c, 0, 1), color(0, 0, 0));
    expectColorClose(pixel_at(c, 1, 1), color(1, 1, 1));
    expectColorClose(pixel_at(c, 150, 50), color(0.2159, 0.2159, 0.2159));
    expectColorClose(pixel_at(c, 250, 50), color(0.5, 0.5, 0.5));
    int whiteCount = 0;
    for (int y = 0; y < c.height; y++) {
      for (int x = 0; x < c.width; x++) {
        if (colorsClose(pixel_at(c, x, y), color(1, 1, 1))) whiteCount++;
      }
    }
    expectEqInt(whiteCount, 5000);
  });

  test('The gray match, as a file', () {
    final c = gray_match();
    final ref = read_file('reference/chapter-01/gray-match.ppm');
    final ppm = canvas_to_ppm(c);
    expectRgb(ppm_pixel(ppm, 0, 0), 255, 255, 255, 1);
    expectRgb(ppm_pixel(ppm, 1, 0), 0, 0, 0, 1);
    expectRgb(ppm_pixel(ppm, 150, 50), 128, 128, 128, 1);
    expectRgb(ppm_pixel(ppm, 250, 50), 188, 188, 188, 1);
    expectTrue(max_channel_difference(ppm, ref) <= 1);
  });

  test('One pixel in four', () {
    final c = quarter_match();
    final ref = read_file('reference/chapter-01/quarter-match.ppm');
    final ppm = canvas_to_ppm(c);
    expectEqInt(c.width, 200);
    expectEqInt(c.height, 100);
    expectColorClose(pixel_at(c, 0, 0), color(1, 1, 1));
    expectColorClose(pixel_at(c, 1, 0), color(0, 0, 0));
    expectColorClose(pixel_at(c, 2, 2), color(1, 1, 1));
    expectColorClose(pixel_at(c, 3, 1), color(1, 1, 1));
    expectColorClose(pixel_at(c, 150, 50), color(0.25, 0.25, 0.25));
    int whiteCount = 0;
    for (int y = 0; y < c.height; y++) {
      for (int x = 0; x < c.width; x++) {
        if (colorsClose(pixel_at(c, x, y), color(1, 1, 1))) whiteCount++;
      }
    }
    expectEqInt(whiteCount, 2500);
    expectRgb(ppm_pixel(ppm, 150, 50), 137, 137, 137, 1);
    expectTrue(max_channel_difference(ppm, ref) <= 1);
  });

  // features/chapter01-mix.feature
  feature('chapter01-mix');

  test('Halfway between black and white', () {
    final a = color(0, 0, 0);
    final b = color(1, 1, 1);
    expectColorClose(mix(a, b, 0.5), color(0.5, 0.5, 0.5));
  });

  test('The ends of a mix are its inputs', () {
    final a = color(0.7, 0, 0);
    final b = color(0, 0.3, 0.02);
    expectColorClose(mix(a, b, 0), a);
    expectColorClose(mix(a, b, 1), b);
  });

  test('Red to green, in light', () {
    final a = color(0.7, 0, 0);
    final b = color(0, 0.3, 0.02);
    expectColorClose(mix(a, b, 0.5), color(0.35, 0.15, 0.01));
    expectColorClose(mix(a, b, 0.25), color(0.525, 0.075, 0.005));
  });

  test('Halfway between black and white, the way browsers do it', () {
    setLinearBlending(false);
    final a = color(0, 0, 0);
    final b = color(1, 1, 1);
    expectColorClose(mix(a, b, 0.5), color(0.2140, 0.2140, 0.2140));
  });

  test('Red to green, the way browsers do it', () {
    setLinearBlending(false);
    final a = color(0.7, 0, 0);
    final b = color(0, 0.3, 0.02);
    expectColorClose(mix(a, b, 0.5), color(0.1527, 0.0693, 0.0067));
  });

  test('The light\'s way never clamps', () {
    final a = color(1.5, 0.5, -0.2);
    final b = color(0, 0, 0);
    expectColorClose(mix(a, b, 0), color(1.5, 0.5, -0.2));
    expectColorClose(mix(a, b, 0.5), color(0.75, 0.25, -0.1));
  });

  test('The switch can be passed instead of set', () {
    final a = color(0, 0, 0);
    final b = color(1, 1, 1);
    expectColorClose(mix(a, b, 0.5, true), color(0.5, 0.5, 0.5));
    expectColorClose(mix(a, b, 0.5, false), color(0.2140, 0.2140, 0.2140));
    expectTrue(isLinearBlending());
  });

  test('The browser\'s way clamps each end before encoding it', () {
    setLinearBlending(false);
    final a = color(1.5, 0.5, -0.2);
    final b = color(0, 0, 0);
    expectColorClose(mix(a, b, 0), color(1, 0.5, 0));
    expectColorClose(mix(a, b, 0.5), color(0.2140, 0.1113, 0.0000));
  });

  test('The ends of a mix are its inputs either way, when they\'re in range', () {
    setLinearBlending(false);
    final a = color(0.7, 0, 0);
    final b = color(0, 0.3, 0.02);
    expectColorClose(mix(a, b, 0), a);
    expectColorClose(mix(a, b, 1), b);
  });

  // features/chapter01-limits.feature
  feature('chapter01-limits');

  test('A 256-step ramp', () {
    final c = ramp();
    expectEqInt(c.width, 256);
    expectEqInt(c.height, 32);
    expectColorClose(pixel_at(c, 0, 0), color(0, 0, 0));
    expectColorClose(pixel_at(c, 128, 0), color(0.5020, 0.5020, 0.5020));
    expectColorClose(pixel_at(c, 255, 31), color(1, 1, 1));
  });

  test('Encoding stretches the dark end and squeezes the bright end', () {
    final c = ramp();
    final ref = read_file('reference/chapter-01/ramp.ppm');
    final ppm = canvas_to_ppm(c);
    expectEqStr(ppm_lines(ppm, 4, 4)[0],
        '0 0 0 13 13 13 22 22 22 28 28 28 34 34 34 38 38 38 42 42 42 46 46 46');
    expectRgb(ppm_pixel(ppm, 75, 0), 148, 148, 148, 1);
    expectRgb(ppm_pixel(ppm, 76, 0), 148, 148, 148, 1);
    expectRgb(ppm_pixel(ppm, 254, 0), 255, 255, 255, 1);
    expectEqInt(distinct_values(ppm), 183);
    expectTrue(max_channel_difference(ppm, ref) <= 1);
  });

  test('Clamping changes the color, not only the brightness', () {
    final c = clamp_pair();
    final ref = read_file('reference/chapter-01/clamp-pair.ppm');
    final ppm = canvas_to_ppm(c);
    expectEqInt(c.width, 200);
    expectEqInt(c.height, 100);
    expectColorClose(pixel_at(c, 50, 50), color(2, 0.5, 0.5));
    expectColorClose(pixel_at(c, 150, 50), color(1, 0.25, 0.25));
    expectRgb(ppm_pixel(ppm, 50, 50), 255, 188, 188, 1);
    expectRgb(ppm_pixel(ppm, 150, 50), 255, 137, 137, 1);
    expectTrue(max_channel_difference(ppm, ref) <= 1);
  });

  // features/chapter01-plate.feature
  feature('chapter01-plate');

  test('Plate 1', () {
    final c = plate_01();
    final ref = read_file('reference/chapter-01/plate-01.ppm');
    final ppm = canvas_to_ppm(c);
    expectEqInt(c.width, 400);
    expectEqInt(c.height, 180);
    expectRgb(ppm_pixel(ppm, 0, 20), 0, 0, 0, 1);
    expectRgb(ppm_pixel(ppm, 399, 20), 255, 255, 255, 1);
    expectRgb(ppm_pixel(ppm, 200, 20), 128, 128, 128, 1);
    expectRgb(ppm_pixel(ppm, 200, 65), 188, 188, 188, 1);
    expectRgb(ppm_pixel(ppm, 200, 42), 0, 0, 0, 1);
    expectRgb(ppm_pixel(ppm, 0, 110), 218, 0, 0, 1);
    expectRgb(ppm_pixel(ppm, 399, 110), 0, 149, 39, 1);
    expectRgb(ppm_pixel(ppm, 200, 110), 109, 75, 19, 1);
    expectRgb(ppm_pixel(ppm, 200, 155), 160, 108, 26, 1);
    expectRgb(ppm_pixel(ppm, 200, 87), 0, 0, 0, 1);
    expectRgb(ppm_pixel(ppm, 200, 132), 0, 0, 0, 1);
    expectRgb(ppm_pixel(ppm, 200, 177), 0, 0, 0, 1);
    expectTrue(max_channel_difference(ppm, ref) <= 1);
  });
}

void expectEqualLines(List<String> actual, List<String> expected) {
  if (actual.length != expected.length) {
    fail('expected ${expected.length} lines, got ${actual.length}');
  }
  for (int i = 0; i < actual.length; i++) {
    expectEqStr(actual[i], expected[i]);
  }
}
