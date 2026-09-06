// Writes every chapter's renders to out/, using the reference filenames,
// and reports max_channel_difference against reference/chapter-0N/.
//
//   dart tool/render.dart
//
// Run from the project root (ch6-dart/) so reference/ resolves and out/
// is created in the right place.
import 'dart:io';
import '../lib/renderer.dart';

// Chapter 1's reference images are plain-text P3 (binary P6 starts in
// chapter 2, per the book), so the writer to use depends on the chapter.
void renderOne(String chapterDir, String name, Canvas Function() build, {bool binary = true}) {
  final sw = Stopwatch()..start();
  final c = build();
  final ppm = binary ? canvas_to_p6(c) : canvas_to_ppm(c);
  sw.stop();

  final outDir = Directory('out/$chapterDir');
  outDir.createSync(recursive: true);
  final outPath = 'out/$chapterDir/$name.ppm';
  File(outPath).writeAsBytesSync(ppm.bytes);

  final refPath = 'reference/$chapterDir/$name.ppm';
  String verdict;
  if (File(refPath).existsSync()) {
    final ref = read_file(refPath);
    final diff = max_channel_difference(ppm, ref);
    verdict = 'max_channel_difference=$diff';
  } else {
    verdict = 'no reference file at $refPath';
  }
  print('${sw.elapsedMilliseconds.toString().padLeft(6)} ms  $chapterDir/$name.ppm  ($verdict)');
}

void main() {
  print('Rendering chapters 1-6 to out/ ...');
  print('');

  renderOne('chapter-01', 'gray-match', gray_match, binary: false);
  renderOne('chapter-01', 'quarter-match', quarter_match, binary: false);
  renderOne('chapter-01', 'ramp', ramp, binary: false);
  renderOne('chapter-01', 'clamp-pair', clamp_pair, binary: false);
  renderOne('chapter-01', 'plate-01', plate_01, binary: false);

  renderOne('chapter-02', 'disc-centers', disc_centers);
  renderOne('chapter-02', 'disc-coverage', disc_coverage);
  renderOne('chapter-02', 'painted-twice', painted_twice);
  renderOne('chapter-02', 'plate-02', plate_02);

  renderOne('chapter-03', 'fan-bresenham', fan_bresenham);
  renderOne('chapter-03', 'fan-wu', fan_wu);
  renderOne('chapter-03', 'fan-coverage', fan_coverage);
  renderOne('chapter-03', 'plate-03', plate_03);

  renderOne('chapter-04', 'fan-both-orders', fan_both_orders);
  renderOne('chapter-04', 'plate-04', plate_04);

  renderOne('chapter-05', 'star-centers', star_centers);
  renderOne('chapter-05', 'star-coverage', star_coverage);
  renderOne('chapter-05', 'plate-05', plate_05);

  renderOne('chapter-06', 'spiral', spiral);
  renderOne('chapter-06', 'plate-06', plate_06);

  print('');
  print('Done.');
}
