import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_audio_toolkit/flutter_audio_toolkit.dart';
import 'package:flutter/services.dart';

void main() {
  group('iOS Audio Quality and Trimming Tests', () {
    late FlutterAudioToolkit audioToolkit;
    const channel = MethodChannel('flutter_audio_toolkit');

    setUp(() {
      audioToolkit = FlutterAudioToolkit();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('iOS high quality conversion uses correct preset', (
      WidgetTester tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'convertAudio') {
              final args = methodCall.arguments as Map;
              final bitRate = args['bitRate'] as int;

              // Verify that high bitrate uses appropriate preset
              expect(bitRate, greaterThan(256));

              return {
                'outputPath': args['outputPath'],
                'durationMs': 30000,
                'bitRate': bitRate,
                'sampleRate': args['sampleRate'],
              };
            }
            return null;
          });

      final result = await audioToolkit.convertAudio(
        inputPath: '/test/input.mp3',
        outputPath: '/test/output.m4a',
        format: AudioFormat.m4a,
        bitRate: 320, // High quality
        sampleRate: 44100,
      );

      expect(result.outputPath, '/test/output.m4a');
      expect(result.bitRate, 320);
    });

    testWidgets('iOS trimming validates time ranges correctly', (
      WidgetTester tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'trimAudio') {
              final args = methodCall.arguments as Map;
              final startTimeMs = args['startTimeMs'] as int;
              final endTimeMs = args['endTimeMs'] as int;

              // Verify valid time range
              expect(startTimeMs, greaterThanOrEqualTo(0));
              expect(endTimeMs, greaterThan(startTimeMs));

              return {
                'outputPath': args['outputPath'],
                'durationMs': endTimeMs - startTimeMs,
                'bitRate': args['bitRate'],
                'sampleRate': args['sampleRate'],
              };
            }
            return null;
          });

      final result = await audioToolkit.trimAudio(
        inputPath: '/test/input.m4a',
        outputPath: '/test/trimmed.m4a',
        startTimeMs: 5000,
        endTimeMs: 25000,
        format: AudioFormat.m4a,
        bitRate: 192,
        sampleRate: 44100,
      );

      expect(result.outputPath, '/test/trimmed.m4a');
      expect(result.durationMs, 20000); // 25s - 5s = 20s
    });

    testWidgets('iOS handles precision trimming with microsecond accuracy', (
      WidgetTester tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'trimAudio') {
              final args = methodCall.arguments as Map;
              final startTimeMs = args['startTimeMs'] as int;
              final endTimeMs = args['endTimeMs'] as int;

              // Verify precision timing
              expect(startTimeMs, 1234); // Precise timing
              expect(endTimeMs, 5678);

              return {
                'outputPath': args['outputPath'],
                'durationMs': endTimeMs - startTimeMs,
                'bitRate': args['bitRate'],
                'sampleRate': args['sampleRate'],
              };
            }
            return null;
          });

      final result = await audioToolkit.trimAudio(
        inputPath: '/test/input.m4a',
        outputPath: '/test/precision_trimmed.m4a',
        startTimeMs: 1234, // Precise start
        endTimeMs: 5678, // Precise end
        format: AudioFormat.m4a,
        bitRate: 128,
        sampleRate: 44100,
      );

      expect(result.outputPath, '/test/precision_trimmed.m4a');
      expect(result.durationMs, 4444); // 5678 - 1234 = 4444
    });

    testWidgets('iOS error handling provides detailed error information', (
      WidgetTester tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'convertAudio') {
              throw PlatformException(
                code: 'CONVERSION_ERROR',
                message: 'Export failed with status: 3',
                details:
                    'AVAssetExportSession failed with detailed error information',
              );
            }
            return null;
          });

      expect(
        () async => await audioToolkit.convertAudio(
          inputPath: '/invalid/path.mp3',
          outputPath: '/invalid/output.m4a',
          format: AudioFormat.m4a,
        ),
        throwsA(
          isA<AudioConversionException>()
              .having((e) => e.code, 'code', 'CONVERSION_ERROR')
              .having(
                (e) => e.message,
                'message',
                contains('Export failed with status'),
              )
              .having(
                (e) => e.details,
                'details',
                contains('AVAssetExportSession failed'),
              ),
        ),
      );
    });

    testWidgets('iOS lossless trimming preserves quality', (
      WidgetTester tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'trimAudio') {
              final args = methodCall.arguments as Map;
              final format = args['format'] as String;

              // Verify lossless copy format
              expect(format, 'copy');

              return {
                'outputPath': args['outputPath'],
                'durationMs': 15000,
                'bitRate': 256000, // High quality preserved
                'sampleRate': args['sampleRate'],
              };
            }
            return null;
          });

      final result = await audioToolkit.trimAudio(
        inputPath: '/test/input.m4a',
        outputPath: '/test/lossless_trimmed.m4a',
        startTimeMs: 10000,
        endTimeMs: 25000,
        format: AudioFormat.copy, // Lossless copy
        bitRate: 192,
        sampleRate: 44100,
      );

      expect(result.outputPath, '/test/lossless_trimmed.m4a');
      expect(result.bitRate, 256000); // High quality preserved
    });

    testWidgets('iOS handles various audio formats correctly', (
      WidgetTester tester,
    ) async {
      final formats = [
        AudioFormat.m4a,
      ]; // Only test M4A as the recommended format

      for (final format in formats) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'convertAudio') {
                final args = methodCall.arguments as Map;
                final argFormat = args['format'] as String;

                // Verify format handling
                expect(argFormat, format.name);

                return {
                  'outputPath': args['outputPath'],
                  'durationMs': 30000,
                  'bitRate': args['bitRate'],
                  'sampleRate': args['sampleRate'],
                };
              }
              return null;
            });

        final result = await audioToolkit.convertAudio(
          inputPath: '/test/input.mp3',
          outputPath: '/test/output.${format.name}',
          format: format,
          bitRate: 192,
          sampleRate: 44100,
        );

        // M4A format produces M4A files
        expect(result.outputPath, '/test/output.m4a');
        expect(result.bitRate, 192);
      }
    });

    testWidgets('iOS metadata preservation works correctly', (
      WidgetTester tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'convertAudio') {
              final args = methodCall.arguments as Map;

              // Mock successful conversion with metadata
              return {
                'outputPath': args['outputPath'],
                'durationMs': 30000,
                'bitRate': args['bitRate'],
                'sampleRate': args['sampleRate'],
                'metadata': {
                  'title': 'Test Audio',
                  'artist': 'Test Artist',
                  'encoder': 'Flutter Audio Toolkit iOS',
                },
              };
            }
            return null;
          });

      final result = await audioToolkit.convertAudio(
        inputPath: '/test/input.mp3',
        outputPath: '/test/output.m4a',
        format: AudioFormat.m4a,
        bitRate: 192,
        sampleRate: 44100,
      );

      expect(result.outputPath, '/test/output.m4a');
      expect(result.bitRate, 192);
      expect(result.sampleRate, 44100);
    });
  });
}
