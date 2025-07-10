# Flutter Audio Toolkit

A comprehensive Flutter plugin for native audio processing that provides conversion, trimming, and waveform extraction capabilities using platform-specific APIs. Perfect for audio editing apps, music players, and audio visualization tools.

## 🚀 Features

- **🔄 Audio Conversion**: Convert audio files between formats (MP3, WAV, OGG → AAC, M4A)
- **✂️ Audio Trimming**: Precise audio trimming with lossless and lossy options
- **📊 Waveform Extraction**: Extract amplitude data for visual waveform displays
- **🎨 Fake Waveform Generation**: Generate realistic waveform patterns for testing and previews
- **🌐 Network Audio Processing**: Download and process audio files from URLs
- **📋 Audio Analysis**: Comprehensive audio file information and metadata
- **⚡ Native Performance**: Uses platform-optimized native libraries (MediaCodec, AVFoundation)
- **📈 Progress Tracking**: Real-time progress callbacks for all operations
- **🔍 Format Detection**: Automatic audio format detection and compatibility checking
- **💾 Lossless Processing**: Support for lossless audio trimming without re-encoding

## 📱 Platform Support

| Platform | Audio Conversion | Audio Trimming | Waveform Extraction | Lossless Processing | Implementation |
|----------|-----------------|----------------|-------------------|-------------------|----------------|
| Android  | ✅ | ✅ | ✅ | ✅ | MediaCodec, MediaMuxer, MediaExtractor |
| iOS      | ✅ | ✅ | ✅ | ✅ | AVAudioConverter, AVAssetExportSession, AVAssetReader |

### Supported Audio Formats

**Input Formats**: MP3, M4A, AAC, WAV, OGG  
**Output Formats**: AAC, M4A, Original (for lossless trimming)

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_audio_toolkit: ^1.0.0
```

## 📖 Usage

### Basic Setup

```dart
import 'package:flutter_audio_toolkit/flutter_audio_toolkit.dart';

class AudioProcessor {
  final audioToolkit = FlutterAudioToolkit();
  
  Future<void> processAudio() async {
    // Your audio processing code here
  }
}
```

### 🔍 Audio Information & Analysis

Get comprehensive information about audio files including format details, compatibility, and metadata:

```dart
// Get detailed audio file information
final audioInfo = await audioToolkit.getAudioInfo('/path/to/audio.mp3');

// Access audio properties
print('Format: ${audioInfo['mime']}');                    // e.g., "audio/mpeg"
print('Duration: ${audioInfo['durationMs']}ms');          // Duration in milliseconds
print('Sample Rate: ${audioInfo['sampleRate']}Hz');       // e.g., 44100
print('Channels: ${audioInfo['channels']}');              // e.g., 2 (stereo)
print('Bit Rate: ${audioInfo['bitRate']}bps');           // Bit rate in bits per second
print('File Size: ${audioInfo['fileSize']}bytes');        // File size in bytes

// Feature compatibility checking
print('Conversion Support: ${audioInfo['supportedForConversion']}');      // true/false
print('Trimming Support: ${audioInfo['supportedForTrimming']}');          // true/false
print('Lossless Trimming: ${audioInfo['supportedForLosslessTrimming']}'); // true/false
print('Waveform Support: ${audioInfo['supportedForWaveform']}');          // true/false

// Format diagnostics
print('Format Details: ${audioInfo['formatDiagnostics']}');  // Human-readable format info
print('Found Tracks: ${audioInfo['foundTracks']}');          // List of detected tracks

// Validation status
if (audioInfo['isValid'] == true) {
  print('✅ Audio file is valid and ready for processing');
} else {
  print('❌ Error: ${audioInfo['error']}');
  print('Details: ${audioInfo['details']}');
}
```

### 🔄 Audio Conversion

Convert audio files between different formats with customizable quality settings:

```dart
// Convert MP3 to M4A with custom settings
final result = await audioToolkit.convertAudio(
  inputPath: '/path/to/input.mp3',
  outputPath: '/path/to/output.m4a',
  format: AudioFormat.m4a,
  bitRate: 128,      // Quality: 128kbps
  sampleRate: 44100, // Standard sample rate
  onProgress: (progress) {
    print('Conversion progress: ${(progress * 100).toStringAsFixed(1)}%');
  },
);

