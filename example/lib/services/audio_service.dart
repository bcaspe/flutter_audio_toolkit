import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_audio_toolkit/flutter_audio_toolkit.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_state.dart';
import 'validation_service.dart';

/// Service class for audio processing operations using the new FlutterAudioToolkit API
class AudioService {
  static final FlutterAudioToolkit _audioToolkit = FlutterAudioToolkit();

  /// Gets the output directory for saving processed files
  static Future<Directory> getOutputDirectory() async {
    if (Platform.isAndroid) {
      try {
        // Try to use the Downloads folder on Android 10+ (API 29+)
        final downloadsDirectory = await getExternalStorageDirectory();
        if (downloadsDirectory != null) {
          final audioDirectory = Directory(
            '${downloadsDirectory.path}/AudioToolkit',
          );
          if (!await audioDirectory.exists()) {
            await audioDirectory.create(recursive: true);
          }
          // Keep this print as it's helpful for users to know where files are saved
          if (kDebugMode) {
            print('Using Android Downloads folder: ${downloadsDirectory.path}');
          }
          return audioDirectory;
        }
      } catch (e) {
        // Fallback to app storage
        if (kDebugMode) {
          print(
            'Could not access Downloads folder: $e, falling back to app storage',
          );
        }
      }

      // Fallback to app-specific directory
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final audioDirectory = Directory('${appDir.path}/AudioToolkit');
        if (!await audioDirectory.exists()) {
          await audioDirectory.create(recursive: true);
        }
        if (kDebugMode) {
          print('Using Android app storage: ${audioDirectory.path}');
        }
        return audioDirectory;
      } catch (e) {
        // Final fallback - use temp directory
        if (kDebugMode) {
          print('Error setting up Android storage: $e');
        }
        final tempDir = await getTemporaryDirectory();
        return tempDir;
      }
    } else if (Platform.isIOS) {
      // On iOS, use the Documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final audioDirectory = Directory('${documentsDir.path}/AudioToolkit');
      if (!await audioDirectory.exists()) {
        await audioDirectory.create(recursive: true);
      }
      if (kDebugMode) {
        print('Using iOS Documents directory: ${audioDirectory.path}');
      }
      return audioDirectory;
    } else {
      // For other platforms, use the temp directory
      final tempDir = await getTemporaryDirectory();
      return tempDir;
    }
  }

  /// Gets a user-friendly description of the output location
  static Future<String> getOutputLocationDescription() async {
    if (Platform.isAndroid) {
      return 'Files are saved in your device\'s Downloads → AudioToolkit folder';
    } else if (Platform.isIOS) {
      return 'Files are saved in the app\'s Documents folder. You can access them via the Files app or share them directly from the app.';
    } else {
      return 'Files are saved in the app\'s temporary storage.';
    }
  }

  /// Gets the platform version
  static Future<void> getPlatformVersion(AppState appState) async {
    try {
      appState.platformVersion =
          await _audioToolkit.getPlatformVersion() ?? 'Unknown';
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get platform version: $e');
      }
      appState.platformVersion = 'Error: $e';
    }
  }

  /// Gets audio file information
  static Future<void> getAudioInfo(AppState appState) async {
    if (appState.selectedFilePath == null) return;

    try {
      final info = await _audioToolkit.getAudioInfo(appState.selectedFilePath!);
      appState.audioInfo = info;

      // Set default trim end time to full duration
      if (info.durationMs != null) {
        appState.trimEndMs = info.durationMs!;
      }

      if (kDebugMode) {
        print('Audio info loaded: ${info.toString()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get audio info: $e');
      }
      appState.audioInfo = null;
    }
  }

  /// Converts audio using the new simplified API
  static Future<void> convertAudio(AppState appState) async {
    if (!await ValidationService.validateSelectedFile(appState)) return;
    if (!await ValidationService.validateStoragePermissions()) return;

    appState.isConverting = true;
    appState.conversionProgress = 0.0;

    try {
      final directory = await getOutputDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final format = appState.selectedConversionFormat;
      String fileExtension;
      switch (format) {
        case AudioFormat.m4a:
          fileExtension = 'm4a';
          break;
        default:
          // Default to m4a for any other format
          fileExtension = 'm4a';
          break;
      }

      final fileName =
          'converted_audio_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final outputPath = '${directory.path}/$fileName';
      final result = await _audioToolkit.convertAudio(
        inputPath: appState.selectedFilePath!,
        outputPath: outputPath,
        format: format,
        bitRate: appState.selectedBitRate,
        sampleRate: 44100, // Use standard sample rate
        onProgress: (progress) {
          appState.conversionProgress = progress;
          // Only log at 10% intervals to reduce log spam
          if (kDebugMode &&
              (progress == 0.0 || progress >= 1.0 || progress % 0.1 < 0.01)) {
            debugPrint(
              'Conversion progress: ${(progress * 100).toStringAsFixed(1)}%',
            );
          }
        },
      );

      appState.convertedFilePath = result.outputPath;
      appState.isConverting = false;

      if (kDebugMode) {
        debugPrint('Audio converted successfully!');
        debugPrint('  Output file: ${result.outputPath}');
        debugPrint('  Duration: ${result.durationMs}ms');
        debugPrint('  BitRate: ${result.bitRate}kbps');
        debugPrint('  SampleRate: ${result.sampleRate}Hz');
      }
    } catch (e) {
      appState.isConverting = false;
      if (kDebugMode) {
        debugPrint('Conversion failed: $e');
      }
      rethrow;
    }
  }

  /// Trims audio using the new simplified API
  static Future<void> trimAudio(AppState appState) async {
    if (!await ValidationService.validateSelectedFile(appState)) return;
    if (!await ValidationService.validateStoragePermissions()) return;

    appState.isTrimming = true;
    appState.trimProgress = 0.0;

    try {
      final directory = await getOutputDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Use the format from AppState
      final format = appState.trimFormat;
      const fileExtension = 'm4a';

      final fileName =
          'trimmed_audio_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final outputPath = '${directory.path}/$fileName';

      // Keep this detailed logging as it's helpful for debugging trim issues
      if (kDebugMode) {
        print('🎵 Trimming audio file:');
        print('  • Format: M4A with AAC codec');
        print('  • Bitrate: ${appState.trimBitRate} kbps (high quality)');
        print('  • Sample rate: 44100 Hz');
        print('  • Input file: ${appState.selectedFilePath}');
        print('  • Output file: $outputPath');
        print(
          '  • Trim range: ${(appState.trimStartMs / 1000).toStringAsFixed(1)}s - ${(appState.trimEndMs / 1000).toStringAsFixed(1)}s',
        );
        print(
          '  • Duration: ${((appState.trimEndMs - appState.trimStartMs) / 1000).toStringAsFixed(1)}s',
        );
      }

      final result = await _audioToolkit.trimAudio(
        inputPath: appState.selectedFilePath!,
        outputPath: outputPath,
        startTimeMs: appState.trimStartMs,
        endTimeMs: appState.trimEndMs,
        format: format,
        bitRate: appState.trimBitRate,
        sampleRate: 44100,
        onProgress: (progress) {
          appState.trimProgress = progress;
          // Only log at 10% intervals to reduce log spam
          if (kDebugMode &&
              (progress == 0.0 || progress >= 1.0 || progress % 0.1 < 0.01)) {
            debugPrint(
              'Trim progress: ${(progress * 100).toStringAsFixed(1)}%',
            );
          }
        },
      );

      appState.trimmedFilePath = result.outputPath;
      appState.isTrimming = false;

      if (kDebugMode) {
        print('✅ Audio trimming completed successfully:');
        print('  • Output file: ${result.outputPath}');
        print(
          '  • Duration: ${(result.durationMs / 1000).toStringAsFixed(1)}s',
        );
        print('  • Actual bitrate: ${result.bitRate} kbps');
        print('  • Sample rate: ${result.sampleRate} Hz');
        print('  • File size: ${await File(result.outputPath).length()} bytes');
      }
    } catch (e) {
      appState.isTrimming = false;
      if (kDebugMode) {
        debugPrint('❌ Trimming failed: $e');
      }
      rethrow;
    }
  }

  /// Extracts waveform data using the new API
  static Future<void> extractWaveform(AppState appState) async {
    if (!await ValidationService.validateSelectedFile(appState)) return;

    appState.isExtracting = true;
    appState.waveformProgress = 0.0;

    try {
      if (kDebugMode) {
        debugPrint('Extracting waveform from: ${appState.selectedFilePath}');
      }

      final waveformData = await _audioToolkit.extractWaveform(
        inputPath: appState.selectedFilePath!,
        samplesPerSecond: 100,
        onProgress: (progress) {
          appState.waveformProgress = progress;
          if (kDebugMode &&
              (progress == 0.0 || progress >= 1.0 || progress % 0.1 < 0.01)) {
            debugPrint(
              'Waveform extraction progress: ${(progress * 100).toStringAsFixed(1)}%',
            );
          }
        },
      );

      appState.waveformData = waveformData;
      appState.isExtracting = false;

      if (kDebugMode) {
        print('Waveform extracted successfully!');
        print('  Samples: ${waveformData.amplitudes.length}');
        print('  Sample rate: ${waveformData.sampleRate}');
        print('  Duration: ${waveformData.durationMs}ms');
      }
    } catch (e) {
      appState.isExtracting = false;
      if (kDebugMode) {
        print('Waveform extraction failed: $e');
      }
      rethrow;
    }
  }

  /// Generates fake waveform data for testing
  static void generateFakeWaveform(AppState appState) {
    if (kDebugMode) {
      print(
        'Generating fake waveform with pattern: ${appState.selectedWaveformPattern.name}',
      );
    }

    try {
      final waveformData = _audioToolkit.generateFakeWaveform(
        pattern: appState.selectedWaveformPattern,
        durationMs: appState.audioInfo?.durationMs ?? 30000,
        samplesPerSecond: 100,
      );

      appState.waveformData = waveformData;

      if (kDebugMode) {
        print('Fake waveform generated successfully!');
        print('  Pattern: ${appState.selectedWaveformPattern.name}');
        print('  Samples: ${waveformData.amplitudes.length}');
        print('  Duration: ${waveformData.durationMs}ms');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Fake waveform generation failed: $e');
      }
      rethrow;
    }
  }

  /// Analyzes noise levels using the new API
  static Future<void> analyzeNoise(AppState appState) async {
    if (!await ValidationService.validateSelectedFile(appState)) return;

    appState.isAnalyzingNoise = true;
    appState.noiseAnalysisProgress = 0.0;

    try {
      if (kDebugMode) {
        debugPrint('Analyzing noise in: ${appState.selectedFilePath}');
      }

      final result = await _audioToolkit.analyzeNoise(
        inputPath: appState.selectedFilePath!,
        onProgress: (progress) {
          appState.noiseAnalysisProgress = progress;
          if (kDebugMode &&
              (progress == 0.0 || progress >= 1.0 || progress % 0.1 < 0.01)) {
            debugPrint(
              'Noise analysis progress: ${(progress * 100).toStringAsFixed(1)}%',
            );
          }
        },
      );

      appState.noiseAnalysisResult = result;
      appState.isAnalyzingNoise = false;
    } catch (e) {
      appState.isAnalyzingNoise = false;
      if (kDebugMode) {
        print('Noise analysis failed: $e');
      }
      rethrow;
    }
  }

  /// Downloads audio from URL using the new API
  static Future<void> downloadAudio(AppState appState, String url) async {
    appState.isDownloading = true;
    appState.downloadProgress = 0.0;

    try {
      final directory = await getOutputDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Generate output filename from URL
      final uri = Uri.parse(url);
      final originalName = uri.pathSegments.last;
      final fileName =
          'downloaded_${DateTime.now().millisecondsSinceEpoch}_$originalName';
      final outputPath = '${directory.path}/$fileName';

      if (kDebugMode) {
        debugPrint('Downloading audio from: $url');
        debugPrint('Saving to: $outputPath');
      }

      final downloadedPath = await _audioToolkit.downloadFile(
        url,
        outputPath,
        onProgress: (progress) {
          appState.downloadProgress = progress;
          if (kDebugMode &&
              (progress == 0.0 || progress >= 1.0 || progress % 0.1 < 0.01)) {
            debugPrint(
              'Download progress: ${(progress * 100).toStringAsFixed(1)}%',
            );
          }
        },
      );

      appState.selectedFilePath = downloadedPath;
      appState.isDownloading = false;

      // Automatically get audio info for the downloaded file
      await getAudioInfo(appState);

      if (kDebugMode) {
        debugPrint('Audio downloaded successfully!');
        debugPrint('  Output file: $downloadedPath');
        final file = File(downloadedPath);
        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint('  File size: $fileSize bytes');
        }
      }
    } catch (e) {
      appState.isDownloading = false;
      if (kDebugMode) {
        debugPrint('Download failed: $e');
      }
      rethrow;
    }
  }

  /// Validates format support using the new API
  static Future<bool> isFormatSupported(String filePath) async {
    try {
      return await _audioToolkit.isFormatSupported(filePath);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking format support: $e');
      }
      return false;
    }
  }
}
