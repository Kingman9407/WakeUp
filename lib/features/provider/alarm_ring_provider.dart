// ==================== ALARM RING PROVIDER (alarm_ring_provider.dart) ====================

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:wake_up_new/core/services/alarm_ring_service.dart';
import 'package:wake_up_new/core/services/alarm_service.dart';
import 'package:wake_up_new/features/provider/alarm_provider.dart';
import 'package:wake_up_new/main.dart';

class AlarmRingProvider extends ChangeNotifier {
  final int alarmId;
  final AlarmProvider alarmProvider;

  AlarmRingProvider({
    required this.alarmId,
    required this.alarmProvider,
  }) {
    _initialize();
  }

  // ================= STATE VARIABLES =================

  bool _checking = false;
  String _statusText = 'Waiting for preparation to complete...';

  Timer? _prepTimer;
  int _remainingSeconds = 30;
  bool _prepComplete = false;
  bool _manualCheckEnabled = false;

  Timer? _autoSnoozeTimer;
  int _totalTimeLimit = 90;
  bool _autoSnoozed = false;

  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isDetecting = false;
  Timer? _detectionTimer;
  double _sleepinessScore = 0.0;
  String _sleepinessLevel = 'Initializing...';
  bool _showCamera = false;

  bool _isDisposed = false;

  // ================= GETTERS =================

  bool get checking => _checking;
  String get statusText => _statusText;
  int get remainingSeconds => _remainingSeconds;
  bool get prepComplete => _prepComplete;
  bool get manualCheckEnabled => _manualCheckEnabled;
  bool get autoSnoozed => _autoSnoozed;
  int get totalTimeLimit => _totalTimeLimit;
  CameraController? get cameraController => _cameraController;
  double get sleepinessScore => _sleepinessScore;
  String get sleepinessLevel => _sleepinessLevel;
  bool get showCamera => _showCamera;

  int get remainingBeforeSnooze {
    final elapsedTime = 30 - _remainingSeconds;
    return _totalTimeLimit - elapsedTime;
  }

  // ================= INITIALIZATION =================