print('✅ Converted to: ${result.outputPath}');
print('Duration: ${result.durationMs}ms');
print('Bit Rate: ${result.bitRate}bps');
print('Sample Rate: ${result.sampleRate}Hz');
```

### ✂️ Audio Trimming

Trim audio files with precision, supporting both lossless and lossy processing:

```dart
// Lossless trimming (preserves original quality)
final losslessResult = await audioToolkit.trimAudio(
  inputPath: '/path/to/input.m4a',
  outputPath: '/path/to/trimmed.m4a',
  startTimeMs: 10000,  // Start at 10 seconds
  endTimeMs: 30000,    // End at 30 seconds
  format: AudioFormat.copy, // Lossless copy
  onProgress: (progress) {
    print('Trimming progress: ${(progress * 100).toStringAsFixed(1)}%');
  },
);

// Lossy trimming with format conversion
final lossyResult = await audioToolkit.trimAudio(
  inputPath: '/path/to/input.mp3',
  outputPath: '/path/to/trimmed.m4a',
  startTimeMs: 5000,   // Start at 5 seconds
  endTimeMs: 25000,    // End at 25 seconds
  format: AudioFormat.m4a,
  bitRate: 192,        // Higher quality
  sampleRate: 48000,   // Higher sample rate
  onProgress: (progress) {
    print('Converting and trimming: ${(progress * 100).toStringAsFixed(1)}%');
  },
);
```

### 📊 Waveform Extraction

Extract waveform data for audio visualization and analysis:

```dart
// Extract waveform data
final waveformData = await audioToolkit.extractWaveform(
  inputPath: '/path/to/audio.mp3',
  samplesPerSecond: 100, // Resolution: 100 samples per second
  onProgress: (progress) {
    print('Extraction progress: ${(progress * 100).toStringAsFixed(1)}%');
  },
);

// Use waveform data for visualization
print('Samples: ${waveformData.amplitudes.length}');
print('Duration: ${waveformData.durationMs}ms');
print('Sample Rate: ${waveformData.sampleRate}Hz');
print('Channels: ${waveformData.channels}');

// Amplitude values are normalized (0.0 to 1.0)
for (int i = 0; i < waveformData.amplitudes.length; i++) {
  final amplitude = waveformData.amplitudes[i];
  final timeMs = (i / waveformData.samplesPerSecond) * 1000;
  print('Time: ${timeMs.toStringAsFixed(1)}ms, Amplitude: ${amplitude.toStringAsFixed(3)}');
}
```

### 🎨 Fake Waveform Generation

Generate realistic-looking fake waveform data for testing, previews, or when you need to display waveforms without the overhead of processing actual audio files:

```dart
// Generate different waveform patterns
final musicWaveform = audioToolkit.generateFakeWaveform(
  pattern: WaveformPattern.music,
  durationMs: 30000,        // 30 seconds
  samplesPerSecond: 100,    // 100 samples per second
  frequency: 440.0,         // Base frequency in Hz
);

final speechWaveform = audioToolkit.generateFakeWaveform(
  pattern: WaveformPattern.speech,
  durationMs: 15000,        // 15 seconds
  samplesPerSecond: 120,    // Higher resolution
);

// Available patterns
enum WaveformPattern {
  sine,    // Smooth sine wave pattern
  random,  // Random amplitude values
  music,   // Music-like with beats and dynamics
  speech,  // Speech-like with pauses and variations
  pulse,   // Rhythmic pulse/beat pattern
  fade,    // Gradual fade in/out
  burst,   // Sudden bursts with quiet periods
}
```

### 🌐 Network Audio Processing

Process audio files directly from network URLs:

```dart
// Extract real waveform from network audio file
final networkWaveform = await audioToolkit.extractWaveformFromUrl(
  url: 'https://example.com/audio.mp3',
  localPath: '/tmp/downloaded_audio.mp3',
  samplesPerSecond: 100,
  onDownloadProgress: (progress) {
    print('Download: ${(progress * 100).toStringAsFixed(1)}%');
  },
  onExtractionProgress: (progress) {
    print('Extraction: ${(progress * 100).toStringAsFixed(1)}%');
  },
);

