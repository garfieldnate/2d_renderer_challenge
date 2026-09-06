// Run every chapter's translated scenarios.
//
//   dart test/run_tests.dart
//
// Run from the project root (ch6-dart/) so read_file's relative paths
// into reference/ resolve.
import 'harness.dart';
import 'chapter01_test.dart';
import 'chapter02_test.dart';
import 'chapter03_test.dart';
import 'chapter04_test.dart';
import 'chapter05_test.dart';
import 'chapter06_test.dart';

void main() {
  runChapter01Tests();
  runChapter02Tests();
  runChapter03Tests();
  runChapter04Tests();
  runChapter05Tests();
  runChapter06Tests();
  summarize();
}
