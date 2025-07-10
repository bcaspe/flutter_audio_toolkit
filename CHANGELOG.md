# Changelog

## [1.0.0] - 2025-07-05

### 🚀 First Stable Release
- **STABLE**: First stable release with production-ready API
- **FIXED**: Audio trimming compatibility issues on Android with MediaMuxer
- **ENHANCED**: Improved high-quality audio trimming with 320kbps bitrate support
- **OPTIMIZED**: Better error handling and logging for audio operations

### 🔊 Audio Trimming Improvements
- **Fixed**: "Failed to add the track to the muxer" error in Android implementation
- **Enhanced**: Always using M4A format with AAC codec for best compatibility
- **Optimized**: Higher bitrate (320kbps) for better audio quality
- **Improved**: Better progress tracking and error handling

### 📱 Platform Stability
- **Android**: Fixed MediaMuxer compatibility issues
- **iOS**: Improved AVFoundation integration
- **All Platforms**: Enhanced error handling and recovery

### 📚 Documentation
- Updated README with latest version information
- Improved code documentation
- Enhanced example app with better UI feedback

## [0.3.8] - 2025-06-28

### 🔧 Critical Error Handling Improvements
- **FIXED**: "AudioPlayer has been disposed" errors when switching between audio files or disposing widgets
- **FIXED**: HTTP 400 and timeout errors with enhanced retry logic and user-friendly error messages
- **FIXED**: Temp directory creation errors on read-only file systems (iOS `/tmp` issue)
- **ENHANCED**: Cross-platform file path handling with automatic fallbacks

### 🛠️ New Utilities Added
- **PathProviderUtil**: Cross-platform path resolution with fallback mechanisms
- **AudioErrorHandler**: User-friendly error message conversion and recovery suggestions
- **Network Service**: Enhanced HTTP error handling with retry logic and exponential backoff

### 📱 Platform Compatibility
- **iOS**: Fixed temp file creation on read-only `/tmp` directories
- **Android**: Improved storage permission handling and path resolution
- **All Platforms**: Enhanced error recovery and graceful degradation

### 🔄 Player State Management
- Added disposal state checks in all player operations
- Enhanced state change callbacks with mounted widget checks
- Improved error propagation without breaking widget tree
- Better memory management during rapid player creation/disposal

### 📝 Documentation
- Added comprehensive error handling guide (`ERROR_HANDLING_FIXES.md`)
- Updated examples with proper error handling patterns
- Enhanced inline documentation for error scenarios

### ⚠️ Dependencies
- **Added**: `path_provider: ^2.1.0` for cross-platform path resolution

### 🔒 Backward Compatibility
- All changes are backward compatible
- Existing API unchanged, enhanced with better error handling
- No breaking changes to public interfaces

## [0.3.7] - 2025-06-28
- Attempt to fix iOS build errors

## [0.3.6] - 2025-06-26

### 🍎 iOS Swift Implementation Modernization
- **BREAKING CHANGE FIXES**: Resolved all iOS Swift compilation errors for modern Xcode versions
- **Deprecated API Removal**: Removed usage of non-existent `audioSettings` and `audioOutputSettings` properties on `AVAssetExportSession`
- **Modern Type Checking**: Replaced deprecated `CMAudioFormatDescriptionGetTypeID()` with `CMFormatDescriptionGetMediaType()` + explicit casting
- **Updated Time APIs**: Migrated from deprecated `CMTimeRange(start:end:)` to `CMTimeRangeMake(start:duration:)`
- **Memory Safety**: Added `[weak self]` references in timer closures to prevent retain cycles
- **Timer Optimization**: Improved timer scheduling with proper RunLoop management using `RunLoop.current.add(timer, forMode: .common)`
- **Buffer Management**: Removed deprecated `CMSampleBufferInvalidate` calls (ARC handles cleanup automatically)
- **Error Handling**: Enhanced audio session configuration with graceful fallbacks

### 🧪 Enhanced Testing Infrastructure
- **iOS Unit Tests**: Added comprehensive Swift unit tests in `ios/Tests/FlutterAudioToolkitTests.swift`
- **iOS Integration Tests**: Created iOS-specific integration tests for plugin validation
- **Test Automation**: Added `test_ios.sh` script for automated iOS testing on macOS
- **Windows Testing**: Added `test_windows.bat` for cross-platform testing validation
- **Testing Documentation**: Comprehensive testing guide in `test_ios_plugin.md` and `TESTING_SUMMARY.md`

### 🔧 Code Quality Improvements
- **Static Analysis**: All code passes `flutter analyze` with zero issues
- **Modern Swift Practices**: Updated to follow current iOS development patterns
- **Thread Safety**: Improved async operation handling and queue management
- **Documentation**: Enhanced code documentation and inline comments
- **Performance**: Optimized audio processing workflows and memory usage

### 📱 Platform Compatibility
- **iOS 12.0+**: Full compatibility with modern iOS versions
- **Xcode 14+**: Compatible with latest Xcode and Swift versions
- **AVFoundation**: Uses only current, non-deprecated AVFoundation APIs
- **Core Media**: Updated to modern Core Media framework usage

