// The 2D Renderer Challenge -- reader implementation in Dart.
// Chapters 1 through 6. Names follow the book's API names as closely as
// Dart's conventions allow (snake_case top-level functions to match the
// scenarios; PascalCase classes as Dart requires).
//
// Dart SDK 2.18: no records, no patterns, no class modifiers. Pair-like
// values use small dedicated classes instead of tuples.

import 'dart:io';
import 'dart:math' as math;

// ---------------------------------------------------------------------
// Chapter 1: color, canvas, sRGB, mix, PPM
// ---------------------------------------------------------------------

class Color {
  final double red, green, blue;
  const Color(this.red, this.green, this.blue);

  Color operator +(Color o) => Color(red + o.red, green + o.green, blue + o.blue);
  Color operator -(Color o) => Color(red - o.red, green - o.green, blue - o.blue);
  Color operator -() => Color(-red, -green, -blue);

  // Overloaded: c * 2 (scale) or c1 * c2 (Hadamard product / "multiply").
  Color operator *(Object other) {
    if (other is Color) return multiply(other);
    return scale((other as num).toDouble());
  }

  Color scale(double s) => Color(red * s, green * s, blue * s);
  Color multiply(Color o) => Color(red * o.red, green * o.green, blue * o.blue);

  @override
  String toString() => 'color($red, $green, $blue)';
}

Color color(double r, double g, double b) => Color(r, g, b);

const Color black = Color(0, 0, 0);

class Canvas {
  final int width;
  final int height;
  final List<Color> _pixels;

  Canvas(this.width, this.height)
      : _pixels = List<Color>.filled(width * height, black);

  Color pixelAt(int x, int y) => _pixels[y * width + x];

  void writePixel(int x, int y, Color c) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    _pixels[y * width + x] = c;
  }

  void fillAll(Color c) {
    for (int i = 0; i < _pixels.length; i++) {
      _pixels[i] = c;
    }
  }

  Canvas copy() {
    final c = Canvas(width, height);
    for (int i = 0; i < _pixels.length; i++) {
      c._pixels[i] = _pixels[i];
    }
    return c;
  }
}

Canvas canvas(int w, int h) => Canvas(w, h);
void write_pixel(Canvas c, int x, int y, Color col) => c.writePixel(x, y, col);
Color pixel_at(Canvas c, int x, int y) => c.pixelAt(x, y);
void fill(Canvas c, Color col) => c.fillAll(col);

