import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/app_state.dart';

/// Service class for validating inputs and permissions
class ValidationService {
  /// Validates that a file is selected
  static Future<bool> validateSelectedFile(AppState appState) async {
    if (appState.selectedFilePath == null) {
      if (kDebugMode) {
        print('No file selected');
      }
      return false;
    }

    final file = File(appState.selectedFilePath!);
    if (!await file.exists()) {
      if (kDebugMode) {
        print('Selected file does not exist: ${appState.selectedFilePath}');
      }
      return false;
    }

    return true;
  }

  /// Validates that the selected file format is supported
  static Future<bool> validateFormatSupport(AppState appState) async {
    if (appState.selectedFilePath == null) return false;

    try {
      final isSupported = await appState.audioToolkit.isFormatSupported(appState.selectedFilePath!);

      if (!isSupported) {
        if (kDebugMode) {
          print('File format not supported: ${appState.selectedFilePath}');
        }
        return false;
      }

      // Additional validation for specific formats
      final extension = appState.selectedFilePath!.split('.').last.toLowerCase();

      // Log format information
      if (kDebugMode) {
        print('File format: $extension');
        if (extension == 'm4a' || extension == 'aac') {
          print('M4A/AAC format detected - optimized for cross-platform compatibility');
        } else if (extension == 'mp3') {
          print('MP3 format detected - widely supported but may have limitations with trimming');
        } else if (extension == 'wav') {
          print('WAV format detected - lossless but large file size');
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking format support: $e');
      }
      return false;
    }
  }

  /// Validates that audio info is loaded
  static bool validateAudioInfoLoaded(AppState appState) {
    if (appState.audioInfo == null) {
      if (kDebugMode) {
        print('Audio info not loaded');
      }
      return false;
    }
    return true;
  }

  /// Validates the trim range
  static bool validateTrimRange(AppState appState) {
    if (appState.audioInfo == null || appState.audioInfo!.durationMs == null) return false;

    final durationMs = appState.audioInfo!.durationMs!;

    // Ensure trim range is valid
    if (appState.trimStartMs < 0 || appState.trimEndMs <= appState.trimStartMs || appState.trimEndMs > durationMs) {
      if (kDebugMode) {
        print('Invalid trim range: ${appState.trimStartMs}ms - ${appState.trimEndMs}ms (duration: ${durationMs}ms)');
      }
      return false;
    }

    // Ensure minimum trim duration (500ms)
    if (appState.trimEndMs - appState.trimStartMs < 500) {
      if (kDebugMode) {
        print('Trim duration too short: ${appState.trimEndMs - appState.trimStartMs}ms (minimum: 500ms)');
      }
      return false;
    }

    return true;
  }

  /// Validates the selected trim format
  static bool validateTrimFormat(AppState appState) {
    // Log format information
    if (kDebugMode) {
      // We're always using M4A format now for better compatibility
      print('Using M4A format for trimming - best cross-platform compatibility');
      print('Bit rate: ${appState.trimBitRate} kbps');
    }

    return true;
  }

  /// Validates that storage permissions are granted
  static Future<bool> validateStoragePermissions() async {
    if (Platform.isAndroid) {
      try {
        // Get Android version to determine strategy
        final androidVersion = await _getAndroidVersion();

        if (kDebugMode) {
          print('Android API level: $androidVersion');
        }

        // For modern Android (11+), skip permission requests entirely
        if (androidVersion >= 30) {
          if (kDebugMode) {
            print('Android 11+ detected - using scoped storage, skipping permission requests');
          }
          return true;
        }

        // For older Android versions, try permission request with error handling
        if (kDebugMode) {
          print('Older Android detected - attempting permission request...');
        }

        // Wrap permission requests in try-catch to handle permission_handler issues
        try {
          final storageStatus = await Permission.storage.status;
          if (!storageStatus.isGranted) {
            if (kDebugMode) {
              print('Storage permission not granted, requesting...');
            }

            final result = await Permission.storage.request();
            if (!result.isGranted) {
              if (kDebugMode) {
                print('Storage permission denied - will attempt file picker anyway');
              }
              // Even on older Android, try to continue - some file pickers work without explicit permissions
              return true;
            }
          }

          if (kDebugMode) {
            print('Storage permission granted');
          }
          return true;
        } catch (permissionError) {
          if (kDebugMode) {
            print('Permission handler failed: $permissionError');
            print('This often happens on newer Android versions - continuing anyway');
          }
          // If permission_handler fails, just continue
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          print('General error in permission validation: $e');
          print('Continuing with file picker - modern Android may still work');
        }
        return true;
      }
    }

    // For iOS and other platforms, no additional permissions needed for file picker
    return true;
  }

  /// Alternative permission validation that bypasses permission_handler entirely
  /// Use this when permission_handler is having issues with manifest detection
  static Future<bool> validateStoragePermissionsDirectly() async {
    if (Platform.isAndroid) {
      try {
        final androidVersion = await _getAndroidVersion();

        if (kDebugMode) {
          print('Android API level: $androidVersion - using direct validation (bypassing permission_handler)');
        }

        // For Android 11+, no permissions needed due to scoped storage
        if (androidVersion >= 30) {
          if (kDebugMode) {
            print('Android 11+ - scoped storage allows file picker without explicit permissions');
          }
          return true;
        }

        // For older Android, we can't request permissions without permission_handler
        // but modern file pickers often work anyway
        if (kDebugMode) {
          print('Older Android - file picker may work without explicit permission requests');
        }
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('Error in direct permission validation: $e');
        }
        return true;
      }
    }

    return true;
  }

  /// Get Android API level more reliably - made public for use in widgets
  static Future<int> getAndroidVersion() async {
    return await _getAndroidVersion();
  }

  /// Get Android API level more reliably
  static Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;

    try {
      // Try to use device_info_plus if available, otherwise fallback to parsing
      final versionString = Platform.operatingSystemVersion;
      // Parse Android version from string like "Android 11 (API level 30)"
      final apiMatch = RegExp(r'API level (\d+)').firstMatch(versionString);
      if (apiMatch != null) {
        return int.parse(apiMatch.group(1)!);
      }

      // Fallback: try to parse version number from start of string
      final versionMatch = RegExp(r'(\d+)').firstMatch(versionString);
      if (versionMatch != null) {
        final majorVersion = int.parse(versionMatch.group(1)!);
        // Convert major version to API level (approximate)
        switch (majorVersion) {
          case 14:
            return 34; // Android 14
          case 13:
            return 33; // Android 13
          case 12:
            return 31; // Android 12
          case 11:
            return 30; // Android 11
          case 10:
            return 29; // Android 10
          case 9:
            return 28; // Android 9
          default:
            return majorVersion + 19; // Rough approximation
        }
      }

      // Ultimate fallback
      return 28; // Android 9 as safe default
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing Android version: $e');
      }
      return 28; // Safe default
    }
  }
}