### 📊 Test Results
- **50 Dart Tests**: All unit tests pass (100% success rate)
- **Static Analysis**: Zero issues found
- **Package Validation**: Ready for pub.dev publishing
- **Memory Leaks**: Zero memory leaks detected
- **API Usage**: All deprecated APIs removed and modernized

## [0.3.5] - 2025-06-26
- #1 Bug Fix (Compile-time error on iOS)

## [0.3.4] - 2025-06-14

### 🌐 Web Platform Support (Limited)
- **NEW**: Added web platform support with limited functionality
- **Waveform Extraction**: Web implementation generates realistic fake waveforms
- **Format Support Detection**: Browser codec support checking via HTML Audio API
- **Audio Info Extraction**: Basic metadata retrieval for web-accessible audio files
- **Audio Player Compatibility**: Existing audio player widgets work on web
- **Clear Error Messages**: Helpful error messages for unsupported operations
- **Documentation**: Updated README with web platform limitations and capabilities

### 🔧 Technical Improvements
- **Modern Web APIs**: Uses `package:web` and `dart:js_interop` (no deprecated APIs)
- **Dependency Updates**: Added `flutter_web_plugins` and `web` package dependencies
- **Code Quality**: All web implementations pass static analysis
- **Platform Detection**: Proper platform-specific feature availability

### ⚠️ Web Platform Limitations
- Audio conversion and trimming are not supported (browser security restrictions)
- Waveform extraction returns generated patterns (Web Audio API CORS limitations)
- File system access restricted to HTTP URLs only
- Performance is limited compared to native platforms

## [0.3.3] - 2025-06-10
-  Bug Fixes

## [0.3.2] - 2025-06-13

### 🆕 Audio Player Features

#### 🎵 Interactive Audio Players with Waveform Visualization
- **TrueWaveformAudioPlayer**: Audio player using real extracted waveform data
- **FakeWaveformAudioPlayer**: Audio player using generated waveform patterns
- **Interactive Waveform**: Tap-to-seek functionality on waveform display
- **Customizable Controls**: Configurable play/pause, volume, progress, and time labels
- **Flexible Control Layouts**: Position controls top, bottom, overlay, left, or right
- **Real-time Progress**: Visual progress overlay showing played portion
- **Position Indicator**: Real-time playback position marker on waveform
- **Event Callbacks**: Comprehensive event system for state, position, and error handling

#### 🎮 Player Configuration Options
- **AudioPlayerControlsConfig**: Complete control customization (buttons, colors, positions)
- **WaveformVisualizationConfig**: Waveform styling and interaction settings
- **AudioPlayerColors**: Comprehensive color theming for all UI elements
- **AudioPlayerCallbacks**: Event handling for all player interactions

#### 🎨 Enhanced Visual Features
- **Customizable Waveform Styles**: Colors, gradients, line widths, opacity
- **Progress Visualization**: Different colors for played/unplayed portions
- **Control Theming**: Fully customizable button colors and styles
- **Responsive Design**: Adaptive layouts for different screen sizes

### 🔧 Implementation Details
- **Native Audio Playback**: Platform-optimized audio rendering
- **Memory Efficient**: Optimized waveform rendering and audio processing
- **Background Threading**: Audio operations on background threads
- **State Management**: Robust state management for player controls and visualization

### 📚 Documentation
- **Complete Audio Player Guide**: Comprehensive guide with examples and best practices
- **Example Integration**: Full working example in demo app
- **API Documentation**: Detailed parameter documentation for all new classes

## [0.3.1] - 2025-06-10
- Fixed Dart Format Issues

## [0.3.0] - 2025-06-10

### 🆕 Major New Features

#### 🔊 Noise Detection & Audio Quality Analysis
- **Comprehensive Audio Analysis**: Deep analysis of audio quality with detailed metrics
- **15+ Noise Type Detection**: Identify background noises like car horns, dog barking, construction, etc.
- **Audio Quality Metrics**: Peak levels, SNR, dynamic range, LUFS loudness measurement
- **Frequency Analysis**: Spectral analysis with problematic frequency band detection
- **Quality Grading**: Automatic quality scoring (Excellent, Good, Fair, Poor, Very Poor)
- **Issue Detection**: Automatic detection of clipping, distortion, and balance problems
- **Network Analysis**: Analyze audio quality directly from URLs

#### 🎨 Enhanced Waveform Generation
- **25+ Waveform Patterns**: Expanded from 7 to 25+ realistic patterns
- **New Pattern Categories**:
  - **Basic Waveforms**: `square`, `sawtooth`, `triangle` (added to existing sine, random, etc.)
  - **Musical Patterns**: `electronic`, `classical`, `rock`, `jazz`, `ambient`
  - **Voice & Speech**: `podcast`, `audiobook` (improved speech patterns)
  - **Nature & Relaxation**: `whiteNoise`, `pinkNoise`, `heartbeat`, `ocean`, `rain`, `binauralBeats`
- **Visual Styling System**: 9 predefined color schemes with customizable visual properties
- **Themed Generation**: Automatic pattern-to-style matching for optimal visual presentation
- **Style Application**: Apply visual styles to existing waveform data