// sRGB transfer functions.
double decode(double v) {
  if (v <= 0.04045) return v / 12.92;
  return math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double encode(double l) {
  if (l <= 0.0031308) return l * 12.92;
  return 1.055 * math.pow(l, 1 / 2.4).toDouble() - 0.055;
}

Color decodeColor(Color c) => Color(decode(c.red), decode(c.green), decode(c.blue));
Color encodeColor(Color c) => Color(encode(c.red), encode(c.green), encode(c.blue));

double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

int toFileValue(double lightChannel) {
  final clamped = clamp01(lightChannel);
  final encoded = encode(clamped);
  return (encoded * 255).round();
}

// Global linear-blending switch. Defaults on.
bool _linearBlending = true;
void setLinearBlending(bool v) {
  _linearBlending = v;
}

bool isLinearBlending() => _linearBlending;

Color mix(Color a, Color b, double t, [bool? linear]) {
  final useLinear = linear ?? _linearBlending;
  if (useLinear) {
    return a + (b - a).scale(t);
  }
  final aPrime = Color(clamp01(a.red), clamp01(a.green), clamp01(a.blue));
  final bPrime = Color(clamp01(b.red), clamp01(b.green), clamp01(b.blue));
  final ea = encodeColor(aPrime);
  final eb = encodeColor(bPrime);
  final blended = ea + (eb - ea).scale(t);
  return decodeColor(blended);
}

// PPM output. Both P3 and P6 are represented as raw bytes so the readers
// (ppm_pixel, distinct_values, max_channel_difference) work uniformly on
// both, per chapter 2.
class Ppm {
  final List<int> bytes;
  Ppm(this.bytes);

  String get text => String.fromCharCodes(bytes);
}

String _channelsForRow(Canvas c, int y) {
  final buf = StringBuffer();
  String line = '';
  bool firstOnLine = true;
  void emit(String value) {
    if (firstOnLine) {
      line = value;
      firstOnLine = false;
    } else if (line.length + 1 + value.length > 70) {
      buf.write(line);
      buf.write('\n');
      line = value;
    } else {
      line = '$line $value';
    }
  }

  for (int x = 0; x < c.width; x++) {
    final col = c.pixelAt(x, y);
    emit(toFileValue(col.red).toString());
    emit(toFileValue(col.green).toString());
    emit(toFileValue(col.blue).toString());
  }
  buf.write(line);
  buf.write('\n');
  return buf.toString();
}

Ppm canvas_to_ppm(Canvas c) {
  final buf = StringBuffer();
  buf.write('P3\n');
  buf.write('${c.width} ${c.height}\n');
  buf.write('255\n');
  for (int y = 0; y < c.height; y++) {
    buf.write(_channelsForRow(c, y));
  }
  return Ppm(buf.toString().codeUnits);
}

Ppm canvas_to_p6(Canvas c) {
  final bytes = <int>[];
  bytes.addAll('P6\n${c.width} ${c.height}\n255\n'.codeUnits);
  for (int y = 0; y < c.height; y++) {
    for (int x = 0; x < c.width; x++) {
      final col = c.pixelAt(x, y);
      bytes.add(toFileValue(col.red));
      bytes.add(toFileValue(col.green));
      bytes.add(toFileValue(col.blue));
    }
  }
  return Ppm(bytes);
}

Ppm read_file(String path) => Ppm(File(path).readAsBytesSync());

// Header parsing shared by ppm_pixel, distinct_values, max_channel_difference.
// Returns [width, height, pixelDataStart] by reading three whitespace
// separated tokens after the magic bytes, then skipping exactly one
// whitespace byte.
class _PpmHeader {
  final int width;
  final int height;
  final int dataStart;
  _PpmHeader(this.width, this.height, this.dataStart);
}

bool _isWs(int b) => b == 32 || b == 10 || b == 13 || b == 9;

_PpmHeader _parseHeader(Ppm p) {
  final b = p.bytes;
  // b[0], b[1] are the magic 'P3' or 'P6'; skip them, then read three
  // whitespace-delimited tokens (width, height, maxval).
  int i = 2;
  final tokens = <int>[];
  for (int t = 0; t < 3; t++) {
    while (i < b.length && _isWs(b[i])) {
      i++;
    }
    int start = i;
    while (i < b.length && !_isWs(b[i])) {
      i++;
    }
    tokens.add(int.parse(String.fromCharCodes(b.sublist(start, i))));
  }
  // Skip exactly one whitespace byte after the last header token.
  i++;
  return _PpmHeader(tokens[0], tokens[1], i);
}

class _ParsedPixels {
  final int width;
  final int height;
  final List<int> values; // flat list, 3 per pixel
  _ParsedPixels(this.width, this.height, this.values);
}

_ParsedPixels _parsePixels(Ppm p) {
  final header = _parseHeader(p);
  final bytes = p.bytes;
  final isP6 = bytes[0] == 80 && bytes[1] == 54; // 'P','6'
  final values = <int>[];
  if (isP6) {
    for (int i = header.dataStart; i < bytes.length; i++) {
      values.add(bytes[i]);
    }
  } else {
    // P3: re-split remaining text on whitespace.
    final rest = String.fromCharCodes(bytes.sublist(header.dataStart));
    for (final tok in rest.split(RegExp(r'\s+'))) {
      if (tok.isEmpty) continue;
      values.add(int.parse(tok));
    }
  }
  return _ParsedPixels(header.width, header.height, values);
}

class RgbTriple {
  final int r, g, b;
  RgbTriple(this.r, this.g, this.b);
}

RgbTriple ppm_pixel(Ppm p, int x, int y) {
  final parsed = _parsePixels(p);
  final idx = (y * parsed.width + x) * 3;
  return RgbTriple(parsed.values[idx], parsed.values[idx + 1], parsed.values[idx + 2]);
}

int distinct_values(Ppm p) {
  final parsed = _parsePixels(p);
  final seen = <int>{};
  for (final v in parsed.values) {
    seen.add(v);
  }
  return seen.length;
}

int max_channel_difference(Ppm a, Ppm b) {
  final ha = _parseHeader(a);
  final hb = _parseHeader(b);
  if (ha.width != hb.width || ha.height != hb.height) return 255;
  final pa = _parsePixels(a);
  final pb = _parsePixels(b);
  int maxDiff = 0;
  for (int i = 0; i < pa.values.length; i++) {
    final d = (pa.values[i] - pb.values[i]).abs();
    if (d > maxDiff) maxDiff = d;
  }
  return maxDiff;
}

int length_bytes(Ppm p) => p.bytes.length;
int byte_at(Ppm p, int oneIndexed) => p.bytes[oneIndexed - 1];
bool ppm_begins_with(Ppm p, String prefix) {
  final pref = prefix.codeUnits;
  if (p.bytes.length < pref.length) return false;
  for (int i = 0; i < pref.length; i++) {
    if (p.bytes[i] != pref[i]) return false;
  }
  return true;
}

bool ppm_ends_with_newline(Ppm p) => p.bytes.isNotEmpty && p.bytes.last == 10;

List<String> ppm_lines(Ppm p, int startLine, int endLine) {
  final all = p.text.split('\n');
  // startLine/endLine are 1-indexed, inclusive.
  return all.sublist(startLine - 1, endLine);
}

// ---------------------------------------------------------------------
// Chapter 1 renders
// ---------------------------------------------------------------------

Canvas gray_match() {
  final c = canvas(300, 100);
  for (int y = 0; y < 100; y++) {
    for (int x = 0; x < 100; x++) {
      final white = (x + y) % 2 == 0;
      write_pixel(c, x, y, white ? color(1, 1, 1) : color(0, 0, 0));
    }
  }
  final g = decode(128.0 / 255.0);
  for (int y = 0; y < 100; y++) {
    for (int x = 100; x < 200; x++) {
      write_pixel(c, x, y, color(g, g, g));
    }
  }
  for (int y = 0; y < 100; y++) {
    for (int x = 200; x < 300; x++) {
      write_pixel(c, x, y, color(0.5, 0.5, 0.5));
    }
  }
  return c;
}

Canvas quarter_match() {
  final c = canvas(200, 100);
  for (int y = 0; y < 100; y++) {
    for (int x = 0; x < 100; x++) {
      final white = (x + y) % 4 == 0;
      write_pixel(c, x, y, white ? color(1, 1, 1) : color(0, 0, 0));
    }
  }
  for (int y = 0; y < 100; y++) {
    for (int x = 100; x < 200; x++) {
      write_pixel(c, x, y, color(0.25, 0.25, 0.25));
    }
  }
  return c;
}

Canvas ramp() {
  final c = canvas(256, 32);
  for (int x = 0; x < 256; x++) {
    final g = x / 255.0;
    for (int y = 0; y < 32; y++) {
      write_pixel(c, x, y, color(g, g, g));
    }
  }
  return c;
}

Canvas clamp_pair() {
  final c = canvas(200, 100);
  for (int y = 0; y < 100; y++) {
    for (int x = 0; x < 100; x++) {
      write_pixel(c, x, y, color(2, 0.5, 0.5));
    }
    for (int x = 100; x < 200; x++) {
      write_pixel(c, x, y, color(1, 0.25, 0.25));
    }
  }
  return c;
}

void ramp_pair(Canvas c, int top, Color a, Color b) {
  for (int x = 0; x < 400; x++) {
    final t = x / 399.0;
    final naive = mix(a, b, t, false);
    final light = mix(a, b, t, true);
    for (int y = top; y <= top + 39; y++) {
      write_pixel(c, x, y, naive);
    }
    for (int y = top + 45; y <= top + 84; y++) {
      write_pixel(c, x, y, light);
    }
  }
}

Canvas plate_01() {
  final c = canvas(400, 180);
  ramp_pair(c, 0, color(0, 0, 0), color(1, 1, 1));
  ramp_pair(c, 90, color(0.7, 0, 0), color(0, 0.3, 0.02));
  return c;
}

// ---------------------------------------------------------------------
// Chapter 2: shapes, magnify, coverage buffer, paint_through
// ---------------------------------------------------------------------

abstract class Shape {
  bool inside(double x, double y);
}

class Circle implements Shape {
  final double cx, cy, r;
  Circle(this.cx, this.cy, this.r);
  @override
  bool inside(double x, double y) {
    final dx = x - cx, dy = y - cy;
    return dx * dx + dy * dy <= r * r;
  }
}

Circle circle(double cx, double cy, double r) => Circle(cx, cy, r);

class RectangleShape implements Shape {
  final double x0, y0, x1, y1;
  RectangleShape(this.x0, this.y0, this.x1, this.y1);
  @override
  bool inside(double x, double y) => x >= x0 && x <= x1 && y >= y0 && y <= y1;
}

RectangleShape rectangle(double x0, double y0, double x1, double y1) =>
    RectangleShape(x0, y0, x1, y1);

class HalfPlane implements Shape {
  final double px, py, nx, ny;
  HalfPlane(this.px, this.py, this.nx, this.ny);
  @override
  bool inside(double x, double y) {
    final dx = x - px, dy = y - py;
    return dx * nx + dy * ny >= 0;
  }
}

HalfPlane half_plane(double px, double py, double nx, double ny) =>
    HalfPlane(px, py, nx, ny);

bool inside(Shape s, double x, double y) => s.inside(x, y);

Canvas magnify(Canvas c, int k) {
  final m = canvas(c.width * k, c.height * k);
  for (int y = 0; y < c.height; y++) {
    for (int x = 0; x < c.width; x++) {
      final col = c.pixelAt(x, y);
      for (int dy = 0; dy < k; dy++) {
        for (int dx = 0; dx < k; dx++) {
          write_pixel(m, x * k + dx, y * k + dy, col);
        }
      }
    }
  }
  return m;
}

class CoverageBuffer {
  final int width;
  final int height;
  final List<double> _data;
  CoverageBuffer(this.width, this.height) : _data = List<double>.filled(width * height, 0.0);

  double at(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return 0.0;
    return _data[y * width + x];
  }

  void set(int x, int y, double v) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    _data[y * width + x] = v;
  }

  double ink() {
    double total = 0.0;
    for (final v in _data) {
      total += v;
    }
    return total;
  }
}

