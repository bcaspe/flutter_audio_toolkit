import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_toolkit/flutter_audio_toolkit.dart';

void main() {
  group('iOS Method Channel Tests', () {
    const MethodChannel channel = MethodChannel('flutter_audio_toolkit');
    late FlutterAudioToolkit toolkit;

    setUp(() {
      toolkit = FlutterAudioToolkit();
    });

    testWidgets('iOS platform version call works', (WidgetTester tester) async {
      // Mock the method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'getPlatformVersion') {
              return 'iOS 16.0';
            }
            return null;
          });

      final version = await toolkit.getPlatformVersion();
      expect(version, 'iOS 16.0');
    });

    testWidgets('iOS format support check works', (WidgetTester tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'isFormatSupported') {
              final args = methodCall.arguments as Map;
              final inputPath = args['inputPath'] as String;

              // Mock iOS format support
              if (inputPath.endsWith('.mp3') ||
                  inputPath.endsWith('.wav') ||
                  inputPath.endsWith('.m4a') ||
                  inputPath.endsWith('.aac')) {
                return true;
              }
              return false;
            }
            return null;
          });

      expect(await toolkit.isFormatSupported('/test/audio.mp3'), isTrue);
      expect(await toolkit.isFormatSupported('/test/audio.wav'), isTrue);
      expect(await toolkit.isFormatSupported('/test/audio.m4a'), isTrue);
      expect(await toolkit.isFormatSupported('/test/audio.aac'), isTrue);
      expect(await toolkit.isFormatSupported('/test/video.mp4'), isFalse);
      expect(await toolkit.isFormatSupported('/test/unknown.xyz'), isFalse);
    });

    testWidgets('iOS audio conversion method call works', (
      WidgetTester tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'convertAudio') {
              final args = methodCall.arguments as Map;

              // Validate required arguments for iOS
              expect(args['inputPath'], isNotNull);
              expect(args['outputPath'], isNotNull);
              expect(args['format'], isNotNull);
              expect(args['bitRate'], isA<int>());
              expect(args['sampleRate'], isA<int>());

              // Mock successful iOS conversion
              return {
                'outputPath': args['outputPath'],
                'durationMs': 30000,
                'bitRate': args['bitRate'],
                'sampleRate': args['sampleRate'],
              };
            }
            return null;
          });

      final result = await toolkit.convertAudio(
        inputPath: '/test/input.mp3',
        outputPath: '/test/output.m4a',
        format: AudioFormat.m4a,
        bitRate: 128,
        sampleRate: 44100,
      );

      expect(result.outputPath, '/test/output.m4a');
      expect(result.durationMs, 30000);
      expect(result.bitRate, 128);
      expect(result.sampleRate, 44100);
    });

    testWidgets('iOS error handling works correctly', (
      WidgetTester tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'convertAudio') {
              throw PlatformException(
                code: 'CONVERSION_ERROR',
                message: 'iOS audio conversion failed',
                details: 'AVAssetExportSession failed',
              );
            }
            return null;
          });

      expect(
        () async => await toolkit.convertAudio(
          inputPath: '/invalid/path.mp3',
          outputPath: '/invalid/output.m4a',
          format: AudioFormat.m4a,
        ),
        throwsA(isA<AudioConversionException>()),
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });
}
