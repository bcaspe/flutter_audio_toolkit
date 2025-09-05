/// Base exception class for all Flutter Audio Toolkit errors
abstract class FlutterAudioToolkitException implements Exception {
  /// Error message
  final String message;

  /// Additional error details
  final String? details;

  /// Error code for programmatic handling
  final String? code;

  /// Original error from the platform (if any)
  final dynamic originalError;

  const FlutterAudioToolkitException(
    this.message, {
    this.details,
    this.code,
    this.originalError,
  });

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (details != null) {
      buffer.write('\nDetails: $details');
    }
    if (code != null) {
      buffer.write('\nCode: $code');
    }
    return buffer.toString();
  }
}

/// Exception thrown when audio conversion fails
class AudioConversionException extends FlutterAudioToolkitException {
  /// Input file path
  final String? inputPath;

  /// Output file path
  final String? outputPath;

  /// Target format
  final String? targetFormat;

  const AudioConversionException(
    super.message, {
    super.details,
    super.code,
    super.originalError,
    this.inputPath,
    this.outputPath,
    this.targetFormat,
  });
}

/// Exception thrown when audio trimming fails
class AudioTrimmingException extends FlutterAudioToolkitException {
  /// Input file path
  final String? inputPath;

  /// Output file path
  final String? outputPath;

  /// Start time in milliseconds
  final int? startTimeMs;

  /// End time in milliseconds
  final int? endTimeMs;

  const AudioTrimmingException(
    super.message, {
    super.details,
    super.code,
    super.originalError,
    this.inputPath,
    this.outputPath,
    this.startTimeMs,
    this.endTimeMs,
  });
}

/// Exception thrown when waveform extraction fails
class WaveformExtractionException extends FlutterAudioToolkitException {
  /// Input file path
  final String? inputPath;

  /// Samples per second
  final int? samplesPerSecond;

  const WaveformExtractionException(
    super.message, {
    super.details,
    super.code,
    super.originalError,
    this.inputPath,
    this.samplesPerSecond,
  });
}

/// Exception thrown when audio analysis fails
class AudioAnalysisException extends FlutterAudioToolkitException {
  /// Input file path
  final String? inputPath;

  const AudioAnalysisException(
    super.message, {
    super.details,
    super.code,
    super.originalError,
    this.inputPath,
  });
}

/// Exception thrown when noise analysis fails
class NoiseAnalysisException extends FlutterAudioToolkitException {
  /// Input file path
  final String? inputPath;

  /// Sensitivity level used
  final double? sensitivityLevel;

  const NoiseAnalysisException(
    super.message, {
    super.details,
    super.code,
    super.originalError,
    this.inputPath,
    this.sensitivityLevel,
  });
}

/// Exception thrown when network audio operations fail
class NetworkAudioException extends FlutterAudioToolkitException {
  /// URL that failed
  final String? url;

  /// Local path
  final String? localPath;

  /// HTTP status code (if applicable)
  final int? statusCode;

  const NetworkAudioException(
    super.message, {
    super.details,
    super.code,
    super.originalError,
    this.url,
    this.localPath,
    this.statusCode,
  });
}

/// Exception thrown when platform operations are not supported
class PlatformNotSupportedException extends FlutterAudioToolkitException {
  /// Platform name
  final String? platform;

  /// Operation that is not supported
  final String? operation;

  const PlatformNotSupportedException(
    super.message, {
    super.details,
    super.code,
    super.originalError,
    this.platform,
    this.operation,
  });
}

/// Exception thrown when invalid arguments are provided
class InvalidArgumentsException extends FlutterAudioToolkitException {
  /// Parameter name that is invalid
  final String? parameterName;

  /// Expected value type or range
  final String? expectedValue;

  /// Actual value provided
  final dynamic actualValue;

  const InvalidArgumentsException(
    super.message, {
    super.details,
    super.code,
    super.originalError,
    this.parameterName,
    this.expectedValue,
    this.actualValue,
  });
}

/// Exception thrown when audio splicing operations fail
class AudioSplicingException extends FlutterAudioToolkitException {
  /// List of input file paths that were being spliced
  final List<String> inputPaths;
  
  /// Output path where the spliced file was to be saved
  final String outputPath;

  AudioSplicingException(
    String message, {
    this.inputPaths = const [],
    this.outputPath = '',
    String? details,
    String? code,
    dynamic originalError,
  }) : super(
          message,
          details: details,
          code: code,
          originalError: originalError,
        );

  @override
  String toString() {
    return 'AudioSplicingException: $message\n'
        'Input paths: ${inputPaths.join(', ')}\n'
        'Output path: $outputPath\n'
        '${details != null ? 'Details: $details' : ''}';
  }
}
