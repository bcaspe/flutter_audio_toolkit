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

  /// Gets the appropriate output directory for the current platform
  static Future<Directory> getOutputDirectory() async {
    if (Platform.isAndroid) {
      try {
        // For Android, try to use Downloads directory first (most user-accessible)
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Navigate to the public Downloads folder
          // This is more accessible to users across different Android versions
          final publicPath = directory.path.replaceAll(
            '/Android/data/${directory.path.split('/')[4]}/files',
            '/Download',
          );
          final downloadsDirectory = Directory('$publicPath/AudioToolkit');

          try {
            if (!await downloadsDirectory.exists()) {
              await downloadsDirectory.create(recursive: true);
            }

            if (kDebugMode) {
              print('Using Android Downloads folder: ${downloadsDirectory.path}');
              print('Files will be accessible via Downloads folder in file manager');
            }

            return downloadsDirectory;
          } catch (e) {
            if (kDebugMode) {
              print('Could not access Downloads folder: $e, falling back to app storage');
            }
          }
        }

        // Fallback: Use the app's external storage directory with clearer folder structure
        if (directory != null) {
          final audioDirectory = Directory('${directory.path}/AudioFiles');
          if (!await audioDirectory.exists()) {
            await audioDirectory.create(recursive: true);
          }

          if (kDebugMode) {
            print('Using Android app storage: ${audioDirectory.path}');
          }

          return audioDirectory;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error setting up Android storage: $e');
        }
      }

      // Final fallback: app documents directory
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isIOS) {
      // iOS: Use documents directory (accessible via Files app)
      final directory = await getApplicationDocumentsDirectory();
      final audioDirectory = Directory('${directory.path}/AudioFiles');

      if (!await audioDirectory.exists()) {
        await audioDirectory.create(recursive: true);
      }

      if (kDebugMode) {
        print('Using iOS Documents directory: ${audioDirectory.path}');
      }

      return audioDirectory;
    } else {
      // Other platforms: use documents directory
      return await getApplicationDocumentsDirectory();
    }
  }

  /// Gets a user-friendly description of where files are stored
  static Future<String> getOutputLocationDescription() async {
    final directory = await getOutputDirectory();

    if (Platform.isAndroid) {
      if (directory.path.contains('/Download/AudioToolkit')) {
        return 'Files are saved in your Downloads folder: .';
      } else if (directory.path.contains('Android/data')) {
        return 'Files are saved in the app folder:\\n${directory.path}';
      } else {
        return 'Files are saved in your device storage:\\n${directory.path}.';
      }
    } else if (Platform.isIOS) {
      return 'Files are saved in the app folder, accessible via the Files app.\\n\\nTo access: Open Files app → On My iPhone → flutter_audio_toolkit_example';
    } else {
      return 'Files are saved in: ${directory.path}';
    }
  }

  /// Gets platform version using the new API
  static Future<String> getPlatformVersion(AppState appState) async {
    try {
      return await _audioToolkit.getPlatformVersion() ?? 'Unknown platform version';
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get platform version: $e');
      }
      return 'Failed to get platform version.';
    }
  }

  /// Gets audio file information using the new API
  static Future<void> getAudioInfo(AppState appState) async {
    if (appState.selectedFilePath == null) return;

    try {
      final info = await _audioToolkit.getAudioInfo(appState.selectedFilePath!);
      appState.audioInfo = info;

      // Set default trim range to full audio duration if available
      if (info.durationMs != null) {
        appState.trimStartMs = 0;
        appState.trimEndMs = info.durationMs!;
      }

      if (kDebugMode) {
        print('Audio info loaded: ${info.toString()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get audio info: $e');
      }
      // Set empty audio info on error
      appState.audioInfo = null;
    }
  }

  /// Converts audio to specified format using the new simplified API
  static Future<void> convertAudio(
    AppState appState,
    AudioFormat format, {
    int bitRate = 192, // Default to high quality
    int sampleRate = 44100,
  }) async {
    // Perform comprehensive validations
    if (!await ValidationService.validateSelectedFile(appState)) return;
    if (!await ValidationService.validateFormatSupport(appState)) return;
    if (!await ValidationService.validateStoragePermissions()) return;

    appState.isConverting = true;
    appState.conversionProgress = 0.0;

    try {
      // Get appropriate output directory for the platform
      final directory = await getOutputDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Determine file extension based on format
      String fileExtension;
      switch (format) {
        case AudioFormat.m4a:
          fileExtension = 'm4a';
          break;
        case AudioFormat.copy:
          // Use original extension for copy
          final inputFile = File(appState.selectedFilePath!);
          fileExtension = inputFile.path.split('.').last.toLowerCase();
          break;
      }

      final fileName = 'converted_audio_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final outputPath = '${directory.path}/$fileName';
      // Use the new simplified API
      final result = await _audioToolkit.convertAudio(
        inputPath: appState.selectedFilePath!,
        outputPath: outputPath,
        format: format,
        bitRate: bitRate,
        sampleRate: sampleRate,
        onProgress: (progress) {
          appState.conversionProgress = progress;
          if (kDebugMode && (progress == 0.0 || progress >= 1.0 || progress % 0.1 < 0.01)) {
            debugPrint('Conversion progress: ${(progress * 100).toStringAsFixed(1)}%');
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

      final fileName = 'trimmed_audio_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final outputPath = '${directory.path}/$fileName';

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
        print('  • Duration: ${((appState.trimEndMs - appState.trimStartMs) / 1000).toStringAsFixed(1)}s');
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
          if (kDebugMode && (progress == 0.0 || progress >= 1.0 || progress % 0.1 < 0.01)) {
            debugPrint('Trim progress: ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
      );

      appState.trimmedFilePath = result.outputPath;
      appState.isTrimming = false;

      if (kDebugMode) {
        print('✅ Audio trimming completed successfully:');
        print('  • Output file: ${result.outputPath}');
        print('  • Duration: ${(result.durationMs / 1000).toStringAsFixed(1)}s');
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
          if (kDebugMode && (progress == 0.0 || progress >= 1.0 || progress % 0.1 < 0.01)) {
            debugPrint('Waveform extraction progress: ${(progress * 100).toStringAsFixed(1)}%');
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
      print('Generating fake waveform with pattern: ${appState.selectedWaveformPattern.name}');
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
          if (kDebugMode && (progress == 0.0 || progress >= 1.0 || progress % 0.1 < 0.01)) {
            debugPrint('Noise analysis progress: ${(progress * 100).toStringAsFixed(1)}%');
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
      final fileName = 'downloaded_${DateTime.now().millisecondsSinceEpoch}_$originalName';
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
          if (kDebugMode && (progress == 0.0 || progress >= 1.0 || progress % 0.1 < 0.01)) {
            debugPrint('Download progress: ${(progress * 100).toStringAsFixed(1)}%');
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
