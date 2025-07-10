import '../models/models.dart';
import '../network/network_service.dart';
import '../../flutter_audio_toolkit_platform_interface.dart';

/// Core audio operations service that handles platform-specific functionality
class AudioService {
  /// Ensures proper file extension based on platform and format
  static String _ensureProperExtension(String outputPath, AudioFormat format) {
    // Handle case where path might not have an extension
    final lastDotIndex = outputPath.lastIndexOf('.');
    String pathWithoutExtension;

    if (lastDotIndex == -1) {
      // No extension found
      pathWithoutExtension = outputPath;
    } else {
      pathWithoutExtension = outputPath.substring(0, lastDotIndex);
    }

    // Always use M4A format for conversion (AAC codec in M4A container)
    // This ensures universal playback support across all devices and players
    if (format == AudioFormat.m4a) {
      return '$pathWithoutExtension.m4a';
    }

    // Keep original extension for copy operations
    if (format == AudioFormat.copy) {
      // Check if the path already has an extension
      if (lastDotIndex != -1) {
        return outputPath;
      } else {
        // Default to M4A if no extension provided
        return '$pathWithoutExtension.m4a';
      }
    }

    // Default fallback to M4A for any other format
    return '$pathWithoutExtension.m4a';
  }

  /// Extracts waveform data from an audio file
  ///
  /// [inputPath] - Path to the input audio file
  /// [samplesPerSecond] - Number of amplitude samples per second (default: 100)
  /// [onProgress] - Optional callback for extraction progress
  static Future<WaveformData> extractWaveform({
    required String inputPath,
    int samplesPerSecond = 100,
    ProgressCallback? onProgress,
  }) {
    return FlutterAudioToolkitPlatform.instance.extractWaveform(
      inputPath: inputPath,
      samplesPerSecond: samplesPerSecond,
      onProgress: onProgress,
    );
  }

  /// Trims an audio file to the specified time range
  ///
  /// [inputPath] - Path to the input audio file
  /// [outputPath] - Path where the trimmed file will be saved
  /// [startTimeMs] - Start time in milliseconds
  /// [endTimeMs] - End time in milliseconds
  /// [format] - Target audio format:
  ///   - AudioFormat.m4a: AAC codec in M4A container (universal compatibility)
  ///   - AudioFormat.copy: Keep original format (lossless where possible)
  /// [bitRate] - Target bit rate in kbps (default: 128)
  /// [sampleRate] - Target sample rate in Hz (default: 44100)
  /// [onProgress] - Optional callback for trimming progress
  ///
  /// Note: M4A format (AAC codec in M4A container) provides the best
  /// cross-platform compatibility for trimming operations
  static Future<ConversionResult> trimAudio({
    required String inputPath,
    required String outputPath,
    required int startTimeMs,
    required int endTimeMs,
    required AudioFormat format,
    int bitRate = 128,
    int sampleRate = 44100,
    ProgressCallback? onProgress,
  }) {
    // Ensure proper file extension for cross-platform compatibility
    final correctedOutputPath = _ensureProperExtension(outputPath, format);

    return FlutterAudioToolkitPlatform.instance.trimAudio(
      inputPath: inputPath,
      outputPath: correctedOutputPath,
      startTimeMs: startTimeMs,
      endTimeMs: endTimeMs,
      format: format,
      bitRate: bitRate,
      sampleRate: sampleRate,
      onProgress: onProgress,
    );
  }

  /// Checks if the given audio format is supported for conversion
  static Future<bool> isFormatSupported(String inputPath) {
    return FlutterAudioToolkitPlatform.instance.isFormatSupported(inputPath);
  }

  /// Gets audio file information without conversion
  static Future<AudioInfo> getAudioInfo(String inputPath) {
    return FlutterAudioToolkitPlatform.instance.getAudioInfo(inputPath);
  }

