import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:wake_up_bud/core/services/alarm_ring_service.dart';
import 'package:wake_up_bud/core/services/alarm_service.dart';
import 'package:wake_up_bud/features/provider/alarm_provider.dart';
import 'package:wake_up_bud/main.dart';
import 'package:wake_up_bud/features/provider/alarm_wake_provider.dart';

class AlarmRingScreen extends StatefulWidget {
  final int alarmId;
  const AlarmRingScreen({super.key, required this.alarmId});

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  AlarmWakeProvider? _wakeProvider;
  bool _permissionGranted = false;
  bool _permissionChecked = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    AlarmRingService.startRinging();
    _checkAndRequestPermission();
  }

  Future<void> _checkAndRequestPermission() async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      setState(() {
        _permissionGranted = true;
        _permissionChecked = true;
      });
      _initializeCamera();
    } else if (status.isDenied) {
      final result = await Permission.camera.request();
      setState(() {
        _permissionGranted = result.isGranted;
        _permissionChecked = true;
      });

      if (result.isGranted) {
        _initializeCamera();
      }
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _permissionGranted = false;
        _permissionChecked = true;
      });

      if (mounted) {
        _showPermissionDeniedDialog();
      }
    }
  }

  void _initializeCamera() {
    if (_isInitializing || _wakeProvider != null) {
      debugPrint('⚠️ Camera already initializing or initialized');
      return;
    }

    if (mounted) {
      setState(() {
        _isInitializing = true;
      });

      debugPrint('🎥 Creating new AlarmWakeProvider...');

      // Dispose old provider if exists
      _wakeProvider?.dispose();

      setState(() {
        _wakeProvider = AlarmWakeProvider();
        _isInitializing = false;
      });
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'Camera access is required to detect when you wake up.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _dismiss(context);
            },
            child: const Text('Dismiss Alarm'),
          ),
          TextButton(
            onPressed: () async {
              await openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _dismiss(BuildContext context) async {
    await AlarmRingService.stopRinging();
    await AlarmService.cancelAlarm(widget.alarmId);
    await notificationsPlugin.cancel(widget.alarmId);

    if (mounted) {
      context.read<AlarmProvider>().toggleAlarm(widget.alarmId, false);
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing AlarmRingScreen...');
    _wakeProvider?.dispose();
    _wakeProvider = null;
    super.dispose();
    debugPrint('✅ AlarmRingScreen disposed');
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionChecked) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Requesting camera permission...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (!_permissionGranted) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 80,
                  color: Colors.white54,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Camera Permission Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Camera access is required to detect when you wake up.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Open Settings'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => _dismiss(context),
                  child: const Text(
                    'Dismiss Alarm',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_wakeProvider == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Initializing camera...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: _wakeProvider!,
      child: Consumer<AlarmWakeProvider>(
        builder: (context, wake, _) {
          // Dismiss alarm when user is detected as awake
          if (wake.isAwake) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _dismiss(context);
            });
          }

          return PopScope(
            canPop: false,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: wake.errorMessage != null
                  ? _buildErrorState(wake.errorMessage!)
                  : wake.cameraController == null ||
                  !wake.cameraController!.value.isInitialized
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              )
                  : _buildCameraView(context, wake),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _dismiss(context),
              child: const Text('Dismiss Alarm'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView(BuildContext context, AlarmWakeProvider wake) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Preview
        CameraPreview(wake.cameraController!),

        // Dark overlay
        Container(
          color: Colors.black.withOpacity(0.5),
        ),

        // Top Instructions
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'WAKE UP',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Open your eyes and look at camera',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Detection status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: wake.faceDetected
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: wake.faceDetected
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          wake.faceDetected
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: wake.faceDetected
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          wake.faceDetected
                              ? 'Eyes Open Detected ✓'
                              : 'Waiting for eyes open...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: wake.faceDetected
                                ? Colors.greenAccent
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom Progress Indicator
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Keep your eyes open',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Progress circles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isActive = index < wake.consecutiveDetections;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? Colors.greenAccent
                                : Colors.white30,
                            boxShadow: isActive
                                ? [
                              BoxShadow(
                                color: Colors.greenAccent.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                                : null,
                          ),
                          child: isActive
                              ? const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.black,
                          )
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${wake.consecutiveDetections}/3',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}