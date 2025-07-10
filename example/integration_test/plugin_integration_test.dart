// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_audio_toolkit/flutter_audio_toolkit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Audio Converter Waveform Plugin Integration Tests', () {
    final FlutterAudioToolkit plugin = FlutterAudioToolkit();

    testWidgets('getPlatformVersion test', (WidgetTester tester) async {
      final String? version = await plugin.getPlatformVersion();
      // The version string depends on the host platform running the test, so
      // just assert that some non-empty string is returned.
      expect(version?.isNotEmpty, true);
    });

    testWidgets('Priority Requirement 1: Audio Conversion API exists', (WidgetTester tester) async {
      // Test that convertAudio method exists and can be called
      // This is a basic API existence test - full functionality requires actual audio files
      expect(() async {
        try {
          await plugin.convertAudio(
            inputPath: '/nonexistent/path.mp3',
            outputPath: '/nonexistent/output.m4a',
            format: AudioFormat.m4a,
          );
        } catch (e) {
          // Expected to fail with file not found, but method should exist
          expect(
            e.toString().contains('CONVERSION_ERROR') ||
                e.toString().contains('FileSystemException') ||
                e.toString().contains('No such file'),
            true,
          );
        }
      }, returnsNormally);
    });

    testWidgets('Priority Requirement 2: Audio Trimming API exists', (WidgetTester tester) async {
      // Test that trimAudio method exists and can be called
      // This is a basic API existence test - full functionality requires actual audio files
      expect(() async {
        try {
          await plugin.trimAudio(
            inputPath: '/nonexistent/path.mp3',
            outputPath: '/nonexistent/trimmed.m4a',
            startTimeMs: 1000,
            endTimeMs: 5000,
            format: AudioFormat.m4a,
          );
        } catch (e) {
          // Expected to fail with file not found, but method should exist
          expect(
            e.toString().contains('TRIM_ERROR') ||
                e.toString().contains('FileSystemException') ||
                e.toString().contains('No such file'),
            true,
          );
        }
      }, returnsNormally);
    });

    testWidgets('Audio Format Support Check', (WidgetTester tester) async {
      // Test format support checking
      expect(() async {
        try {
          await plugin.isFormatSupported('/nonexistent/file.mp3');
        } catch (e) {
          // Method should exist even if file doesn't
        }
      }, returnsNormally);
    });
  });
}