CoverageBuffer coverage_buffer(int w, int h) => CoverageBuffer(w, h);
double coverage_at(CoverageBuffer cov, int x, int y) => cov.at(x, y);
void set_coverage(CoverageBuffer cov, int x, int y, double v) => cov.set(x, y, v);
double ink(CoverageBuffer cov) => cov.ink();

num center_inside(Shape s, int x, int y) => s.inside(x + 0.5, y + 0.5) ? 1 : 0;

const int _gridN = 8;

num coverage(Shape s, int x, int y) {
  int count = 0;
  for (int j = 0; j < _gridN; j++) {
    for (int i = 0; i < _gridN; i++) {
      final sx = x + (i + 0.5) / _gridN;
      final sy = y + (j + 0.5) / _gridN;
      if (s.inside(sx, sy)) count++;
    }
  }
  return count / (_gridN * _gridN);
}

CoverageBuffer rasterize_centers(Shape s, int w, int h) {
  final cov = coverage_buffer(w, h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      set_coverage(cov, x, y, center_inside(s, x, y).toDouble());
    }
  }
  return cov;
}

CoverageBuffer rasterize(Shape s, int w, int h) {
  final cov = coverage_buffer(w, h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      set_coverage(cov, x, y, coverage(s, x, y).toDouble());
    }
  }
  return cov;
}

void paint_through(Canvas c, CoverageBuffer cov, Color col) {
  for (int y = 0; y < c.height; y++) {
    for (int x = 0; x < c.width; x++) {
      final cvg = cov.at(x, y);
      if (cvg == 0.0) continue;
      final current = c.pixelAt(x, y);
      c.writePixel(x, y, mix(current, col, cvg, true));
    }
  }
}

Canvas disc_centers() {
  final c = canvas(40, 40);
  fill(c, color(0.02, 0.02, 0.025));
  final cov = rasterize_centers(circle(20, 20, 16), 40, 40);
  paint_through(c, cov, color(0.9, 0.55, 0.1));
  return magnify(c, 8);
}

Canvas disc_coverage() {
  final c = canvas(40, 40);
  fill(c, color(0.02, 0.02, 0.025));
  final cov = rasterize(circle(20, 20, 16), 40, 40);
  paint_through(c, cov, color(0.9, 0.55, 0.1));
  return magnify(c, 8);
}

Canvas painted_twice() {
  final c = canvas(80, 40);
  fill(c, color(0.02, 0.02, 0.025));
  final cov = rasterize(circle(20, 20, 16), 40, 40);

  final once = coverage_buffer(80, 40);
  for (int y = 0; y < 40; y++) {
    for (int x = 0; x < 40; x++) {
      set_coverage(once, x, y, coverage_at(cov, x, y));
      set_coverage(once, x + 40, y, coverage_at(cov, x, y));
    }
  }
  paint_through(c, once, color(0.9, 0.55, 0.1));

  final twice = coverage_buffer(80, 40);
  for (int y = 0; y < 40; y++) {
    for (int x = 0; x < 40; x++) {
      set_coverage(twice, x + 40, y, coverage_at(cov, x, y));
    }
  }
  paint_through(c, twice, color(0.9, 0.55, 0.1));

  return magnify(c, 6);
}

Canvas plate_02() {
  final c = canvas(80, 40);
  fill(c, color(0.02, 0.02, 0.025));
  final shape = circle(20, 20, 16);
  final left = rasterize_centers(shape, 40, 40);
  final right = rasterize(shape, 40, 40);

  final both = coverage_buffer(80, 40);
  for (int y = 0; y < 40; y++) {
    for (int x = 0; x < 40; x++) {
      set_coverage(both, x, y, coverage_at(left, x, y));
      set_coverage(both, x + 40, y, coverage_at(right, x, y));
    }
  }

  paint_through(c, both, color(0.9, 0.55, 0.1));
  return magnify(c, 6);
}

// ---------------------------------------------------------------------
// Chapter 3: lines
// ---------------------------------------------------------------------