  void _initialize() {
    AlarmRingService.stopRinging();
    debugPrint('🔕 Alarm stopped - AlarmRingScreen opened');

    _requestCameraPermission();
    _startPrepTimer();
    _startAutoSnoozeTimer();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      debugPrint('✅ Camera permission granted');
    } else {
      debugPrint('❌ Camera permission denied');
    }
  }

  // ================= PREPARATION TIMER =================

  void _startPrepTimer() {
    debugPrint('⏱️ Starting 30-second preparation timer');

    _prepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      _remainingSeconds--;

      if (_remainingSeconds <= 10 && !_manualCheckEnabled) {
        _manualCheckEnabled = true;
        _statusText = 'Ready! Click "I am awake" to start face verification.';
        debugPrint('✅ Manual check enabled');
      }

      if (_remainingSeconds <= 0) {
        _prepComplete = true;
        _manualCheckEnabled = true;
        _statusText = 'Preparation complete! Click "I am awake" to verify.';
        timer.cancel();
        debugPrint('✅ Preparation timer complete');
      } else if (!_manualCheckEnabled) {
        _statusText = 'Get Ready... Time remaining: ${_remainingSeconds}s';
      }

      notifyListeners();
    });
  }

  // ================= AUTO-SNOOZE TIMER =================

  void _startAutoSnoozeTimer() {
    debugPrint('⏰ Starting auto-snooze timer: ${_totalTimeLimit}s');

    _autoSnoozeTimer = Timer(Duration(seconds: _totalTimeLimit), () async {
      if (!_autoSnoozed && !_isDisposed) {
        debugPrint('😴 User did not verify in time - triggering auto-snooze');

        _autoSnoozed = true;
        _statusText = 'Time expired! New alarm created for 1 minute...';
        notifyListeners();

        await _triggerAutoSnooze();
      }
    });
  }

  Future<void> _triggerAutoSnooze() async {
    final newAlarmId = await alarmProvider.createAutoSnoozeAlarm(
      originalAlarmId: alarmId,
      snoozeDelay: const Duration(minutes: 1),
    );

    if (newAlarmId != null) {
      debugPrint('✅ Auto-snooze successful. New alarm ID: $newAlarmId');
    } else {
      debugPrint('❌ Auto-snooze failed');
    }
  }

  // ================= CAMERA & DETECTION =================

  Future<void> initializeCameraAndDetection() async {
    try {
      _statusText = 'Initializing camera...';
      _showCamera = true;
      notifyListeners();

      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (_isDisposed) return;

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableTracking: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      _detectionTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        _detectSleepiness();
      });

      _statusText = 'Camera ready! Keep your face visible and eyes open...';
      notifyListeners();

      debugPrint('✅ Camera and detection initialized');
    } catch (e) {
      debugPrint('❌ Error initializing camera: $e');
      _statusText = 'Camera initialization failed. Please try again.';
      notifyListeners();
    }
  }

  Future<void> _detectSleepiness() async {
    if (_isDetecting || _isDisposed || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _isDetecting = true;

    try {
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final faces = await _faceDetector!.processImage(inputImage);

      if (_isDisposed) return;

      if (faces.isNotEmpty) {
        final face = faces.first;

        final leftEye = face.leftEyeOpenProbability ?? 0.0;
        final rightEye = face.rightEyeOpenProbability ?? 0.0;
        final avgEyeOpen = (leftEye + rightEye) / 2;

        final sleepiness = 1.0 - avgEyeOpen;

        _sleepinessScore = sleepiness;

        if (sleepiness < 0.3) {
          _sleepinessLevel = 'Wide Awake 😊';
        } else if (sleepiness < 0.5) {
          _sleepinessLevel = 'Alert ✓';
        } else if (sleepiness < 0.7) {
          _sleepinessLevel = 'Drowsy ⚠️';
        } else {
          _sleepinessLevel = 'Very Sleepy 😴';
        }

        notifyListeners();

        debugPrint('👁️ Left: ${leftEye.toStringAsFixed(2)}, Right: ${rightEye.toStringAsFixed(2)}, Sleepiness: ${sleepiness.toStringAsFixed(2)}');
      } else {
        _sleepinessLevel = 'No face detected';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error detecting sleepiness: $e');
    } finally {
      _isDetecting = false;
    }
  }

  // ================= MANUAL EYE CHECK =================

  Future<bool> performManualEyeCheck() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return false;
    }

    try {
      int successCount = 0;

      _statusText = 'Analyzing... Keep your eyes open!';
      notifyListeners();

      for (int i = 0; i < 3; i++) {
        final picture = await _cameraController!.takePicture();
        final image = InputImage.fromFilePath(picture.path);
        final faces = await _faceDetector!.processImage(image);

        if (faces.isNotEmpty) {
          final face = faces.first;
          final left = face.leftEyeOpenProbability ?? 0.0;
          final right = face.rightEyeOpenProbability ?? 0.0;
          final avgEyeOpen = (left + right) / 2;

          debugPrint('Check ${i + 1}/3: Left: ${left.toStringAsFixed(2)}, Right: ${right.toStringAsFixed(2)}, Avg: ${avgEyeOpen.toStringAsFixed(2)}');

          if (avgEyeOpen > 0.6) {
            successCount++;
            _statusText = 'Check ${i + 1}/3: Eyes detected open ✓';
          } else {
            _statusText = 'Check ${i + 1}/3: Eyes appear closed ✗';
          }
        } else {
          _statusText = 'Check ${i + 1}/3: No face detected ✗';
        }

        notifyListeners();

        if (i < 2) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }

      debugPrint('✅ Manual check complete: $successCount/3 successful');
      return successCount >= 2;
    } catch (e) {
      debugPrint('❌ Error in manual eye check: $e');
      return false;
    }
  }

  // ================= CHECK AWAKE FLOW =================

  Future<bool> checkAwake() async {
    if (_checking || _autoSnoozed) return false;

    if (!_manualCheckEnabled) {
      _statusText = 'Manual check available in ${_remainingSeconds} seconds';
      notifyListeners();
      return false;
    }

    _checking = true;
    notifyListeners();

    // Initialize camera if not already done
    if (_cameraController == null) {
      await initializeCameraAndDetection();
      await Future.delayed(const Duration(seconds: 2));
    }

    final awake = await performManualEyeCheck();

    if (_isDisposed) return false;

    if (awake) {
      _statusText = 'Verification successful! You are awake ✔';
      notifyListeners();
      await Future.delayed(const Duration(seconds: 1));
      return true; // Success - caller should dismiss alarm
    } else {
      _checking = false;
      _statusText = 'Verification failed. Please keep your eyes open and try again 👀';
      notifyListeners();
      return false;
    }
  }

  // ================= DISMISS ALARM =================

  Future<void> dismissAlarm() async {
    _autoSnoozeTimer?.cancel();
    _autoSnoozed = true;

    await AlarmRingService.stopRinging();
    await AlarmService.cancelAlarm(alarmId);
    await notificationsPlugin.cancel(alarmId);

    debugPrint('✅ Alarm dismissed');
  }

  // ================= CLEANUP =================

  @override
  void dispose() {
    _isDisposed = true;

    _prepTimer?.cancel();
    _detectionTimer?.cancel();
    _autoSnoozeTimer?.cancel();

    _cameraController?.dispose();
    _faceDetector?.close();

    AlarmRingService.stopRinging();

    super.dispose();
  }
}