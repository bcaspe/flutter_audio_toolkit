import 'dart:io';
import 'package:flutter/material.dart';
import '../models/app_state.dart';
import '../services/audio_service.dart';

/// Widget for audio trimming controls
class TrimmingWidget extends StatelessWidget {
  final AppState appState;
  final VoidCallback onStateChanged;

  const TrimmingWidget({
    super.key,
    required this.appState,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (appState.audioInfo == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Load an audio file to enable trimming'),
        ),
      );
    }

    // Set default trim range if not set
    if (appState.trimStartMs == 0 &&
        appState.trimEndMs == 0 &&
        appState.audioInfo!.durationMs != null) {
      appState.trimEndMs = appState.audioInfo!.durationMs!;
      onStateChanged();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '✂️ Audio Trimming',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Trim your audio file to a specific time range. The trimmed file will be saved in M4A format for best compatibility.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            if (appState.audioInfo != null &&
                appState.audioInfo!.durationMs != null) ...[
              // Trim range controls
              const Text('Start Time (seconds):'),
              Slider(
                value: (appState.trimStartMs / 1000).toDouble(),
                max: (appState.audioInfo!.durationMs! / 1000).toDouble(),
                onChanged: (value) {
                  final newStartMs = (value * 1000).toInt();
                  final durationMs = appState.audioInfo!.durationMs!;

                  // Ensure start time is within valid bounds
                  appState.trimStartMs = newStartMs.clamp(0, durationMs - 1000);

                  // Ensure end time maintains minimum 1 second gap
                  if (appState.trimEndMs <= appState.trimStartMs) {
                    appState.trimEndMs = (appState.trimStartMs + 1000).clamp(
                      1000,
                      durationMs,
                    );
                  }
                  onStateChanged();
                },
                label: '${(appState.trimStartMs / 1000).toStringAsFixed(1)}s',
              ),
              const Text('End Time (seconds):'),
              Slider(
                value: (appState.trimEndMs / 1000).toDouble(),
                max: (appState.audioInfo!.durationMs! / 1000).toDouble(),
                onChanged: (value) {
                  final newEndMs = (value * 1000).toInt();
                  final durationMs = appState.audioInfo!.durationMs!;

                  // Ensure end time is within valid bounds
                  appState.trimEndMs = newEndMs.clamp(1000, durationMs);

                  // Ensure start time maintains minimum 1 second gap
                  if (appState.trimStartMs >= appState.trimEndMs) {
                    appState.trimStartMs = (appState.trimEndMs - 1000).clamp(
                      0,
                      durationMs - 1000,
                    );
                  }
                  onStateChanged();
                },
                label: '${(appState.trimEndMs / 1000).toStringAsFixed(1)}s',
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trim range: ${(appState.trimStartMs / 1000).toStringAsFixed(1)}s - ${(appState.trimEndMs / 1000).toStringAsFixed(1)}s',
                  ),
                  Text(
                    'Duration: ${((appState.trimEndMs - appState.trimStartMs) / 1000).toStringAsFixed(1)}s',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              // Format information
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Trimmed audio will be saved in M4A format with AAC codec at 320kbps (high quality) for best compatibility and audio clarity.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Trim button
            ElevatedButton(
              onPressed:
                  (appState.isTrimming ||
                          appState.selectedFilePath == null ||
                          appState.audioInfo == null)
                      ? null
                      : _trimAudio,
              child: const Text('Trim Audio'),
            ),

            // Progress indicator
            if (appState.isTrimming) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: appState.trimProgress),
              const SizedBox(height: 8),
              Text(
                'Trimming: ${(appState.trimProgress * 100).toStringAsFixed(1)}%',
              ),
            ],

            // Trimmed file info and playback
            if (appState.trimmedFilePath != null) ...[
              const SizedBox(height: 16),
              Text(
                'Trimmed file: ${appState.trimmedFilePath!.split('/').last}',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _playTrimmedFile(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Play Trimmed Audio'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _showFileLocation(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Show File Location'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _trimAudio() async {
    await AudioService.trimAudio(appState);
    onStateChanged();
  }

  void _playTrimmedFile(BuildContext context) {
    if (appState.trimmedFilePath != null) {
      // Set the trimmed file as the current audio file for playback
      appState.currentPlayingFile = appState.trimmedFilePath;

      // Show a snackbar to indicate playback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Playing trimmed file: ${appState.trimmedFilePath!.split('/').last}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      onStateChanged();
    }
  }

  Future<void> _showFileLocation(BuildContext context) async {
    if (appState.trimmedFilePath != null) {
      final locationDescription =
          await AudioService.getOutputLocationDescription();
      final fileName = appState.trimmedFilePath!.split('/').last;
      final fullPath = appState.trimmedFilePath!;

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('📁 File Location'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your trimmed audio file has been saved!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('📄 File name: $fileName'),
                    const SizedBox(height: 16),
                    Text(locationDescription),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '💡 Quick Tips:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• Open your device\'s file manager app',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            '• Look for "Downloads" or "AudioToolkit" folder',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            '• Search for the file name above if needed',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Text(
                            '• Files are compatible with most audio players',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      title: const Text(
                        '🔧 Full Path (Advanced)',
                        style: TextStyle(fontSize: 14),
                      ),
                      children: [
                        SelectableText(
                          fullPath,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it!'),
                ),
                if (Platform.isAndroid)
                  ElevatedButton(
                    onPressed: () => _openFileManager(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Open File Manager'),
                  ),
              ],
            );
          },
        );
      }
    }
  }

  void _openFileManager(BuildContext context) {
    // This is a placeholder - in a real app, you might use a plugin like
    // android_intent_plus to open the file manager directly
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please open your device\'s file manager app and navigate to Downloads → AudioToolkit',
        ),
        duration: Duration(seconds: 4),
        backgroundColor: Colors.blue,
      ),
    );
    Navigator.of(context).pop();
  }
}
