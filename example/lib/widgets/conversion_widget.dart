import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_audio_toolkit/flutter_audio_toolkit.dart';
import '../models/app_state.dart';
import '../services/audio_service.dart';

/// Widget for audio conversion controls
class ConversionWidget extends StatelessWidget {
  final AppState appState;
  final VoidCallback onStateChanged;

  const ConversionWidget({
    super.key,
    required this.appState,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (appState.selectedFilePath == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Audio Conversion',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Format selection
            Row(
              children: [
                const Text('Output Format: '),
                const SizedBox(width: 8),
                DropdownButton<AudioFormat>(
                  value: appState.selectedConversionFormat,
                  items: const [
                    DropdownMenuItem(
                      value: AudioFormat.m4a,
                      child: Text('M4A (AAC codec)'),
                    ),
                    DropdownMenuItem(
                      value: AudioFormat.copy,
                      child: Text('Copy (Lossless)'),
                    ),
                  ],
                  onChanged: (AudioFormat? value) {
                    if (value != null) {
                      appState.selectedConversionFormat = value;
                      onStateChanged();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quality settings
            if (appState.selectedConversionFormat == AudioFormat.m4a) ...[
              Row(
                children: [
                  const Text('Bit Rate: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: appState.selectedBitRate,
                    items: const [
                      DropdownMenuItem(value: 64, child: Text('64 kbps (Low)')),
                      DropdownMenuItem(
                        value: 128,
                        child: Text('128 kbps (Medium)'),
                      ),
                      DropdownMenuItem(
                        value: 192,
                        child: Text('192 kbps (High)'),
                      ),
                      DropdownMenuItem(
                        value: 256,
                        child: Text('256 kbps (Very High)'),
                      ),
                    ],
                    onChanged: (int? value) {
                      if (value != null) {
                        appState.selectedBitRate = value;
                        onStateChanged();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'M4A format provides the best cross-platform compatibility with high-quality AAC encoding.',
                style: TextStyle(fontSize: 12, color: Colors.blue[700]),
              ),
            ] else ...[
              const Text(
                'Copy mode preserves the original format and quality without any conversion.',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
            ],

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  appState.isConverting
                      ? null
                      : () => _convertAudio(appState.selectedConversionFormat),
              child: Text(
                appState.selectedConversionFormat == AudioFormat.m4a
                    ? 'Convert to M4A (AAC codec)'
                    : 'Copy with Original Format',
              ),
            ),

            if (appState.isConverting) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: appState.conversionProgress),
              const SizedBox(height: 8),
              Text(
                'Converting: ${(appState.conversionProgress * 100).toStringAsFixed(1)}%',
              ),

              // Add manual completion button when stuck at 100%
              if (appState.conversionProgress >= 1.0) ...[
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _forceCompleteConversion(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Force Complete (Stuck at 100%?)'),
                ),
                const SizedBox(height: 4),
                const Text(
                  'If conversion is stuck at 100%, click above to force completion',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ],
            if (appState.convertedFilePath != null) ...[
              const SizedBox(height: 16),
              Text(
                'Converted file: ${appState.convertedFilePath!.split('/').last}',
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _playConvertedFile(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Play Converted Audio'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _convertAudio(AudioFormat format) async {
    if (kDebugMode) {
      print('*** CONVERSION WIDGET: Starting conversion ***');
      print('Selected format: ${format.name}');
      print('Current isConverting: ${appState.isConverting}');
    }

    // Set the selected format in the app state
    appState.selectedConversionFormat = format;

    try {
      await AudioService.convertAudio(appState);

      if (kDebugMode) {
        print('*** CONVERSION WIDGET: AudioService.convertAudio returned ***');
        print('Post-conversion isConverting: ${appState.isConverting}');
        print(
          'Post-conversion convertedFilePath: ${appState.convertedFilePath}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('*** CONVERSION WIDGET: Conversion failed with error: $e ***');
      }
    } finally {
      if (kDebugMode) {
        print('*** CONVERSION WIDGET: In finally block ***');
        print('Pre-onStateChanged isConverting: ${appState.isConverting}');
      }

      // Force UI update even if conversion fails
      onStateChanged();

      // Additional safety check to ensure conversion state is reset
      if (appState.isConverting) {
        if (kDebugMode) {
          print(
            '*** CONVERSION WIDGET: WARNING - isConverting still true, forcing reset ***',
          );
        }
        appState.isConverting = false;
        onStateChanged();
      }

      if (kDebugMode) {
        print('*** CONVERSION WIDGET: Conversion attempt completed ***');
        print('Final isConverting: ${appState.isConverting}');
        print('Final convertedFilePath: ${appState.convertedFilePath}');
      }
    }
  }

  void _playConvertedFile(BuildContext context) {
    if (appState.convertedFilePath != null) {
      // Set the converted file as the current audio file for playback
      appState.currentPlayingFile = appState.convertedFilePath;

      // Show a snackbar to indicate playback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Playing converted file: ${appState.convertedFilePath!.split('/').last}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      onStateChanged();
    }
  }

  void _forceCompleteConversion(BuildContext context) async {
    if (kDebugMode) {
      print('*** USER MANUALLY FORCING CONVERSION COMPLETION ***');
      print(
        'Progress was: ${(appState.conversionProgress * 100).toStringAsFixed(1)}%',
      );
    }

    // Store context-dependent functions early to avoid async gaps
    void showSnackBar(String message, Color backgroundColor) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: backgroundColor),
        );
      }
    }

    // Check if there's an output directory and look for recent files
    try {
      final directory = await AudioService.getOutputDirectory();
      final files = directory.listSync();

      // Look for the most recent file that might be our conversion
      File? mostRecentFile;
      DateTime? mostRecentTime;

      for (final file in files) {
        if (file is File && file.path.contains('converted_audio_')) {
          final stat = file.statSync();
          if (mostRecentTime == null || stat.modified.isAfter(mostRecentTime)) {
            mostRecentTime = stat.modified;
            mostRecentFile = file;
          }
        }
      }

      if (mostRecentFile != null && await mostRecentFile.exists()) {
        final fileSize = await mostRecentFile.length();
        if (kDebugMode) {
          print('*** FOUND RECENT CONVERSION FILE: ${mostRecentFile.path} ***');
          print('*** FILE SIZE: $fileSize bytes ***');
        }

        if (fileSize > 1000) {
          // Reasonable file size
          appState.isConverting = false;
          appState.convertedFilePath = mostRecentFile.path;
          onStateChanged();

          if (kDebugMode) {
            print('*** MANUALLY COMPLETED CONVERSION SUCCESSFULLY ***');
          }

          showSnackBar(
            'Conversion completed manually! File found and ready.',
            Colors.green,
          );
          return;
        }
      }

      if (kDebugMode) {
        print('*** NO SUITABLE CONVERSION FILE FOUND ***');
      }

      showSnackBar(
        'No completed conversion file found. The conversion may still be processing.',
        Colors.orange,
      );
    } catch (e) {
      if (kDebugMode) {
        print('*** ERROR DURING MANUAL COMPLETION: $e ***');
      }

      showSnackBar('Error during manual completion: $e', Colors.red);
    }
  }
}
