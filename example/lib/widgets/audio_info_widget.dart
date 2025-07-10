import 'package:flutter/material.dart';
import '../models/app_state.dart';

/// Widget for displaying audio file information
class AudioInfoWidget extends StatelessWidget {
  final AppState appState;

  const AudioInfoWidget({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    if (appState.audioInfo == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Audio Info',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (appState.audioInfo!.isValid) ...[
              Text('Format: ${appState.audioInfo!.mimeType ?? 'Unknown'}'),
              if (appState.audioInfo!.formatDiagnostics != null)
                Text(
                  'Detected: ${appState.audioInfo!.formatDiagnostics}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              Text(
                'Duration: ${(appState.audioInfo!.durationMs! / 1000).toStringAsFixed(2)}s',
              ),
              Text('Sample Rate: ${appState.audioInfo!.sampleRate} Hz'),
              Text('Channels: ${appState.audioInfo!.channels}'),
              Text('Bit Rate: ${appState.audioInfo!.bitRate} bps'),
              if (appState.audioInfo!.fileSize != null)
                Text(
                  'File Size: ${(appState.audioInfo!.fileSize! / 1024 / 1024).toStringAsFixed(2)} MB',
                ),
              const SizedBox(height: 12),
              const Text(
                'Feature Compatibility:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              _buildCompatibilityRow(
                'Audio Conversion',
                appState.audioInfo!.supportedForConversion,
              ),
              _buildCompatibilityRow(
                'Audio Trimming',
                appState.audioInfo!.supportedForTrimming,
                subtitle:
                    !appState.audioInfo!.supportedForLosslessTrimming &&
                            appState.audioInfo!.supportedForTrimming
                        ? ' (requires conversion)'
                        : null,
              ),
              _buildCompatibilityRow(
                'Waveform Extraction',
                appState.audioInfo!.supportedForWaveform,
              ),
              if (appState.audioInfo!.foundTracks != null) ...[
                const SizedBox(height: 8),
                ExpansionTile(
                  title: const Text(
                    'Track Information',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  children: [
                    for (String track in appState.audioInfo!.foundTracks!)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 16,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '• $track',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ] else ...[
              // Show error information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'File Analysis Failed',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${appState.audioInfo!.error ?? 'Unknown error'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (appState.audioInfo!.details != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        appState.audioInfo!.details!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (appState.audioInfo!.formatDiagnostics != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Format Analysis: ${appState.audioInfo!.formatDiagnostics}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (appState.audioInfo!.foundTracks != null) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Found tracks:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      for (String track in appState.audioInfo!.foundTracks!)
                        Text('• $track', style: const TextStyle(fontSize: 12)),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Supported formats: MP3, M4A, AAC, WAV, OGG',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompatibilityRow(
    String feature,
    bool isSupported, {
    String? subtitle,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              isSupported ? Icons.check_circle : Icons.cancel,
              color: isSupported ? Colors.green : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(feature),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
          ],
        ),
      ],
    );
  }
}