// Generate consistent fake waveform for a URL (useful for previews)
final fakeUrlWaveform = audioToolkit.generateFakeWaveformForUrl(
  url: 'https://example.com/audio.mp3',
  pattern: WaveformPattern.music,
  estimatedDurationMs: 180000, // 3 minutes estimated
  samplesPerSecond: 100,
);
```

### 🔍 Format Validation

Check format compatibility before processing:

```dart
// Check if file format is supported
final isSupported = await audioToolkit.isFormatSupported('/path/to/audio.unknown');

if (isSupported) {
  print('✅ Format is supported for processing');
  // Proceed with conversion/trimming/extraction
} else {
  print('❌ Unsupported format. Please use MP3, M4A, AAC, WAV, or OGG files');
}
```

## 📚 API Reference

### FlutterAudioToolkit

Main class providing audio conversion, trimming, and waveform extraction capabilities.

#### Methods

##### `getAudioInfo(String inputPath)`
Analyzes an audio file and returns comprehensive information about its properties and compatibility.

```dart
Future<Map<String, dynamic>> getAudioInfo(String inputPath)
```

**Returns**: A `Map<String, dynamic>` containing:

| Key | Type | Description |
|-----|------|-------------|
| `isValid` | `bool` | Whether the file is valid and processable |
| `mime` | `String` | MIME type (e.g., "audio/mpeg", "audio/mp4") |
| `durationMs` | `int` | Duration in milliseconds |
| `sampleRate` | `int` | Sample rate in Hz (e.g., 44100) |
| `channels` | `int` | Number of audio channels (1=mono, 2=stereo) |
| `bitRate` | `int` | Bit rate in bits per second |
| `fileSize` | `int` | File size in bytes |
| `supportedForConversion` | `bool` | Can be used for format conversion |
| `supportedForTrimming` | `bool` | Can be trimmed/edited |
| `supportedForLosslessTrimming` | `bool` | Supports lossless trimming |
| `supportedForWaveform` | `bool` | Can extract waveform data |
| `formatDiagnostics` | `String` | Human-readable format details |
| `foundTracks` | `List<String>` | List of detected audio tracks |
| `error` | `String?` | Error message if `isValid` is false |
| `details` | `String?` | Additional error details |

##### `convertAudio()`
Converts an audio file to a different format.

```dart
Future<ConversionResult> convertAudio({
  required String inputPath,
  required String outputPath,
  required AudioFormat format,
  int bitRate = 128,
  int sampleRate = 44100,
  ProgressCallback? onProgress,
})
```

**Parameters**:
- `inputPath`: Source audio file path (MP3, WAV, OGG, M4A, AAC)
- `outputPath`: Destination file path
- `format`: Target format (`AudioFormat.m4a` - AAC codec in M4A container for universal compatibility)
- `bitRate`: Quality in kbps (32-320, default: 128)
- `sampleRate`: Sample rate in Hz (8000-192000, default: 44100)
- `onProgress`: Optional progress callback (0.0-1.0)

##### `trimAudio()`
Trims an audio file to a specific time range with optional format conversion.

```dart
Future<ConversionResult> trimAudio({
  required String inputPath,
  required String outputPath,
  required int startTimeMs,
  required int endTimeMs,
  required AudioFormat format,
  int bitRate = 128,
  int sampleRate = 44100,
  ProgressCallback? onProgress,
})
```

**Parameters**:
- `inputPath`: Source audio file path
- `outputPath`: Destination file path
- `startTimeMs`: Start time in milliseconds
- `endTimeMs`: End time in milliseconds
- `format`: Output format (`AudioFormat.m4a` - AAC codec in M4A container, or `AudioFormat.copy` for lossless)
- `bitRate`: Quality for lossy formats (ignored for lossless)
- `sampleRate`: Sample rate for lossy formats (ignored for lossless)
- `onProgress`: Optional progress callback (0.0-1.0)

##### `extractWaveform()`
Extracts amplitude data from an audio file for waveform visualization.

```dart
Future<WaveformData> extractWaveform({
  required String inputPath,
  int samplesPerSecond = 100,
  ProgressCallback? onProgress,
})
```