import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_audio_toolkit/flutter_audio_toolkit.dart';
import 'package:flutter/services.dart';

void main() {
  group('BitRate Conversion Tests', () {
    late FlutterAudioToolkit audioToolkit;
    const channel = MethodChannel('flutter_audio_toolkit');

    setUp(() {
      audioToolkit = FlutterAudioToolkit();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    testWidgets('convertAudio receives bitRate in kbps and returns kbps', (WidgetTester tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'convertAudio') {
          final args = methodCall.arguments as Map;
          final bitRate = args['bitRate'] as int;

          // Dart sends bitRate in kbps (e.g., 192)
          expect(bitRate, equals(192));

          // Mock platform returns bitRate in kbps for consistency
          return {
            'outputPath': args['outputPath'],
            'durationMs': 30000,
            'bitRate': 192, // Return in kbps for Dart consistency
            'sampleRate': args['sampleRate'],
          };
        }
        return null;
      });

      final result = await audioToolkit.convertAudio(
        inputPath: '/test/input.wav',
        outputPath: '/test/output.m4a',
        format: AudioFormat.m4a,
        bitRate: 192, // Pass in kbps
        sampleRate: 44100,
      );

      expect(result.outputPath, '/test/output.m4a');
      expect(result.bitRate, 192); // Should return in kbps
      expect(result.sampleRate, 44100);
    });

    testWidgets('trimAudio receives bitRate in kbps and returns kbps', (WidgetTester tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'trimAudio') {
          final args = methodCall.arguments as Map;
          final bitRate = args['bitRate'] as int;

          // Dart sends bitRate in kbps (e.g., 128)
          expect(bitRate, equals(128));

          // Mock platform returns bitRate in kbps for consistency
          return {
            'outputPath': args['outputPath'],
            'durationMs': 15000,
            'bitRate': 128, // Return in kbps for Dart consistency
            'sampleRate': args['sampleRate'],
          };
        }
        return null;
      });

      final result = await audioToolkit.trimAudio(
        inputPath: '/test/input.wav',
        outputPath: '/test/output.m4a',
        startTimeMs: 5000,
        endTimeMs: 20000,
        format: AudioFormat.m4a,
        bitRate: 128, // Pass in kbps
        sampleRate: 44100,
      );

      expect(result.outputPath, '/test/output.m4a');
      expect(result.bitRate, 128); // Should return in kbps
      expect(result.sampleRate, 44100);
    });

    testWidgets('high quality bitRate 320 kbps works correctly', (WidgetTester tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'convertAudio') {
          final args = methodCall.arguments as Map;
          final bitRate = args['bitRate'] as int;

          // High quality: 320 kbps
          expect(bitRate, equals(320));

          return {
            'outputPath': args['outputPath'],
            'durationMs': 240000, // 4 minutes
            'bitRate': 320, // Return in kbps
            'sampleRate': args['sampleRate'],
          };
        }
        return null;
      });

      final result = await audioToolkit.convertAudio(
        inputPath: '/test/large_input.wav',
        outputPath: '/test/high_quality_output.m4a',
        format: AudioFormat.m4a,
        bitRate: 320, // High quality bitRate
        sampleRate: 44100,
      );

      expect(result.outputPath, '/test/high_quality_output.m4a');
      expect(result.bitRate, 320); // Should maintain high quality
      expect(result.durationMs, 240000); // 4 minutes
    });
  });
}
