/// Audio formats supported for conversion
///
/// M4A format is the recommended and primary format for all audio operations
/// providing optimal compatibility, quality, and features across all platforms.
enum AudioFormat {
  /// AAC codec in M4A container (.m4a file) - RECOMMENDED
  ///
  /// - Universal compatibility across iOS, Android, and all major platforms
  /// - Industry standard for high-quality AAC audio distribution
  /// - Excellent metadata support and streaming capabilities
  /// - Optimized for both conversion and trimming operations
  /// - Frame-accurate editing support for precise trimming
  /// - Better compression efficiency than MP3
  /// - Supports advanced audio features (surround sound, etc.)
  m4a,

  /// Keep original format (copy mode)
  ///
  /// - Preserves original quality without re-encoding when possible
  /// - May convert container format for platform compatibility
  /// - Output format depends on source file and platform capabilities
  /// - Note: Trimming may require conversion to M4A for precision
  copy,
}
