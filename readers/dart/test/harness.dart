// Minimal hand-rolled test harness. No pub packages.
import 'dart:io';
import '../lib/renderer.dart';

int _passCount = 0;
int _failCount = 0;
final List<String> _failures = [];
String _currentFeature = '';

void feature(String name) {
  _currentFeature = name;
}

void test(String name, void Function() body) {
  // Every scenario resets to the book's default global state.
  setLinearBlending(true);
  try {
    body();
    _passCount++;
  } catch (e, st) {
    _failCount++;
    _failures.add('[$_currentFeature] $name\n    $e\n    ${_firstFrame(st)}');
  }
}

String _firstFrame(StackTrace st) {
  final lines = st.toString().split('\n');
  return lines.isNotEmpty ? lines.first : '';
}

class ExpectationFailed implements Exception {
  final String message;
  ExpectationFailed(this.message);
  @override
  String toString() => message;
}

void fail(String message) => throw ExpectationFailed(message);

void expectTrue(bool value, [String? message]) {
  if (!value) fail(message ?? 'expected true, got false');
}

void expectFalse(bool value, [String? message]) {
  if (value) fail(message ?? 'expected false, got true');
}

void expectEqInt(int actual, int expected, [String? message]) {
  if (actual != expected) {
    fail(message ?? 'expected $expected, got $actual');
  }
}

void expectEqStr(String actual, String expected, [String? message]) {
  if (actual != expected) {
    fail(message ?? 'expected "$expected", got "$actual"');
  }
}

void expectClose(double actual, double expected, [double eps = 0.0001]) {
  if (!numsClose(actual, expected, eps)) {
    fail('expected $expected ± $eps, got $actual');
  }
}

void expectNotClose(double actual, double expected, [double eps = 0.0001]) {
  if (numsClose(actual, expected, eps)) {
    fail('expected NOT $expected ± $eps, got $actual');
  }
}

void expectColorClose(Color actual, Color expected, [double eps = 0.0001]) {
  if (!colorsClose(actual, expected, eps)) {
    fail('expected $expected, got $actual');
  }
}

void expectTupClose(Tup actual, Tup expected, [double eps = 0.0001]) {
  if (!tupsClose(actual, expected, eps)) {
    fail('expected $expected, got $actual');
  }
}

void expectMatrixClose(Matrix3 actual, Matrix3 expected, [double eps = 0.0001]) {
  if (!matricesClose(actual, expected, eps)) {
    fail('matrices differ');
  }
}

void expectBoundsClose(Bounds actual, Bounds expected, [double eps = 0.0001]) {
  if (!boundsClose(actual, expected, eps)) {
    fail(
        'expected (${expected.minX}, ${expected.minY}, ${expected.maxX}, ${expected.maxY}), '
        'got (${actual.minX}, ${actual.minY}, ${actual.maxX}, ${actual.maxY})');
  }
}

// RGB triple comparison, with an optional +/-1 tolerance per channel, as the
// scenarios distinguish.
void expectRgb(RgbTriple actual, int r, int g, int b, [int tol = 0]) {
  if ((actual.r - r).abs() > tol || (actual.g - g).abs() > tol || (actual.b - b).abs() > tol) {
    fail('expected ($r, $g, $b) ± $tol, got (${actual.r}, ${actual.g}, ${actual.b})');
  }
}

void expectIntPoints(List<IntPoint> actual, List<IntPoint> expected) {
  if (actual.length != expected.length) {
    fail('expected ${expected.length} points, got ${actual.length}: $actual');
  }
  for (int i = 0; i < actual.length; i++) {
    if (actual[i] != expected[i]) {
      fail('at index $i expected ${expected[i]}, got ${actual[i]}\nfull actual: $actual');
    }
  }
}

void expectSpans(List<Span> actual, List<Span> expected) {
  if (actual.length != expected.length) {
    fail('expected $expected, got $actual');
  }
  for (int i = 0; i < actual.length; i++) {
    if (!numsClose(actual[i].x0, expected[i].x0) || !numsClose(actual[i].x1, expected[i].x1)) {
      fail('expected $expected, got $actual');
    }
  }
}

void expectCrossings(List<Crossing> actual, List<Crossing> expected) {
  if (actual.length != expected.length) {
    fail('expected $expected, got $actual');
  }
  for (int i = 0; i < actual.length; i++) {
    if (!numsClose(actual[i].x, expected[i].x) || actual[i].direction != expected[i].direction) {
      fail('expected $expected, got $actual');
    }
  }
}

void summarize() {
  print('');
  print('=== $_passCount passed, $_failCount failed ===');
  if (_failures.isNotEmpty) {
    print('');
    print('Failures:');
    for (final f in _failures) {
      print('- $f');
    }
  }
  if (_failCount > 0) {
    exitCode = 1;
  }
}
