import 'package:flutter/material.dart';
import 'package:flutter_audio_toolkit/flutter_audio_toolkit.dart';

/// Main application state that holds all the data and state variables
class AppState extends ChangeNotifier {
  String _platformVersion = 'Unknown';
  final FlutterAudioToolkit _flutterAudioToolkitPlugin = FlutterAudioToolkit();
  String? _selectedFilePath;
  String? _convertedFilePath;
  String? _trimmedFilePath;
  WaveformData? _waveformData;
  double _conversionProgress = 0.0;
  double _waveformProgress = 0.0;
  double _trimProgress = 0.0;
  bool _isConverting = false;
  bool _isExtracting = false;
  bool _isTrimming = false;
  AudioInfo? _audioInfo;
  int _trimStartMs = 0;
  int _trimEndMs = 0;
  // Using M4A format for best compatibility
  final AudioFormat trimFormat = AudioFormat.m4a;
  final int trimBitRate = 320; // Higher bitrate for better audio clarity

  // New properties for enhanced conversion options
  AudioFormat _selectedConversionFormat = AudioFormat.m4a;
  int _selectedBitRate = 192; // Default to high quality
  String? _currentPlayingFile;

  // Fake waveform generation state
  WaveformPattern _selectedWaveformPattern = WaveformPattern.music;
  bool _isFakeWaveformMode = false;
  // Network file processing state
  final TextEditingController _urlController = TextEditingController();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  // Noise detection state
  NoiseDetectionResult? _noiseAnalysisResult;
  bool _isAnalyzingNoise = false;
  double _noiseAnalysisProgress = 0.0;

  // Getters
  String get platformVersion => _platformVersion;
  FlutterAudioToolkit get audioToolkit => _flutterAudioToolkitPlugin;
  String? get selectedFilePath => _selectedFilePath;
  String? get convertedFilePath => _convertedFilePath;
  String? get trimmedFilePath => _trimmedFilePath;
  WaveformData? get waveformData => _waveformData;
  double get conversionProgress => _conversionProgress;
  double get waveformProgress => _waveformProgress;
  double get trimProgress => _trimProgress;
  bool get isConverting => _isConverting;
  bool get isExtracting => _isExtracting;
  bool get isTrimming => _isTrimming;
  AudioInfo? get audioInfo => _audioInfo;
  int get trimStartMs => _trimStartMs;
  int get trimEndMs => _trimEndMs;
  WaveformPattern get selectedWaveformPattern => _selectedWaveformPattern;
  bool get isFakeWaveformMode => _isFakeWaveformMode;
  TextEditingController get urlController => _urlController;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  NoiseDetectionResult? get noiseAnalysisResult => _noiseAnalysisResult;
  bool get isAnalyzingNoise => _isAnalyzingNoise;
  double get noiseAnalysisProgress => _noiseAnalysisProgress;

  // New getters for enhanced conversion options
  AudioFormat get selectedConversionFormat => _selectedConversionFormat;
  int get selectedBitRate => _selectedBitRate;
  String? get currentPlayingFile => _currentPlayingFile;

  // Setters with notification
  set platformVersion(String value) {
    _platformVersion = value;
    notifyListeners();
  }

  set selectedFilePath(String? value) {
    _selectedFilePath = value;
    notifyListeners();
  }

  set convertedFilePath(String? value) {
    _convertedFilePath = value;
    notifyListeners();
  }

  set trimmedFilePath(String? value) {
    _trimmedFilePath = value;
    notifyListeners();
  }

  set waveformData(WaveformData? value) {
    _waveformData = value;
    notifyListeners();
  }

  set conversionProgress(double value) {
    _conversionProgress = value;
    notifyListeners();
  }

  set waveformProgress(double value) {
    _waveformProgress = value;
    notifyListeners();
  }

  set trimProgress(double value) {
    _trimProgress = value;
    notifyListeners();
  }

  set isConverting(bool value) {
    _isConverting = value;
    notifyListeners();
  }

  set isExtracting(bool value) {
    _isExtracting = value;
    notifyListeners();
  }

  set isTrimming(bool value) {
    _isTrimming = value;
    notifyListeners();
  }

  set audioInfo(AudioInfo? value) {
    _audioInfo = value;
    notifyListeners();
  }

  set trimStartMs(int value) {
    _trimStartMs = value;
    notifyListeners();
  }

  set trimEndMs(int value) {
    _trimEndMs = value;
    notifyListeners();
  }

  // New setters for enhanced conversion options
  set selectedConversionFormat(AudioFormat value) {
    _selectedConversionFormat = value;
    notifyListeners();
  }

  set selectedBitRate(int value) {
    _selectedBitRate = value;
    notifyListeners();
  }

  set currentPlayingFile(String? value) {
    _currentPlayingFile = value;
    notifyListeners();
  }

  set selectedWaveformPattern(WaveformPattern value) {
    _selectedWaveformPattern = value;
    notifyListeners();
  }

  set isFakeWaveformMode(bool value) {
    _isFakeWaveformMode = value;
    notifyListeners();
  }

  set isDownloading(bool value) {
    _isDownloading = value;
    notifyListeners();
  }

  set downloadProgress(double value) {
    _downloadProgress = value;
    notifyListeners();
  }

  set noiseAnalysisResult(NoiseDetectionResult? value) {
    _noiseAnalysisResult = value;
    notifyListeners();
  }

  set isAnalyzingNoise(bool value) {
    _isAnalyzingNoise = value;
    notifyListeners();
  }

  set noiseAnalysisProgress(double value) {
    _noiseAnalysisProgress = value;
    notifyListeners();
  }

  /// Reset all state when selecting a new file
  void resetForNewFile() {
    _convertedFilePath = null;
    _trimmedFilePath = null;
    _waveformData = null;
    _audioInfo = null;
    _trimStartMs = 0;
    _trimEndMs = 0;
    _isFakeWaveformMode = false;
    _noiseAnalysisResult = null;
    _currentPlayingFile = null;
    notifyListeners();
  }

  /// Clear waveform data
  void clearWaveformData() {
    _waveformData = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
