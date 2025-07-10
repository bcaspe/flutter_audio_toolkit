import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'src/models/models.dart';

/// The interface that platform-specific implementations of flutter_audio_toolkit must implement.
///
/// Platform implementations should extend this class rather than implement it as `FlutterAudioToolkitPlatform`.
/// Extending this class (using `extends`) ensures that the subclass will get the default
/// implementation, while platform implementations that `implements` this interface
/// will be broken by newly added [FlutterAudioToolkitPlatform] methods.
abstract class FlutterAudioToolkitPlatform extends PlatformInterface {
  /// Constructs a FlutterAudioToolkitPlatform.
  FlutterAudioToolkitPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterAudioToolkitPlatform? _instance;

  /// The default instance of [FlutterAudioToolkitPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterAudioToolkit].
  static FlutterAudioToolkitPlatform get instance {
    if (_instance == null) {
      // Late import to avoid circular dependencies
      // This will be set by the method channel implementation
      throw UnimplementedError('Platform implementation not set');
    }
    return _instance!;
  }

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterAudioToolkitPlatform] when
  /// they register themselves.
  static set instance(FlutterAudioToolkitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // Platform Information
  /// Gets the platform version string
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  // Audio Conversion
  /// Converts an audio file to the specified format
  ///
  /// Supports converting between various audio formats with customizable quality settings.
  /// Uses native platform APIs for optimal performance and compatibility.
  ///
  /// [inputPath] - Path to the input audio file
  /// [outputPath] - Path where the converted file will be saved
  /// [format] - Target audio format (see [AudioFormat])
  /// [bitRate] - Target bit rate in kbps (default: 128)
  /// [sampleRate] - Target sample rate in Hz (default: 44100)
  /// [onProgress] - Optional callback for conversion progress (0.0 to 1.0)
  ///
  /// Returns [ConversionResult] with output file information.
  /// Throws [AudioConversionException] if conversion fails.
  Future<ConversionResult> convertAudio({
    required String inputPath,
    required String outputPath,
    required AudioFormat format,
    int bitRate = 128,
    int sampleRate = 44100,
    ProgressCallback? onProgress,
  }) {
    throw UnimplementedError('convertAudio() has not been implemented.');
  }

  // Audio Trimming
  /// Trims an audio file to the specified time range
  ///
  /// Supports both lossless and lossy trimming modes depending on format compatibility.
  /// Lossless trimming preserves original quality when possible.
  ///
  /// [inputPath] - Path to the input audio file
  /// [outputPath] - Path where the trimmed file will be saved
  /// [startTimeMs] - Start time in milliseconds
  /// [endTimeMs] - End time in milliseconds
  /// [format] - Output format (see [AudioFormat])
  /// [bitRate] - Target bit rate for lossy trimming (default: 128)
  /// [sampleRate] - Target sample rate for lossy trimming (default: 44100)
  /// [onProgress] - Optional callback for trimming progress (0.0 to 1.0)
  ///
  /// Returns [ConversionResult] with trimmed file information.
  /// Throws [AudioTrimmingException] if trimming fails.
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
    throw UnimplementedError('trimAudio() has not been implemented.');
  }

  // Waveform Extraction
  /// Extracts waveform amplitude data from an audio file
  ///
  /// Analyzes the audio file and extracts amplitude values for visualization.
  /// The extracted data can be used to create waveform displays in your UI.
  ///
  /// [inputPath] - Path to the input audio file
  /// [samplesPerSecond] - Number of amplitude samples per second (default: 100)
  /// [onProgress] - Optional callback for extraction progress (0.0 to 1.0)
  ///
  /// Returns [WaveformData] containing amplitude values and audio information.
  /// Throws [WaveformExtractionException] if extraction fails.
  Future<WaveformData> extractWaveform({
    required String inputPath,
    int samplesPerSecond = 100,
    ProgressCallback? onProgress,
  }) {
    throw UnimplementedError('extractWaveform() has not been implemented.');
  }

  // Audio Information & Analysis
  /// Gets comprehensive information about an audio file
  ///
  /// Analyzes the audio file and returns detailed information including format,
  /// duration, quality metrics, and compatibility information.
  ///
  /// [inputPath] - Path to the input audio file
  ///
  /// Returns [AudioInfo] with comprehensive file information.
  /// Throws [AudioAnalysisException] if analysis fails.
  Future<AudioInfo> getAudioInfo(String inputPath) {
    throw UnimplementedError('getAudioInfo() has not been implemented.');
  }

  /// Checks if the given audio format is supported for processing
  ///
  /// [inputPath] - Path to the audio file to check
  ///
  /// Returns true if the format is supported, false otherwise.
  Future<bool> isFormatSupported(String inputPath) {
    throw UnimplementedError('isFormatSupported() has not been implemented.');
  }

  // Noise Detection & Analysis
  /// Analyzes an audio file for noise detection and quality assessment
  ///
  /// Performs comprehensive audio analysis to detect background noise,
  /// audio quality issues, and provides recommendations for improvement.
  ///
  /// [inputPath] - Path to the input audio file
  /// [sensitivityLevel] - Noise detection sensitivity (0.0 to 1.0, default: 0.5)
  /// [onProgress] - Optional callback for analysis progress (0.0 to 1.0)
  ///
  /// Returns [NoiseDetectionResult] with analysis results and recommendations.
  /// Throws [NoiseAnalysisException] if analysis fails.
  Future<NoiseDetectionResult> analyzeAudioNoise({
    required String inputPath,
    double sensitivityLevel = 0.5,
    ProgressCallback? onProgress,
  }) {
    throw UnimplementedError('analyzeAudioNoise() has not been implemented.');
  }

  // Network Audio Processing
  /// Downloads and processes audio from a network URL
  ///
  /// Downloads audio from the specified URL to a local file and optionally
  /// processes it (conversion, trimming, waveform extraction).
  ///
  /// [url] - URL of the audio file to download
  /// [localPath] - Local path where the file will be saved
  /// [onDownloadProgress] - Optional callback for download progress (0.0 to 1.0)
  ///
  /// Returns the local file path when download completes.
  /// Throws [NetworkAudioException] if download fails.
  Future<String> downloadAudioFromUrl({
    required String url,
    required String localPath,
    ProgressCallback? onDownloadProgress,
  }) {
    throw UnimplementedError(
      'downloadAudioFromUrl() has not been implemented.',
    );
  }

  // Audio Session Configuration (iOS specific, no-op on other platforms)
  /// Configures the audio session for optimal audio processing
  ///
  /// This is primarily used on iOS to set up the audio session for recording
  /// and playback. On other platforms, this method may be a no-op.
  ///
  /// [configuration] - Audio session configuration options
  ///
  /// Returns true if configuration was successful.
  Future<bool> configureAudioSession({Map<String, dynamic>? configuration}) {
    throw UnimplementedError(
      'configureAudioSession() has not been implemented.',
    );
  }
}
