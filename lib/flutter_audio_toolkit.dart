import 'package:flutter_audio_toolkit/src/core/audio_service.dart';

import 'flutter_audio_toolkit_platform_interface.dart';
import 'flutter_audio_toolkit_method_channel.dart';
import 'src/generators/waveform_generator.dart';
import 'src/models/models.dart';

// Re-export all models and types for public API
export 'src/models/models.dart';

// Export audio player widgets and services (these still use the service layer)
export 'src/widgets/true_waveform_audio_player.dart';
export 'src/widgets/fake_waveform_audio_player.dart';
export 'src/widgets/audio_player_controls.dart';
export 'src/widgets/waveform_visualizer.dart';
export 'src/core/audio_player_service.dart';

// Export utilities
export 'src/utils/path_provider_util.dart';
export 'src/utils/audio_error_handler.dart';

/// Main class for audio conversion, trimming, and waveform extraction
///
/// This class provides a high-level API for audio processing operations
/// using native platform implementations. All heavy operations are delegated
/// to specialized service classes for better maintainability and testability.
class FlutterAudioToolkit {
  // Ensure platform instance is set
  static bool _initialized = false;

  static void _ensureInitialized() {
    if (!_initialized) {
      FlutterAudioToolkitPlatform.instance = MethodChannelFlutterAudioToolkit();
      _initialized = true;
    }
  }

  /// Gets the platform version
  Future<String?> getPlatformVersion() {
    _ensureInitialized();
    return FlutterAudioToolkitPlatform.instance.getPlatformVersion();
  }

  /// Splices multiple audio files into a single output file
///
/// Combines multiple audio files sequentially into one continuous audio file.
/// All input files are processed and concatenated with proper timestamp adjustment
/// to ensure seamless playback without gaps or overlaps.
///
/// [inputPaths] - List of paths to input audio files to splice together
/// [outputPath] - Path where the spliced file will be saved
/// [format] - Target audio format (M4A recommended for universal compatibility)
/// [bitRate] - Target bit rate in kbps (default: 128)
/// [sampleRate] - Target sample rate in Hz (default: 44100)
/// [onProgress] - Optional callback for splicing progress
///
/// M4A format with AAC codec provides optimal cross-platform compatibility
/// and high-quality audio with excellent compression for spliced content.
Future<ConversionResult> spliceAudio({
  required List<String> inputPaths,
  required String outputPath,
  required AudioFormat format,
  int bitRate = 128,
  int sampleRate = 44100,
  ProgressCallback? onProgress,
}) {
  _ensureInitialized();
  return FlutterAudioToolkitPlatform.instance.spliceAudio(
    inputPaths: inputPaths,
    outputPath: outputPath,
    format: format,
    bitRate: bitRate,
    sampleRate: sampleRate,
    onProgress: onProgress,
  );
}

  /// Converts an audio file to M4A format with AAC codec
  ///
  /// [inputPath] - Path to the input audio file (mp3, wav, ogg)
  /// [outputPath] - Path where the converted file will be saved
  /// [format] - Target audio format (M4A recommended for universal compatibility)
  /// [bitRate] - Target bit rate in kbps (default: 128)
  /// [sampleRate] - Target sample rate in Hz (default: 44100)
  /// [onProgress] - Optional callback for conversion progress
  ///
  /// M4A format with AAC codec provides optimal cross-platform compatibility
  /// and high-quality audio with excellent compression.
  Future<ConversionResult> convertAudio({
    required String inputPath,
    required String outputPath,
    required AudioFormat format,
    int bitRate = 128,
    int sampleRate = 44100,
    ProgressCallback? onProgress,
  }) {
    _ensureInitialized();
    return FlutterAudioToolkitPlatform.instance.convertAudio(
      inputPath: inputPath,
      outputPath: outputPath,
      format: format,
      bitRate: bitRate,
      sampleRate: sampleRate,
      onProgress: onProgress,
    );
  }

