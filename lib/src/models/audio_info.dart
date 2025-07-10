/// Comprehensive information about an audio file
///
/// Contains detailed metadata, format information, and compatibility analysis
/// for audio files. This class provides everything needed to understand an
/// audio file's characteristics and processing capabilities.
class AudioInfo {
  // Basic file information
  /// Whether the audio file is valid and readable
  final bool isValid;

  /// File size in bytes
  final int? fileSize;

  /// Duration in milliseconds
  final int? durationMs;

  // Audio format details
  /// MIME type of the audio (e.g., "audio/mpeg", "audio/mp4")
  final String? mimeType;

  /// File format description (e.g., "MP3", "M4A", "AAC")
  final String? format;

  /// Audio codec used (e.g., "AAC", "MP3", "PCM")
  final String? codec;

  // Audio quality metrics
  /// Bit rate in bits per second
  final int? bitRate;

  /// Sample rate in Hz (e.g., 44100, 48000)
  final int? sampleRate;

  /// Number of audio channels (1 = mono, 2 = stereo)
  final int? channels;

  /// Bit depth (e.g., 16, 24)
  final int? bitDepth;

  // Compatibility information
  /// Whether this format can be converted to other formats
  final bool supportedForConversion;

  /// Whether this file can be trimmed
  final bool supportedForTrimming;

  /// Whether lossless trimming is supported (no re-encoding)
  final bool supportedForLosslessTrimming;

  /// Whether waveform data can be extracted from this file
  final bool supportedForWaveform;

  // Metadata
  /// Title from metadata
  final String? title;

  /// Artist from metadata
  final String? artist;

  /// Album from metadata
  final String? album;

  /// Year from metadata
  final int? year;

  /// Genre from metadata
  final String? genre;

  // Error information (when isValid is false)
  /// Error message if file is invalid
  final String? error;

  /// Additional error details
  final String? details;

  // Diagnostic information
  /// Human-readable format diagnostics
  final String? formatDiagnostics;

  /// List of detected audio tracks
  final List<String>? foundTracks;

  /// Creates a new AudioInfo instance
  const AudioInfo({
    required this.isValid,
    this.fileSize,
    this.durationMs,
    this.mimeType,
    this.format,
    this.codec,
    this.bitRate,
    this.sampleRate,
    this.channels,
    this.bitDepth,
    this.supportedForConversion = false,
    this.supportedForTrimming = false,
    this.supportedForLosslessTrimming = false,
    this.supportedForWaveform = false,
    this.title,
    this.artist,
    this.album,
    this.year,
    this.genre,
    this.error,
    this.details,
    this.formatDiagnostics,
    this.foundTracks,
  });

  /// Creates an AudioInfo from a platform map response
  factory AudioInfo.fromMap(Map<String, dynamic> map) {
    return AudioInfo(
      isValid: map['isValid'] as bool? ?? false,
      fileSize: map['fileSize'] as int?,
      durationMs: map['durationMs'] as int?,
      mimeType: map['mime'] as String?,
      format: map['format'] as String?,
      codec: map['codec'] as String?,
      bitRate: map['bitRate'] as int?,
      sampleRate: map['sampleRate'] as int?,
      channels: map['channels'] as int?,
      bitDepth: map['bitDepth'] as int?,
      supportedForConversion: map['supportedForConversion'] as bool? ?? false,
      supportedForTrimming: map['supportedForTrimming'] as bool? ?? false,
      supportedForLosslessTrimming:
          map['supportedForLosslessTrimming'] as bool? ?? false,
      supportedForWaveform: map['supportedForWaveform'] as bool? ?? false,
      title: map['title'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      year: map['year'] as int?,
      genre: map['genre'] as String?,
      error: map['error'] as String?,
      details: map['details'] as String?,
      formatDiagnostics: map['formatDiagnostics'] as String?,
      foundTracks: (map['foundTracks'] as List?)?.cast<String>(),
    );
  }

  /// Converts this AudioInfo to a map for platform communication
  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      if (fileSize != null) 'fileSize': fileSize,
      if (durationMs != null) 'durationMs': durationMs,
      if (mimeType != null) 'mime': mimeType,
      if (format != null) 'format': format,
      if (codec != null) 'codec': codec,
      if (bitRate != null) 'bitRate': bitRate,
      if (sampleRate != null) 'sampleRate': sampleRate,
      if (channels != null) 'channels': channels,
      if (bitDepth != null) 'bitDepth': bitDepth,
      'supportedForConversion': supportedForConversion,
      'supportedForTrimming': supportedForTrimming,
      'supportedForLosslessTrimming': supportedForLosslessTrimming,
      'supportedForWaveform': supportedForWaveform,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (year != null) 'year': year,
      if (genre != null) 'genre': genre,
      if (error != null) 'error': error,
      if (details != null) 'details': details,
      if (formatDiagnostics != null) 'formatDiagnostics': formatDiagnostics,
      if (foundTracks != null) 'foundTracks': foundTracks,
    };
  }

  /// Returns a human-readable description of the audio file
  String get description {
    if (!isValid) {
      return error ?? 'Invalid audio file';
    }

    final parts = <String>[];

    if (format != null) parts.add(format!);
    if (codec != null && codec != format) parts.add('($codec codec)');
    if (durationMs != null) {
      final seconds = durationMs! / 1000;
      parts.add('${seconds.toStringAsFixed(1)}s');
    }
    if (bitRate != null) parts.add('${bitRate}bps');
    if (sampleRate != null) parts.add('${sampleRate}Hz');
    if (channels != null) {
      parts.add(
        channels == 1
            ? 'Mono'
            : channels == 2
            ? 'Stereo'
            : '${channels}ch',
      );
    }

    return parts.join(' · ');
  }

  /// Returns a quality assessment string
  String get qualityAssessment {
    if (!isValid) return 'Unknown';

    final quality = <String>[];

    if (bitRate != null) {
      if (bitRate! >= 320) {
        quality.add('Very High Quality');
      } else if (bitRate! >= 192) {
        quality.add('High Quality');
      } else if (bitRate! >= 128) {
        quality.add('Standard Quality');
      } else {
        quality.add('Low Quality');
      }
    }

    if (sampleRate != null) {
      if (sampleRate! >= 48000) {
        quality.add('Hi-Res Audio');
      } else if (sampleRate! >= 44100) {
        quality.add('CD Quality');
      }
    }

    return quality.join(' · ');
  }

  @override
  String toString() {
    return 'AudioInfo(isValid: $isValid, format: $format, '
        'duration: ${durationMs}ms, bitRate: $bitRate, sampleRate: $sampleRate, '
        'channels: $channels)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AudioInfo &&
        other.isValid == isValid &&
        other.fileSize == fileSize &&
        other.durationMs == durationMs &&
        other.mimeType == mimeType &&
        other.format == format &&
        other.codec == codec &&
        other.bitRate == bitRate &&
        other.sampleRate == sampleRate &&
        other.channels == channels &&
        other.bitDepth == bitDepth &&
        other.supportedForConversion == supportedForConversion &&
        other.supportedForTrimming == supportedForTrimming &&
        other.supportedForLosslessTrimming == supportedForLosslessTrimming &&
        other.supportedForWaveform == supportedForWaveform;
  }

  @override
  int get hashCode {
    return Object.hash(
      isValid,
      fileSize,
      durationMs,
      mimeType,
      format,
      codec,
      bitRate,
      sampleRate,
      channels,
      bitDepth,
      supportedForConversion,
      supportedForTrimming,
      supportedForLosslessTrimming,
      supportedForWaveform,
    );
  }
}
