import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_audio_toolkit/flutter_audio_toolkit.dart';

/// Real audio player service for the example app
class ExampleAudioPlayerService {
  /// Currently active player instances
  static final Map<String, ExampleAudioPlayerService> _instances = {};

  /// Unique identifier for this player instance
  final String playerId;

  /// Real audio player instance
  late final AudioPlayer _audioPlayer;

  /// Current state
  AudioPlayerState _state = AudioPlayerState.stopped;

  /// Current position
  Duration _position = Duration.zero;

  /// Total duration
  Duration _duration = Duration.zero;

  /// Current volume
  double _volume = 1.0;

  /// Audio file path
  String? _audioPath;

  /// Waveform data
  WaveformData? _waveformData;

  /// State change callbacks
  final List<void Function(AudioPlayerState)> _stateCallbacks = [];
  final List<void Function(Duration)> _positionCallbacks = [];
  final List<void Function(Duration)> _durationCallbacks = [];
  final List<void Function(String)> _errorCallbacks = [];

  /// Whether this player is disposed
  bool _isDisposed = false;

  ExampleAudioPlayerService._({required this.playerId}) {
    _instances[playerId] = this;
    _audioPlayer = AudioPlayer(playerId: playerId);
    _setupAudioPlayerListeners();
  }

  /// Creates a new audio player instance
  static ExampleAudioPlayerService create({String? playerId}) {
    final id = playerId ?? DateTime.now().millisecondsSinceEpoch.toString();
    return ExampleAudioPlayerService._(playerId: id);
  }

  /// Gets an existing player instance by ID
  static ExampleAudioPlayerService? getInstance(String playerId) {
    return _instances[playerId];
  }