  /// Extracts waveform data from an audio file
  ///
  /// [inputPath] - Path to the input audio file
  /// [samplesPerSecond] - Number of amplitude samples per second (default: 100)
  /// [onProgress] - Optional callback for extraction progress
  Future<WaveformData> extractWaveform({
    required String inputPath,
    int samplesPerSecond = 100,
    ProgressCallback? onProgress,
  }) {
    _ensureInitialized();
    return FlutterAudioToolkitPlatform.instance.extractWaveform(
      inputPath: inputPath,
      samplesPerSecond: samplesPerSecond,
      onProgress: onProgress,
    );
  }

  /// Checks if the given audio format is supported for conversion
  Future<bool> isFormatSupported(String inputPath) {
    _ensureInitialized();
    return FlutterAudioToolkitPlatform.instance.isFormatSupported(inputPath);
  }

  /// Gets comprehensive audio file information
  ///
  /// Returns detailed information about the audio file including format,
  /// duration, quality metrics, and compatibility information.
  Future<AudioInfo> getAudioInfo(String inputPath) {
    _ensureInitialized();
    return FlutterAudioToolkitPlatform.instance.getAudioInfo(inputPath);
  }

  /// Trims an audio file to the specified time range
  ///
  /// [inputPath] - Path to the input audio file
  /// [outputPath] - Path where the trimmed file will be saved
  /// [startTimeMs] - Start time in milliseconds
  /// [endTimeMs] - End time in milliseconds
  /// [format] - Target audio format (M4A recommended for precision)
  /// [bitRate] - Target bit rate in kbps (default: 128)
  /// [sampleRate] - Target sample rate in Hz (default: 44100)
  /// [onProgress] - Optional callback for trimming progress
  ///
  /// M4A format ensures precise trimming with frame-accurate cutting
  /// and maintains high audio quality across all platforms.
  Future<ConversionResult> trimAudio({
    required String inputPath,
    required String outputPath,
    required int startTimeMs,
    required int endTimeMs,
    required AudioFormat format,
    int bitRate = 128,
    int sampleRate = 44100,
    ProgressCallback? onProgress,
  }) {
    _ensureInitialized();
    return FlutterAudioToolkitPlatform.instance.trimAudio(
      inputPath: inputPath,
      outputPath: outputPath,
      startTimeMs: startTimeMs,
      endTimeMs: endTimeMs,
      format: format,
      bitRate: bitRate,
      sampleRate: sampleRate,
      onProgress: onProgress,
    );
  }

