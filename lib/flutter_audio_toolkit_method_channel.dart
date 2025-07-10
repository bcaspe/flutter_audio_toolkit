import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_audio_toolkit_platform_interface.dart';
import 'src/models/models.dart';

/// An implementation of [FlutterAudioToolkitPlatform] that uses method channels.
class MethodChannelFlutterAudioToolkit extends FlutterAudioToolkitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_audio_toolkit');

  /// Event channel for progress callbacks
  final _progressChannel = const EventChannel('flutter_audio_toolkit/progress');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<ConversionResult> convertAudio({
    required String inputPath,
    required String outputPath,
    required AudioFormat format,
    int bitRate = 128,
    int sampleRate = 44100,
    ProgressCallback? onProgress,
  }) async {
    // Validate arguments
    _validateFilePath(inputPath, 'inputPath');
    _validateFilePath(outputPath, 'outputPath');
    _validateBitRate(bitRate);
    _validateSampleRate(sampleRate);

    // Set up progress listening
    StreamSubscription<dynamic>? progressSub;
    if (onProgress != null) {
      progressSub = _progressChannel.receiveBroadcastStream().listen((data) {
        if (data is Map && data['operation'] == 'convert') {
          final progress = data['progress'] as double?;
          if (progress != null) {
            onProgress(progress);
          }
        }
      });
    }

    try {
      final Map<String, dynamic> arguments = {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'format': format.name,
        'bitRate': bitRate,
        'sampleRate': sampleRate,
      };

      final result = await methodChannel
          .invokeMethod('convertAudio', arguments)
          .timeout(const Duration(minutes: 10));

      if (result == null) {
        throw AudioConversionException(
          'Conversion failed: No result returned from platform',
          inputPath: inputPath,
          outputPath: outputPath,
          targetFormat: format.name,
        );
      }

      // Safely convert the result to Map<String, dynamic>
      final Map<String, dynamic> convertedResult;
      if (result is Map) {
        convertedResult = Map<String, dynamic>.from(result);
      } else {
        throw AudioConversionException(
          'Conversion failed: Invalid result type from platform',
          inputPath: inputPath,
          outputPath: outputPath,
          targetFormat: format.name,
        );
      }

      return ConversionResult(
        outputPath: convertedResult['outputPath'] as String,
        durationMs: convertedResult['durationMs'] as int,
        bitRate: convertedResult['bitRate'] as int,
        sampleRate: convertedResult['sampleRate'] as int,
      );
    } on PlatformException catch (e) {
      throw _convertPlatformException(e, AudioConversionException.new, {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'targetFormat': format.name,
      });
    } catch (e) {
      throw AudioConversionException(
        'Conversion failed: $e',
        originalError: e,
        inputPath: inputPath,
        outputPath: outputPath,
        targetFormat: format.name,
      );
    } finally {
      await progressSub?.cancel();
    }
  }

  @override
  Future<ConversionResult> trimAudio({
    required String inputPath,
    required String outputPath,
    required int startTimeMs,
    required int endTimeMs,
    required AudioFormat format,
    int bitRate = 128,
    int sampleRate = 44100,
    ProgressCallback? onProgress,
  }) async {
    // Validate arguments
    _validateFilePath(inputPath, 'inputPath');
    _validateFilePath(outputPath, 'outputPath');
    _validateTimeRange(startTimeMs, endTimeMs);
    _validateBitRate(bitRate);
    _validateSampleRate(sampleRate);

    // Set up progress listening
    StreamSubscription<dynamic>? progressSub;
    if (onProgress != null) {
      progressSub = _progressChannel.receiveBroadcastStream().listen((data) {
        if (data is Map && data['operation'] == 'trim') {
          final progress = data['progress'] as double?;
          if (progress != null) {
            onProgress(progress);
          }
        }
      });
    }

    try {
      final Map<String, dynamic> arguments = {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
        'format': format.name,
        'bitRate': bitRate,
        'sampleRate': sampleRate,
      };

      final result = await methodChannel
          .invokeMethod('trimAudio', arguments)
          .timeout(const Duration(minutes: 10));

      if (result == null) {
        throw AudioTrimmingException(
          'Trimming failed: No result returned from platform',
          inputPath: inputPath,
          outputPath: outputPath,
          startTimeMs: startTimeMs,
          endTimeMs: endTimeMs,
        );
      }

      // Safely convert the result to Map<String, dynamic>
      final Map<String, dynamic> convertedResult;
      if (result is Map) {
        convertedResult = Map<String, dynamic>.from(result);
      } else {
        throw AudioTrimmingException(
          'Trimming failed: Invalid result type from platform',
          inputPath: inputPath,
          outputPath: outputPath,
          startTimeMs: startTimeMs,
          endTimeMs: endTimeMs,
        );
      }

      return ConversionResult(
        outputPath: convertedResult['outputPath'] as String,
        durationMs: convertedResult['durationMs'] as int,
        bitRate: convertedResult['bitRate'] as int,
        sampleRate: convertedResult['sampleRate'] as int,
      );
    } on PlatformException catch (e) {
      throw _convertPlatformException(e, AudioTrimmingException.new, {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
      });
    } catch (e) {
      throw AudioTrimmingException(
        'Trimming failed: $e',
        originalError: e,
        inputPath: inputPath,
        outputPath: outputPath,
        startTimeMs: startTimeMs,
        endTimeMs: endTimeMs,
      );
    } finally {
      await progressSub?.cancel();
    }
  }

  @override
  Future<WaveformData> extractWaveform({
    required String inputPath,
    int samplesPerSecond = 100,
    ProgressCallback? onProgress,
  }) async {
    // Validate arguments
    _validateFilePath(inputPath, 'inputPath');
    _validateSamplesPerSecond(samplesPerSecond);

    // Set up progress listening
    StreamSubscription<dynamic>? progressSub;
    if (onProgress != null) {
      progressSub = _progressChannel.receiveBroadcastStream().listen((data) {
        if (data is Map && data['operation'] == 'extract') {
          final progress = data['progress'] as double?;
          if (progress != null) {
            onProgress(progress);
          }
        }
      });
    }

    try {
      final Map<String, dynamic> arguments = {
        'inputPath': inputPath,
        'samplesPerSecond': samplesPerSecond,
      };

      final result = await methodChannel
          .invokeMethod('extractWaveform', arguments)
          .timeout(const Duration(minutes: 5));

      if (result == null) {
        throw WaveformExtractionException(
          'Waveform extraction failed: No result returned from platform',
          inputPath: inputPath,
          samplesPerSecond: samplesPerSecond,
        );
      }

      // Safely convert the result to Map<String, dynamic>
      final Map<String, dynamic> convertedResult;
      if (result is Map) {
        convertedResult = Map<String, dynamic>.from(result);
      } else {
        throw WaveformExtractionException(
          'Waveform extraction failed: Invalid result type from platform',
          inputPath: inputPath,
          samplesPerSecond: samplesPerSecond,
        );
      }

      return WaveformData(
        amplitudes:
            (convertedResult['amplitudes'] as List<dynamic>).cast<double>(),
        sampleRate: convertedResult['sampleRate'] as int,
        durationMs: convertedResult['durationMs'] as int,
        channels: convertedResult['channels'] as int,
      );
    } on PlatformException catch (e) {
      throw _convertPlatformException(e, WaveformExtractionException.new, {
        'inputPath': inputPath,
        'samplesPerSecond': samplesPerSecond,
      });
    } catch (e) {
      throw WaveformExtractionException(
        'Waveform extraction failed: $e',
        originalError: e,
        inputPath: inputPath,
        samplesPerSecond: samplesPerSecond,
      );
    } finally {
      await progressSub?.cancel();
    }
  }

  @override
  Future<AudioInfo> getAudioInfo(String inputPath) async {
    // Validate arguments
    _validateFilePath(inputPath, 'inputPath');

    try {
      final result = await methodChannel
          .invokeMethod('getAudioInfo', {'inputPath': inputPath})
          .timeout(const Duration(seconds: 30));

      if (result == null) {
        throw AudioAnalysisException(
          'Audio analysis failed: No result returned from platform',
          inputPath: inputPath,
        );
      }

      // Safely convert the result to Map<String, dynamic>
      final Map<String, dynamic> convertedResult;
      if (result is Map) {
        convertedResult = Map<String, dynamic>.from(result);
      } else {
        throw AudioAnalysisException(
          'Audio analysis failed: Invalid result type from platform',
          inputPath: inputPath,
        );
      }

      return AudioInfo.fromMap(convertedResult);
    } on PlatformException catch (e) {
      throw _convertPlatformException(e, AudioAnalysisException.new, {
        'inputPath': inputPath,
      });
    } catch (e) {
      throw AudioAnalysisException(
        'Audio analysis failed: $e',
        originalError: e,
        inputPath: inputPath,
      );
    }
  }

  @override
  Future<bool> isFormatSupported(String inputPath) async {
    _validateFilePath(inputPath, 'inputPath');

    try {
      final result = await methodChannel
          .invokeMethod<bool>('isFormatSupported', {'inputPath': inputPath})
          .timeout(const Duration(seconds: 10));

      return result ?? false;
    } on PlatformException catch (e) {
      if (e.code == 'PLATFORM_NOT_SUPPORTED') {
        return false;
      }
      throw _convertPlatformException(e, AudioAnalysisException.new, {
        'inputPath': inputPath,
      });
    } catch (e) {
      return false;
    }
  }

  @override
  Future<NoiseDetectionResult> analyzeAudioNoise({
    required String inputPath,
    double sensitivityLevel = 0.5,
    ProgressCallback? onProgress,
  }) async {
    _validateFilePath(inputPath, 'inputPath');
    _validateSensitivityLevel(sensitivityLevel);

    // Set up progress listening
    StreamSubscription<dynamic>? progressSub;
    if (onProgress != null) {
      progressSub = _progressChannel.receiveBroadcastStream().listen((data) {
        if (data is Map && data['operation'] == 'noise_analysis') {
          final progress = data['progress'] as double?;
          if (progress != null) {
            onProgress(progress);
          }
        }
      });
    }

    try {
      final Map<String, dynamic> arguments = {
        'inputPath': inputPath,
        'sensitivityLevel': sensitivityLevel,
      };

      final result = await methodChannel
          .invokeMethod('analyzeAudioNoise', arguments)
          .timeout(const Duration(minutes: 3));

      if (result == null) {
        throw NoiseAnalysisException(
          'Noise analysis failed: No result returned from platform',
          inputPath: inputPath,
          sensitivityLevel: sensitivityLevel,
        );
      }

      // Safely convert the result to Map<String, dynamic>
      final Map<String, dynamic> convertedResult;
      if (result is Map) {
        convertedResult = Map<String, dynamic>.from(result);
      } else {
        throw NoiseAnalysisException(
          'Noise analysis failed: Invalid result type from platform',
          inputPath: inputPath,
          sensitivityLevel: sensitivityLevel,
        );
      }

      return NoiseDetectionResult.fromMap(convertedResult);
    } on PlatformException catch (e) {
      if (e.code == 'PLATFORM_NOT_SUPPORTED') {
        throw PlatformNotSupportedException(
          'Noise analysis is not supported on this platform',
          platform: Platform.operatingSystem,
          operation: 'analyzeAudioNoise',
        );
      }
      throw _convertPlatformException(e, NoiseAnalysisException.new, {
        'inputPath': inputPath,
        'sensitivityLevel': sensitivityLevel,
      });
    } catch (e) {
      throw NoiseAnalysisException(
        'Noise analysis failed: $e',
        originalError: e,
        inputPath: inputPath,
        sensitivityLevel: sensitivityLevel,
      );
    } finally {
      await progressSub?.cancel();
    }
  }

  @override
  Future<String> downloadAudioFromUrl({
    required String url,
    required String localPath,
    ProgressCallback? onDownloadProgress,
  }) async {
    // Validate arguments
    if (url.isEmpty) {
      throw InvalidArgumentsException(
        'URL cannot be empty',
        parameterName: 'url',
        expectedValue: 'non-empty string',
        actualValue: url,
      );
    }

    if (localPath.isEmpty) {
      throw InvalidArgumentsException(
        'Local path cannot be empty',
        parameterName: 'localPath',
        expectedValue: 'non-empty string',
        actualValue: localPath,
      );
    }

    // Set up progress listening
    StreamSubscription<dynamic>? progressSub;
    if (onDownloadProgress != null) {
      progressSub = _progressChannel.receiveBroadcastStream().listen((data) {
        if (data is Map && data['operation'] == 'download') {
          final progress = data['progress'] as double?;
          if (progress != null) {
            onDownloadProgress(progress);
          }
        }
      });
    }

    try {
      final Map<String, dynamic> arguments = {
        'url': url,
        'localPath': localPath,
      };

      final result = await methodChannel
          .invokeMethod<String>('downloadAudioFromUrl', arguments)
          .timeout(const Duration(minutes: 15));

      if (result == null) {
        throw NetworkAudioException(
          'Download failed: No result returned from platform',
          url: url,
          localPath: localPath,
        );
      }

      return result;
    } on PlatformException catch (e) {
      throw _convertPlatformException(e, NetworkAudioException.new, {
        'url': url,
        'localPath': localPath,
      });
    } catch (e) {
      throw NetworkAudioException(
        'Download failed: $e',
        originalError: e,
        url: url,
        localPath: localPath,
      );
    } finally {
      await progressSub?.cancel();
    }
  }

  @override
  Future<bool> configureAudioSession({
    Map<String, dynamic>? configuration,
  }) async {
    try {
      final result = await methodChannel
          .invokeMethod<bool>('configureAudioSession', configuration ?? {})
          .timeout(const Duration(seconds: 10));

      return result ??
          true; // Default to success for platforms that don't need it
    } on PlatformException catch (e) {
      if (e.code == 'PLATFORM_NOT_SUPPORTED') {
        return true; // Audio session configuration is not needed on this platform
      }
      throw AudioAnalysisException(
        'Audio session configuration failed: ${e.message}',
        code: e.code,
        details: e.details?.toString(),
        originalError: e,
      );
    } catch (e) {
      throw AudioAnalysisException(
        'Audio session configuration failed: $e',
        originalError: e,
      );
    }
  }

  // Validation helpers
  void _validateFilePath(String path, String parameterName) {
    if (path.isEmpty) {
      throw InvalidArgumentsException(
        'File path cannot be empty',
        parameterName: parameterName,
        expectedValue: 'non-empty string',
        actualValue: path,
      );
    }
  }

  void _validateBitRate(int bitRate) {
    if (bitRate < 32 || bitRate > 320) {
      throw InvalidArgumentsException(
        'Bit rate must be between 32 and 320 kbps',
        parameterName: 'bitRate',
        expectedValue: '32-320',
        actualValue: bitRate,
      );
    }
  }

  void _validateSampleRate(int sampleRate) {
    const validRates = [
      8000,
      11025,
      16000,
      22050,
      32000,
      44100,
      48000,
      88200,
      96000,
    ];
    if (!validRates.contains(sampleRate)) {
      throw InvalidArgumentsException(
        'Sample rate must be one of: ${validRates.join(', ')}',
        parameterName: 'sampleRate',
        expectedValue: validRates.join(', '),
        actualValue: sampleRate,
      );
    }
  }

  void _validateTimeRange(int startTimeMs, int endTimeMs) {
    if (startTimeMs < 0) {
      throw InvalidArgumentsException(
        'Start time cannot be negative',
        parameterName: 'startTimeMs',
        expectedValue: '>= 0',
        actualValue: startTimeMs,
      );
    }

    if (endTimeMs <= startTimeMs) {
      throw InvalidArgumentsException(
        'End time must be greater than start time',
        parameterName: 'endTimeMs',
        expectedValue: '> $startTimeMs',
        actualValue: endTimeMs,
      );
    }
  }

  void _validateSamplesPerSecond(int samplesPerSecond) {
    if (samplesPerSecond < 1 || samplesPerSecond > 1000) {
      throw InvalidArgumentsException(
        'Samples per second must be between 1 and 1000',
        parameterName: 'samplesPerSecond',
        expectedValue: '1-1000',
        actualValue: samplesPerSecond,
      );
    }
  }

  void _validateSensitivityLevel(double sensitivityLevel) {
    if (sensitivityLevel < 0.0 || sensitivityLevel > 1.0) {
      throw InvalidArgumentsException(
        'Sensitivity level must be between 0.0 and 1.0',
        parameterName: 'sensitivityLevel',
        expectedValue: '0.0-1.0',
        actualValue: sensitivityLevel,
      );
    }
  }

  // Helper to convert platform exceptions to domain exceptions
  T _convertPlatformException<T extends FlutterAudioToolkitException>(
    PlatformException e,
    T Function(String, {String? details, String? code, dynamic originalError})
    constructor,
    Map<String, dynamic> additionalData,
  ) {
    String message = e.message ?? 'Unknown platform error';

    // Add context based on error code
    switch (e.code) {
      case 'INVALID_ARGUMENTS':
        message = 'Invalid arguments provided: $message';
        break;
      case 'CONVERSION_ERROR':
        message = 'Audio conversion failed: $message';
        break;
      case 'TRIM_ERROR':
        message = 'Audio trimming failed: $message';
        break;
      case 'WAVEFORM_ERROR':
        message = 'Waveform extraction failed: $message';
        break;
      case 'INFO_ERROR':
        message = 'Audio information retrieval failed: $message';
        break;
      case 'PLATFORM_NOT_SUPPORTED':
        return PlatformNotSupportedException(
              message,
              code: e.code,
              details: e.details?.toString(),
              originalError: e,
              platform: Platform.operatingSystem,
            )
            as T;
    }

    return constructor(
      message,
      details: e.details?.toString(),
      code: e.code,
      originalError: e,
    );
  }
}
