import 'package:flutter/material.dart';
import '../models/app_state.dart';
import 'audio_player_documentation_widget.dart';
import 'true_waveform_player_widget.dart';
import 'lib_fake_waveform_player_widget.dart';
import 'custom_fake_waveform_player.dart';
import 'remote_audio_demo_widget.dart';

/// Widget that demonstrates different audio player implementations
class AudioPlayerDemoWidget extends StatefulWidget {
  final AppState appState;

  const AudioPlayerDemoWidget({super.key, required this.appState});

  @override
  State<AudioPlayerDemoWidget> createState() => _AudioPlayerDemoWidgetState();
}

class _AudioPlayerDemoWidgetState extends State<AudioPlayerDemoWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which file to play (selected, converted, or trimmed)
    String? fileToPlay =
        widget.appState.currentPlayingFile ?? widget.appState.selectedFilePath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Audio Player Demo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // File selection info
        if (fileToPlay != null) ...[
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Playing: ${fileToPlay.split('/').last}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (fileToPlay == widget.appState.convertedFilePath)
                    const Text(
                      '(Converted file)',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  if (fileToPlay == widget.appState.trimmedFilePath)
                    const Text(
                      '(Trimmed file)',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          tabs: const [
            Tab(text: 'True Waveform'),
            Tab(text: 'Fake Waveform'),
            Tab(text: 'Custom Player'),
            Tab(text: 'Remote Audio'),
            Tab(text: 'Documentation'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // True Waveform Player Tab
              fileToPlay != null && widget.appState.waveformData != null
                  ? TrueWaveformPlayerWidget(
                    audioPath: fileToPlay,
                    waveformData: widget.appState.waveformData!,
                  )
                  : TrueWaveformPlayerWidget.placeholder(context),

              // Fake Waveform Player Tab
              fileToPlay != null
                  ? LibFakeWaveformPlayerWidget(audioPath: fileToPlay)
                  : LibFakeWaveformPlayerWidget.placeholder(context),

              // Custom Fake Waveform Player Tab
              fileToPlay != null
                  ? CustomFakeWaveformPlayer(
                    audioPath: fileToPlay,
                    waveformData:
                        null, // Let the custom player generate its own waveform
                  )
                  : CustomFakeWaveformPlayer.placeholder(context),

              // Remote Audio Demo Tab
              const RemoteAudioDemoWidget(),

              // Documentation Tab
              const AudioPlayerDocumentationWidget(),
            ],
          ),
        ),
      ],
    );
  }
}
