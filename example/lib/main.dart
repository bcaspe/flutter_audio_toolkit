import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

// Import our modular components
import 'models/app_state.dart';
import 'services/audio_service.dart';
import 'widgets/file_picker_widget.dart';
import 'widgets/audio_info_widget.dart';
import 'widgets/conversion_widget.dart';
import 'widgets/waveform_widget.dart';
import 'widgets/trimming_widget.dart';
import 'widgets/noise_detection_widget.dart';
import 'widgets/audio_player_demo_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Audio Toolkit Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ChangeNotifierProvider(create: (context) => AppState(), child: const AudioToolkitHome()),
    );
  }
}

class AudioToolkitHome extends StatefulWidget {
  const AudioToolkitHome({super.key});

  @override
  State<AudioToolkitHome> createState() => _AudioToolkitHomeState();
}

class _AudioToolkitHomeState extends State<AudioToolkitHome> {
  bool _permissionsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    if (kDebugMode) {
      print('Initializing app...');
    }

    final appState = Provider.of<AppState>(context, listen: false);

    // Initialize default URL
    appState.urlController.text =
        'https://ro-prod-content.blr1.cdn.digitaloceanspaces.com/dolby/previews/fr_marchingband_a.mp4';

    // Request permissions first
    await _requestPermissions();

    // Then initialize platform state
    await _initPlatformState(appState);

    if (kDebugMode) {
      print('App initialization complete');
    }
  }

  Future<void> _requestPermissions() async {
    if (_permissionsInitialized) {
      if (kDebugMode) {
        print('Permissions already initialized');
      }
      return;
    }

    if (kDebugMode) {
      print('Requesting ALL permissions aggressively...');
    }

    if (Platform.isAndroid) {
      if (kDebugMode) {
        print('Android platform detected - requesting comprehensive permissions');
      }

      try {
        // Get Android API level for targeted permission requests
        final androidInfo = Platform.operatingSystemVersion;
        if (kDebugMode) {
          print('Android version info: $androidInfo');
        }

        // Request all relevant permissions simultaneously for better user experience
        final permissionsToRequest = <Permission>[];

        // Audio/Media permissions
        permissionsToRequest.add(Permission.audio);
        permissionsToRequest.add(Permission.storage);

        // Microphone for recording features
        permissionsToRequest.add(Permission.microphone);

        // External storage management (for Android 11+)
        permissionsToRequest.add(Permission.manageExternalStorage);

        // Notification permission (sometimes needed for media operations)
        permissionsToRequest.add(Permission.notification);

        if (kDebugMode) {
          print('Requesting ${permissionsToRequest.length} permissions...');
        }

        // Request all permissions at once
        final results = await permissionsToRequest.request();

        if (kDebugMode) {
          print('Permission results:');
          for (final entry in results.entries) {
            print('  ${entry.key}: ${entry.value}');
          }
        }

        // Check specific critical permissions
        final audioStatus = await Permission.audio.status;
        final storageStatus = await Permission.storage.status;

        if (kDebugMode) {
          print('Critical permission status:');
          print('  Audio: $audioStatus');
          print('  Storage: $storageStatus');
        }

        // If critical permissions are denied, show user guidance
        if (audioStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
          if (kDebugMode) {
            print('Some permissions permanently denied - user should check app settings');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error requesting permissions: $e');
          print('Continuing with app initialization - some features may be limited');
        }
      }
    } else if (Platform.isIOS) {
      // iOS permissions are requested as needed
      if (kDebugMode) {
        print('iOS platform - permissions will be requested as needed');
      }
    }

    _permissionsInitialized = true;

    if (kDebugMode) {
      print('Permission initialization completed');
    }
  }

  Future<void> _initPlatformState(AppState appState) async {
    if (kDebugMode) {
      print('Initializing platform state...');
    }

    try {
      final platformVersion = await AudioService.getPlatformVersion(appState);
      appState.platformVersion = platformVersion;

      if (kDebugMode) {
        print('Platform version: $platformVersion');
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to get platform version: $e');
      }
      appState.platformVersion = 'Failed to get platform version.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    if (kDebugMode) {
      print('ERROR: $message');
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)));
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Audio Converter & Waveform'), backgroundColor: Colors.blue),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // File Picker and URL Input Section
                FilePickerWidget(appState: appState, onError: () => _showError('Failed to select or process file')),

                // Audio Information Section
                AudioInfoWidget(appState: appState),

                // Audio Conversion Section
                if (appState.selectedFilePath != null) ...[
                  const SizedBox(height: 16),
                  ConversionWidget(appState: appState, onStateChanged: _onStateChanged),

                  // Waveform Extraction Section
                  const SizedBox(height: 16),
                  WaveformWidget(
                    appState: appState,
                    onStateChanged: _onStateChanged,
                  ), // Audio Trimming Section                  const SizedBox(height: 16),
                  TrimmingWidget(
                    appState: appState,
                    onStateChanged: _onStateChanged,
                  ), // Noise Detection & Analysis Section
                  const SizedBox(height: 16),
                  NoiseDetectionWidget(
                    appState: appState,
                    onStateChanged: _onStateChanged,
                  ), // Audio Player Demo Section
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 600, // Fixed height for tab view
                    child: AudioPlayerDemoWidget(appState: appState),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