class IntPoint {
  final int x, y;
  IntPoint(this.x, this.y);
  @override
  bool operator ==(Object other) => other is IntPoint && other.x == x && other.y == y;
  @override
  int get hashCode => x.hashCode ^ y.hashCode;
  @override
  String toString() => '($x, $y)';
}

List<IntPoint> lit_pixels(Canvas c) {
  final result = <IntPoint>[];
  for (int y = 0; y < c.height; y++) {
    for (int x = 0; x < c.width; x++) {
      final col = c.pixelAt(x, y);
      if (!(numsClose(col.red, 0) && numsClose(col.green, 0) && numsClose(col.blue, 0))) {
        result.add(IntPoint(x, y));
      }
    }
  }
  return result;
}

void line_bresenham(Canvas c, int x0, int y0, int x1, int y1, Color col) {
  bool steep = (y1 - y0).abs() > (x1 - x0).abs();
  int ax0 = x0, ay0 = y0, ax1 = x1, ay1 = y1;
  if (steep) {
    int tmp = ax0;
    ax0 = ay0;
    ay0 = tmp;
    tmp = ax1;
    ax1 = ay1;
    ay1 = tmp;
  }
  if (ax0 > ax1) {
    int tmp = ax0;
    ax0 = ax1;
    ax1 = tmp;
    tmp = ay0;
    ay0 = ay1;
    ay1 = tmp;
  }

  final dx = ax1 - ax0;
  final dy = (ay1 - ay0).abs();
  final ystep = ay0 < ay1 ? 1 : -1;
  int err = dx ~/ 2;
  int y = ay0;

  for (int x = ax0; x <= ax1; x++) {
    if (steep) {
      write_pixel(c, y, x, col);
    } else {
      write_pixel(c, x, y, col);
    }
    err -= dy;
    if (err < 0) {
      y += ystep;
      err += dx;
    }
  }
}

List<IntPoint> ray_ends() {
  final ends = <IntPoint>[];
  for (int k = 0; k < 12; k++) {
    final a = k * 30 * math.pi / 180;
    ends.add(IntPoint((80 + 72 * math.cos(a)).round(), (80 + 72 * math.sin(a)).round()));
  }
  return ends;
}

Canvas fan_bresenham() {
  final c = canvas(160, 160);
  fill(c, color(0.02, 0.02, 0.025));
  for (final p in ray_ends()) {
    line_bresenham(c, 80, 80, p.x, p.y, color(0.92, 0.92, 0.88));
  }
  return c;
}

void plot(Canvas c, int x, int y, Color col, double weight) {
  if (weight == 0.0) return;
  if (x < 0 || x >= c.width || y < 0 || y >= c.height) return;
  final current = c.pixelAt(x, y);
  write_pixel(c, x, y, mix(current, col, weight, true));
}

void line_wu(Canvas c, int x0, int y0, int x1, int y1, Color col) {
  bool steep = (y1 - y0).abs() > (x1 - x0).abs();
  int ax0 = x0, ay0 = y0, ax1 = x1, ay1 = y1;
  if (steep) {
    int tmp = ax0;
    ax0 = ay0;
    ay0 = tmp;
    tmp = ax1;
    ax1 = ay1;
    ay1 = tmp;
  }
  if (ax0 > ax1) {
    int tmp = ax0;
    ax0 = ax1;
    ax1 = tmp;
    tmp = ay0;
    ay0 = ay1;
    ay1 = tmp;
  }

  final dx = ax1 - ax0;
  final slope = dx == 0 ? 0.0 : (ay1 - ay0) / dx;

  for (int x = ax0; x <= ax1; x++) {
    final y = ay0 + (x - ax0) * slope;
    final yi = y.floor();
    final f = y - yi;
    if (steep) {
      plot(c, yi, x, col, 1 - f);
      plot(c, yi + 1, x, col, f);
    } else {
      plot(c, x, yi, col, 1 - f);
      plot(c, x, yi + 1, col, f);
    }
  }
}

double total_ink(Canvas c) {
  double total = 0.0;
  for (int y = 0; y < c.height; y++) {
    for (int x = 0; x < c.width; x++) {
      total += c.pixelAt(x, y).red;
    }
  }
  return total;
}

Canvas fan_wu() {
  final c = canvas(160, 160);
  fill(c, color(0.02, 0.02, 0.025));
  for (final p in ray_ends()) {
    line_wu(c, 80, 80, p.x, p.y, color(0.92, 0.92, 0.88));
  }
  return c;
}

class ThickLine implements Shape {
  final Shape _inner;
  ThickLine(double x0, double y0, double x1, double y1, double width)
      : _inner = _buildThickLine(x0, y0, x1, y1, width);

  @override
  bool inside(double x, double y) => _inner.inside(x, y);
}

Shape _buildThickLine(double x0, double y0, double x1, double y1, double width) {
  double ax = x0 + 0.5, ay = y0 + 0.5;
  double bx = x1 + 0.5, by = y1 + 0.5;
  return _thickLineFromCenters(ax, ay, bx, by, width);
}

Shape _thickLineFromCenters(double ax, double ay, double bx, double by, double width) {
  final h = width / 2;
  double dx, dy;
  final len = math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay));
  if (len == 0) {
    dx = 1;
    dy = 0;
    ax = ax - h;
    bx = bx + h;
  } else {
    dx = (bx - ax) / len;
    dy = (by - ay) / len;
  }
  final nx = -dy, ny = dx;
  return AndShape([
    half_plane(ax, ay, dx, dy),
    half_plane(bx, by, -dx, -dy),
    half_plane(ax + nx * h, ay + ny * h, -nx, -ny),
    half_plane(ax - nx * h, ay - ny * h, nx, ny),
  ]);
}

class AndShape implements Shape {
  final List<Shape> parts;
  AndShape(this.parts);
  @override
  bool inside(double x, double y) {
    for (final p in parts) {
      if (!p.inside(x, y)) return false;
    }
    return true;
  }
}

Shape thick_line(double x0, double y0, double x1, double y1, double width) =>
    ThickLine(x0, y0, x1, y1, width);

Canvas fan_coverage() {
  final c = canvas(160, 160);
  fill(c, color(0.02, 0.02, 0.025));
  for (final p in ray_ends()) {
    final cov = rasterize(thick_line(80, 80, p.x.toDouble(), p.y.toDouble(), 1), 160, 160);
    paint_through(c, cov, color(0.92, 0.92, 0.88));
  }
  return magnify(c, 2);
}

