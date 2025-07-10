import 'package:flutter/material.dart';
import 'package:flutter_audio_toolkit/flutter_audio_toolkit.dart';
import '../models/app_state.dart';
import '../services/audio_service.dart';
import '../utils/pattern_helper.dart';

/// Widget for waveform extraction and display
class WaveformWidget extends StatelessWidget {
  final AppState appState;
  final VoidCallback onStateChanged;

  const WaveformWidget({
    super.key,
    required this.appState,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (appState.selectedFilePath == null) return const SizedBox.shrink();

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waveform Extraction',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Fake waveform mode toggle
                CheckboxListTile(
                  title: const Text('Use Fake Waveform'),
                  subtitle: const Text(
                    'Generate synthetic waveform instead of extracting from audio',
                  ),
                  value: appState.isFakeWaveformMode,
                  onChanged: (bool? value) {
                    appState.isFakeWaveformMode = value ?? false;
                    // Clear existing waveform data when mode changes
                    appState.waveformData = null;
                    onStateChanged();
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 8),

                // Conditional buttons based on fake waveform mode
                if (appState.isFakeWaveformMode) ...[
                  // Fake waveform pattern selection
                  Row(
                    children: [
                      const Text('Pattern: '),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<WaveformPattern>(
                          value: appState.selectedWaveformPattern,
                          isExpanded: true,
                          onChanged: (WaveformPattern? value) {
                            if (value != null) {
                              appState.selectedWaveformPattern = value;
                              onStateChanged();
                            }
                          },
                          items:
                              WaveformPattern.values.map((
                                WaveformPattern pattern,
                              ) {
                                return DropdownMenuItem<WaveformPattern>(
                                  value: pattern,
                                  child: Text(
                                    PatternHelper.getPatternDescription(
                                      pattern,
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed:
                        appState.isExtracting ? null : _generateFakeWaveform,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Generate Fake Waveform'),
                  ),
                ] else ...[
                  // Real waveform extraction
                  ElevatedButton(
                    onPressed: appState.isExtracting ? null : _extractWaveform,
                    child: const Text('Extract Real Waveform'),
                  ),
                ],

                if (appState.isExtracting) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: appState.waveformProgress),
                  const SizedBox(height: 8),
                  Text(
                    appState.isFakeWaveformMode
                        ? 'Generating: ${(appState.waveformProgress * 100).toStringAsFixed(1)}%'
                        : 'Extracting: ${(appState.waveformProgress * 100).toStringAsFixed(1)}%',
                  ),
                ],
              ],
            ),
          ),
        ),

        if (appState.waveformData != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Waveform Data',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          appState.isFakeWaveformMode
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                      border: Border.all(
                        color:
                            appState.isFakeWaveformMode
                                ? Colors.orange
                                : Colors.green,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          appState.isFakeWaveformMode
                              ? Icons.auto_fix_high
                              : Icons.graphic_eq,
                          color:
                              appState.isFakeWaveformMode
                                  ? Colors.orange
                                  : Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          appState.isFakeWaveformMode
                              ? 'Fake Waveform (${appState.selectedWaveformPattern.name.toUpperCase()} pattern)'
                              : 'Real Waveform Data',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color:
                                appState.isFakeWaveformMode
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Samples: ${appState.waveformData!.amplitudes.length}'),
                  Text(
                    'Duration: ${(appState.waveformData!.durationMs / 1000).toStringAsFixed(2)}s',
                  ),
                  Text('Sample Rate: ${appState.waveformData!.sampleRate} Hz'),
                  Text('Channels: ${appState.waveformData!.channels}'),
                  const SizedBox(height: 16),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomPaint(
                      painter: WaveformPainter(
                        waveformData: appState.waveformData!,
                        config: WaveformVisualizationConfig(
                          height: 100,
                          interactive: true,
                          style: const WaveformStyle(
                            primaryColor: Colors.blue,
                            lineWidth: 2.0,
                          ),
                        ),
                        currentPosition: Duration.zero,
                        duration: Duration(
                          milliseconds: appState.waveformData!.durationMs,
                        ),
                      ),
                      size: const Size.fromHeight(100),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _extractWaveform() async {
    await AudioService.extractWaveform(appState);
    onStateChanged();
  }

  void _generateFakeWaveform() {
    AudioService.generateFakeWaveform(appState);
    onStateChanged();
  }
}
