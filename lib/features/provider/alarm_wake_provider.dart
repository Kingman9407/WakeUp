import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class AlarmWakeProvider extends ChangeNotifier {
  CameraController? _cameraController;
  CameraDescription? _camera;
  late final FaceDetector _faceDetector;

  bool _faceDetected = false;
  bool _isAwake = false;
  bool _isDisposed = false;
  bool _isProcessing = false;

  int _consecutiveDetections = 0;
  int _frameCount = 0;

  // ================= GETTERS =================

  CameraController? get cameraController => _cameraController;
  bool get faceDetected => _faceDetected;
  bool get isAwake => _isAwake;
  int get consecutiveDetections => _consecutiveDetections;

  // ================= CONSTRUCTOR =================

  AlarmWakeProvider() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false, // ❌ Eye prob unreliable
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initCamera();
  }

  // ================= CAMERA INIT =================

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      _camera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        _camera!,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21, // REQUIRED
      );

      await _cameraController!.initialize();
      if (_isDisposed) return;

      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 400));

      await _cameraController!.startImageStream(_processImage);
    } catch (e) {
      debugPrint('❌ Camera init error: $e');
    }
  }

  // ================= IMAGE PROCESSING =================

  Future<void> _processImage(CameraImage image) async {
    _frameCount++;

    // Process ~1 frame per second
    if (_frameCount % 30 != 0) return;
    if (_isProcessing || _isAwake || _isDisposed) return;

    _isProcessing = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (_isDisposed) return;

      if (faces.isNotEmpty) {
        final face = faces.first;

        final yaw = face.headEulerAngleY ?? 0;   // left-right
        final pitch = face.headEulerAngleX ?? 0; // up-down

        debugPrint('🧠 yaw=$yaw pitch=$pitch');

        final isMoving =
            yaw.abs() > 10 || pitch.abs() > 10;

        if (isMoving) {
          _faceDetected = true;
          _consecutiveDetections++;

          debugPrint('✅ Movement $_consecutiveDetections');

          if (_consecutiveDetections >= 3) {
            _isAwake = true;
            debugPrint('🎉 USER IS AWAKE');
          }
        } else {
          _resetDetection();
        }
      } else {
        _resetDetection();
      }
    } catch (e) {
      debugPrint('⚠️ Face detection error: $e');
      _resetDetection();
    } finally {
      _isProcessing = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  // ================= INPUT IMAGE BUILDER =================

  InputImage? _buildInputImage(CameraImage image) {
    if (_camera == null) return null;

    try {
      final WriteBuffer buffer = WriteBuffer();
      for (final plane in image.planes) {
        buffer.putUint8List(plane.bytes);
      }

      final bytes = buffer.done().buffer.asUint8List();

      final rotation =
      _camera!.lensDirection == CameraLensDirection.front
          ? InputImageRotation.rotation270deg
          : InputImageRotation.rotation0deg;

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: metadata,
      );
    } catch (e) {
      debugPrint('❌ InputImage error: $e');
      return null;
    }
  }

  // ================= HELPERS =================

  void _resetDetection() {
    _faceDetected = false;
    _consecutiveDetections = 0;
  }

  // ================= DISPOSE =================

  @override
  void dispose() {
    _isDisposed = true;

    if (_cameraController?.value.isStreamingImages == true) {
      _cameraController?.stopImageStream();
    }

    _cameraController?.dispose();
    _faceDetector.close();

    super.dispose();
  }
}
