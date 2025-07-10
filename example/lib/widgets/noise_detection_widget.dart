import 'package:flutter/material.dart';
import 'package:flutter_audio_toolkit/flutter_audio_toolkit.dart';
import '../models/app_state.dart';
import '../services/audio_service.dart';

class NoiseDetectionWidget extends StatefulWidget {
  final AppState appState;
  final VoidCallback onStateChanged;

  const NoiseDetectionWidget({
    super.key,
    required this.appState,
    required this.onStateChanged,
  });

  @override
  State<NoiseDetectionWidget> createState() => _NoiseDetectionWidgetState();
}

class _NoiseDetectionWidgetState extends State<NoiseDetectionWidget> {
  bool _isAnalyzing = false;
  NoiseDetectionResult? _analysisResult;
  String? _errorMessage;

  Future<void> _analyzeAudio() async {
    if (widget.appState.selectedFilePath == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _analysisResult = null;
    });

    try {
      await AudioService.analyzeNoise(widget.appState);

      setState(() {
        _analysisResult = widget.appState.noiseAnalysisResult;
        _isAnalyzing = false;
      });

      widget.onStateChanged();
    } catch (e) {
      setState(() {
        _errorMessage = 'Analysis failed: $e';
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Noise Detection & Audio Quality Analysis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Analyze Button
            if (widget.appState.selectedFilePath != null) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _analyzeAudio,
                  icon:
                      _isAnalyzing
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.analytics),
                  label: Text(
                    _isAnalyzing
                        ? 'Analyzing Audio...'
                        : 'Analyze for Noise & Quality',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Select an audio file to analyze noise and quality',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Error Message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ], // Analysis Results
            if (_analysisResult != null) ...[
              // Quality Metrics Section
              _buildQualitySection(_analysisResult!.qualityMetrics),
              const SizedBox(height: 16),

              // Detected Noises Section
              if (_analysisResult!.detectedNoises.isNotEmpty) ...[
                _buildNoisesSection(_analysisResult!.detectedNoises),
                const SizedBox(height: 16),
              ],

              // Frequency Analysis Section
              _buildFrequencySection(_analysisResult!.frequencyAnalysis),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQualitySection(AudioQualityMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.high_quality, color: Colors.blue),
            const SizedBox(width: 8),
            const Text(
              'Audio Quality Analysis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getGradeColor(metrics.grade),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                metrics.grade.description,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.5,
          children: [
            _buildMetricTile('Peak Level', metrics.peakLevelFormatted),
            _buildMetricTile('Average Level', metrics.averageLevelFormatted),
            _buildMetricTile(
              'Dynamic Range',
              '${metrics.dynamicRange.toStringAsFixed(1)} dB',
            ),
            _buildMetricTile('SNR', metrics.snrFormatted),
            _buildMetricTile('Loudness', metrics.lufsFormatted),
            _buildMetricTile(
              'Overall Score',
              '${(metrics.overallScore * 100).toStringAsFixed(0)}%',
            ),
          ],
        ),
        if (metrics.hasClipping ||
            metrics.hasDistortion ||
            metrics.hasBalanceIssues) ...[
          const SizedBox(height: 8),
          const Text(
            'Issues Detected:',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
          ),
          if (metrics.hasClipping)
            const Text(
              '⚠️ Audio clipping detected',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          if (metrics.hasDistortion)
            const Text(
              '⚠️ Distortion present',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          if (metrics.hasBalanceIssues)
            const Text(
              '⚠️ Stereo balance issues',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
        ],
      ],
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoisesSection(List<DetectedNoise> noises) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.volume_up, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Detected Background Noises (${noises.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...noises.map(
          (noise) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getNoiseColor(noise.confidence)),
              color: _getNoiseColor(noise.confidence).withValues(alpha: 0.05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        noise.type.description,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getNoiseColor(noise.confidence),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(noise.confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${(noise.confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                Text(
                  'Found at: ${noise.timeRange}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencySection(FrequencyAnalysis analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.equalizer, color: Colors.purple),
            SizedBox(width: 8),
            Text(
              'Frequency Analysis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (analysis.fundamentalFrequency != null)
          Text(
            'Fundamental Frequency: ${analysis.fundamentalFrequency!.toStringAsFixed(1)} Hz',
          ),
        const SizedBox(height: 8),
        // Simple frequency bars visualization
        Row(
          children: [
            Expanded(
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text('Bass', style: TextStyle(fontSize: 10)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text('Mid', style: TextStyle(fontSize: 10)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text('Treble', style: TextStyle(fontSize: 10)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Characteristics: ${analysis.tonalCharacteristics.join(', ')}'),
        if (analysis.problematicBands.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Problematic Frequency Bands:',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
          ),
          ...analysis.problematicBands.map(
            (band) => Text(
              '• ${band.toString()}',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }

  Color _getGradeColor(AudioQualityGrade grade) {
    switch (grade) {
      case AudioQualityGrade.excellent:
        return Colors.green;
      case AudioQualityGrade.good:
        return Colors.lightGreen;
      case AudioQualityGrade.fair:
        return Colors.orange;
      case AudioQualityGrade.poor:
        return Colors.deepOrange;
      case AudioQualityGrade.veryPoor:
        return Colors.red;
    }
  }

  Color _getNoiseColor(double confidence) {
    if (confidence >= 0.8) return Colors.red;
    if (confidence >= 0.6) return Colors.orange;
    if (confidence >= 0.4) return Colors.yellow.shade700;
    return Colors.green;
  }
}
