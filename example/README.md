# Flutter Audio Toolkit Example

This example app demonstrates the capabilities of the Flutter Audio Toolkit package, showcasing audio conversion, trimming, waveform extraction, and playback features.

## Features

### Enhanced Audio Conversion
- Convert audio files to M4A format (AAC codec in M4A container) for universal compatibility
- Support for lossless copy mode to preserve original quality
- Configurable bit rate settings for quality control
- Progress tracking during conversion

### Improved Audio Trimming
- Precise audio trimming with millisecond accuracy
- Support for both M4A output and lossless copy modes
- Cross-platform compatibility for iOS and Android
- Interactive trim range selection with visual feedback
- Quality settings for optimized output

### Waveform Visualization
- Extract real waveform data from audio files
- Generate fake waveforms for quick previews
- Multiple waveform pattern options
- Interactive waveform visualization with playback position

### Audio Player Demo
- True waveform audio player with extracted data
- Fake waveform audio player with generated patterns
- Custom player implementation
- Remote audio playback support

### Noise Detection
- Analyze audio files for noise and quality assessment
- Detect background noises and issues
- Get recommendations for improvement

## Getting Started

1. Clone the repository
2. Run `flutter pub get` in the example directory
3. Connect a device or start an emulator
4. Run `flutter run` to start the app

## Implementation Notes

### M4A Format Support
The example app now fully supports M4A format (AAC codec in M4A container) for both conversion and trimming operations. This format provides the best cross-platform compatibility across iOS, Android, web, and desktop platforms.

### Enhanced Audio Trimming
The trimming functionality has been improved to work consistently across both Android and iOS platforms. The implementation now handles edge cases better and provides more accurate trimming results.

### Platform-Specific Considerations
- **iOS**: Files are saved to the app's Documents directory, accessible via the Files app
- **Android**: Files are saved to the Downloads directory for easy access

## Usage Examples

### Convert Audio to M4A Format
```dart
final result = await audioToolkit.convertAudio(
  inputPath: '/path/to/input.mp3',
  outputPath: '/path/to/output.m4a',
  format: AudioFormat.m4a,
  bitRate: 192,
  sampleRate: 44100,
  onProgress: (progress) {
    print('Conversion progress: ${progress * 100}%');
  },
);
```

### Trim Audio with Original Format
```dart
final result = await audioToolkit.trimAudio(
  inputPath: '/path/to/input.m4a',
  outputPath: '/path/to/trimmed.m4a',
  startTimeMs: 1000, // 1 second
  endTimeMs: 6000,   // 6 seconds
  format: AudioFormat.copy, // Keep original format
  onProgress: (progress) {
    print('Trimming progress: ${progress * 100}%');
  },
);
```

## License

This example app is part of the Flutter Audio Toolkit package, licensed under the MIT License.