Canvas plate_03() {
  final both = canvas(320, 160);
  final a = fan_bresenham();
  final b = fan_wu();
  for (int y = 0; y < 160; y++) {
    for (int x = 0; x < 160; x++) {
      write_pixel(both, x, y, pixel_at(a, x, y));
      write_pixel(both, x + 160, y, pixel_at(b, x, y));
    }
  }
  return magnify(both, 2);
}

// ---------------------------------------------------------------------
// Shared tolerance helpers (used by lib and tests alike)
// ---------------------------------------------------------------------

bool numsClose(double a, double b, [double eps = 0.0001]) => (a - b).abs() <= eps;
bool colorsClose(Color a, Color b, [double eps = 0.0001]) =>
    numsClose(a.red, b.red, eps) && numsClose(a.green, b.green, eps) && numsClose(a.blue, b.blue, eps);

// ---------------------------------------------------------------------
// Chapter 4: points, vectors, matrices, transforms
// ---------------------------------------------------------------------

class Tup {
  final double x, y, w;
  const Tup(this.x, this.y, this.w);

  Tup operator +(Tup o) => Tup(x + o.x, y + o.y, w + o.w);
  Tup operator -(Tup o) => Tup(x - o.x, y - o.y, w - o.w);
  Tup operator -() => Tup(-x, -y, -w);
  Tup operator *(double s) => Tup(x * s, y * s, w * s);
  Tup operator /(double s) => Tup(x / s, y / s, w / s);

  bool get isPoint => w != 0;

  @override
  String toString() => 'Tup($x, $y, $w)';
}

Tup point(double x, double y) => Tup(x, y, 1);
Tup vector(double x, double y) => Tup(x, y, 0);

bool tupsClose(Tup a, Tup b, [double eps = 0.0001]) =>
    numsClose(a.x, b.x, eps) && numsClose(a.y, b.y, eps) && numsClose(a.w, b.w, eps);

double magnitude(Tup v) => math.sqrt(v.x * v.x + v.y * v.y);

Tup normalize(Tup v) {
  final m = magnitude(v);
  return Tup(v.x / m, v.y / m, v.w / m);
}

double dot(Tup a, Tup b) => a.x * b.x + a.y * b.y;

double cross(Tup a, Tup b) => a.x * b.y - a.y * b.x;

class Matrix3 {
  // Row-major, 3x3.
  final List<List<double>> _rows;
  Matrix3(this._rows);

  factory Matrix3.of(
    double m00,
    double m01,
    double m02,
    double m10,
    double m11,
    double m12,
    double m20,
    double m21,
    double m22,
  ) =>
      Matrix3([
        [m00, m01, m02],
        [m10, m11, m12],
        [m20, m21, m22],
      ]);

  double at(int r, int c) => _rows[r][c];

  List<double> operator [](int r) => _rows[r];

  // Strongly-typed multiplications. Chained expressions (A * B * C) should
  // use these (or the mm()/mmAll() helpers below) rather than the dynamic
  // operator*, so the return type is unambiguous at every step -- Dart's
  // precedence for "as" relative to "*" makes chaining casts inline risky.
  Matrix3 multiplyMatrix(Matrix3 other) {
    final result = List.generate(3, (r) => List<double>.filled(3, 0.0));
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        double sum = 0;
        for (int k = 0; k < 3; k++) {
          sum += at(r, k) * other.at(k, c);
        }
        result[r][c] = sum;
      }
    }
    return Matrix3(result);
  }

  Tup multiplyTup(Tup t) {
    final rx = at(0, 0) * t.x + at(0, 1) * t.y + at(0, 2) * t.w;
    final ry = at(1, 0) * t.x + at(1, 1) * t.y + at(1, 2) * t.w;
    final rw = at(2, 0) * t.x + at(2, 1) * t.y + at(2, 2) * t.w;
    return Tup(rx, ry, rw);
  }

  // Dynamic operator*, kept for the common case of a single multiplication
  // in an expression (A * B, A * p, and so on).
  dynamic operator *(Object other) {
    if (other is Matrix3) {
      return multiplyMatrix(other);
    } else if (other is Tup) {
      return multiplyTup(other);
    }
    throw ArgumentError('Matrix3 * unsupported type: ${other.runtimeType}');
  }

  bool equalsClose(Matrix3 o, [double eps = 0.0001]) {
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (!numsClose(at(r, c), o.at(r, c), eps)) return false;
      }
    }
    return true;
  }
}

Matrix3 matrix3(
  double m00,
  double m01,
  double m02,
  double m10,
  double m11,
  double m12,
  double m20,
  double m21,
  double m22,
) =>
    Matrix3.of(m00, m01, m02, m10, m11, m12, m20, m21, m22);

// For scenarios that build a matrix "row by row" from a Gherkin table.
Matrix3 matrixFromRows(List<List<double>> rows) => Matrix3(rows);

bool matricesClose(Matrix3 a, Matrix3 b, [double eps = 0.0001]) => a.equalsClose(b, eps);

// Chained matrix products (A * B * C): matrix multiplication is
// associative, so folding left to right in this order is correct
// regardless of how the pseudo-code parenthesizes it.
Matrix3 mm(Matrix3 a, Matrix3 b) => a.multiplyMatrix(b);
Matrix3 mmAll(List<Matrix3> ms) => ms.reduce(mm);

Matrix3 identity() => matrix3(1, 0, 0, 0, 1, 0, 0, 0, 1);

Matrix3 transpose(Matrix3 m) {
  final result = List.generate(3, (r) => List<double>.filled(3, 0.0));
  for (int r = 0; r < 3; r++) {
    for (int c = 0; c < 3; c++) {
      result[r][c] = m.at(c, r);
    }
  }
  return Matrix3(result);
}

double minor(Matrix3 m, int r, int c) {
  final rows = [0, 1, 2].where((i) => i != r).toList();
  final cols = [0, 1, 2].where((i) => i != c).toList();
  return m.at(rows[0], cols[0]) * m.at(rows[1], cols[1]) - m.at(rows[0], cols[1]) * m.at(rows[1], cols[0]);
}

