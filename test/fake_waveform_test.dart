import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_audio_toolkit/flutter_audio_toolkit.dart';

void main() {
  group('Fake Waveform Generation Tests', () {
    late FlutterAudioToolkit audioToolkit;

    setUp(() {
      audioToolkit = FlutterAudioToolkit();
    });

    test('generateFakeWaveform creates correct data structure', () {
      final waveform = audioToolkit.generateFakeWaveform(
        pattern: WaveformPattern.sine,
        durationMs: 1000, // 1 second
        samplesPerSecond: 10, // 10 samples per second
      );

      expect(
        waveform.amplitudes.length,
        equals(10),
      ); // 1 second * 10 samples/second
      expect(waveform.durationMs, equals(1000));
      expect(waveform.sampleRate, equals(44100));
      expect(waveform.channels, equals(2));

      // All amplitudes should be between 0.0 and 1.0
      for (final amplitude in waveform.amplitudes) {
        expect(amplitude, greaterThanOrEqualTo(0.0));
        expect(amplitude, lessThanOrEqualTo(1.0));
      }
    });

    test('all waveform patterns generate valid data', () {
      for (final pattern in WaveformPattern.values) {
        final waveform = audioToolkit.generateFakeWaveform(
          pattern: pattern,
          durationMs: 2000, // 2 seconds
          samplesPerSecond: 50,
        );

        expect(
          waveform.amplitudes.length,
          equals(100),
        ); // 2 seconds * 50 samples/second
        expect(waveform.amplitudes.isNotEmpty, isTrue);

        // Check that amplitudes are within valid range
        for (final amplitude in waveform.amplitudes) {
          expect(amplitude, greaterThanOrEqualTo(0.0));
          expect(amplitude, lessThanOrEqualTo(1.0));
        }
      }
    });

    test('music pattern has realistic characteristics', () {
      final waveform = audioToolkit.generateFakeWaveform(
        pattern: WaveformPattern.music,
        durationMs: 5000, // 5 seconds
        samplesPerSecond: 100,
      );

      // Music pattern should have variation (not all same value)
      final uniqueValues = waveform.amplitudes.toSet();
      expect(
        uniqueValues.length,
        greaterThan(10),
      ); // Should have many different amplitude values      // Should have some higher energy (music typically has peaks)
      final highEnergyCount = waveform.amplitudes.where((a) => a > 0.3).length;
      expect(highEnergyCount, greaterThan(0));
    });

    test('speech pattern has characteristic pauses', () {
      final waveform = audioToolkit.generateFakeWaveform(
        pattern: WaveformPattern.speech,
        durationMs: 3000, // 3 seconds
        samplesPerSecond: 100,
      );

      // Speech should have low-energy periods (pauses)
      final lowEnergyCount = waveform.amplitudes.where((a) => a < 0.1).length;
      expect(
        lowEnergyCount,
        greaterThan(10),
      ); // Should have several quiet moments
    });
    test('pulse pattern has rhythmic characteristics', () {
      final waveform = audioToolkit.generateFakeWaveform(
        pattern: WaveformPattern.pulse,
        durationMs: 4000, // 4 seconds
        samplesPerSecond: 100,
      );

      final highEnergyCount = waveform.amplitudes.where((a) => a > 0.8).length;
      final midEnergyCount =
          waveform.amplitudes.where((a) => a > 0.5 && a <= 0.8).length;

      expect(highEnergyCount, greaterThan(0)); // Should have strong beats
      expect(midEnergyCount, greaterThan(0)); // Should have varied amplitudes
      expect(waveform.amplitudes.isNotEmpty, true); // Basic sanity check
    });

    test(
      'generateFakeWaveformForUrl creates consistent results for same URL',
      () {
        const testUrl = 'https://example.com/test.mp3';

        final waveform1 = audioToolkit.generateFakeWaveformForUrl(
          url: testUrl,
          pattern: WaveformPattern.music,
          estimatedDurationMs: 5000,
        );

        final waveform2 = audioToolkit.generateFakeWaveformForUrl(
          url: testUrl,
          pattern: WaveformPattern.music,
          estimatedDurationMs: 5000,
        );

        // Same URL should produce identical waveforms
        expect(
          waveform1.amplitudes.length,
          equals(waveform2.amplitudes.length),
        );
        for (int i = 0; i < waveform1.amplitudes.length; i++) {
          expect(
            waveform1.amplitudes[i],
            closeTo(waveform2.amplitudes[i], 0.1),
            reason:
                'Amplitude at index $i should be somewhat consistent for same URL',
          );
        }
      },
    );

    test('different URLs produce different waveforms', () {
      const url1 = 'https://example.com/song1.mp3';
      const url2 = 'https://example.com/song2.mp3';

      final waveform1 = audioToolkit.generateFakeWaveformForUrl(
        url: url1,
        pattern: WaveformPattern.music,
        estimatedDurationMs: 3000,
      );

      final waveform2 = audioToolkit.generateFakeWaveformForUrl(
        url: url2,
        pattern: WaveformPattern.music,
        estimatedDurationMs: 3000,
      );

      // Different URLs should produce different waveforms
      bool foundDifference = false;
      for (
        int i = 0;
        i < waveform1.amplitudes.length && i < waveform2.amplitudes.length;
        i++
      ) {
        if ((waveform1.amplitudes[i] - waveform2.amplitudes[i]).abs() > 0.001) {
          foundDifference = true;
          break;
        }
      }

      expect(
        foundDifference,
        isTrue,
        reason: 'Different URLs should produce different waveforms',
      );
    });

    test('custom parameters work correctly', () {
      final waveform = audioToolkit.generateFakeWaveform(
        pattern: WaveformPattern.sine,
        durationMs: 3000,
        samplesPerSecond: 25,
        frequency: 880.0, // Custom frequency
        sampleRate: 22050, // Custom sample rate
        channels: 1, // Mono
      );

      expect(
        waveform.amplitudes.length,
        equals(75),
      ); // 3 seconds * 25 samples/second
      expect(waveform.durationMs, equals(3000));
      expect(waveform.sampleRate, equals(22050));
      expect(waveform.channels, equals(1));
    });
  });
}
