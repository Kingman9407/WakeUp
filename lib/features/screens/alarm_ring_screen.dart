import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:wake_up_bud/core/services/alarm_ring_service.dart';
import 'package:wake_up_bud/core/services/alarm_service.dart';
import 'package:wake_up_bud/main.dart';

class AlarmRingScreen extends StatefulWidget {
  final int alarmId;
  const AlarmRingScreen({super.key, required this.alarmId});

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  bool _checking = false;
  String _statusText = 'Open your eyes and look at the camera';

  @override
  void initState() {
    super.initState();
    AlarmRingService.startRinging();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    await Permission.camera.request();
  }

  // ================= EYE OPEN DETECTION =================

  Future<bool> _detectEyesOpen() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      frontCamera,
      ResolutionPreset.low,
      enableAudio: false,
    );

    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    await controller.initialize();

    try {
      int successCount = 0;

      for (int i = 0; i < 3; i++) {
        final picture = await controller.takePicture();
        final image = InputImage.fromFilePath(picture.path);
        final faces = await faceDetector.processImage(image);

        if (faces.isNotEmpty) {
          final face = faces.first;
          final left = face.leftEyeOpenProbability ?? 0.0;
          final right = face.rightEyeOpenProbability ?? 0.0;

          final eyesOpen = ((left + right) / 2) > 0.6;

          if (eyesOpen) {
            successCount++;
          }
        }

        await Future.delayed(const Duration(milliseconds: 600));
      }

      return successCount >= 2;
    } finally {
      await controller.dispose();
      await faceDetector.close();
    }
  }

  // ================= DISMISS ALARM =================

  Future<void> _dismissAlarm() async {
    await AlarmRingService.stopRinging();
    await AlarmService.cancelAlarm(widget.alarmId);
    await notificationsPlugin.cancel(widget.alarmId);

    if (mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  // ================= CHECK FLOW =================

  Future<void> _checkAwake() async {
    if (_checking) return;

    setState(() {
      _checking = true;
      _statusText = 'Checking your eyes...';
    });

    final awake = await _detectEyesOpen();

    if (!mounted) return;

    if (awake) {
      _statusText = 'Awake detected ✔';
      await _dismissAlarm();
    } else {
      setState(() {
        _checking = false;
        _statusText = 'Eyes not detected. Try again 👀';
      });
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.alarm, size: 80, color: Colors.red),
                  const SizedBox(height: 20),

                  const Text(
                    'WAKE UP!',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 40),

                  ElevatedButton(
                    onPressed: _checking ? null : _checkAwake,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _checking
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'I am awake',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: _dismissAlarm,
                    child: const Text(
                      'Dismiss (Emergency)',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