  /// Generates fake waveform data for preview purposes
  ///
  /// [pattern] - Waveform pattern to generate
  /// [durationMs] - Duration in milliseconds (default: 30000 = 30 seconds)
  /// [samplesPerSecond] - Samples per second (default: 100)
  /// [frequency] - Base frequency for pattern generation (default: 440.0 Hz)
  /// [sampleRate] - Sample rate in Hz (default: 44100)
  /// [channels] - Number of audio channels (default: 2 for stereo)
  ///
  /// Returns a [WaveformData] object containing the generated waveform
  WaveformData generateFakeWaveform({
    required WaveformPattern pattern,
    int durationMs = 30000, // 30 seconds default
    int samplesPerSecond = 100,
    double frequency = 440.0,
    int sampleRate = 44100,
    int channels = 2,
  }) {
    return WaveformGenerator.generateFakeWaveform(
      pattern: pattern,
      durationMs: durationMs,
      samplesPerSecond: samplesPerSecond,
      frequency: frequency,
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  /// Generates a styled waveform with visual configuration
  ///
  /// [pattern] - Waveform pattern to generate
  /// [style] - Visual style configuration for the waveform
  /// [durationMs] - Duration of the waveform in milliseconds (default: 30000 = 30 seconds)
  /// [samplesPerSecond] - Number of amplitude samples per second (default: 100)
  /// [frequency] - Base frequency for pattern generation (default: 440.0 Hz)
  /// [sampleRate] - Sample rate in Hz (default: 44100)
  /// [channels] - Number of audio channels (default: 2 for stereo)
  ///
  /// Returns a [WaveformData] object with the specified style
  WaveformData generateStyledWaveform({
    required WaveformPattern pattern,
    required WaveformStyle style,
    int durationMs = 30000,
    int samplesPerSecond = 100,
    double frequency = 440.0,
    int sampleRate = 44100,
    int channels = 2,
  }) {
    return WaveformGenerator.generateStyledWaveform(
      pattern: pattern,
      style: style,
      durationMs: durationMs,
      samplesPerSecond: samplesPerSecond,
      frequency: frequency,
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  /// Generates a themed waveform with automatic styling
  ///
  /// [pattern] - Waveform pattern to generate (style is automatically selected)
  /// [durationMs] - Duration of the waveform in milliseconds (default: 30000 = 30 seconds)
  /// [samplesPerSecond] - Number of amplitude samples per second (default: 100)
  ///
  /// Returns a [WaveformData] object with automatically selected styling
  WaveformData generateThemedWaveform({
    required WaveformPattern pattern,
    int durationMs = 30000,
    int samplesPerSecond = 100,
  }) {
    return WaveformGenerator.generateThemedWaveform(
      pattern: pattern,
      durationMs: durationMs,
      samplesPerSecond: samplesPerSecond,
    );
  }

  /// Downloads an audio file from a network URL and extracts its waveform
  ///
  /// [url] - URL of the audio file to download
  /// [localPath] - Local path where the downloaded file will be saved temporarily
  /// [samplesPerSecond] - Number of amplitude samples per second (default: 100)
  /// [onDownloadProgress] - Optional callback for download progress (0.0 to 0.5)
  /// [onExtractionProgress] - Optional callback for waveform extraction progress (0.5 to 1.0)
  ///
  /// Returns a [WaveformData] object containing the extracted waveform
  Future<WaveformData> extractWaveformFromUrl({
    required String url,
    required String localPath,
    int samplesPerSecond = 100,
    ProgressCallback? onDownloadProgress,
    ProgressCallback? onExtractionProgress,
  }) {
    return AudioService.extractWaveformFromUrl(
      url: url,
      localPath: localPath,
      samplesPerSecond: samplesPerSecond,
      onDownloadProgress: onDownloadProgress,
      onExtractionProgress: onExtractionProgress,
    );
  }

  /// Generates fake waveform for network audio without downloading
  /// Useful for quick previews without the overhead of downloading
  ///
  /// [url] - URL of the audio file (used for consistent pattern generation)
  /// [pattern] - Waveform pattern to generate
  /// [estimatedDurationMs] - Estimated duration (default: 180000 = 3 minutes)
  /// [samplesPerSecond] - Samples per second (default: 100)
  ///
  /// Returns a [WaveformData] object with realistic-looking waveform data
  WaveformData generateFakeWaveformForUrl({
    required String url,
    required WaveformPattern pattern,
    int estimatedDurationMs = 180000, // 3 minutes default
    int samplesPerSecond = 100,
  }) {
    return WaveformGenerator.generateFakeWaveformForUrl(
      url: url,
      pattern: pattern,
      estimatedDurationMs: estimatedDurationMs,
      samplesPerSecond: samplesPerSecond,
    );
  }

  /// Downloads an audio file from the given URL and saves it to the local file system
  ///
  /// [url] - URL of the audio file to download
  /// [outputPath] - Local path where the downloaded file will be saved
  /// [onProgress] - Optional callback for download progress
  Future<String> downloadFile(
    String url,
    String outputPath, {
    ProgressCallback? onProgress,
  }) {
    return AudioService.downloadFile(url, outputPath, onProgress: onProgress);
  }

  /// Extracts comprehensive metadata from an audio file
  ///
  /// [inputPath] - Path to the input audio file
  ///
  /// Returns an [AudioMetadata] object containing all available metadata including
  /// title, artist, album, duration, bitrate, sample rate, and more
  Future<AudioMetadata> extractMetadata(String inputPath) {
    return AudioService.extractMetadata(inputPath);
  }

  /// Extracts metadata from a network audio file
  ///
  /// [url] - URL of the audio file
  /// [localPath] - Temporary local path for downloading
  /// [onProgress] - Optional callback for download progress
  ///
  /// Returns an [AudioMetadata] object containing all available metadata
  Future<AudioMetadata> extractMetadataFromUrl({
    required String url,
    required String localPath,
    ProgressCallback? onProgress,
  }) {
    return AudioService.extractMetadataFromUrl(
      url: url,
      localPath: localPath,
      onProgress: onProgress,
    );
  }

  /// Analyzes an audio file for noise detection and quality assessment
  ///
  /// [inputPath] - Path to the input audio file
  /// [sensitivityLevel] - Noise detection sensitivity (0.0 to 1.0, default: 0.5)
  /// [onProgress] - Optional callback for analysis progress
  ///
  /// Returns a comprehensive [NoiseDetectionResult] with:
  /// - Overall noise level assessment
  /// - Volume level analysis
  /// - Detected background noises (traffic, dogs, etc.)
  /// - Audio quality metrics
  /// - Frequency analysis
  /// - Time-based segment analysis
  /// - Recommendations for improvement
  Future<NoiseDetectionResult> analyzeNoise({
    required String inputPath,
    double sensitivityLevel = 0.5,
    ProgressCallback? onProgress,
  }) {
    _ensureInitialized();
    return FlutterAudioToolkitPlatform.instance.analyzeAudioNoise(
      inputPath: inputPath,
      sensitivityLevel: sensitivityLevel,
      onProgress: onProgress,
    );
  }

  /// Analyzes an audio file for noise detection and quality assessment
  ///
  /// [inputPath] - Path to the input audio file
  /// [segmentDurationMs] - Duration of analysis segments in milliseconds (default: 5000)
  /// [onProgress] - Optional callback for analysis progress
  ///
  /// Returns a comprehensive [NoiseDetectionResult] with:
  /// - Overall noise level assessment
  /// - Volume level analysis
  /// - Detected background noises (traffic, dogs, etc.)
  /// - Audio quality metrics
  /// - Frequency analysis
  /// - Time-based segment analysis
  /// - Recommendations for improvement
  /// (This method is deprecated - use the new analyzeNoise method below)
  @Deprecated('Use analyzeNoise instead')
  Future<NoiseDetectionResult> analyzeNoiseWithSegments({
    required String inputPath,
    int segmentDurationMs = 5000,
    ProgressCallback? onProgress,
  }) {
    _ensureInitialized();
    return FlutterAudioToolkitPlatform.instance.analyzeAudioNoise(
      inputPath: inputPath,
      sensitivityLevel: 0.5, // Default sensitivity
      onProgress: onProgress,
    );
  }

  /// Analyzes audio from a network URL for noise detection
  /// (This method is deprecated - use downloadAudioFromUrl + analyzeNoise instead)
  @Deprecated('Use downloadAudioFromUrl + analyzeNoise instead')
  Future<NoiseDetectionResult> analyzeNoiseFromUrl({
    required String url,
    required String localPath,
    double sensitivityLevel = 0.5,
    ProgressCallback? onDownloadProgress,
    ProgressCallback? onAnalysisProgress,
  }) async {
    // Legacy implementation using service layer
    final audioPath = await downloadAudioFromUrl(
      url: url,
      localPath: localPath,
      onDownloadProgress: onDownloadProgress,
    );

    return analyzeNoise(
      inputPath: audioPath,
      sensitivityLevel: sensitivityLevel,
      onProgress: onAnalysisProgress,
    );
  }

  /// Downloads an audio file from a network URL
  ///
  /// [url] - URL of the audio file to download
  /// [localPath] - Local path where the downloaded file will be saved
  /// [onDownloadProgress] - Optional callback for download progress
  ///
  /// Returns the local file path when download completes.
  Future<String> downloadAudioFromUrl({
    required String url,
    required String localPath,
    ProgressCallback? onDownloadProgress,
  }) {
    _ensureInitialized();
    return FlutterAudioToolkitPlatform.instance.downloadAudioFromUrl(
      url: url,
      localPath: localPath,
      onDownloadProgress: onDownloadProgress,
    );
  }

  /// Configures the audio session for optimal audio processing
  ///
  /// This is primarily used on iOS to set up the audio session for recording
  /// and playback. On other platforms, this method may be a no-op.
  ///
  /// [configuration] - Audio session configuration options
  ///
  /// Returns true if configuration was successful.
  Future<bool> configureAudioSession({Map<String, dynamic>? configuration}) {
    _ensureInitialized();
    return FlutterAudioToolkitPlatform.instance.configureAudioSession(
      configuration: configuration,
    );
  }
}