double cofactor(Matrix3 m, int r, int c) {
  final mm = minor(m, r, c);
  return (r + c).isOdd ? -mm : mm;
}

double determinant(Matrix3 m) =>
    m.at(0, 0) * cofactor(m, 0, 0) + m.at(0, 1) * cofactor(m, 0, 1) + m.at(0, 2) * cofactor(m, 0, 2);

bool is_invertible(Matrix3 m) => determinant(m) != 0;

Matrix3 inverse(Matrix3 m) {
  final d = determinant(m);
  final result = List.generate(3, (r) => List<double>.filled(3, 0.0));
  for (int r = 0; r < 3; r++) {
    for (int c = 0; c < 3; c++) {
      result[c][r] = cofactor(m, r, c) / d;
    }
  }
  return Matrix3(result);
}

Matrix3 translation(double tx, double ty) => matrix3(1, 0, tx, 0, 1, ty, 0, 0, 1);
Matrix3 scaling(double sx, double sy) => matrix3(sx, 0, 0, 0, sy, 0, 0, 0, 1);
Matrix3 rotation(double r) => matrix3(math.cos(r), -math.sin(r), 0, math.sin(r), math.cos(r), 0, 0, 0, 1);
Matrix3 shearing(double xy, double yx) => matrix3(1, xy, 0, yx, 1, 0, 0, 0, 1);

double approx_scale(Matrix3 m) {
  final a = m.at(0, 0), b = m.at(0, 1), c = m.at(1, 0), d = m.at(1, 1);
  return math.sqrt((a * d - b * c).abs());
}

// ---------------------------------------------------------------------
// Chapter 4: transforming what you draw
// ---------------------------------------------------------------------

Shape segment(Tup a, Tup b, double width) =>
    _thickLineFromCenters(a.x, a.y, b.x, b.y, width);

class UnionShape implements Shape {
  final List<Shape> shapes;
  UnionShape(this.shapes);
  @override
  bool inside(double x, double y) {
    for (final s in shapes) {
      if (s.inside(x, y)) return true;
    }
    return false;
  }
}

Shape union(List<Shape> shapes) => UnionShape(shapes);

class TransformedShape implements Shape {
  final Shape original;
  final Matrix3? inv;
  TransformedShape(this.original, Matrix3 m) : inv = is_invertible(m) ? inverse(m) : null;

  @override
  bool inside(double x, double y) {
    if (inv == null) return false;
    final p = inv! * point(x, y);
    return original.inside(p.x, p.y);
  }
}

Shape transformed(Shape shape, Matrix3 m) => TransformedShape(shape, m);

List<Tup> transform_points(List<Tup> pts, Matrix3 m) => pts.map((p) => m.multiplyTup(p)).toList();

Shape outline(List<Tup> points, Matrix3 m, double width) {
  final pts = transform_points(points, m);
  final segments = <Shape>[];
  for (int i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    segments.add(segment(a, b, width));
  }
  return union(segments);
}

// ---------------------------------------------------------------------
// Chapter 4 renders
// ---------------------------------------------------------------------

List<Tup> fan_points() {
  final pts = <Tup>[point(0, 0)];
  for (int k = 0; k < 12; k++) {
    final a = k * 30 * math.pi / 180;
    pts.add(point(36 * math.cos(a), 36 * math.sin(a)));
  }
  return pts;
}

Canvas fan_transformed(Matrix3 m) {
  final c = canvas(160, 160);
  fill(c, color(0.02, 0.02, 0.025));
  final pts = transform_points(fan_points(), m);
  final rays = <Shape>[];
  for (int k = 1; k <= 12; k++) {
    rays.add(segment(pts[0], pts[k], 1));
  }
  paint_through(c, rasterize(union(rays), 160, 160), color(0.92, 0.92, 0.88));
  return c;
}

Canvas side_by_side(Canvas a, Canvas b) {
  final c = canvas(a.width + b.width, math.max(a.height, b.height));
  for (int y = 0; y < a.height; y++) {
    for (int x = 0; x < a.width; x++) {
      write_pixel(c, x, y, pixel_at(a, x, y));
    }
  }
  for (int y = 0; y < b.height; y++) {
    for (int x = 0; x < b.width; x++) {
      write_pixel(c, a.width + x, y, pixel_at(b, x, y));
    }
  }
  return c;
}

Canvas fan_both_orders() {
  final turn = rotation(math.pi / 6);
  final move = translation(104.5, 76.5);
  return side_by_side(fan_transformed(move * turn), fan_transformed(turn * move));
}

List<Tup> letter_f() => [
      point(-20, -30),
      point(20, -30),
      point(20, -20),
      point(-10, -20),
      point(-10, -5),
      point(12, -5),
      point(12, 5),
      point(-10, 5),
      point(-10, 30),
      point(-20, 30),
    ];

Canvas f_both_orders() {
  final turn = rotation(math.pi / 6);
  final move = translation(104.5, 76.5);
  final home = translation(44.5, 44.5);
  final ink = color(0.92, 0.92, 0.88);
  final dim = color(0.16, 0.16, 0.17);
  final ghost = canvas(160, 160);
  fill(ghost, color(0.02, 0.02, 0.025));
  paint_through(ghost, rasterize(outline(letter_f(), home, 1), 160, 160), dim);
  final a = ghost.copy();
  final b = ghost.copy();
  paint_through(a, rasterize(outline(letter_f(), move * turn, 1), 160, 160), ink);
  paint_through(b, rasterize(outline(letter_f(), turn * move, 1), 160, 160), ink);
  return side_by_side(a, b);
}

Canvas plate_04() => magnify(f_both_orders(), 2);

// ---------------------------------------------------------------------
// Chapter 5: paths and insideness
// ---------------------------------------------------------------------

class Subpath {
  final List<Tup> points = [];
  bool closed = false;
}

class Edge {
  final Tup a, b;
  Edge(this.a, this.b);
}

class Bounds {
  final double minX, minY, maxX, maxY;
  Bounds(this.minX, this.minY, this.maxX, this.maxY);
}

bool boundsClose(Bounds a, Bounds b, [double eps = 0.0001]) =>
    numsClose(a.minX, b.minX, eps) &&
    numsClose(a.minY, b.minY, eps) &&
    numsClose(a.maxX, b.maxX, eps) &&
    numsClose(a.maxY, b.maxY, eps);