  /// Extracts comprehensive metadata from an audio file
  ///
  /// [inputPath] - Path to the input audio file
  ///
  /// Returns an [AudioMetadata] object containing all available metadata
  static Future<AudioMetadata> extractMetadata(String inputPath) async {
    final audioInfo = await FlutterAudioToolkitPlatform.instance.getAudioInfo(
      inputPath,
    );
    // Convert AudioInfo to Map for AudioMetadata.fromMap
    return AudioMetadata.fromMap({
      'title': audioInfo.title,
      'artist': audioInfo.artist,
      'album': audioInfo.album,
      'year': audioInfo.year,
      'genre': audioInfo.genre,
      'durationMs': audioInfo.durationMs,
      'bitrate': audioInfo.bitRate,
      'sampleRate': audioInfo.sampleRate,
      'channels': audioInfo.channels,
      'format': audioInfo.format,
      'fileSizeBytes': audioInfo.fileSize,
    });
  }

  /// Extracts metadata from a network audio file
  ///
  /// [url] - URL of the audio file
  /// [localPath] - Temporary local path for downloading
  /// [onProgress] - Optional callback for download progress
  ///
  /// Returns an [AudioMetadata] object containing all available metadata
  static Future<AudioMetadata> extractMetadataFromUrl({
    required String url,
    required String localPath,
    ProgressCallback? onProgress,
  }) async {
    try {
      // Download the file
      await NetworkService.downloadFile(url, localPath, onProgress: onProgress);

      // Extract metadata from the downloaded file
      final metadata = await extractMetadata(localPath);

      // Clean up the temporary file
      await NetworkService.cleanupFile(localPath);

      return metadata;
    } catch (e) {
      // Clean up temporary file on error
      await NetworkService.cleanupFile(localPath);
      rethrow;
    }
  }

  /// Gets basic audio information as legacy Map format
  ///
  /// Use [extractMetadata] for structured metadata access
  static Future<Map<String, dynamic>> getBasicAudioInfo(
    String inputPath,
  ) async {
    final audioInfo = await getAudioInfo(inputPath);
    // Convert AudioInfo to Map for legacy compatibility
    return {
      'isValid': audioInfo.isValid,
      'fileSize': audioInfo.fileSize,
      'durationMs': audioInfo.durationMs,
      'mimeType': audioInfo.mimeType,
      'format': audioInfo.format,
      'codec': audioInfo.codec,
      'bitRate': audioInfo.bitRate,
      'sampleRate': audioInfo.sampleRate,
      'channels': audioInfo.channels,
      'bitDepth': audioInfo.bitDepth,
      'supportedForConversion': audioInfo.supportedForConversion,
      'supportedForTrimming': audioInfo.supportedForTrimming,
      'supportedForLosslessTrimming': audioInfo.supportedForLosslessTrimming,
      'supportedForWaveform': audioInfo.supportedForWaveform,
      'title': audioInfo.title,
      'artist': audioInfo.artist,
      'album': audioInfo.album,
      'year': audioInfo.year,
      'genre': audioInfo.genre,
      'error': audioInfo.error,
      'details': audioInfo.details,
      'formatDiagnostics': audioInfo.formatDiagnostics,
      'foundTracks': audioInfo.foundTracks,
    };
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
  static Future<WaveformData> extractWaveformFromUrl({
    required String url,
    required String localPath,
    int samplesPerSecond = 100,
    ProgressCallback? onDownloadProgress,
    ProgressCallback? onExtractionProgress,
  }) async {
    try {
      // Download the file with progress tracking
      await NetworkService.downloadFile(
        url,
        localPath,
        onProgress: (progress) {
          onDownloadProgress?.call(
            progress * 0.5,
          ); // Download takes 50% of total progress
        },
      );

      // Extract waveform from the downloaded file
      final waveformData = await extractWaveform(
        inputPath: localPath,
        samplesPerSecond: samplesPerSecond,
        onProgress: (progress) {
          onExtractionProgress?.call(
            0.5 + progress * 0.5,
          ); // Extraction takes remaining 50%
        },
      );

      // Clean up the temporary file
      await NetworkService.cleanupFile(localPath);

      return waveformData;
    } catch (e) {
      // Clean up temporary file on error
      await NetworkService.cleanupFile(localPath);
      rethrow;
    }
  }

  /// Downloads an audio file from the given URL and saves it to the local file system
  ///
  /// [url] - URL of the audio file to download
  /// [outputPath] - Local path where the downloaded file will be saved
  /// [onProgress] - Optional callback for download progress
  static Future<String> downloadFile(
    String url,
    String outputPath, {
    ProgressCallback? onProgress,
  }) async {
    await NetworkService.downloadFile(url, outputPath, onProgress: onProgress);
    return outputPath;
  }
}