  /// Sets up audio player listeners
  void _setupAudioPlayerListeners() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      final newState = _convertPlayerState(state);
      if (newState != _state) {
        _state = newState;
        _notifyStateCallbacks(newState);
      }
    });

    _audioPlayer.onPositionChanged.listen((Duration position) {
      _position = position;
      _notifyPositionCallbacks(position);
    });

    _audioPlayer.onDurationChanged.listen((Duration duration) {
      _duration = duration;
      _notifyDurationCallbacks(duration);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _state = AudioPlayerState.stopped;
      _position = Duration.zero;
      _notifyStateCallbacks(AudioPlayerState.stopped);
      _notifyPositionCallbacks(Duration.zero);
    });
  }

  /// Converts audioplayers PlayerState to our AudioPlayerState
  AudioPlayerState _convertPlayerState(PlayerState state) {
    switch (state) {
      case PlayerState.playing:
        return AudioPlayerState.playing;
      case PlayerState.paused:
        return AudioPlayerState.paused;
      case PlayerState.stopped:
        return AudioPlayerState.stopped;
      case PlayerState.completed:
        return AudioPlayerState.stopped;
      case PlayerState.disposed:
        return AudioPlayerState.stopped;
    }
  }

  /// Loads an audio file for playback
  Future<void> loadAudio(String audioPath) async {
    if (_isDisposed) throw StateError('Player has been disposed');

    try {
      _state = AudioPlayerState.loading;
      _notifyStateCallbacks(AudioPlayerState.loading);

      // Verify file exists
      final file = File(audioPath);
      if (!await file.exists()) {
        throw FileSystemException('Audio file not found', audioPath);
      }

      // Load audio
      await _audioPlayer.setSource(DeviceFileSource(audioPath));

      _audioPath = audioPath;
      _state = AudioPlayerState.stopped;
      _position = Duration.zero;

      // Wait for duration to be available
      int retryCount = 0;
      const maxRetries = 10;
      const retryDelay = Duration(milliseconds: 200);

      while (_duration == Duration.zero && retryCount < maxRetries) {
        await Future.delayed(retryDelay);
        retryCount++;
      }

      _notifyStateCallbacks(AudioPlayerState.stopped);
    } catch (e) {
      _state = AudioPlayerState.error;
      _notifyStateCallbacks(AudioPlayerState.error);
      _notifyErrorCallbacks('Failed to load audio: $e');
      rethrow;
    }
  }

  /// Loads audio with true waveform extraction
  Future<void> loadAudioWithTrueWaveform(String audioPath) async {
    await loadAudio(audioPath);

    try {
      // Extract real waveform data in background
      final toolkit = FlutterAudioToolkit();
      final waveformData = await toolkit.extractWaveform(inputPath: audioPath, samplesPerSecond: 100);
      _waveformData = waveformData;
    } catch (e) {
      // Failed to extract waveform data
    }
  }

  /// Loads audio with fake waveform generation
  Future<void> loadAudioWithFakeWaveform(
    String audioPath, {
    WaveformPattern pattern = WaveformPattern.music,
    int samplesPerSecond = 100,
  }) async {
    await loadAudio(audioPath);

    try {
      // Generate fake waveform based on actual duration
      final toolkit = FlutterAudioToolkit();
      final fakeWaveform = toolkit.generateFakeWaveform(
        pattern: pattern,
        durationMs: _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 180000,
        samplesPerSecond: samplesPerSecond,
      );
      _waveformData = fakeWaveform;
    } catch (e) {
      // Failed to generate fake waveform
    }
  }

  /// Starts or resumes playback
  Future<void> play() async {
    if (_isDisposed) throw StateError('Player has been disposed');

    try {
      await _audioPlayer.play(DeviceFileSource(_audioPath!));
    } catch (e) {
      _notifyErrorCallbacks('Failed to play audio: $e');
      rethrow;
    }
  }

  /// Pauses playback
  Future<void> pause() async {
    if (_isDisposed) throw StateError('Player has been disposed');

    try {
      await _audioPlayer.pause();
    } catch (e) {
      _notifyErrorCallbacks('Failed to pause audio: $e');
      rethrow;
    }
  }

  /// Stops playback and resets position
  Future<void> stop() async {
    if (_isDisposed) throw StateError('Player has been disposed');

    try {
      await _audioPlayer.stop();
      _position = Duration.zero;
    } catch (e) {
      _notifyErrorCallbacks('Failed to stop audio: $e');
      rethrow;
    }
  }

  /// Seeks to a specific position
  Future<void> seekTo(Duration position) async {
    if (_isDisposed) throw StateError('Player has been disposed');

    try {
      final clampedPosition = Duration(milliseconds: position.inMilliseconds.clamp(0, _duration.inMilliseconds));
      await _audioPlayer.seek(clampedPosition);
    } catch (e) {
      _notifyErrorCallbacks('Failed to seek: $e');
      rethrow;
    }
  }

  /// Sets the playback volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    if (_isDisposed) throw StateError('Player has been disposed');

    volume = volume.clamp(0.0, 1.0);

    try {
      await _audioPlayer.setVolume(volume);
      _volume = volume;
    } catch (e) {
      _notifyErrorCallbacks('Failed to set volume: $e');
      rethrow;
    }
  }

  /// Toggles between play and pause
  Future<void> togglePlayPause() async {
    if (_state == AudioPlayerState.playing) {
      await pause();
    } else {
      await play();
    }
  }

  /// Disposes the player and releases resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    try {
      await _audioPlayer.dispose();
    } catch (e) {
      // Error disposing audio player
    }

    _instances.remove(playerId);
    _stateCallbacks.clear();
    _positionCallbacks.clear();
    _durationCallbacks.clear();
    _errorCallbacks.clear();
  }

  /// Add state change callback
  void addStateCallback(void Function(AudioPlayerState) callback) {
    _stateCallbacks.add(callback);
  }

  /// Add position change callback
  void addPositionCallback(void Function(Duration) callback) {
    _positionCallbacks.add(callback);
  }

  /// Add duration change callback
  void addDurationCallback(void Function(Duration) callback) {
    _durationCallbacks.add(callback);
  }

  /// Add error callback
  void addErrorCallback(void Function(String) callback) {
    _errorCallbacks.add(callback);
  }

  /// Remove callbacks
  void removeStateCallback(void Function(AudioPlayerState) callback) {
    _stateCallbacks.remove(callback);
  }

  void removePositionCallback(void Function(Duration) callback) {
    _positionCallbacks.remove(callback);
  }

  void removeDurationCallback(void Function(Duration) callback) {
    _durationCallbacks.remove(callback);
  }

  void removeErrorCallback(void Function(String) callback) {
    _errorCallbacks.remove(callback);
  }

  /// Notify callbacks
  void _notifyStateCallbacks(AudioPlayerState state) {
    for (final callback in _stateCallbacks) {
      try {
        callback(state);
      } catch (e) {
        // Error in state callback
      }
    }
  }

  void _notifyPositionCallbacks(Duration position) {
    for (final callback in _positionCallbacks) {
      try {
        callback(position);
      } catch (e) {
        // Error in position callback
      }
    }
  }

  void _notifyDurationCallbacks(Duration duration) {
    for (final callback in _durationCallbacks) {
      try {
        callback(duration);
      } catch (e) {
        // Error in duration callback
      }
    }
  }

  void _notifyErrorCallbacks(String error) {
    for (final callback in _errorCallbacks) {
      try {
        callback(error);
      } catch (e) {
        // Error in error callback
      }
    }
  }

  /// Getters
  AudioPlayerState get state => _state;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  String? get audioPath => _audioPath;
  WaveformData? get waveformData => _waveformData;
  bool get isPlaying => _state == AudioPlayerState.playing;
  bool get isPaused => _state == AudioPlayerState.paused;
  bool get isStopped => _state == AudioPlayerState.stopped;
}