class PathObj {
  final List<Subpath> _subpaths = [];

  void moveTo(Tup p) {
    final sp = Subpath();
    sp.points.add(p);
    _subpaths.add(sp);
  }

  void lineTo(Tup p) {
    if (_subpaths.isEmpty) {
      moveTo(p);
      return;
    }
    final last = _subpaths.last;
    if (last.closed) {
      final start = last.points[0];
      final sp = Subpath();
      sp.points.add(start);
      sp.points.add(p);
      _subpaths.add(sp);
    } else {
      last.points.add(p);
    }
  }

  void closePath() {
    if (_subpaths.isEmpty) return;
    _subpaths.last.closed = true;
  }

  List<Subpath> get subpaths => _subpaths;
}

PathObj path() => PathObj();
void move_to(PathObj p, Tup pt) => p.moveTo(pt);
void line_to(PathObj p, Tup pt) => p.lineTo(pt);
void close(PathObj p) => p.closePath();
List<Subpath> subpaths(PathObj p) => p.subpaths;

List<Edge> edges(PathObj p) {
  final result = <Edge>[];
  for (final sp in p.subpaths) {
    final n = sp.points.length;
    if (n < 2) continue;
    for (int i = 0; i < n; i++) {
      result.add(Edge(sp.points[i], sp.points[(i + 1) % n]));
    }
  }
  return result;
}

Bounds bounds(PathObj p) {
  double? minX, minY, maxX, maxY;
  for (final sp in p.subpaths) {
    for (final pt in sp.points) {
      minX = (minX == null) ? pt.x : math.min(minX, pt.x);
      minY = (minY == null) ? pt.y : math.min(minY, pt.y);
      maxX = (maxX == null) ? pt.x : math.max(maxX, pt.x);
      maxY = (maxY == null) ? pt.y : math.max(maxY, pt.y);
    }
  }
  if (minX == null) return Bounds(0, 0, 0, 0);
  return Bounds(minX, minY!, maxX!, maxY!);
}

PathObj polygon(List<Tup> pts) {
  final p = path();
  for (int i = 0; i < pts.length; i++) {
    if (i == 0) {
      move_to(p, pts[i]);
    } else {
      line_to(p, pts[i]);
    }
  }
  close(p);
  return p;
}

PathObj circle_path(double cx, double cy, double r, int n) {
  final p = path();
  for (int k = 0; k < n; k++) {
    final a = k * 2 * math.pi / n;
    final pt = point(cx + r * math.cos(a), cy + r * math.sin(a));
    if (k == 0) {
      move_to(p, pt);
    } else {
      line_to(p, pt);
    }
  }
  close(p);
  return p;
}

int crossings(PathObj p, double x, double y) {
  int count = 0;
  for (final e in edges(p)) {
    final a = e.a, b = e.b;
    bool spans;
    if (a.y <= y && y < b.y) {
      spans = true;
    } else if (b.y <= y && y < a.y) {
      spans = true;
    } else {
      spans = false;
    }
    if (!spans) continue;
    final t = (y - a.y) / (b.y - a.y);
    final ex = a.x + t * (b.x - a.x);
    if (ex > x) count++;
  }
  return count;
}

int winding_at(PathObj p, double x, double y) {
  final q = point(x, y);
  int w = 0;
  for (final e in edges(p)) {
    final a = e.a, b = e.b;
    if (a.y <= y) {
      if (b.y > y && cross(b - a, q - a) > 0) w++;
    } else {
      if (b.y <= y && cross(b - a, q - a) < 0) w--;
    }
  }
  return w;
}

bool inside_nonzero(PathObj p, double x, double y) => winding_at(p, x, y) != 0;
bool inside_evenodd(PathObj p, double x, double y) => winding_at(p, x, y).isOdd;

class FilledPath implements Shape {
  final PathObj path;
  final String rule;
  FilledPath(this.path, this.rule);

  @override
  bool inside(double x, double y) {
    final w = winding_at(path, x, y);
    return rule == 'nonzero' ? w != 0 : w.isOdd;
  }
}

Shape filled(PathObj p, String rule) => FilledPath(p, rule);

CoverageBuffer rasterize_within(Shape s, Bounds box, int w, int h) {
  final cov = coverage_buffer(w, h);
  int x0 = math.max(box.minX.floor(), 0);
  int x1 = math.min(box.maxX.ceil(), w);
  int y0 = math.max(box.minY.floor(), 0);
  int y1 = math.min(box.maxY.ceil(), h);
  for (int y = y0; y < y1; y++) {
    for (int x = x0; x < x1; x++) {
      set_coverage(cov, x, y, coverage(s, x, y).toDouble());
    }
  }
  return cov;
}

// ---------------------------------------------------------------------
// Chapter 5 renders
// ---------------------------------------------------------------------

PathObj star() {
  final p = path();
  for (int k = 0; k < 5; k++) {
    final a = (-90 + 144 * k) * math.pi / 180;
    final q = point(80.5 + 70 * math.cos(a), 80.5 + 70 * math.sin(a));
    if (k == 0) {
      move_to(p, q);
    } else {
      line_to(p, q);
    }
  }
  close(p);
  return p;
}

Canvas star_panel(String rule, String method) {
  final c = canvas(160, 160);
  fill(c, color(0.02, 0.02, 0.025));
  final s = filled(star(), rule);
  CoverageBuffer cov;
  if (method == 'centers') {
    cov = rasterize_centers(s, 160, 160);
  } else {
    cov = rasterize_within(s, bounds(star()), 160, 160);
  }
  paint_through(c, cov, color(0.9, 0.55, 0.1));
  return c;
}

Canvas star_centers() => side_by_side(star_panel('nonzero', 'centers'), star_panel('evenodd', 'centers'));
Canvas star_coverage() => side_by_side(star_panel('nonzero', 'coverage'), star_panel('evenodd', 'coverage'));

Canvas plate_05() {
  final top = star_centers();
  final bottom = star_coverage();
  final both = canvas(320, 320);
  for (int y = 0; y < 160; y++) {
    for (int x = 0; x < 320; x++) {
      write_pixel(both, x, y, pixel_at(top, x, y));
      write_pixel(both, x, y + 160, pixel_at(bottom, x, y));
    }
  }
  return magnify(both, 2);
}