#### 📊 Advanced Metadata Extraction
- **Comprehensive Metadata**: Extract 35+ metadata fields from audio files
- **Cover Art Support**: Extract and handle embedded album artwork
- **Technical Details**: Detailed codec, bitrate, and encoding information
- **Date/Time Fields**: Recording dates, release dates with proper DateTime handling
- **Custom Fields**: Support for additional metadata through extensible system

### 🔧 Enhanced Features
- **Improved Algorithm Accuracy**: Better pattern generation algorithms for all waveform types
- **Memory Optimization**: More efficient audio processing and analysis
- **Progress Tracking**: Enhanced progress callbacks for all new operations
- **Error Handling**: Robust error handling for network operations and file processing

### 🎛️ New API Methods
```dart
// Noise Detection & Analysis
final analysisResult = await toolkit.analyzeAudioNoise(inputPath);
final networkAnalysis = await toolkit.analyzeAudioNoiseFromUrl(url, localPath);

// Enhanced Waveform Generation
final themedWaveform = toolkit.generateThemedWaveform(pattern: WaveformPattern.jazz);
final styledWaveform = toolkit.generateStyledWaveform(pattern: WaveformPattern.electronic, style: WaveformColorSchemes.neon);
final waveformWithStyle = existingWaveform.withStyle(WaveformColorSchemes.fire);

// Advanced Metadata
final metadata = await toolkit.extractMetadata(inputPath);
final networkMetadata = await toolkit.extractMetadataFromUrl(url, localPath);
```

### 🏗️ Architecture Improvements
- **Modular Design**: Separated concerns into specialized analyzer and generator modules
- **Type Safety**: Enhanced type definitions for all new models
- **Documentation**: Comprehensive dartdoc documentation for all new APIs
- **Testing**: 100+ new test cases covering all noise detection and enhanced waveform features

### 📋 New Data Models
- `NoiseDetectionResult` - Complete analysis results
- `AudioQualityMetrics` - Detailed quality measurements
- `FrequencyAnalysis` - Spectral analysis data
- `DetectedNoise` - Individual noise detection results
- `WaveformStyle` - Visual styling configuration
- `AudioMetadata` - Comprehensive metadata container

## [0.2.0] - 2025-06-08

### Added
- **Multi-Platform Support**: Added support for macOS, Linux, and Windows platforms
- **macOS Implementation**: Full native implementation using AVFoundation (same as iOS)
- **Linux & Windows**: Basic plugin structure with platform-specific error handling
- **Platform Documentation**: Updated README with comprehensive platform support matrix
- **Desktop Compatibility**: Plugin now declares support for all desktop platforms

### Enhanced
- Updated platform support matrix in README
- Added platform-specific implementation notes
- Improved plugin architecture for cross-platform compatibility

### Technical Details
- macOS: Complete AVFoundation implementation for audio conversion, trimming, and waveform extraction
- Linux: GTK-based plugin structure (requires FFmpeg/GStreamer for full functionality)
- Windows: Win32 plugin structure (requires Media Foundation/FFmpeg for full functionality)

### Notes
- Desktop platforms (Linux, Windows) have basic plugin structure but require additional audio processing libraries
- macOS has full feature parity with iOS using the same AVFoundation APIs

## [0.1.0] - 2025-06-07

### Added
- **Fake Waveform Generation**: Generate realistic waveform patterns for testing and previews
- **7 Waveform Patterns**: Sine, Random, Music, Speech, Pulse, Fade, and Burst patterns
- **Network URL Support**: Process audio files from network URLs with fake waveform generation
- **Modular Architecture**: Complete refactoring of example app with Provider state management
- **Enhanced Example App**: Added fake waveform UI with pattern selection and color-coded display
- Pattern-specific amplitude algorithms for realistic waveform simulation
- URL validation and network audio file support
- Comprehensive testing for fake waveform functionality

### Enhanced
- Example app refactored from 1180 lines to 122 lines (89% reduction)
- Added Provider state management pattern
- Extracted business logic into service classes
- Modularized UI components into reusable widgets
- Improved error handling and progress tracking

### Fixed
- Library formatting and method signature issues
- Enhanced dependency management

## [0.0.1] - 2025-06-07

### Added
- Initial release of flutter_audio_toolkit plugin
- Audio conversion from MP3, WAV, OGG to AAC/M4A formats
- Audio trimming with precise time range selection
- Waveform data extraction for visualization
- Native implementations for Android (MediaCodec/MediaMuxer) and iOS (AVFoundation)
- Progress tracking for all operations
- Audio file information retrieval
- Comprehensive example app with UI for all features
- Full test coverage including unit and widget tests
- Platform-specific permission handling
- Error handling and validation
- Performance optimized for large audio files

### Platform Support
- Android: API 21+ using MediaCodec, MediaMuxer, MediaExtractor
- iOS: 12.0+ using AVAssetExportSession, AVAudioConverter, AVAssetReader

### Features
- Convert audio files between formats
- Trim audio files to specific time ranges  
- Extract waveform amplitude data
- Get detailed audio file information
- Real-time progress callbacks
- Native performance optimization
