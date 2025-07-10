import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/app_state.dart';
import '../services/audio_service.dart';
import '../services/validation_service.dart';

/// Widget for file picking and URL input
class FilePickerWidget extends StatelessWidget {
  final AppState appState;
  final VoidCallback onError;

  const FilePickerWidget({super.key, required this.appState, required this.onError});

  Future<void> _pickAudioFile() async {
    if (kDebugMode) {
      print('Pick Audio File button pressed');
    }

    try {
      // Try primary permission validation first
      if (kDebugMode) {
        print('Checking storage permissions...');
      }

      bool permissionsOk = false;
      try {
        permissionsOk = await ValidationService.validateStoragePermissions();
      } catch (e) {
        if (kDebugMode) {
          print('Primary permission validation failed: $e');
          print('Trying fallback permission validation...');
        }
        // Fallback to direct validation that bypasses permission_handler
        permissionsOk = await ValidationService.validateStoragePermissionsDirectly();
      }

      if (!permissionsOk) {
        if (kDebugMode) {
          print('All permission validation methods failed');
        }
        return;
      }

      if (kDebugMode) {
        print('Permissions validated, opening file picker...');
      }

      // Try multiple file picker approaches for better Android compatibility
      FilePickerResult? result;

      try {
        // First try with custom extensions (most restrictive)
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a', 'aac'],
          allowMultiple: false,
        );
      } catch (e) {
        if (kDebugMode) {
          print('Custom file type failed, trying audio type: $e');
        }

        try {
          // Fallback to audio file type
          result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
        } catch (e2) {
          if (kDebugMode) {
            print('Audio file type failed, trying any type: $e2');
          }

          // Last resort - any file type
          result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
        }
      }

      if (kDebugMode) {
        print('File picker result: ${result != null ? "Selected" : "Cancelled"}');
      }

      if (result != null && result.files.isNotEmpty) {
        final selectedPath = result.files.single.path;

        if (kDebugMode) {
          print('Selected file path: $selectedPath');
        }

        // Validate the selected file
        if (selectedPath == null) {
          if (kDebugMode) {
            print('Selected path is null');
          }
          onError();
          return;
        }

        final file = File(selectedPath);
        if (!await file.exists()) {
          if (kDebugMode) {
            print('File does not exist: $selectedPath');
          }
          onError();
          return;
        }

        // Check if file has audio data (basic check)
        final fileSize = await file.length();
        if (fileSize == 0) {
          if (kDebugMode) {
            print('File is empty: $selectedPath');
          }
          onError();
          return;
        }

        // Validate file extension for audio files
        final extension = selectedPath.split('.').last.toLowerCase();
        final allowedExtensions = ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'mp4', 'flac'];

        if (!allowedExtensions.contains(extension)) {
          if (kDebugMode) {
            print('File extension not supported: $extension');
          }
          onError();
          return;
        }

        if (kDebugMode) {
          print('Setting selected file path and resetting state');
        }

        appState.selectedFilePath = selectedPath;
        appState.resetForNewFile();

        if (appState.selectedFilePath != null) {
          // Validate format support first
          if (kDebugMode) {
            print('Validating format support');
          }

          if (await ValidationService.validateFormatSupport(appState)) {
            if (kDebugMode) {
              print('Format supported, getting audio info');
            }

            await AudioService.getAudioInfo(appState);

            // Initialize trim end time to audio duration
            if (appState.audioInfo != null && appState.audioInfo!.durationMs != null) {
              if (kDebugMode) {
                print('Setting trim end time to: ${appState.audioInfo!.durationMs} ms');
              }

              appState.trimEndMs = appState.audioInfo!.durationMs!;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in file picker: $e');
        print('Stack trace: ${StackTrace.current}');
      }
      onError();
    }
  }

  Future<void> _processUrlFile() async {
    try {
      // Make sure we're using the actual text from the controller
      final url = appState.urlController.text;
      if (kDebugMode) {
        print('Processing URL: $url');
      }

      // Extract waveform from URL
      await AudioService.extractWaveform(appState);
    } catch (e) {
      if (kDebugMode) {
        print('Error processing URL file: $e');
      }
      onError();
    }
  }

  Future<void> _generateFakeWaveformFromUrl() async {
    try {
      // Generate fake waveform
      if (kDebugMode) {
        print('Generating fake waveform');
      }
      AudioService.generateFakeWaveform(appState);
    } catch (e) {
      if (kDebugMode) {
        print('Error generating fake waveform: $e');
      }
      onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform: ${appState.platformVersion}'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _pickAudioFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.audio_file),
                  SizedBox(width: 8),
                  Text('Pick Audio File', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
            if (appState.selectedFilePath != null) ...[
              const SizedBox(height: 8),
              Text('Selected: ${appState.selectedFilePath!.split('/').last}'),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Or process from Network URL:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: appState.urlController,
              decoration: const InputDecoration(
                hintText: 'https://example.com/audio.mp3',
                labelText: 'Audio File URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              enabled: !appState.isDownloading && !appState.isExtracting,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (appState.isDownloading || appState.isExtracting || appState.urlController.text.trim().isEmpty)
                            ? null
                            : _processUrlFile,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Extract Real Waveform'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (appState.isExtracting || appState.urlController.text.trim().isEmpty)
                            ? null
                            : _generateFakeWaveformFromUrl,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Generate Fake'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade100,
                      foregroundColor: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),

            if (appState.isDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: appState.downloadProgress),
              const SizedBox(height: 8),
              Text('Downloading: ${(appState.downloadProgress * 100).toStringAsFixed(1)}%'),
            ],
          ],
        ),
      ),
    );
  }
}