// ---------------------------------------------------------------------
// Chapter 6: filling a polygon
// ---------------------------------------------------------------------

class EdgeEntry {
  final double yTop, yBottom, xTop, slope;
  final int direction;
  EdgeEntry(this.yTop, this.yBottom, this.xTop, this.slope, this.direction);
}

List<EdgeEntry> edge_table(PathObj p) {
  final result = <EdgeEntry>[];
  for (final e in edges(p)) {
    final a = e.a, b = e.b;
    if (a.y == b.y) continue; // horizontal: dropped
    final int direction = a.y < b.y ? 1 : -1;
    double yTop, yBottom, xTop, xBottom;
    if (a.y < b.y) {
      yTop = a.y;
      xTop = a.x;
      yBottom = b.y;
      xBottom = b.x;
    } else {
      yTop = b.y;
      xTop = b.x;
      yBottom = a.y;
      xBottom = a.x;
    }
    final slope = (xBottom - xTop) / (yBottom - yTop);
    result.add(EdgeEntry(yTop, yBottom, xTop, slope, direction));
  }
  result.sort((x, y) {
    final c1 = x.yTop.compareTo(y.yTop);
    if (c1 != 0) return c1;
    return x.xTop.compareTo(y.xTop);
  });
  return result;
}

double x_at(EdgeEntry edge, double y) => edge.xTop + (y - edge.yTop) * edge.slope;

class Crossing {
  final double x;
  final int direction;
  Crossing(this.x, this.direction);
  @override
  bool operator ==(Object other) => other is Crossing && numsClose(other.x, x) && other.direction == direction;
  @override
  int get hashCode => x.hashCode ^ direction.hashCode;
  @override
  String toString() => '($x, $direction)';
}

List<Crossing> crossings_on_row(List<EdgeEntry> table, double y) {
  final result = <Crossing>[];
  for (final e in table) {
    if (e.yTop <= y && y < e.yBottom) {
      result.add(Crossing(x_at(e, y), e.direction));
    }
  }
  result.sort((a, b) => a.x.compareTo(b.x));
  return result;
}

class Span {
  final double x0, x1;
  Span(this.x0, this.x1);
  @override
  bool operator ==(Object other) => other is Span && numsClose(other.x0, x0) && numsClose(other.x1, x1);
  @override
  int get hashCode => x0.hashCode ^ x1.hashCode;
  @override
  String toString() => '($x0, $x1)';
}

List<Span> spans_from_crossings(List<Crossing> xs, String rule) {
  final out = <Span>[];
  int w = 0;
  double? start;
  for (final cr in xs) {
    w += cr.direction;
    final bool isInside = rule == 'nonzero' ? w != 0 : w.isOdd;
    if (isInside && start == null) {
      start = cr.x;
    }
    if (!isInside && start != null) {
      out.add(Span(start, cr.x));
      start = null;
    }
  }
  return out;
}

List<Span> spans(PathObj p, String rule, int row) {
  final y = row + 0.5;
  final table = edge_table(p);
  final xs = crossings_on_row(table, y);
  return spans_from_crossings(xs, rule);
}

void fill_span(CoverageBuffer cov, int row, double x0, double x1) {
  final first = (x0 - 0.5).ceil();
  final last = (x1 - 0.5).ceil() - 1;
  final lo = math.max(first, 0);
  final hi = math.min(last, cov.width - 1);
  for (int x = lo; x <= hi; x++) {
    set_coverage(cov, x, row, 1.0);
  }
}

CoverageBuffer fill_path_aliased(PathObj p, String rule, int w, int h) {
  final cov = coverage_buffer(w, h);
  final table = edge_table(p);
  final active = <EdgeEntry>[];
  int next = 0;
  for (int row = 0; row < h; row++) {
    final y = row + 0.5;
    while (next < table.length && table[next].yTop <= y) {
      active.add(table[next]);
      next++;
    }
    active.removeWhere((e) => e.yBottom <= y);
    final xs = <Crossing>[for (final e in active) Crossing(x_at(e, y), e.direction)];
    xs.sort((a, b) => a.x.compareTo(b.x));
    for (final span in spans_from_crossings(xs, rule)) {
      fill_span(cov, row, span.x0, span.x1);
    }
  }
  return cov;
}

double max_coverage_difference(CoverageBuffer a, CoverageBuffer b) {
  if (a.width != b.width || a.height != b.height) return 1.0;
  double maxDiff = 0.0;
  for (int y = 0; y < a.height; y++) {
    for (int x = 0; x < a.width; x++) {
      final d = (a.at(x, y) - b.at(x, y)).abs();
      if (d > maxDiff) maxDiff = d;
    }
  }
  return maxDiff;
}

PathObj transform_path(PathObj p, Matrix3 m) {
  final q = path();
  for (final sp in p.subpaths) {
    for (int i = 0; i < sp.points.length; i++) {
      final transformed = m * sp.points[i];
      if (i == 0) {
        move_to(q, transformed);
      } else {
        line_to(q, transformed);
      }
    }
    if (sp.closed) close(q);
  }
  return q;
}

// ---------------------------------------------------------------------
// Chapter 6 renders
// ---------------------------------------------------------------------

PathObj unit_star() => transform_path(star(), scaling(1 / 70, 1 / 70) * translation(-80.5, -80.5));

Canvas spiral() {
  final c = canvas(320, 320);
  fill(c, color(0.02, 0.02, 0.025));
  final inks = [color(0.9, 0.55, 0.1), color(0.2, 0.55, 0.85), color(0.85, 0.25, 0.3)];
  final us = unit_star();
  for (int k = 0; k < 24; k++) {
    final a = k * 25 * math.pi / 180;
    final r = 20 + 5 * k;
    final m = translation(160.5 + r * math.cos(a), 160.5 + r * math.sin(a)) *
        rotation(a) *
        scaling(6 + 1.25 * k, 6 + 1.25 * k);
    final cov = fill_path_aliased(transform_path(us, m), 'nonzero', 320, 320);
    paint_through(c, cov, inks[k % 3]);
  }
  return c;
}

Canvas plate_06() => magnify(spiral(), 2);
